extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const PIERCING_ARROW_SCENE := preload("res://effects/projectiles/piercing_arrow.tscn")
const MELEE_UTILS := preload("res://combat/melee_utils.gd")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const RANGER_BODY_TEXTURE_PATH := "res://actors/bosses/textures/ranger_boss.png"
const RANGER_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_ranger_blade.png"
const MELEE_EFFECT_TEXTURE_PATH := "res://assets/effects/vfx/magic_circle.webp"

@export var max_hp: float = 3600.0
@export var defense_value: float = 190.0
@export var move_speed: float = 210.0
@export var attack_damage: float = 42.0
@export var attack_range: float = 92.0
@export var attack_arc_degrees: float = 112.0
@export var attack_interval: float = 1.35
@export var skill_cycle_interval: float = 7.0
@export var skill_cycle_initial_delay: float = 3.0

@export var cloud_arrow_damage: float = 60.0
@export var cloud_arrow_charge_duration: float = 0.75
@export var cloud_arrow_spread_degrees: float = 11.0
@export var cloud_arrow_wave_delay: float = 0.22
@export var cloud_arrow_fan_count: int = 5
@export var cloud_arrow_speed: float = 560.0

@export var shadow_step_duration: float = 2.8
@export var shadow_step_damage_reduction: float = 0.9
@export var shadow_step_orbit_duration: float = 2.2
@export var shadow_step_speed: float = 370.0
@export var shadow_step_orbit_radius: float = 300.0
@export var shadow_shockwave_charge_duration: float = 0.85
@export var shadow_shockwave_radius: float = 170.0
@export var shadow_shockwave_damage: float = 50.0
@export var shadow_burst_interval: float = 0.48
@export var shadow_burst_projectiles: int = 8
@export var shadow_burst_damage: float = 26.0
@export var shadow_burst_speed: float = 330.0

@export var assassination_damage: float = 46.0
@export var assassination_first_charge_duration: float = 1.0
@export var assassination_followup_charge_duration: float = 0.3
@export var assassination_first_lock_time: float = 0.55
@export var assassination_dash_speed: float = 1120.0
@export var assassination_dash_width: float = 38.0
@export var assassination_dash_overshoot: float = 150.0
@export var assassination_reappear_distance: float = 200.0
@export var assassination_pentagram_charge_duration: float = 0.8
@export var assassination_pentagram_radius: float = 150.0
@export var assassination_pentagram_dash_total_duration: float = 0.8

@onready var body: Polygon2D = $Body
@onready var weapon: Node2D = $Weapon
@onready var aim_ring: Line2D = $AimRing
@onready var assassination_mark: Line2D = $AssassinationMark
@onready var projectile_spawner: Node2D = $ProjectileSpawner
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

var target: Node2D = null
var hp: float = 0.0
var state: StringName = &"idle"
var state_time: float = 0.0
var recover_duration: float = 0.0
var attack_cooldown: float = 0.0
var skill_cycle_remaining: float = 0.0
var action_committed: bool = false
var invulnerable: bool = false
var line_direction: Vector2 = Vector2.RIGHT
var shadow_orbit_direction: float = 1.0
var shadow_afterimage_timer: float = 0.0
var shadow_burst_next_time: float = 0.0
var shadow_damage_reduction_time_remaining: float = 0.0
var active_skill_target: Node2D = null
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0
var body_sprite: Sprite2D = null
var weapon_sprite: Sprite2D = null
var weapon_angle_offset: float = 0.0
var melee_texture: Texture2D = null
var visual_last_position: Vector2 = Vector2.ZERO
var visual_bob_time: float = 0.0
var skill_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var cloud_arrow_wave_count: int = 0
var cloud_arrow_waves_fired: int = 0
var cloud_arrow_next_wave_time: float = 0.0
var cloud_arrow_locked_direction: Vector2 = Vector2.RIGHT
var cloud_arrow_left_marker: Line2D = null
var cloud_arrow_right_marker: Line2D = null
var cloud_arrow_pending_relock: bool = false

var assassination_anchor_position: Vector2 = Vector2.ZERO
var assassination_locked_position: Vector2 = Vector2.ZERO
var assassination_lock_captured: bool = false
var assassination_dash_index: int = 0
var assassination_dash_total: int = 0
var assassination_dash_start: Vector2 = Vector2.ZERO
var assassination_dash_end: Vector2 = Vector2.ZERO
var assassination_dash_duration: float = 0.0
var assassination_dash_hit_targets: Array[Node] = []
var assassination_path_points: Array[Vector2] = []
var assassination_followup_target_position: Vector2 = Vector2.ZERO
var assassination_pentagram_repeat_index: int = 0
var assassination_pentagram_repeat_total: int = 3

