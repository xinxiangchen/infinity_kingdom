extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ROYAL_BOLT_SCENE := preload("res://effects/projectiles/royal_bolt.tscn")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const MELEE_UTILS := preload("res://combat/melee_utils.gd")
const TWIN_PHASE1_BODY_TEXTURE_PATH := "res://actors/bosses/textures/twin_first_boss.png"
const TWIN_PHASE2_BODY_TEXTURE_PATH := "res://actors/bosses/textures/twin_second_boss.png"
const TWIN_PHASE1_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_twin_first_sword.png"
const TWIN_PHASE2_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_twin_second_sword.png"
const MELEE_EFFECT_TEXTURE_PATH := "res://assets/effects/vfx/magic_circle.webp"
const BARRAGE_WAVE_TIMINGS := [0.18, 0.42, 0.68, 0.96]
const BARRAGE_WAVE_OFFSETS := [
	[-10.0, 0.0, 10.0],
	[-18.0, -9.0, 0.0, 9.0, 18.0],
	[-28.0, -18.0, -8.0, 0.0, 8.0, 18.0, 28.0],
	[-36.0, -28.0, -20.0, -12.0, -4.0, 4.0, 12.0, 20.0, 28.0, 36.0]
]

@export var max_hp_value: float = 5000.0
@export var defense_value: float = 220.0
@export var move_speed: float = 235.0
@export var basic_attack_damage: float = 50.0
@export var basic_attack_interval: float = 2.0
@export var basic_attack_recover: float = 1.0
@export var basic_attack_range: float = 90.0
@export var teleport_interval: float = 5.0
@export var teleport_charge_duration: float = 1.5
@export var teleport_landing_radius: float = 132.0
@export var teleport_landing_damage: float = 50.0
@export var line_slash_damage: float = 72.0
@export var line_slash_length: float = 392.0
@export var line_slash_width: float = 84.0
@export var line_slash_charge_duration: float = 1.0
@export var barrage_damage: float = 18.0
@export var barrage_interval: float = 5.0
@export var barrage_recover: float = 0.8
@export var dash_charge_duration: float = 1.5
@export var dash_duration: float = 0.68
@export var dash_speed: float = 980.0
@export var dash_hit_width: float = 44.0
@export var dash_damage: float = 20.0
@export var dash_player_root_duration: float = 3.0
@export var dash_hit_lockout_duration: float = 5.0
@export var dash_miss_stun_duration: float = 4.0
@export var dash_miss_damage_multiplier: float = 1.5
@export var dash_miss_burst_damage: float = 24.0
@export var dash_miss_burst_radius: float = 120.0
@export var dash_miss_teleport_delay: float = 1.0

@onready var body: Polygon2D = $Body
@onready var spear: Polygon2D = $Spear
@onready var teleport_marker: Line2D = $TeleportMarker
@onready var charge_line: Line2D = $ChargeLine
@onready var phase_ring: Line2D = $PhaseRing
@onready var projectile_spawner: Node2D = $ProjectileSpawner
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

var target: Node2D = null
var hp: float = 0.0
var current_phase: int = 1
var state: StringName = &"intro"
var state_time: float = 0.0
var recover_duration: float = 0.0
var action_committed: bool = false
var invulnerable: bool = false
var teleport_cooldown: float = 1.2
var barrage_cooldown: float = 2.4
var attack_cooldown: float = 0.8
var phase_threshold_hp: float = 2500.0
var normal_attack_counter: int = 0
var barrage_counter: int = 0
var barrage_wave_index: int = 0
var pending_post_stun_teleport: bool = false
var dash_connected: bool = false
var line_direction: Vector2 = Vector2.RIGHT
var teleport_target_position: Vector2 = Vector2.ZERO
var dash_direction: Vector2 = Vector2.RIGHT
var body_sprite: Sprite2D = null
var spear_sprite: Sprite2D = null
var melee_texture: Texture2D = null
var visual_last_position: Vector2 = Vector2.ZERO
var visual_bob_time: float = 0.0
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0

