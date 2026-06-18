extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ROYAL_BOLT_SCENE := preload("res://effects/projectiles/royal_bolt.tscn")
const MELEE_UTILS := preload("res://combat/melee_utils.gd")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const EMPEROR_BODY_TEXTURE_PATH := "res://actors/bosses/textures/emperor_boss.png"
const EMPEROR_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_emperor_sword.png"
const MELEE_EFFECT_TEXTURE_PATH := "res://assets/effects/vfx/magic_circle.webp"

@export var max_hp: float = 5000.0
@export var defense_value: float = 260.0
@export var move_speed: float = 150.0
@export var attack_damage: float = 42.0
@export var attack_range: float = 96.0
@export var attack_arc_degrees: float = 120.0
@export var attack_interval: float = 2.1
@export var phase_two_threshold: float = 2000.0
@export var phase_transition_duration: float = 0.9

@export var skill_interval: float = 5.8

@export var dash_charge_duration: float = 0.85
@export var dash_distance: float = 420.0
@export var dash_duration: float = 0.34
@export var dash_damage: float = 78.0
@export var dash_hit_radius: float = 82.0
@export var dash_lane_width: float = 34.0

@export var shock_charge_duration: float = 1.25
@export var shock_radius: float = 260.0
@export var shock_damage: float = 82.0
@export var shock_slow_duration: float = 3.0
@export var shock_slow_multiplier: float = 0.74
@export var shock_outer_ring_radius: float = 430.0
@export var shock_outer_ring_damage: float = 56.0

@export var volley_shot_count_phase_one: int = 18
@export var volley_shot_count_phase_two: int = 30
@export var volley_interval_phase_one: float = 0.18
@export var volley_interval_phase_two: float = 0.13
@export var volley_center_radius_phase_one: float = 150.0
@export var volley_center_radius_phase_two: float = 200.0
@export var volley_damage: float = 24.0
@export var volley_bullet_speed: float = 390.0
@export var volley_prediction_time: float = 0.34
@export var volley_ring_shots: int = 8

@onready var body: Polygon2D = $Body
@onready var weapon: Node2D = $Weapon
@onready var burst_ring: Line2D = $BurstRing
@onready var phase_ring: Line2D = $PhaseRing
@onready var projectile_spawner: Node2D = $ProjectileSpawner
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

var target: Node2D = null
var hp: float = 0.0
var state: StringName = &"idle"
var state_time: float = 0.0
var attack_cooldown: float = 0.0
var skill_cooldown: float = skill_interval
var current_skill: StringName = &""
var line_direction: Vector2 = Vector2.RIGHT
var action_committed: bool = false
var phase_two: bool = false
var invulnerable: bool = false
var body_sprite: Sprite2D = null
var weapon_sprite: Sprite2D = null
var weapon_angle_offset: float = 0.0
var melee_texture: Texture2D = null
var visual_last_position: Vector2 = Vector2.ZERO
var visual_bob_time: float = 0.0
var skill_cycle_index: int = 0
var dash_step_index: int = 0
var dash_total_steps: int = 1
var dash_start_position: Vector2 = Vector2.ZERO
var dash_target_position: Vector2 = Vector2.ZERO
var dash_active_damage: float = 0.0
var shock_payload: Dictionary = {}
var volley_shots_remaining: int = 0
var volley_next_fire_time: float = 0.0
var volley_center_position: Vector2 = Vector2.ZERO
var volley_rng := RandomNumberGenerator.new()
var target_last_position: Vector2 = Vector2.ZERO
var target_velocity_estimate: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("damageable")
	volley_rng.randomize()
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	hp = max_hp
	visual_last_position = global_position
	melee_texture = TEXTURE_LOADER.load_texture(MELEE_EFFECT_TEXTURE_PATH)
	_setup_body_visual()
	_setup_weapon_visual()
	burst_ring.visible = false
	phase_ring.visible = false
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player
	if target != null and is_instance_valid(target):
		target_last_position = target.global_position

func get_status_title() -> String:
	return "Emperor"

func get_status_text() -> String:
	return "HP %d / %d\nSkill %.1fs\nState: %s" % [
		int(round(hp)),
		int(round(max_hp)),
		skill_interval,
		String(state)
	]