func _ready() -> void:
	add_to_group("damageable")
	skill_rng.randomize()
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.healed.connect(_on_healed)
	health_component.died.connect(_on_died)
	hp = max_hp
	skill_cycle_remaining = skill_cycle_initial_delay
	visual_last_position = global_position
	melee_texture = TEXTURE_LOADER.load_texture(MELEE_EFFECT_TEXTURE_PATH)
	_setup_body_visual()
	_setup_weapon_visual()
	_setup_cloud_arrow_markers()
	_hide_skill_markers()
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func get_status_title() -> String:
	return "Shadow Huntress"

func get_status_text() -> String:
	var shadow_text := " | Shadow DR" if shadow_damage_reduction_time_remaining > 0.0 else ""
	return "HP %d / %d\nSkill %.1fs%s\nState: %s" % [
		int(round(hp)),
		int(round(max_hp)),
		skill_cycle_remaining,
		shadow_text,
		String(state)
	]

func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	if target == null or not _is_targetable_player(target):
		_find_target()
	_update_status_timers(delta)
	_update_shadow_damage_reduction(delta)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	skill_cycle_remaining = maxf(skill_cycle_remaining - delta, 0.0)
	state_time += delta
	_update_state(delta)
	_update_visuals()

func receive_hit(payload: Dictionary) -> void:
	if invulnerable or state == &"dead":
		return
	var result: Dictionary = health_component.receive_hit(payload)
	var final_damage := float(result.get("damage", 0.0))
	if final_damage > 0.0:
		apply_control_effects(payload)
		_spawn_damage_number(final_damage, bool(result.get("is_critical", false)))

func apply_control_effects(payload: Dictionary) -> void:
	if payload.has("silence_duration"):
		silenced_time_remaining = maxf(silenced_time_remaining, float(payload["silence_duration"]))
	if payload.has("root_duration"):
		root_time_remaining = maxf(root_time_remaining, float(payload["root_duration"]))
	if payload.has("slow_duration"):
		slow_time_remaining = maxf(slow_time_remaining, float(payload["slow_duration"]))
		slow_factor = minf(slow_factor, float(payload.get("slow_multiplier", 1.0)))

func _find_target() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if _is_targetable_player(player):
			target = player
			return
	target = null

func _is_targetable_player(candidate: Variant) -> bool:
	if candidate == null or not (candidate is Node2D):
		return false
	var actor: Node2D = candidate
	if not is_instance_valid(actor):
		return false
	if actor.has_method("is_detectable") and not bool(actor.is_detectable()):
		return false
	var hp_value: Variant = actor.get("hp")
	return hp_value == null or float(hp_value) > 0.0

func _update_status_timers(delta: float) -> void:
	silenced_time_remaining = maxf(silenced_time_remaining - delta, 0.0)
	root_time_remaining = maxf(root_time_remaining - delta, 0.0)
	if slow_time_remaining > 0.0:
		slow_time_remaining = maxf(slow_time_remaining - delta, 0.0)
	else:
		slow_factor = 1.0

func _update_shadow_damage_reduction(delta: float) -> void:
	if shadow_damage_reduction_time_remaining <= 0.0:
		return
	shadow_damage_reduction_time_remaining = maxf(shadow_damage_reduction_time_remaining - delta, 0.0)
	if shadow_damage_reduction_time_remaining <= 0.0:
		health_component.set_damage_reduction(0.0)

func _update_state(delta: float) -> void:
	match state:
		&"idle":
			_process_idle(delta)
		&"basic_attack":
			_process_basic_attack()
		&"skill1_charge":
			_process_skill1_charge()
		&"skill1_fire":
			_process_skill1_fire()
		&"skill2_shadow":
			_process_skill2_shadow(delta)
		&"skill2_shockwave_charge":
			_process_skill2_shockwave_charge()
		&"skill3_charge":
			_process_skill3_charge()
		&"skill3_dash":
			_process_skill3_dash()
		&"skill3_pentagram_charge":
			_process_skill3_pentagram_charge()
		&"skill3_pentagram_dash":
			_process_skill3_pentagram_dash()
		&"recover":
			_process_recover()

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target != Vector2.ZERO:
		line_direction = to_target.normalized()
	if _can_use_skills() and skill_cycle_remaining <= 0.0:
		_start_random_skill()
		return
	if attack_cooldown <= 0.0 and distance <= attack_range:
		_start_basic_attack()
		return
	if root_time_remaining > 0.0:
		return
	var speed := move_speed * slow_factor
	var tangent := Vector2(-line_direction.y, line_direction.x) * shadow_orbit_direction
	if distance > attack_range * 0.86:
		global_position += (line_direction + tangent * 0.22).normalized() * speed * delta
	elif distance < attack_range * 0.58:
		global_position -= line_direction * speed * 0.7 * delta
	else:
		if state_time >= 0.44:
			state_time = 0.0
			shadow_orbit_direction *= -1.0
			tangent = Vector2(-line_direction.y, line_direction.x) * shadow_orbit_direction
		global_position += tangent.normalized() * speed * 0.42 * delta