func _ready() -> void:
	add_to_group("damageable")
	hp = max_hp_value
	phase_threshold_hp = max_hp_value * 0.5
	health_component.setup(max_hp_value, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	visual_last_position = global_position
	melee_texture = TEXTURE_LOADER.load_texture(MELEE_EFFECT_TEXTURE_PATH)
	_setup_body_visual()
	_setup_weapon_visual()
	_refresh_phase_visuals()
	teleport_marker.visible = false
	charge_line.visible = false
	phase_ring.visible = false
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func get_status_title() -> String:
	return "Twin Princes"

func get_status_text() -> String:
	return "Phase %d\nHP %d / %d\nState: %s" % [
		current_phase,
		int(round(hp)),
		int(round(max_hp_value)),
		String(state)
	]

func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	if target == null or not is_instance_valid(target):
		_find_target()
	_update_status_timers(delta)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	barrage_cooldown = maxf(barrage_cooldown - delta, 0.0)
	state_time += delta
	_update_state(delta)
	_update_visuals()

func receive_hit(payload: Dictionary) -> void:
	if invulnerable or state == &"dead":
		return
	var hit_payload := payload.duplicate()
	if state == &"self_stunned":
		hit_payload["damage"] = float(hit_payload.get("damage", 0.0)) * dash_miss_damage_multiplier
	var result: Dictionary = health_component.receive_hit(hit_payload)
	var final_damage := float(result.get("damage", 0.0))
	if final_damage > 0.0:
		apply_control_effects(payload)
		_spawn_damage_number(float(result.get("total_damage", final_damage)), bool(result.get("is_critical", false)))

func apply_control_effects(payload: Dictionary) -> void:
	if payload.has("silence_duration"):
		silenced_time_remaining = maxf(silenced_time_remaining, float(payload["silence_duration"]))
	if payload.has("root_duration"):
		root_time_remaining = maxf(root_time_remaining, float(payload["root_duration"]))
	if payload.has("slow_duration"):
		slow_time_remaining = maxf(slow_time_remaining, float(payload["slow_duration"]))
		slow_factor = minf(slow_factor, float(payload.get("slow_multiplier", 1.0)))

func _find_target() -> void:
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate is Node2D and is_instance_valid(candidate):
			target = candidate as Node2D
			return
	target = null

func _update_status_timers(delta: float) -> void:
	silenced_time_remaining = maxf(silenced_time_remaining - delta, 0.0)
	root_time_remaining = maxf(root_time_remaining - delta, 0.0)
	if slow_time_remaining > 0.0:
		slow_time_remaining = maxf(slow_time_remaining - delta, 0.0)
	else:
		slow_factor = 1.0

func _update_state(delta: float) -> void:
	match state:
		&"intro":
			if state_time >= 0.8:
				state = &"idle"
				state_time = 0.0
		&"idle":
			_process_idle(delta)
		&"basic_attack":
			_process_basic_attack()
		&"teleport_mark":
			_process_teleport_mark()
		&"teleport_attack":
			_process_teleport_attack()
		&"line_slash_charge":
			_process_line_slash_charge()
		&"line_slash":
			_process_line_slash()
		&"barrage_cast":
			_process_barrage_cast()
		&"dash_charge":
			_process_dash_charge()
		&"dash_attack":
			_process_dash_attack(delta)
		&"self_stunned":
			_process_self_stunned()
		&"recover":
			_process_recover()
		&"phase_change":
			_process_phase_change()

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target.length_squared() > 0.0001:
		line_direction = to_target.normalized()
	if normal_attack_counter >= 4 and _can_use_skills():
		_start_line_slash()
		return
	if current_phase == 2 and barrage_counter >= 3 and _can_use_skills():
		_start_dash_charge()
		return
	if current_phase == 2 and barrage_cooldown <= 0.0 and _can_use_skills():
		_start_barrage()
		return
	if teleport_cooldown <= 0.0 and _can_use_skills():
		_start_teleport_attack()
		return
	if distance <= basic_attack_range and attack_cooldown <= 0.0:
		_start_basic_attack()
		return
	if root_time_remaining > 0.0:
		return
	var preferred_distance := basic_attack_range * (1.1 if current_phase == 1 else 1.26)
	if distance > preferred_distance:
		global_position += line_direction * move_speed * slow_factor * delta
	else:
		var orbit := Vector2(-line_direction.y, line_direction.x)
		if orbit.length_squared() > 0.0001:
			var orbit_sign := 1.0 if int(Time.get_ticks_msec() / 260) % 2 == 0 else -1.0
			global_position += orbit.normalized() * move_speed * 0.16 * orbit_sign * slow_factor * delta

func _start_basic_attack() -> void:
	state = &"basic_attack"
	state_time = 0.0
	action_committed = false
	attack_cooldown = basic_attack_interval
	_show_intent_text("Slash", Color(1.0, 0.84, 0.62, 1.0), global_position, 0.8)

func _process_basic_attack() -> void:
	if not action_committed and state_time >= 0.24:
		action_committed = true
		_hit_target_in_arc(basic_attack_range, 110.0, basic_attack_damage)
		_spawn_melee_slash_effect(basic_attack_range, Color(1.0, 0.84, 0.62, 0.92))
		normal_attack_counter += 1
	if state_time >= basic_attack_recover:
		_enter_recover(0.18)

func _start_teleport_attack() -> void:
	state = &"teleport_mark"
	state_time = 0.0
	action_committed = false
	teleport_cooldown = teleport_interval
	teleport_target_position = target.global_position if target != null and is_instance_valid(target) else global_position
	teleport_marker.visible = true
	teleport_marker.global_position = teleport_target_position
	teleport_marker.rotation = 0.0
	Sfx.play_event(&"boss_twin_teleport", global_position)
	_show_intent_text("Teleport Slash", Color(1.0, 0.78, 0.62, 1.0), teleport_target_position, 0.86)

func _process_teleport_mark() -> void:
	teleport_marker.rotation += 0.14
	if state_time < teleport_charge_duration:
		return
	state = &"teleport_attack"
	state_time = 0.0
	action_committed = false
	global_position = teleport_target_position
	teleport_marker.visible = false
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 0.0001:
			line_direction = to_target.normalized()

func _process_teleport_attack() -> void:
	if not action_committed and state_time >= 0.08:
		action_committed = true
		_hit_targets_in_radius(global_position, teleport_landing_radius, teleport_landing_damage)
		_spawn_radius_burst(teleport_landing_radius, Color(1.0, 0.78, 0.58, 0.86))
		_spawn_melee_slash_effect(basic_attack_range + 14.0, Color(1.0, 0.72, 0.56, 0.94))
		normal_attack_counter += 1
	if state_time >= 0.38:
		_enter_recover(0.18)

func _start_line_slash() -> void:
	state = &"line_slash_charge"
	state_time = 0.0
	action_committed = false
	normal_attack_counter = 0
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 0.0001:
			line_direction = to_target.normalized()
	charge_line.visible = true
	charge_line.global_position = global_position
	charge_line.rotation = line_direction.angle()
	charge_line.points = PackedVector2Array([Vector2.ZERO, Vector2(line_slash_length, 0.0)])
	Sfx.play_event(&"boss_twin_charge", global_position)
	_show_intent_text("Heavy Cleave", Color(1.0, 0.74, 0.54, 1.0), global_position, 0.9)

func _process_line_slash_charge() -> void:
	charge_line.visible = true
	charge_line.global_position = global_position
	charge_line.rotation = line_direction.angle()
	if state_time < line_slash_charge_duration:
		return
	state = &"line_slash"
	state_time = 0.0
	action_committed = false

func _process_line_slash() -> void:
	if not action_committed:
		action_committed = true
		charge_line.visible = false
		_hit_target_in_line(line_slash_damage, line_slash_length, line_slash_width)
		_spawn_line_impact(line_slash_length, line_slash_width)
	if state_time >= 0.36:
		_enter_recover(0.34)

func _start_barrage() -> void:
	state = &"barrage_cast"
	state_time = 0.0
	action_committed = false
	barrage_wave_index = 0
	barrage_cooldown = barrage_interval
	_show_intent_text("Barrage", Color(1.0, 0.84, 0.58, 1.0), global_position, 0.82)
	Sfx.play_event(&"boss_twin_barrage", global_position)

func _process_barrage_cast() -> void:
	while barrage_wave_index < BARRAGE_WAVE_TIMINGS.size() and state_time >= float(BARRAGE_WAVE_TIMINGS[barrage_wave_index]):
		action_committed = true
		_fire_barrage_wave(barrage_wave_index)
		barrage_wave_index += 1
	if barrage_wave_index >= BARRAGE_WAVE_TIMINGS.size() and state_time >= barrage_recover:
		barrage_counter += 1
		_enter_recover(0.16)

func _start_dash_charge() -> void:
	state = &"dash_charge"
	state_time = 0.0
	action_committed = false
	barrage_counter = 0
	charge_line.visible = true
	charge_line.global_position = global_position
	charge_line.points = PackedVector2Array([Vector2.ZERO, Vector2(240.0, 0.0)])
	_show_intent_text("Twin Lunge", Color(1.0, 0.7, 0.52, 1.0), global_position, 0.92)
	Sfx.play_event(&"boss_twin_charge", global_position, 1.0)

func _process_dash_charge() -> void:
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 0.0001:
			line_direction = to_target.normalized()
	charge_line.visible = true
	charge_line.global_position = global_position
	charge_line.rotation = line_direction.angle()
	if state_time < dash_charge_duration:
		return
	dash_direction = line_direction if line_direction.length_squared() > 0.0001 else Vector2.RIGHT
	dash_connected = false
	charge_line.visible = false
	state = &"dash_attack"
	state_time = 0.0
	action_committed = false

func _process_dash_attack(delta: float) -> void:
	var start_position := global_position
	global_position += dash_direction * dash_speed * slow_factor * delta
	if not dash_connected and _player_intersects_segment(start_position, global_position, dash_hit_width):
		dash_connected = true
		_apply_dash_hit()
		_enter_recover(dash_hit_lockout_duration)
		return
	if state_time >= dash_duration:
		_start_self_stun()

func _start_self_stun() -> void:
	state = &"self_stunned"
	state_time = 0.0
	action_committed = false
	pending_post_stun_teleport = true
	_show_intent_text("Staggered", Color(1.0, 0.66, 0.58, 1.0), global_position, 0.82)

func _process_self_stunned() -> void:
	if state_time < dash_miss_stun_duration:
		return
	if not action_committed:
		action_committed = true
		_spawn_radius_burst(dash_miss_burst_radius, Color(1.0, 0.72, 0.54, 0.88))
		_hit_target_in_radius(dash_miss_burst_radius, dash_miss_burst_damage)
		state_time = 0.0
		return
	if state_time >= dash_miss_teleport_delay:
		pending_post_stun_teleport = false
		_start_teleport_attack()

func _process_recover() -> void:
	if state_time >= maxf(recover_duration, 0.1):
		state = &"idle"
		state_time = 0.0

func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	recover_duration = duration
	charge_line.visible = false
	teleport_marker.visible = false

func _process_phase_change() -> void:
	phase_ring.visible = true
	phase_ring.rotation += 0.12
	if state_time >= 1.0:
		invulnerable = false
		phase_ring.visible = false
		state = &"idle"
		state_time = 0.0
		teleport_cooldown = 1.2
		barrage_cooldown = 1.5
		attack_cooldown = 0.8

func _hit_target_in_arc(radius: float, arc_degrees: float, damage: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not MELEE_UTILS.is_point_in_arc(global_position, line_direction, target.global_position, radius, arc_degrees):
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.0
	})