func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	_update_target_tracking(delta)
	if target == null or not _is_targetable_player(target):
		_find_target()
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	skill_cooldown = maxf(skill_cooldown - delta, 0.0)
	state_time += delta
	if not phase_two and hp > 0.0 and hp <= phase_two_threshold and state != &"phase_transition":
		_start_phase_transition()
	_update_state(delta)
	_update_visuals()

func receive_hit(payload: Dictionary) -> void:
	if invulnerable or state == &"dead":
		return
	var result: Dictionary = health_component.receive_hit(payload)
	var final_damage := float(result.get("damage", 0.0))
	if final_damage > 0.0:
		_spawn_damage_number(final_damage, bool(result.get("is_critical", false)))

func _update_target_tracking(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target_velocity_estimate = Vector2.ZERO
		return
	var current_position := target.global_position
	if delta > 0.0:
		target_velocity_estimate = (current_position - target_last_position) / delta
	target_last_position = current_position

func _find_target() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if _is_targetable_player(player):
			target = player
			if target != null and is_instance_valid(target):
				target_last_position = target.global_position
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

func _update_state(delta: float) -> void:
	match state:
		&"idle":
			_process_idle(delta)
		&"basic_attack":
			_process_basic_attack()
		&"skill_dash_charge":
			_process_skill_dash_charge()
		&"skill_dash":
			_process_skill_dash(delta)
		&"skill_shock_charge":
			_process_skill_shock_charge()
		&"skill_shock_release":
			_process_skill_shock_release()
		&"skill_volley":
			_process_skill_volley()
		&"phase_transition":
			_process_phase_transition()

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target != Vector2.ZERO:
		line_direction = to_target.normalized()
	if skill_cooldown <= 0.0:
		_start_skill_cast()
		return
	if attack_cooldown <= 0.0 and distance <= attack_range:
		_start_basic_attack()
		return
	if distance > attack_range * 0.9:
		global_position += line_direction * move_speed * delta

func _start_basic_attack() -> void:
	state = &"basic_attack"
	state_time = 0.0
	action_committed = false
	attack_cooldown = attack_interval
	_show_intent_text("!", Color(1.0, 0.95, 0.56, 1.0), global_position, 0.92)
	_animate_weapon_swing(-42.0, 20.0, 0.26)

func _process_basic_attack() -> void:
	if not action_committed and state_time >= 1.0:
		action_committed = true
		_hit_target_in_arc(attack_range, attack_damage, attack_arc_degrees)
		_spawn_slash_effect(attack_range, Color(1.0, 0.84, 0.58, 0.92))
	if state_time >= 1.34:
		_return_to_idle()

func _start_skill_cast() -> void:
	current_skill = _pick_skill()
	action_committed = false
	state_time = 0.0
	skill_cooldown = skill_interval
	match current_skill:
		&"dash":
			_start_dash_skill()
		&"shock":
			_start_shock_skill()
		&"volley":
			_start_volley_skill()

func _pick_skill() -> StringName:
	var pool: Array[StringName] = [&"dash", &"shock", &"volley"]
	var picked := pool[skill_cycle_index % pool.size()]
	skill_cycle_index += 1
	return picked

func _start_dash_skill() -> void:
	state = &"skill_dash_charge"
	state_time = 0.0
	dash_step_index = 0
	dash_total_steps = 2 if phase_two else 1
	dash_active_damage = dash_damage
	_prepare_dash_target(true)
	_show_line_marker(dash_start_position, dash_target_position, dash_lane_width * 2.0, Color(1.0, 0.78, 0.42, 0.82))
	_show_intent_text("Dash Slash", Color(1.0, 0.76, 0.54, 1.0), global_position, 0.9)
	_animate_weapon_swing(-50.0, 10.0, dash_charge_duration)

func _prepare_dash_target(use_current_position: bool) -> void:
	dash_start_position = global_position
	var aim_position := global_position + line_direction * dash_distance
	if target != null and is_instance_valid(target):
		var player_position := target.global_position if use_current_position else (target.global_position + target_velocity_estimate * 0.12)
		var to_target := player_position - global_position
		if to_target.length_squared() > 0.0001:
			line_direction = to_target.normalized()
		aim_position = global_position + line_direction * dash_distance
	dash_target_position = aim_position

func _process_skill_dash_charge() -> void:
	_show_line_marker(dash_start_position, dash_target_position, dash_lane_width * 2.0, Color(1.0, 0.78, 0.42, 0.82))
	if state_time < dash_charge_duration:
		return
	burst_ring.visible = false
	state = &"skill_dash"
	state_time = 0.0
	action_committed = false

func _process_skill_dash(delta: float) -> void:
	var dash_time := dash_duration * (0.7 if phase_two else 1.0)
	var progress := clampf(state_time / maxf(dash_time, 0.001), 0.0, 1.0)
	global_position = dash_start_position.lerp(dash_target_position, progress)
	if not action_committed:
		action_committed = true
		_hit_targets_in_lane(dash_start_position, dash_target_position, dash_lane_width, dash_active_damage)
		_spawn_slash_effect(dash_hit_radius, Color(1.0, 0.78, 0.56, 0.95))
	if progress >= 1.0:
		global_position = dash_target_position
		if phase_two and dash_step_index == 0:
			dash_step_index = 1
			dash_active_damage = dash_damage * 0.5
			dash_start_position = global_position
			dash_target_position = dash_start_position - line_direction * dash_distance
			_show_line_marker(dash_start_position, dash_target_position, dash_lane_width * 2.0, Color(1.0, 0.72, 0.42, 0.78))
			state_time = 0.0
			action_committed = false
			return
		_return_to_idle()

func _start_shock_skill() -> void:
	state = &"skill_shock_charge"
	state_time = 0.0
	action_committed = false
	burst_ring.visible = true
	burst_ring.global_position = global_position
	burst_ring.points = _build_ring_points(shock_radius, 24)
	burst_ring.scale = Vector2.ONE * 0.2
	burst_ring.modulate = Color(1.0, 0.82, 0.58, 0.9)
	shock_payload = {
		"slow_duration": shock_slow_duration,
		"slow_multiplier": shock_slow_multiplier
	}
	_show_intent_text("Shockwave", Color(1.0, 0.82, 0.58, 1.0), global_position, 0.9)

func _process_skill_shock_charge() -> void:
	burst_ring.global_position = global_position
	burst_ring.scale = Vector2.ONE * (0.2 + minf(state_time / maxf(shock_charge_duration, 0.001), 1.0) * 0.95)
	if state_time < shock_charge_duration:
		return
	state = &"skill_shock_release"
	state_time = 0.0
	action_committed = false

func _process_skill_shock_release() -> void:
	if not action_committed:
		action_committed = true
		_hit_targets_in_radius(global_position, shock_radius, shock_damage, shock_payload)
		_hit_targets_in_radius(global_position, shock_outer_ring_radius, shock_outer_ring_damage, {})
		_spawn_burst_effect(global_position, shock_radius, Color(1.0, 0.80, 0.56, 0.9))
		_spawn_burst_effect(global_position, shock_outer_ring_radius, Color(1.0, 0.64, 0.38, 0.72))
		burst_ring.visible = false
	if state_time >= 0.26:
		_return_to_idle()

func _start_volley_skill() -> void:
	state = &"skill_volley"
	state_time = 0.0
	action_committed = false
	volley_shots_remaining = volley_shot_count_phase_two if phase_two else volley_shot_count_phase_one
	volley_next_fire_time = 0.0
	volley_center_position = target.global_position if target != null and is_instance_valid(target) else global_position
	_show_intent_text("Royal Volley", Color(1.0, 0.84, 0.58, 1.0), volley_center_position, 0.88)

func _process_skill_volley() -> void:
	var interval := volley_interval_phase_two if phase_two else volley_interval_phase_one
	if target != null and is_instance_valid(target):
		volley_center_position = target.global_position
	while volley_shots_remaining > 0 and state_time >= volley_next_fire_time:
		_fire_single_volley_bolt()
		volley_shots_remaining -= 1
		volley_next_fire_time += interval
	if volley_shots_remaining <= 0 and state_time >= volley_next_fire_time + 0.18:
		_return_to_idle()

func _fire_single_volley_bolt() -> void:
	if target == null or not is_instance_valid(target):
		return
	var spawn_position := global_position
	var predicted_target := target.global_position + target_velocity_estimate * volley_prediction_time
	var aim_direction := (predicted_target - spawn_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = (target.global_position - spawn_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var bolt := ROYAL_BOLT_SCENE.instantiate()
	bolt.global_position = spawn_position
	scene_root.add_child(bolt)
	bolt.setup(self, aim_direction, volley_damage)
	if bolt.has_method("set"):
		bolt.set("speed", volley_bullet_speed)
	if phase_two or volley_shots_remaining % 3 == 0:
		_spawn_volley_ring_burst()

func _start_phase_transition() -> void:
	phase_two = true
	invulnerable = true
	state = &"phase_transition"
	state_time = 0.0
	action_committed = false
	phase_ring.visible = true
	phase_ring.scale = Vector2.ONE * 0.6
	_show_intent_text("Phase Two", Color(1.0, 0.88, 0.62, 1.0), global_position, 0.94)

func _process_phase_transition() -> void:
	phase_ring.rotation += 0.16
	phase_ring.scale = Vector2.ONE * (0.6 + minf(state_time * 0.55, 0.5))
	if state_time >= phase_transition_duration:
		invulnerable = false
		phase_ring.visible = false
		skill_cooldown = 0.5
		_return_to_idle()

func _return_to_idle() -> void:
	state = &"idle"
	state_time = 0.0
	current_skill = &""
	burst_ring.visible = false

func _hit_target_in_arc(radius: float, damage: float, arc_degrees: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not MELEE_UTILS.is_point_in_arc(global_position, line_direction, target.global_position, radius, arc_degrees):
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.0
	})

func _hit_targets_in_radius(center: Vector2, radius: float, damage: float, payload: Dictionary = {}) -> void:
	for candidate in get_tree().get_nodes_in_group("player"):
		if not _is_targetable_player(candidate):
			continue
		var actor := candidate as Node2D
		if actor.global_position.distance_to(center) > radius:
			continue
		var hit_payload := {
			"source": self,
			"damage": damage,
			"crit_rate": 0.0
		}
		for key in payload.keys():
			hit_payload[key] = payload[key]
		actor.receive_hit(hit_payload)

func _hit_targets_in_lane(start_position: Vector2, end_position: Vector2, width: float, damage: float) -> void:
	for candidate in get_tree().get_nodes_in_group("player"):
		if not _is_targetable_player(candidate):
			continue
		var actor := candidate as Node2D
		if _distance_to_segment(actor.global_position, start_position, end_position) > width:
			continue
		actor.receive_hit({
			"source": self,
			"damage": damage,
			"crit_rate": 0.0
		})

func _spawn_volley_ring_burst() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var base_angle := volley_rng.randf_range(0.0, TAU)
	for index in range(volley_ring_shots):
		var direction := Vector2.RIGHT.rotated(base_angle + TAU * float(index) / float(volley_ring_shots))
		var bolt := ROYAL_BOLT_SCENE.instantiate()
		bolt.global_position = global_position + direction * 34.0
		scene_root.add_child(bolt)
		bolt.setup(self, direction, volley_damage * 0.75)
		if bolt.has_method("set"):
			bolt.set("speed", volley_bullet_speed * 0.74)

func _spawn_slash_effect(radius: float, color: Color) -> void:
	if melee_texture != null:
		var texture_slash := Sprite2D.new()
		texture_slash.texture = melee_texture
		texture_slash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_slash.centered = true
		texture_slash.modulate = color
		texture_slash.position = line_direction * (radius * 0.42)
		texture_slash.rotation = line_direction.angle()
		texture_slash.scale = Vector2(0.24, 0.10)
		effects_layer.add_child(texture_slash)
		var texture_tween := texture_slash.create_tween()
		texture_tween.tween_property(texture_slash, "scale", Vector2(0.34, 0.16), 0.14)
		texture_tween.parallel().tween_property(texture_slash, "modulate:a", 0.0, 0.14)
		texture_tween.finished.connect(texture_slash.queue_free)
	var slash := Line2D.new()
	slash.width = 12.0
	slash.default_color = color
	slash.position = line_direction * 14.0
	slash.rotation = line_direction.angle()
	slash.points = PackedVector2Array([
		Vector2(-8.0, -24.0),
		Vector2(radius * 0.3, -radius * 0.18),
		Vector2(radius * 0.78, 0.0),
		Vector2(radius * 0.3, radius * 0.18),
		Vector2(-8.0, 24.0)
	])
	effects_layer.add_child(slash)
	var tween := create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.16)
	tween.parallel().tween_property(slash, "scale", Vector2.ONE * 1.1, 0.16)
	tween.finished.connect(slash.queue_free)

func _spawn_burst_effect(center: Vector2, radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.closed = true
	ring.default_color = color
	ring.points = _build_ring_points(radius, 24)
	ring.global_position = center
	get_tree().current_scene.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.12, 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.finished.connect(ring.queue_free)

func _show_line_marker(start_position: Vector2, end_position: Vector2, width: float, color: Color) -> void:
	var direction := end_position - start_position
	var length := direction.length()
	if length <= 0.001:
		return
	burst_ring.visible = true
	burst_ring.closed = false
	burst_ring.width = width
	burst_ring.default_color = color
	burst_ring.global_position = start_position
	burst_ring.rotation = direction.angle()
	burst_ring.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])