func _start_basic_attack() -> void:
	state = &"basic_attack"
	state_time = 0.0
	action_committed = false
	attack_cooldown = _get_attack_interval()
	_animate_weapon_swing(-32.0, 14.0, 0.2)
	Sfx.play_event(&"ranger_attack", global_position)

func _process_basic_attack() -> void:
	if not action_committed and state_time >= 1.0:
		action_committed = true
		_hit_target_in_arc(attack_range, attack_damage, attack_arc_degrees)
		_spawn_slash_effect(attack_range, Color(0.88, 1.0, 0.76, 0.92))
	if state_time >= 1.24:
		_enter_recover(0.16)
func _start_random_skill() -> void:
	skill_cycle_remaining = skill_cycle_interval
	match skill_rng.randi_range(0, 2):
		0:
			_start_skill1()
		1:
			_start_skill2()
		_:
			_start_skill3()

func _start_skill1() -> void:
	state = &"skill1_charge"
	state_time = 0.0
	action_committed = false
	cloud_arrow_wave_count = 3 if _is_half_health() else 1
	cloud_arrow_waves_fired = 0
	cloud_arrow_next_wave_time = 0.0
	cloud_arrow_pending_relock = false
	_update_line_direction_to_target()
	cloud_arrow_locked_direction = line_direction if line_direction.length_squared() > 0.0001 else Vector2.RIGHT
	_show_cloud_arrow_markers(cloud_arrow_locked_direction)
	_animate_weapon_swing(-28.0, 10.0, cloud_arrow_charge_duration)

func _process_skill1_charge() -> void:
	_show_cloud_arrow_markers(cloud_arrow_locked_direction)
	if state_time < cloud_arrow_charge_duration:
		return
	state = &"skill1_fire"
	state_time = 0.0
	cloud_arrow_waves_fired = 0
	cloud_arrow_next_wave_time = 0.0
	_fire_cloud_arrow_wave()
	cloud_arrow_waves_fired += 1
	cloud_arrow_next_wave_time += cloud_arrow_wave_delay

func _process_skill1_fire() -> void:
	while cloud_arrow_waves_fired < cloud_arrow_wave_count and state_time >= cloud_arrow_next_wave_time:
		if cloud_arrow_pending_relock:
			_relock_cloud_arrow_direction_from_target()
		cloud_arrow_pending_relock = false
		_fire_cloud_arrow_wave()
		cloud_arrow_waves_fired += 1
		cloud_arrow_next_wave_time += cloud_arrow_wave_delay
		cloud_arrow_pending_relock = cloud_arrow_waves_fired < cloud_arrow_wave_count
	var final_wave_time := maxf(float(cloud_arrow_wave_count - 1) * cloud_arrow_wave_delay, 0.0)
	if cloud_arrow_waves_fired >= cloud_arrow_wave_count and state_time >= final_wave_time + 0.16:
		_hide_cloud_arrow_markers()
		_enter_recover(0.16)

func _fire_cloud_arrow_wave() -> void:
	var base_direction := cloud_arrow_locked_direction if cloud_arrow_locked_direction != Vector2.ZERO else Vector2.RIGHT
	var spread_step := deg_to_rad(cloud_arrow_spread_degrees)
	var center_index := float(cloud_arrow_fan_count - 1) * 0.5
	for index in range(cloud_arrow_fan_count):
		var offset := (float(index) - center_index) * spread_step
		_spawn_piercing_arrow(base_direction.rotated(offset), cloud_arrow_damage)
	Sfx.play_event(&"ranger_skill1_arrow", projectile_spawner.global_position)

func _relock_cloud_arrow_direction_from_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target.length_squared() <= 0.0001:
		return
	cloud_arrow_locked_direction = to_target.normalized()
	_show_cloud_arrow_markers(cloud_arrow_locked_direction)

func _start_skill2() -> void:
	state = &"skill2_shadow"
	state_time = 0.0
	action_committed = false
	shadow_orbit_direction *= -1.0
	shadow_afterimage_timer = 0.0
	shadow_burst_next_time = 0.22
	shadow_damage_reduction_time_remaining = shadow_step_duration
	health_component.set_damage_reduction(shadow_step_damage_reduction)
	_hide_skill_markers()
	Sfx.play_event(&"ranger_skill2_roll", global_position)