func _hit_target_in_line(damage: float, length: float, width: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var start_position := global_position
	var end_position := global_position + line_direction * length
	if _distance_to_segment(target.global_position, start_position, end_position) > width:
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.0
	})

func _hit_target_in_radius(radius: float, damage: float) -> void:
	_hit_targets_in_radius(global_position, radius, damage)

func _hit_targets_in_radius(center: Vector2, radius: float, damage: float) -> void:
	for candidate in get_tree().get_nodes_in_group("damageable"):
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

func _player_intersects_segment(start_position: Vector2, end_position: Vector2, width: float) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return _distance_to_segment(target.global_position, start_position, end_position) <= width

func _apply_dash_hit() -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_node("HealthComponent"):
		var target_health: Node = target.get_node("HealthComponent")
		if target_health != null:
			if target_health.has_method("clear_shield"):
				target_health.clear_shield()
			target_health.set("hp", 1.0)
	target.set("hp", 1.0)
	if target.has_signal("hp_changed"):
		target.hp_changed.emit(1.0, float(target.get("max_hp")))
	if target.has_method("apply_control_effects"):
		target.apply_control_effects({
			"root_duration": dash_player_root_duration,
			"silence_duration": dash_player_root_duration
		})

func _distance_to_segment(point: Vector2, start_position: Vector2, end_position: Vector2) -> float:
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(start_position)
	var weight := clampf((point - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := start_position + segment * weight
	return point.distance_to(closest_point)

func _can_use_skills() -> bool:
	return silenced_time_remaining <= 0.0

func _fire_barrage_wave(wave_index: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	var base_direction := (target.global_position - projectile_spawner.global_position).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT
	var wave_offsets: Array = BARRAGE_WAVE_OFFSETS[min(wave_index, BARRAGE_WAVE_OFFSETS.size() - 1)]
	_spawn_barrage_wave(base_direction, wave_offsets, barrage_damage * (1.0 + 0.08 * float(wave_index)))

func _spawn_barrage_wave(base_direction: Vector2, angles: Array, damage: float) -> void:
	var payload := {
		"slow_duration": 0.9,
		"slow_multiplier": 0.78
	}
	for angle_offset in angles:
		var bolt := ROYAL_BOLT_SCENE.instantiate()
		bolt.global_position = projectile_spawner.global_position
		get_tree().current_scene.add_child(bolt)
		bolt.setup(self, base_direction.rotated(deg_to_rad(float(angle_offset))), damage, payload)

func _setup_body_visual() -> void:
	body_sprite = Sprite2D.new()
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_sprite.centered = true
	body_sprite.scale = Vector2.ONE * 0.31
	body.add_child(body_sprite)
	body.color = Color(1.0, 1.0, 1.0, 0.0)

func _setup_weapon_visual() -> void:
	spear_sprite = Sprite2D.new()
	spear_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spear_sprite.centered = true
	spear_sprite.scale = Vector2.ONE * 0.60
	spear_sprite.position = Vector2(-62.0, 2.0)
	spear.add_child(spear_sprite)
	spear.color = Color(1.0, 1.0, 1.0, 0.0)

func _refresh_phase_visuals() -> void:
	if body_sprite != null:
		body_sprite.texture = TEXTURE_LOADER.load_texture(TWIN_PHASE1_BODY_TEXTURE_PATH if current_phase == 1 else TWIN_PHASE2_BODY_TEXTURE_PATH)
	if spear_sprite != null:
		spear_sprite.texture = TEXTURE_LOADER.load_texture(TWIN_PHASE1_WEAPON_TEXTURE_PATH if current_phase == 1 else TWIN_PHASE2_WEAPON_TEXTURE_PATH)

func _update_visuals() -> void:
	var base_color := Color(0.84, 0.82, 0.88, 1.0) if current_phase == 1 else Color(0.96, 0.76, 0.58, 1.0)
	if state == &"self_stunned":
		base_color = Color(1.0, 0.62, 0.62, 1.0)
	elif silenced_time_remaining > 0.0:
		base_color = Color(0.74, 0.66, 0.92, 1.0)
	_set_body_tint(base_color)
	var aim_direction := line_direction if line_direction.length_squared() > 0.0001 else Vector2.RIGHT
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 0.0001 and state != &"dash_attack":
			aim_direction = to_target.normalized()
	spear.position = aim_direction * 20.0 + Vector2(0.0, 4.0)
	spear.rotation = _weapon_guard_rotation(aim_direction, -42.0)
	_apply_prince_body_motion(aim_direction)
	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.01)
	if teleport_marker.visible:
		teleport_marker.scale = Vector2.ONE * (0.92 + 0.08 * pulse)
		teleport_marker.width = 3.0 + 0.8 * pulse
	if charge_line.visible:
		charge_line.width = 5.0 + 1.2 * pulse
		charge_line.modulate = Color(1.0, 1.0, 1.0, 0.74 + 0.12 * pulse)
	if phase_ring.visible:
		phase_ring.scale = Vector2.ONE * (0.94 + 0.08 * pulse)
		phase_ring.width = 3.4 + 1.0 * pulse
	visual_last_position = global_position

func _weapon_guard_rotation(direction: Vector2, guard_degrees: float) -> float:
	var facing := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var side_sign := -1.0 if facing.x < -0.05 else 1.0
	return facing.angle() + deg_to_rad(guard_degrees * side_sign)

func _apply_prince_body_motion(aim_direction: Vector2) -> void:
	var movement := global_position - visual_last_position
	var motion_ratio := clampf(movement.length() / maxf(move_speed * get_physics_process_delta_time(), 1.0), 0.0, 1.0)
	visual_bob_time += 0.08 + motion_ratio * 0.14
	var facing := -1.0 if aim_direction.x < -0.05 else 1.0
	if body_sprite != null:
		body_sprite.flip_h = facing < 0.0
	body.position = Vector2(0.0, sin(visual_bob_time) * (1.0 + motion_ratio * 2.5))
	body.rotation = sin(visual_bob_time * 0.72) * (0.018 + motion_ratio * 0.04) * facing

func _set_body_tint(color: Color) -> void:
	if body_sprite != null:
		body_sprite.self_modulate = color
	else:
		body.color = color

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -44.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _show_intent_text(label_text: String, color_value: Color, world_position: Vector2, scale_value: float = 0.84) -> void:
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = to_local(world_position) + Vector2(-40.0, -56.0)
	if popup.has_method("setup_text"):
		popup.setup_text(label_text, color_value, scale_value)
	effects_layer.add_child(popup)

func _spawn_melee_slash_effect(radius: float, color: Color) -> void:
	if effects_layer == null:
		return
	if melee_texture != null:
		var texture_slash := Sprite2D.new()
		texture_slash.texture = melee_texture
		texture_slash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_slash.centered = true
		texture_slash.modulate = color
		texture_slash.position = line_direction * (radius * 0.42)
		texture_slash.rotation = line_direction.angle()
		texture_slash.scale = Vector2(0.22, 0.1)
		effects_layer.add_child(texture_slash)
		var texture_tween := texture_slash.create_tween()
		texture_tween.tween_property(texture_slash, "scale", Vector2(0.32, 0.16), 0.14)
		texture_tween.parallel().tween_property(texture_slash, "modulate:a", 0.0, 0.14)
		texture_tween.finished.connect(texture_slash.queue_free)
	var slash := Line2D.new()
	slash.width = 12.0
	slash.default_color = color
	slash.position = line_direction * 14.0
	slash.rotation = line_direction.angle()
	slash.points = PackedVector2Array([
		Vector2(-8.0, -22.0),
		Vector2(radius * 0.3, -radius * 0.16),
		Vector2(radius * 0.78, 0.0),
		Vector2(radius * 0.3, radius * 0.16),
		Vector2(-8.0, 22.0)
	])
	effects_layer.add_child(slash)
	var tween := create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.16)
	tween.parallel().tween_property(slash, "scale", Vector2.ONE * 1.1, 0.16)
	tween.finished.connect(slash.queue_free)

func _spawn_line_impact(length: float, width: float) -> void:
	var slash := Polygon2D.new()
	slash.color = Color(1.0, 0.78, 0.54, 0.9)
	slash.position = line_direction * (length * 0.18)
	slash.rotation = line_direction.angle()
	slash.polygon = PackedVector2Array([
		Vector2(-10.0, -width * 0.5),
		Vector2(length, -width * 0.5),
		Vector2(length, width * 0.5),
		Vector2(-10.0, width * 0.5)
	])
	effects_layer.add_child(slash)
	var tween := create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(slash, "scale", Vector2(1.08, 1.04), 0.18)
	tween.finished.connect(slash.queue_free)

func _spawn_radius_burst(radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = 6.0
	ring.closed = true
	ring.default_color = color
	ring.points = _build_ring_points(radius, 24)
	ring.global_position = global_position
	get_tree().current_scene.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.18, 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.finished.connect(ring.queue_free)

func _build_ring_points(radius: float, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _on_damaged(_amount: float, remaining_hp: float, _source: Node) -> void:
	hp = remaining_hp
	_set_body_tint(Color(1.0, 0.8, 0.8, 1.0))
	var timer := get_tree().create_timer(0.12)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and state != &"dead":
			_update_visuals()
	)
	if current_phase == 1 and hp > 0.0 and hp <= phase_threshold_hp:
		current_phase = 2
		state = &"phase_change"
		state_time = 0.0
		action_committed = false
		invulnerable = true
		normal_attack_counter = 0
		barrage_counter = 0
		teleport_marker.visible = false
		charge_line.visible = false
		phase_ring.visible = true
		_refresh_phase_visuals()
		_show_intent_text("Phase Two", Color(1.0, 0.88, 0.62, 1.0), global_position, 0.94)

func _on_died() -> void:
	state = &"dead"
	invulnerable = true
	teleport_marker.visible = false
	charge_line.visible = false
	phase_ring.visible = false
	Sfx.play_event(&"boss_generic_dead", global_position)
	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)