func _distance_to_segment(point: Vector2, start_position: Vector2, end_position: Vector2) -> float:
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(start_position)
	var weight := clampf((point - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := start_position + segment * weight
	return point.distance_to(closest_point)

func _show_intent_text(label_text: String, color_value: Color, world_position: Vector2, scale_value: float = 0.84) -> void:
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = to_local(world_position) + Vector2(-44.0, -104.0)
	if popup.has_method("setup_text"):
		popup.setup_text(label_text, color_value, scale_value)
	if popup is CanvasItem:
		(popup as CanvasItem).z_index = 60
	popup.lifetime = 0.8
	effects_layer.add_child(popup)

func _build_ring_points(radius: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _setup_body_visual() -> void:
	body_sprite = Sprite2D.new()
	body_sprite.texture = TEXTURE_LOADER.load_texture(EMPEROR_BODY_TEXTURE_PATH)
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_sprite.centered = true
	body_sprite.scale = Vector2.ONE * 0.34
	body.add_child(body_sprite)
	body.color = Color(1.0, 1.0, 1.0, 0.0)

func _set_body_tint(color: Color) -> void:
	if body_sprite != null:
		body_sprite.self_modulate = color
	else:
		body.color = color

func _setup_weapon_visual() -> void:
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture = TEXTURE_LOADER.load_texture(EMPEROR_WEAPON_TEXTURE_PATH)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = true
	weapon_sprite.scale = Vector2.ONE * 0.70
	weapon_sprite.position = Vector2(-64.0, 8.0)
	weapon.add_child(weapon_sprite)

func _animate_weapon_swing(start_degrees: float, end_degrees: float, duration: float) -> void:
	weapon_angle_offset = deg_to_rad(start_degrees)
	var tween := create_tween()
	tween.tween_property(self, "weapon_angle_offset", deg_to_rad(end_degrees), duration)

func _update_visuals() -> void:
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target != Vector2.ZERO:
			line_direction = to_target.normalized()
	_set_body_tint(Color(1.0, 0.94, 0.88, 1.0) if phase_two else Color.WHITE)
	body.modulate = Color(1.0, 1.0, 1.0, 0.8) if invulnerable else Color.WHITE
	_apply_body_motion(0.9, 0.025, 0.012)
	phase_ring.default_color = Color(1.0, 0.84, 0.52, 0.88)
	weapon.position = line_direction * 22.0
	weapon.rotation = _weapon_guard_rotation(line_direction, -48.0) + weapon_angle_offset
	projectile_spawner.position = line_direction * 24.0
	visual_last_position = global_position

func _weapon_guard_rotation(direction: Vector2, guard_degrees: float) -> float:
	var facing := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var side_sign := -1.0 if facing.x < -0.05 else 1.0
	return facing.angle() + deg_to_rad(guard_degrees * side_sign)

func _apply_body_motion(bob_scale: float, sway_scale: float, idle_sway: float) -> void:
	var movement := global_position - visual_last_position
	var motion_ratio := clampf(movement.length() / maxf(move_speed * get_physics_process_delta_time(), 1.0), 0.0, 1.0)
	visual_bob_time += 0.08 + motion_ratio * 0.12
	var facing := -1.0 if line_direction.x < -0.05 else 1.0
	if body_sprite != null:
		body_sprite.flip_h = facing < 0.0
	body.position = Vector2(0.0, sin(visual_bob_time) * (1.0 + motion_ratio * 3.0) * bob_scale)
	body.rotation = sin(visual_bob_time * 0.55) * (idle_sway + motion_ratio * sway_scale) * facing

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -42.0)
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

func _on_died() -> void:
	if state == &"dead":
		return
	hp = 0.0
	invulnerable = true
	state = &"dead"
	burst_ring.visible = false
	phase_ring.visible = false
	weapon.visible = false
	Sfx.play_event(&"boss_generic_dead", global_position)
	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)