func _process_skill2_shadow(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var elapsed := minf(state_time, shadow_step_orbit_duration)
		var target_offset_angle := elapsed * 3.1 * shadow_orbit_direction
		var desired_position := target.global_position + Vector2.RIGHT.rotated(target_offset_angle) * shadow_step_orbit_radius
		global_position = global_position.move_toward(desired_position, shadow_step_speed * slow_factor * delta)
		_update_line_direction_to_target()
	shadow_afterimage_timer -= delta
	if shadow_afterimage_timer <= 0.0:
		shadow_afterimage_timer = 0.055
		_spawn_afterimage()
	while state_time >= shadow_burst_next_time:
		_fire_shadow_burst()
		shadow_burst_next_time += shadow_burst_interval
	if state_time >= shadow_step_duration:
		_start_shadow_shockwave_charge()

func _start_shadow_shockwave_charge() -> void:
	state = &"skill2_shockwave_charge"
	state_time = 0.0
	action_committed = false
	_show_ring_marker(global_position, shadow_shockwave_radius, Color(0.76, 0.94, 1.0, 0.84))

func _process_skill2_shockwave_charge() -> void:
	_show_ring_marker(global_position, shadow_shockwave_radius, Color(0.76, 0.94, 1.0, 0.84))
	if state_time < shadow_shockwave_charge_duration:
		return
	if not action_committed:
		action_committed = true
		assassination_mark.visible = false
		_hit_targets_in_radius(global_position, shadow_shockwave_radius, shadow_shockwave_damage)
		_spawn_radius_burst(global_position, shadow_shockwave_radius, Color(0.72, 0.92, 1.0, 0.9))
		Sfx.play_event(&"ranger_skill2_roll", global_position)
		_enter_recover(0.2)

func _start_skill3() -> void:
	active_skill_target = target
	assassination_anchor_position = target.global_position if target != null and is_instance_valid(target) else global_position + line_direction * 160.0
	assassination_followup_target_position = assassination_anchor_position
	assassination_dash_index = 0
	assassination_dash_hit_targets.clear()
	_hide_skill_markers()
	_animate_weapon_swing(-34.0, 12.0, 0.18)
	Sfx.play_event(&"ranger_skill3_assassinate", global_position)
	if _is_half_health():
		_start_pentagram_assassination()
	else:
		assassination_dash_total = 3
		assassination_lock_captured = false
		assassination_locked_position = assassination_anchor_position
		_start_assassination_charge()

func _start_assassination_charge() -> void:
	state = &"skill3_charge"
	state_time = 0.0
	action_committed = false
	assassination_dash_hit_targets.clear()
	if assassination_dash_index <= 0:
		assassination_lock_captured = false
		_update_line_direction_to_target()
		_show_line_marker(global_position, global_position + line_direction * 260.0, 5.0, Color(1.0, 0.48, 0.42, 0.84))
	else:
		_prepare_followup_assassination_dash()

func _process_skill3_charge() -> void:
	var charge_duration := _current_assassination_charge_duration()
	if assassination_dash_index <= 0:
		if not assassination_lock_captured and state_time >= assassination_first_lock_time:
			_capture_first_assassination_target()
		elif not assassination_lock_captured:
			_update_line_direction_to_target()
			_show_line_marker(global_position, global_position + line_direction * 260.0, 5.0, Color(1.0, 0.48, 0.42, 0.84))
	if state_time < charge_duration:
		return
	if assassination_dash_index <= 0 and not assassination_lock_captured:
		_capture_first_assassination_target()
	_begin_assassination_dash()

func _capture_first_assassination_target() -> void:
	assassination_locked_position = target.global_position if target != null and is_instance_valid(target) else assassination_anchor_position
	assassination_anchor_position = assassination_locked_position
	_prepare_first_assassination_dash(assassination_locked_position)
	assassination_lock_captured = true

func _prepare_first_assassination_dash(lock_position: Vector2) -> void:
	var direction := lock_position - global_position
	line_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	assassination_dash_start = global_position
	assassination_dash_end = lock_position + line_direction * assassination_dash_overshoot
	assassination_dash_duration = _dash_duration_between(assassination_dash_start, assassination_dash_end)
	_show_line_marker(assassination_dash_start, assassination_dash_end, 5.0, Color(1.0, 0.48, 0.42, 0.9))

func _prepare_followup_assassination_dash() -> void:
	var old_position := global_position
	var lock_position := assassination_followup_target_position
	if lock_position == Vector2.ZERO:
		lock_position = assassination_anchor_position
	var spawn_direction := Vector2.RIGHT.rotated(TAU * skill_rng.randf())
	global_position = lock_position + spawn_direction * assassination_reappear_distance
	_spawn_afterimage_at(old_position)
	_spawn_afterimage()
	var facing := (lock_position - global_position).normalized() if lock_position.distance_squared_to(global_position) > 0.0001 else Vector2.RIGHT
	line_direction = facing
	assassination_dash_start = global_position
	assassination_dash_end = lock_position + facing * assassination_dash_overshoot
	assassination_dash_duration = _dash_duration_between(assassination_dash_start, assassination_dash_end)
	_show_line_marker(assassination_dash_start, assassination_dash_end, 5.0, Color(1.0, 0.48, 0.42, 0.9))

func _begin_assassination_dash() -> void:
	state = &"skill3_dash"
	state_time = 0.0
	action_committed = false
	assassination_dash_hit_targets.clear()
	aim_ring.visible = false
	_spawn_dash_impact(assassination_dash_start, assassination_dash_end, assassination_dash_width, Color(1.0, 0.54, 0.44, 0.88))

func _process_skill3_dash() -> void:
	var previous_position := global_position
	var progress := clampf(state_time / maxf(assassination_dash_duration, 0.01), 0.0, 1.0)
	global_position = assassination_dash_start.lerp(assassination_dash_end, progress)
	line_direction = (assassination_dash_end - assassination_dash_start).normalized()
	_hit_targets_between(previous_position, global_position, assassination_dash_width, assassination_damage)
	if progress >= 1.0:
		assassination_followup_target_position = target.global_position if target != null and is_instance_valid(target) else assassination_followup_target_position
		assassination_dash_index += 1
		if assassination_dash_index < assassination_dash_total:
			_start_assassination_charge()
		else:
			_enter_recover(0.24)

func _start_pentagram_assassination() -> void:
	state = &"skill3_pentagram_charge"
	state_time = 0.0
	action_committed = false
	assassination_dash_total = 5
	assassination_dash_index = 0
	assassination_pentagram_repeat_index = 0
	assassination_followup_target_position = assassination_anchor_position
	_build_pentagram_path(assassination_anchor_position, assassination_pentagram_radius * 1.5)
	_show_pentagram_marker(assassination_anchor_position)

func _process_skill3_pentagram_charge() -> void:
	_show_pentagram_marker(assassination_anchor_position)
	if state_time < assassination_pentagram_charge_duration:
		return
	assassination_mark.visible = false
	_start_pentagram_dash_segment()

func _start_pentagram_dash_segment() -> void:
	if assassination_dash_index >= assassination_dash_total or assassination_path_points.size() < assassination_dash_index + 2:
		_enter_recover(0.28)
		return
	var old_position := global_position
	assassination_dash_start = assassination_path_points[assassination_dash_index]
	assassination_dash_end = assassination_path_points[assassination_dash_index + 1]
	var direction := assassination_dash_end - assassination_dash_start
	line_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	_spawn_afterimage_at(old_position)
	global_position = assassination_dash_start
	_spawn_afterimage()
	assassination_dash_duration = assassination_pentagram_dash_total_duration / 5.0
	assassination_dash_hit_targets.clear()
	state = &"skill3_pentagram_dash"
	state_time = 0.0
	action_committed = false
	_spawn_dash_impact(assassination_dash_start, assassination_dash_end, assassination_dash_width, Color(1.0, 0.58, 0.48, 0.9))

func _process_skill3_pentagram_dash() -> void:
	var previous_position := global_position
	var progress := clampf(state_time / maxf(assassination_dash_duration, 0.01), 0.0, 1.0)
	global_position = assassination_dash_start.lerp(assassination_dash_end, progress)
	line_direction = (assassination_dash_end - assassination_dash_start).normalized()
	_hit_targets_between(previous_position, global_position, assassination_dash_width, assassination_damage)
	if progress >= 1.0:
		assassination_dash_index += 1
		if assassination_dash_index < assassination_dash_total:
			_start_pentagram_dash_segment()
		else:
			assassination_pentagram_repeat_index += 1
			if assassination_pentagram_repeat_index < assassination_pentagram_repeat_total:
				assassination_dash_index = 0
				assassination_anchor_position = target.global_position if target != null and is_instance_valid(target) else assassination_anchor_position
				assassination_followup_target_position = assassination_anchor_position
				_build_pentagram_path(assassination_anchor_position, assassination_pentagram_radius * 1.5)
				state = &"skill3_pentagram_charge"
				state_time = 0.0
				action_committed = false
				_show_pentagram_marker(assassination_anchor_position)
			else:
				_enter_recover(0.16)
func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	recover_duration = duration
	active_skill_target = null
	_hide_skill_markers()

func _process_recover() -> void:
	if state_time >= recover_duration:
		state = &"idle"
		state_time = 0.0

func _can_use_skills() -> bool:
	return silenced_time_remaining <= 0.0

func _get_attack_interval() -> float:
	return attack_interval

func _is_half_health() -> bool:
	return hp > 0.0 and hp <= max_hp * 0.5

func _current_assassination_charge_duration() -> float:
	if assassination_dash_index <= 0:
		return assassination_first_charge_duration
	if _is_half_health():
		return assassination_pentagram_charge_duration
	return assassination_followup_charge_duration

func _update_line_direction_to_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target.length_squared() > 0.0001:
		line_direction = to_target.normalized()

func _hit_target_in_arc(radius: float, damage: float, arc_degrees: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not MELEE_UTILS.is_point_in_arc(global_position, line_direction, target.global_position, radius, arc_degrees):
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.12
	})

func _hit_targets_in_radius(center: Vector2, radius: float, damage: float) -> void:
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate == self or not (candidate is Node2D):
			continue
		if not candidate.has_method("receive_hit"):
			continue
		var node_2d: Node2D = candidate
		if node_2d.global_position.distance_to(center) > radius:
			continue
		candidate.receive_hit({
			"source": self,
			"damage": damage,
			"crit_rate": 0.0
		})

func _hit_targets_between(start_position: Vector2, end_position: Vector2, width: float, damage: float) -> void:
	if start_position == end_position:
		return
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate == self or not (candidate is Node2D):
			continue
		if assassination_dash_hit_targets.has(candidate):
			continue
		if not candidate.has_method("receive_hit"):
			continue
		var node_2d: Node2D = candidate
		if _distance_to_segment(node_2d.global_position, start_position, end_position) > width:
			continue
		assassination_dash_hit_targets.append(candidate)
		candidate.receive_hit({
			"source": self,
			"damage": damage,
			"crit_rate": 0.0
		})

func _spawn_piercing_arrow(direction: Vector2, damage: float) -> void:
	var arrow := PIERCING_ARROW_SCENE.instantiate()
	arrow.global_position = projectile_spawner.global_position
	get_tree().current_scene.add_child(arrow)
	arrow.setup(self, direction, damage, 0.0)
	if "speed" in arrow:
		arrow.speed = cloud_arrow_speed

func _fire_shadow_burst() -> void:
	for index in range(shadow_burst_projectiles):
		var angle := TAU * float(index) / float(shadow_burst_projectiles) + state_time * 0.7 * shadow_orbit_direction
		var direction := Vector2.RIGHT.rotated(angle)
		var arrow := PIERCING_ARROW_SCENE.instantiate()
		arrow.global_position = global_position + direction * 22.0
		get_tree().current_scene.add_child(arrow)
		arrow.setup(self, direction, shadow_burst_damage, 0.0)
		if "speed" in arrow:
			arrow.speed = shadow_burst_speed

func _show_line_marker(start_position: Vector2, end_position: Vector2, width: float, color: Color) -> void:
	var direction := end_position - start_position
	var length := direction.length()
	if length <= 0.001:
		return
	aim_ring.visible = true
	aim_ring.closed = false
	aim_ring.global_position = start_position
	aim_ring.rotation = direction.angle()
	aim_ring.width = width
	aim_ring.default_color = color
	aim_ring.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])

func _setup_cloud_arrow_markers() -> void:
	cloud_arrow_left_marker = _create_cloud_arrow_marker(Color(0.68, 1.0, 0.82, 0.7))
	cloud_arrow_right_marker = _create_cloud_arrow_marker(Color(0.68, 1.0, 0.82, 0.7))
	effects_layer.add_child(cloud_arrow_left_marker)
	effects_layer.add_child(cloud_arrow_right_marker)

func _create_cloud_arrow_marker(color: Color) -> Line2D:
	var marker := Line2D.new()
	marker.visible = false
	marker.width = 3.0
	marker.closed = false
	marker.default_color = color
	return marker

func _show_cloud_arrow_markers(direction: Vector2) -> void:
	var base_direction := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var spread := deg_to_rad(cloud_arrow_spread_degrees)
	_show_line_marker(global_position, global_position + base_direction * 320.0, 4.0, Color(0.72, 1.0, 0.86, 0.82))
	if cloud_arrow_left_marker != null:
		cloud_arrow_left_marker.visible = true
		cloud_arrow_left_marker.global_position = global_position
		cloud_arrow_left_marker.rotation = (base_direction.rotated(-spread)).angle()
		cloud_arrow_left_marker.points = PackedVector2Array([Vector2.ZERO, Vector2(320.0, 0.0)])
	if cloud_arrow_right_marker != null:
		cloud_arrow_right_marker.visible = true
		cloud_arrow_right_marker.global_position = global_position
		cloud_arrow_right_marker.rotation = (base_direction.rotated(spread)).angle()
		cloud_arrow_right_marker.points = PackedVector2Array([Vector2.ZERO, Vector2(320.0, 0.0)])

func _hide_cloud_arrow_markers() -> void:
	aim_ring.visible = false
	if cloud_arrow_left_marker != null:
		cloud_arrow_left_marker.visible = false
	if cloud_arrow_right_marker != null:
		cloud_arrow_right_marker.visible = false

func _show_ring_marker(center: Vector2, radius: float, color: Color) -> void:
	assassination_mark.visible = true
	assassination_mark.closed = true
	assassination_mark.global_position = center
	assassination_mark.rotation = 0.0
	assassination_mark.width = 4.0
	assassination_mark.default_color = color
	assassination_mark.points = _build_ring_points(radius, 24)

func _show_pentagram_marker(center: Vector2) -> void:
	if assassination_path_points.is_empty():
		return
	var points := PackedVector2Array()
	for point in assassination_path_points:
		points.append(point - center)
	assassination_mark.visible = true
	assassination_mark.closed = false
	assassination_mark.global_position = center
	assassination_mark.rotation = 0.0
	assassination_mark.width = 4.0
	assassination_mark.default_color = Color(1.0, 0.5, 0.42, 0.9)
	assassination_mark.points = points

func _hide_skill_markers() -> void:
	_hide_cloud_arrow_markers()
	assassination_mark.visible = false

func _build_pentagram_path(center: Vector2, radius: float) -> void:
	assassination_path_points.clear()
	var outer_points: Array[Vector2] = []
	for index in range(5):
		var angle := -PI * 0.5 + TAU * float(index) / 5.0
		outer_points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	for point_index in [0, 2, 4, 1, 3, 0]:
		assassination_path_points.append(outer_points[int(point_index)])

func _dash_duration_between(start_position: Vector2, end_position: Vector2) -> float:
	return maxf(start_position.distance_to(end_position) / maxf(assassination_dash_speed, 1.0), 0.08)

func _distance_to_segment(point: Vector2, start_position: Vector2, end_position: Vector2) -> float:
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(start_position)
	var weight := clampf((point - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := start_position + segment * weight
	return point.distance_to(closest_point)

func _spawn_slash_effect(radius: float, color: Color) -> void:
	if melee_texture != null:
		var texture_slash := Sprite2D.new()
		texture_slash.texture = melee_texture
		texture_slash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_slash.centered = true
		texture_slash.modulate = color
		texture_slash.position = line_direction * (radius * 0.42)
		texture_slash.rotation = line_direction.angle()
		texture_slash.scale = Vector2(0.22, 0.10)
		effects_layer.add_child(texture_slash)
		var texture_tween := texture_slash.create_tween()
		texture_tween.tween_property(texture_slash, "scale", Vector2(0.32, 0.16), 0.12)
		texture_tween.parallel().tween_property(texture_slash, "modulate:a", 0.0, 0.12)
		texture_tween.finished.connect(texture_slash.queue_free)
	var slash := Line2D.new()
	slash.width = 12.0
	slash.antialiased = true
	slash.default_color = color
	slash.position = line_direction * 12.0
	slash.rotation = line_direction.angle()
	slash.points = PackedVector2Array([
		Vector2(-6.0, -20.0),
		Vector2(radius * 0.28, -radius * 0.16),
		Vector2(radius * 0.82, 0.0),
		Vector2(radius * 0.28, radius * 0.16),
		Vector2(-6.0, 20.0)
	])
	effects_layer.add_child(slash)
	var tween := create_tween()
	tween.tween_property(slash, "scale", Vector2.ONE * 1.14, 0.12)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.12)
	tween.finished.connect(slash.queue_free)

func _spawn_radius_burst(center: Vector2, radius: float, color: Color) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var ring := Line2D.new()
	ring.width = 6.0
	ring.closed = true
	ring.default_color = color
	ring.points = _build_ring_points(radius, 24)
	ring.global_position = center
	scene_root.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.18, 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.finished.connect(ring.queue_free)

func _spawn_dash_impact(start_position: Vector2, end_position: Vector2, width: float, color: Color) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var direction := end_position - start_position
	var length := direction.length()
	if length <= 0.001:
		return
	var slash := Polygon2D.new()
	slash.color = color
	slash.global_position = start_position
	slash.rotation = direction.angle()
	slash.polygon = PackedVector2Array([
		Vector2(0.0, -width * 0.5),
		Vector2(length, -width * 0.5),
		Vector2(length, width * 0.5),
		Vector2(0.0, width * 0.5)
	])
	scene_root.add_child(slash)
	var tween := slash.create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.16)
	tween.parallel().tween_property(slash, "scale", Vector2(1.08, 1.04), 0.16)
	tween.finished.connect(slash.queue_free)

func _build_ring_points(radius: float, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _spawn_afterimage() -> void:
	_spawn_afterimage_at(global_position)

func _spawn_afterimage_at(world_position: Vector2) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var ghost := Polygon2D.new()
	ghost.polygon = body.polygon
	ghost.color = Color(0.64, 1.0, 0.86, 0.18)
	ghost.global_position = world_position
	ghost.rotation = body.rotation
	ghost.scale = body.scale
	scene_root.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(ghost, "scale", body.scale * 0.92, 0.18)
	tween.finished.connect(ghost.queue_free)

func _setup_body_visual() -> void:
	body_sprite = Sprite2D.new()
	body_sprite.texture = TEXTURE_LOADER.load_texture(RANGER_BODY_TEXTURE_PATH)
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_sprite.centered = true
	body_sprite.scale = Vector2.ONE * 0.33
	body.add_child(body_sprite)
	body.color = Color(1.0, 1.0, 1.0, 0.0)

func _set_body_tint(color: Color) -> void:
	if body_sprite != null:
		body_sprite.self_modulate = color
	else:
		body.color = color

func _setup_weapon_visual() -> void:
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture = TEXTURE_LOADER.load_texture(RANGER_WEAPON_TEXTURE_PATH)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = true
	weapon_sprite.scale = Vector2.ONE * 0.66
	weapon_sprite.position = Vector2(-60.0, 5.0)
	weapon.add_child(weapon_sprite)

func _animate_weapon_swing(start_degrees: float, end_degrees: float, duration: float) -> void:
	weapon_angle_offset = deg_to_rad(start_degrees)
	var tween := create_tween()
	tween.tween_property(self, "weapon_angle_offset", deg_to_rad(end_degrees), maxf(duration, 0.01))

func _update_visuals() -> void:
	if _should_face_target() and target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target != Vector2.ZERO:
			line_direction = to_target.normalized()
	var body_tint := Color.WHITE
	if silenced_time_remaining > 0.0:
		body_tint = Color(0.9, 0.82, 1.0, 1.0)
	elif shadow_damage_reduction_time_remaining > 0.0:
		body_tint = Color(0.76, 0.94, 1.0, 1.0)
	_set_body_tint(body_tint)
	body.modulate = Color(1.0, 1.0, 1.0, 0.36) if invulnerable else Color.WHITE
	if aim_ring.visible:
		var aim_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
		aim_ring.width = 4.0 + aim_pulse * 1.4
		aim_ring.modulate = Color(1.0, 1.0, 1.0, 0.78 + 0.12 * aim_pulse)
	if assassination_mark.visible:
		var mark_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.014)
		assassination_mark.width = 3.6 + mark_pulse * 1.2
		assassination_mark.modulate = Color(1.0, 1.0, 1.0, 0.76 + 0.14 * mark_pulse)
	weapon.position = line_direction * 18.0 + Vector2(0.0, -2.0)
	weapon.rotation = _weapon_guard_rotation(line_direction, -38.0) + weapon_angle_offset
	projectile_spawner.position = line_direction * 28.0
	_apply_agile_body_motion()
	visual_last_position = global_position

func _should_face_target() -> bool:
	return state in [
		&"idle",
		&"basic_attack",
		&"skill1_charge",
		&"skill1_fire",
		&"skill2_shadow",
		&"skill2_shockwave_charge",
		&"recover"
	]

func _weapon_guard_rotation(direction: Vector2, guard_degrees: float) -> float:
	var facing := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var side_sign := -1.0 if facing.x < -0.05 else 1.0
	return facing.angle() + deg_to_rad(guard_degrees * side_sign)

func _apply_agile_body_motion() -> void:
	var movement := global_position - visual_last_position
	var motion_ratio := clampf(movement.length() / maxf(move_speed * get_physics_process_delta_time(), 1.0), 0.0, 1.0)
	visual_bob_time += 0.11 + motion_ratio * 0.18
	var facing := -1.0 if line_direction.x < -0.05 else 1.0
	if body_sprite != null:
		body_sprite.flip_h = facing < 0.0
		body_sprite.position.x = sin(visual_bob_time * 0.85) * (1.0 + motion_ratio * 3.0) * facing
	body.position = Vector2(sin(visual_bob_time * 0.8) * motion_ratio * 3.2 * facing, sin(visual_bob_time) * (1.5 + motion_ratio * 3.8))
	body.rotation = sin(visual_bob_time * 0.7) * (0.03 + motion_ratio * 0.075) * facing

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -38.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _on_damaged(_amount: float, remaining_hp: float, _source: Node) -> void:
	hp = remaining_hp
	_set_body_tint(Color(1.0, 0.8, 0.8, 1.0))
	var timer := get_tree().create_timer(0.12)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and state != &"dead":
			_update_visuals()
	)

func _on_healed(_amount: float, current_hp: float) -> void:
	hp = current_hp

func _on_died() -> void:
	if state == &"dead":
		return
	hp = 0.0
	invulnerable = true
	state = &"dead"
	shadow_damage_reduction_time_remaining = 0.0
	health_component.set_damage_reduction(0.0)
	_hide_skill_markers()
	weapon.visible = false
	Sfx.play_event(&"boss_generic_dead", global_position)
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)
