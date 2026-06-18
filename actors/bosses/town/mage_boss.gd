extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ARCANE_BOLT_SCENE := preload("res://effects/projectiles/arcane_bolt.tscn")
const MAGE_RED_BOLT_SCENE := preload("res://effects/projectiles/mage_boss_red_bolt.tscn")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const MAGE_BODY_TEXTURE_PATH := "res://actors/bosses/textures/mage_boss.png"
const MAGE_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_mage_staff.png"
const MAGE_SKILL1_BULLET_TEXTURE_PATH := "res://assets/effects/projectiles/boss_bullet_red.webp"
const MAGE_LASER_BODY_TEXTURE_PATH := "res://assets/effects/projectiles/mage_boss_laser_body.webp"
const MAGE_LASER_CORE_TEXTURE_PATH := "res://assets/effects/projectiles/mage_boss_laser_core.png"

@export var max_hp: float = 3300.0
@export var defense_value: float = 205.0
@export var move_speed: float = 170.0

@export var skill_cooldown_between_casts: float = 3.0

@export var skill1_charge_duration: float = 0.85
@export var skill1_radius_from_boss: float = 92.0
@export var skill1_wave_count: int = 6
@export var skill1_wave_interval: float = 0.34
@export var skill1_projectiles_per_ring: int = 18
@export var skill1_spiral_offset_degrees: float = 13.0
@export var skill1_aimed_bullets_per_wave: int = 3
@export var skill1_aimed_spread_degrees: float = 18.0
@export var skill1_damage: float = 30.0
@export var skill1_ring_projectile_speed: float = 235.0
@export var skill1_aimed_projectile_speed: float = 380.0

@export var skill2_marker_radius: float = 30.0
@export var skill2_expand_speed: float = 230.0
@export var skill2_expand_duration: float = 1.35
@export var skill2_damage: float = 88.0

@export var skill3_charge_duration: float = 1.0
@export var skill3_laser_damage: float = 80.0
@export var skill3_rotate_speed_degrees: float = 35.0
@export var skill3_rotate_duration: float = 2.8
@export var skill3_hold_duration: float = 0.55
@export var skill3_laser_length: float = 1040.0
@export var skill3_laser_width: float = 20.0

@export var skill4_burst_spawn_radius: float = 300.0
@export var skill4_burst_radius: float = 56.0
@export var skill4_warning_duration: float = 1.0
@export var skill4_damage: float = 50.0
@export var skill4_burst_count: int = 9

@export var skill5_projectiles_per_wave: int = 28
@export var skill5_wave_count: int = 6
@export var skill5_wave_interval: float = 0.38
@export var skill5_angle_offset_degrees: float = 9.0
@export var skill5_damage: float = 30.0
@export var skill5_projectile_speed: float = 300.0

@onready var body: Polygon2D = $Body
@onready var focus_ring: Line2D = $FocusRing
@onready var burst_ring: Line2D = $BurstRing
@onready var enchant_sigil: Line2D = $EnchantSigil
@onready var blade_orbit: Node2D = $BladeOrbit
@onready var weapon: Node2D = $Weapon
@onready var projectile_spawner: Node2D = $ProjectileSpawner
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

var target: Node2D = null
var hp: float = 0.0
var state: StringName = &"idle"
var state_time: float = 0.0
var recover_duration: float = 0.0
var skill_cooldown_remaining: float = 1.5
var line_direction: Vector2 = Vector2.RIGHT
var action_committed: bool = false
var current_skill_target: Vector2 = Vector2.ZERO
var current_skill_id: int = -1
var last_skill_id: int = -1
var body_sprite: Sprite2D = null
var weapon_sprite: Sprite2D = null
var laser_body_sprite: Sprite2D = null
var laser_core_sprite: Sprite2D = null
var laser_line: Line2D = null
var skill1_bullet_texture: Texture2D = null
var skill3_laser_body_texture: Texture2D = null
var skill3_laser_core_texture: Texture2D = null
var weapon_angle_offset: float = deg_to_rad(98.0)
var visual_last_position: Vector2 = Vector2.ZERO
var visual_bob_time: float = 0.0
var skill_rng := RandomNumberGenerator.new()
var skill1_current_wave: int = 0
var skill1_next_wave_time: float = 0.0
var skill1_base_angle: float = 0.0
var skill1_spin_direction: float = 1.0
var skill2_ring_radius: float = 0.0
var skill3_target_angle: float = 0.0
var skill3_start_angle: float = 0.0
var skill3_current_angle: float = 0.0
var skill4_markers: Array[Dictionary] = []
var skill5_current_wave: int = 0
var skill5_next_wave_time: float = 0.0

func _ready() -> void:
	add_to_group("damageable")
	skill_rng.randomize()
	skill1_bullet_texture = TEXTURE_LOADER.load_texture(MAGE_SKILL1_BULLET_TEXTURE_PATH)
	skill3_laser_body_texture = TEXTURE_LOADER.load_texture(MAGE_LASER_BODY_TEXTURE_PATH)
	skill3_laser_core_texture = TEXTURE_LOADER.load_texture(MAGE_LASER_CORE_TEXTURE_PATH)
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	hp = max_hp
	visual_last_position = global_position
	_setup_body_visual()
	_setup_weapon_visual()
	_setup_laser_visuals()
	focus_ring.visible = false
	burst_ring.visible = false
	enchant_sigil.visible = false
	blade_orbit.visible = false
	_clear_unused_visual_nodes()
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func get_status_title() -> String:
	return "Grand Arcanist"

func get_status_text() -> String:
	return "HP %d / %d\nState: %s" % [
		int(round(hp)),
		int(round(max_hp)),
		String(state)
	]

func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	if target == null or not _is_targetable_player(target):
		_find_target()
	skill_cooldown_remaining = maxf(skill_cooldown_remaining - delta, 0.0)
	state_time += delta
	_update_state(delta)
	_update_visuals()

func receive_hit(payload: Dictionary) -> void:
	if state == &"dead":
		return
	var result: Dictionary = health_component.receive_hit(payload)
	var final_damage := float(result.get("damage", 0.0))
	if final_damage > 0.0:
		_spawn_damage_number(final_damage, bool(result.get("is_critical", false)))

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

func _update_state(delta: float) -> void:
	match state:
		&"idle":
			_process_idle(delta)
		&"skill1_charge":
			_process_skill1_charge()
		&"skill1_release":
			_process_skill1_release()
		&"skill2_charge":
			_process_skill2_charge(delta)
		&"skill2_resolve":
			_process_skill2_resolve()
		&"skill3_charge":
			_process_skill3_charge()
		&"skill3_rotate":
			_process_skill3_rotate()
		&"skill3_hold":
			_process_skill3_hold()
		&"skill4_cast":
			_process_skill4_cast()
		&"skill5_cast":
			_process_skill5_cast()
		&"recover":
			_process_recover()

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target != Vector2.ZERO:
		line_direction = to_target.normalized()
	if skill_cooldown_remaining <= 0.0:
		_start_random_skill()
		return
	var orbit := Vector2(-line_direction.y, line_direction.x)
	global_position += orbit.normalized() * move_speed * 0.45 * delta

func _start_random_skill() -> void:
	var candidates := [1, 2, 3, 4, 5]
	candidates.erase(last_skill_id)
	current_skill_id = candidates[skill_rng.randi_range(0, candidates.size() - 1)]
	last_skill_id = current_skill_id
	skill_cooldown_remaining = skill_cooldown_between_casts
	match current_skill_id:
		1:
			_start_skill1()
		2:
			_start_skill2()
		3:
			_start_skill3()
		4:
			_start_skill4()
		5:
			_start_skill5()

func _start_skill1() -> void:
	state = &"skill1_charge"
	state_time = 0.0
	action_committed = false
	skill1_current_wave = 0
	skill1_next_wave_time = 0.0
	skill1_base_angle = skill_rng.randf_range(0.0, TAU)
	skill1_spin_direction = 1.0 if skill_rng.randi_range(0, 1) == 0 else -1.0
	burst_ring.visible = true
	burst_ring.global_position = global_position
	burst_ring.default_color = Color(1.0, 0.22, 0.12, 0.72)
	burst_ring.points = _build_ring_points(skill1_radius_from_boss, 28)
	_show_intent_text("!", Color(1.0, 0.95, 0.56, 1.0), global_position, 0.92)

func _process_skill1_charge() -> void:
	if state_time < skill1_charge_duration:
		burst_ring.visible = true
		burst_ring.global_position = global_position
		burst_ring.points = _build_ring_points(skill1_radius_from_boss + sin(state_time * 18.0) * 6.0, 28)
		return
	state = &"skill1_release"
	state_time = 0.0
	burst_ring.visible = false

func _process_skill1_release() -> void:
	while skill1_current_wave < skill1_wave_count and state_time >= skill1_next_wave_time:
		_fire_skill1_wave()
		skill1_current_wave += 1
		skill1_next_wave_time += skill1_wave_interval
	if skill1_current_wave >= skill1_wave_count and state_time >= skill1_next_wave_time + 0.2:
		_enter_recover(0.12)

func _fire_skill1_wave() -> void:
	var ring_offset := deg_to_rad(skill1_spiral_offset_degrees * float(skill1_current_wave)) * skill1_spin_direction
	for index in range(skill1_projectiles_per_ring):
		var angle := skill1_base_angle + TAU * float(index) / float(skill1_projectiles_per_ring) + ring_offset
		var direction := Vector2.RIGHT.rotated(angle)
		var spawn_position := global_position + direction * skill1_radius_from_boss
		_spawn_red_bolt(spawn_position, direction, skill1_damage, skill1_ring_projectile_speed)
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target == Vector2.ZERO:
		return
	var aimed_center := to_target.normalized().angle()
	var spread_start := -deg_to_rad(skill1_aimed_spread_degrees) * 0.5
	var spread_step := deg_to_rad(skill1_aimed_spread_degrees) / maxf(float(skill1_aimed_bullets_per_wave - 1), 1.0)
	for index in range(skill1_aimed_bullets_per_wave):
		var aimed_angle := aimed_center + spread_start + spread_step * float(index)
		var aimed_direction := Vector2.RIGHT.rotated(aimed_angle)
		var spawn_position := global_position + aimed_direction * skill1_radius_from_boss
		_spawn_red_bolt(spawn_position, aimed_direction, skill1_damage, skill1_aimed_projectile_speed)

func _start_skill2() -> void:
	state = &"skill2_charge"
	state_time = 0.0
	action_committed = false
	current_skill_target = target.global_position if target != null and is_instance_valid(target) else global_position
	skill2_ring_radius = skill2_marker_radius
	burst_ring.visible = true
	burst_ring.global_position = current_skill_target
	burst_ring.points = _build_ring_points(skill2_ring_radius, 24)
	_show_intent_text("!", Color(1.0, 0.95, 0.56, 1.0), current_skill_target, 0.92)

func _process_skill2_charge(delta: float) -> void:
	skill2_ring_radius = skill2_marker_radius + skill2_expand_speed * minf(state_time, skill2_expand_duration)
	burst_ring.visible = true
	burst_ring.global_position = current_skill_target
	burst_ring.points = _build_ring_points(skill2_ring_radius, 28)
	if state_time < skill2_expand_duration:
		return
	state = &"skill2_resolve"
	state_time = 0.0
	action_committed = false

func _process_skill2_resolve() -> void:
	if not action_committed:
		action_committed = true
		_apply_radius_damage(current_skill_target, skill2_ring_radius, skill2_damage)
		_show_burst_effect(current_skill_target, skill2_ring_radius, Color(0.78, 0.90, 1.0, 0.9))
		burst_ring.visible = false
	if state_time >= 0.18:
		_enter_recover(0.12)

func _start_skill3() -> void:
	state = &"skill3_charge"
	state_time = 0.0
	action_committed = false
	var target_direction := line_direction
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target != Vector2.ZERO:
			target_direction = to_target.normalized()
	skill3_target_angle = target_direction.angle()
	skill3_start_angle = skill_rng.randf_range(-PI, PI)
	skill3_current_angle = skill3_start_angle
	_show_laser_effect()
	_show_intent_text("!", Color(1.0, 0.95, 0.56, 1.0), global_position, 0.92)

func _process_skill3_charge() -> void:
	skill3_current_angle = skill3_start_angle
	_show_laser_effect()
	if state_time < skill3_charge_duration:
		return
	state = &"skill3_rotate"
	state_time = 0.0
	action_committed = false

func _process_skill3_rotate() -> void:
	if not action_committed:
		action_committed = true
	_update_skill3_laser_angles(state_time)
	_show_laser_effect()
	if state_time > 0.18:
		_apply_laser_damage()
	if state_time >= skill3_rotate_duration:
		state = &"skill3_hold"
		state_time = 0.0

func _process_skill3_hold() -> void:
	_update_skill3_laser_angles(skill3_rotate_duration)
	_show_laser_effect()
	_apply_laser_damage()
	if state_time >= skill3_hold_duration:
		_set_laser_visuals_visible(false)
		_enter_recover(0.15)

func _start_skill4() -> void:
	state = &"skill4_cast"
	state_time = 0.0
	action_committed = false
	_clear_skill4_markers()
	_show_intent_text("!", Color(1.0, 0.95, 0.56, 1.0), target.global_position if target != null and is_instance_valid(target) else global_position, 0.92)
	var center := target.global_position if target != null and is_instance_valid(target) else global_position
	for _index in range(skill4_burst_count):
		var angle := skill_rng.randf_range(0.0, TAU)
		var marker_position := center + Vector2.RIGHT.rotated(angle) * skill_rng.randf_range(0.0, skill4_burst_spawn_radius)
		var marker := Line2D.new()
		marker.width = 3.0
		marker.closed = true
		marker.default_color = Color(1.0, 0.72, 0.52, 0.92)
		marker.points = _build_ring_points(skill4_burst_radius, 18)
		marker.global_position = marker_position
		get_tree().current_scene.add_child(marker)
		skill4_markers.append({
			"node": marker,
			"position": marker_position
		})

func _process_skill4_cast() -> void:
	if state_time < skill4_warning_duration:
		return
	if not action_committed:
		action_committed = true
		for marker_data in skill4_markers:
			var marker_position := marker_data.get("position", Vector2.ZERO) as Vector2
			_apply_radius_damage(marker_position, skill4_burst_radius, skill4_damage)
			_show_burst_effect(marker_position, skill4_burst_radius, Color(1.0, 0.70, 0.50, 0.9))
		_clear_skill4_markers()
	if state_time >= skill4_warning_duration + 0.18:
		_enter_recover(0.12)

func _start_skill5() -> void:
	state = &"skill5_cast"
	state_time = 0.0
	action_committed = false
	skill5_current_wave = 0
	skill5_next_wave_time = 0.0
	_show_intent_text("!", Color(1.0, 0.95, 0.56, 1.0), global_position, 0.92)

func _process_skill5_cast() -> void:
	while skill5_current_wave < skill5_wave_count and state_time >= skill5_next_wave_time:
		_fire_skill5_wave(skill5_current_wave)
		skill5_current_wave += 1
		skill5_next_wave_time += skill5_wave_interval
	if skill5_current_wave >= skill5_wave_count and state_time >= skill5_next_wave_time + 0.18:
		_enter_recover(0.12)

func _fire_skill5_wave(wave_index: int) -> void:
	var angle_offset := deg_to_rad(skill5_angle_offset_degrees * float(wave_index))
	for index in range(skill5_projectiles_per_wave):
		var angle := TAU * float(index) / float(skill5_projectiles_per_wave) + angle_offset
		var direction := Vector2.RIGHT.rotated(angle)
		_spawn_red_bolt(global_position, direction, skill5_damage, skill5_projectile_speed)

func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	recover_duration = duration

func _process_recover() -> void:
	if state_time >= recover_duration:
		state = &"idle"
		state_time = 0.0

func _spawn_arcane_bolt(spawn_position: Vector2, direction: Vector2, damage: float) -> void:
	var bolt := ARCANE_BOLT_SCENE.instantiate()
	bolt.global_position = spawn_position
	get_tree().current_scene.add_child(bolt)
	bolt.setup(self, direction, damage, 0.0, &"skill")

func _spawn_skill1_bolt(spawn_position: Vector2, direction: Vector2, damage: float) -> void:
	_spawn_red_bolt(spawn_position, direction, damage, skill1_ring_projectile_speed)

func _spawn_red_bolt(spawn_position: Vector2, direction: Vector2, damage: float, speed: float) -> void:
	var bolt: Area2D = MAGE_RED_BOLT_SCENE.instantiate()
	bolt.global_position = spawn_position
	get_tree().current_scene.add_child(bolt)
	bolt.setup(self, direction, damage, speed)

func _apply_radius_damage(center: Vector2, radius: float, damage: float) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not _is_targetable_player(player):
			continue
		var node_2d: Node2D = player
		if center.distance_to(node_2d.global_position) > radius:
			continue
		node_2d.receive_hit({
			"source": self,
			"damage": damage,
			"crit_rate": 0.0
		})

func _apply_laser_damage() -> void:
	var direction := Vector2.RIGHT.rotated(skill3_current_angle)
	for player in get_tree().get_nodes_in_group("player"):
		if not _is_targetable_player(player):
			continue
		var node_2d := player as Node2D
		if _distance_to_segment(node_2d.global_position, global_position, global_position + direction * skill3_laser_length) <= skill3_laser_width:
			node_2d.receive_hit({
				"source": self,
				"damage": skill3_laser_damage,
				"crit_rate": 0.0
			})

func _show_laser_effect() -> void:
	focus_ring.visible = false
	enchant_sigil.visible = false
	_update_laser_sprite_pair(
		laser_body_sprite,
		laser_core_sprite,
		laser_line,
		skill3_current_angle
	)

func _update_skill3_laser_angles(elapsed: float) -> void:
	var rotate_amount := deg_to_rad(skill3_rotate_speed_degrees) * elapsed
	skill3_current_angle = _move_angle_toward(skill3_start_angle, skill3_target_angle, rotate_amount)

func _show_burst_effect(center: Vector2, radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.closed = true
	ring.default_color = color
	ring.points = _build_ring_points(radius, 20)
	ring.global_position = center
	get_tree().current_scene.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.16, 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.finished.connect(ring.queue_free)

func _clear_skill4_markers() -> void:
	for marker_data in skill4_markers:
		var marker: Variant = marker_data.get("node", null)
		if marker is Node and is_instance_valid(marker):
			(marker as Node).queue_free()
	skill4_markers.clear()

func _clear_unused_visual_nodes() -> void:
	enchant_sigil.visible = false
	focus_ring.visible = false
	blade_orbit.visible = false
	_set_laser_visuals_visible(false)

func _setup_body_visual() -> void:
	body_sprite = Sprite2D.new()
	body_sprite.texture = TEXTURE_LOADER.load_texture(MAGE_BODY_TEXTURE_PATH)
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_sprite.centered = true
	body_sprite.scale = Vector2.ONE * 0.32
	body.add_child(body_sprite)
	body.color = Color(1.0, 1.0, 1.0, 0.0)

func _set_body_tint(color: Color) -> void:
	if body_sprite != null:
		body_sprite.self_modulate = color
	else:
		body.color = color

func _setup_weapon_visual() -> void:
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture = TEXTURE_LOADER.load_texture(MAGE_WEAPON_TEXTURE_PATH)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = true
	weapon_sprite.scale = Vector2.ONE * 0.62
	weapon_sprite.position = Vector2(-40.0, 4.0)
	weapon.add_child(weapon_sprite)

func _setup_laser_visuals() -> void:
	laser_body_sprite = _create_laser_body_sprite("LaserBody")
	laser_core_sprite = _create_laser_core_sprite("LaserCore")
	laser_line = _create_laser_line("LaserLine")

func _create_laser_body_sprite(node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = skill3_laser_body_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.visible = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.94)
	sprite.z_index = 80
	effects_layer.add_child(sprite)
	return sprite

func _create_laser_core_sprite(node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = skill3_laser_core_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.visible = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
	sprite.z_index = 81
	effects_layer.add_child(sprite)
	return sprite

func _create_laser_line(node_name: String) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.width = skill3_laser_width * 1.35
	line.default_color = Color(1.0, 0.82, 0.42, 0.78)
	line.visible = false
	line.z_index = 82
	line.closed = false
	effects_layer.add_child(line)
	return line

func _update_laser_sprite_pair(body_sprite_ref: Sprite2D, core_sprite_ref: Sprite2D, line_ref: Line2D, angle: float) -> void:
	if body_sprite_ref == null or core_sprite_ref == null:
		return
	var direction := Vector2.RIGHT.rotated(angle)
	if line_ref != null:
		line_ref.visible = true
		line_ref.global_position = global_position
		line_ref.points = PackedVector2Array([
			Vector2.ZERO,
			direction * skill3_laser_length
		])
	if skill3_laser_body_texture != null:
		var body_size := skill3_laser_body_texture.get_size()
		var body_scale_x := skill3_laser_length / maxf(body_size.x, 1.0)
		var body_scale_y := maxf((skill3_laser_width * 2.2) / maxf(body_size.y, 1.0), 0.01)
		body_sprite_ref.visible = true
		body_sprite_ref.global_position = global_position + direction * (skill3_laser_length * 0.5)
		body_sprite_ref.rotation = angle
		body_sprite_ref.scale = Vector2(body_scale_x, body_scale_y)
	if skill3_laser_core_texture != null:
		core_sprite_ref.visible = true
		core_sprite_ref.global_position = global_position
		core_sprite_ref.scale = Vector2.ONE * 1.1
		core_sprite_ref.rotation = 0.0

func _set_laser_visuals_visible(visible_value: bool) -> void:
	for item in [laser_body_sprite, laser_core_sprite, laser_line]:
		if item != null:
			item.visible = visible_value

func _update_visuals() -> void:
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target != Vector2.ZERO:
			line_direction = to_target.normalized()
	_set_body_tint(Color.WHITE)
	burst_ring.default_color = Color(0.78, 0.9, 1.0, 0.9)
	_apply_float_body_motion(1.45, 0.055)
	weapon.position = line_direction * 18.0 + Vector2(0.0, -4.0)
	weapon.rotation = line_direction.angle() + weapon_angle_offset
	projectile_spawner.position = line_direction * 26.0
	visual_last_position = global_position

func _apply_float_body_motion(float_scale: float, sway_scale: float) -> void:
	var movement := global_position - visual_last_position
	var motion_ratio := clampf(movement.length() / maxf(move_speed * get_physics_process_delta_time(), 1.0), 0.0, 1.0)
	visual_bob_time += 0.075 + motion_ratio * 0.11
	var facing := -1.0 if line_direction.x < -0.05 else 1.0
	if body_sprite != null:
		body_sprite.flip_h = facing < 0.0
		body_sprite.position.x = sin(visual_bob_time * 0.7) * (1.2 + motion_ratio * 2.4) * facing
		body_sprite.scale = Vector2(0.32 + sin(visual_bob_time * 0.9) * 0.008, 0.32 + cos(visual_bob_time * 0.75) * 0.018)
	body.position = Vector2(0.0, sin(visual_bob_time) * (2.0 + motion_ratio * 3.4) * float_scale)
	body.rotation = sin(visual_bob_time * 0.6) * (0.018 + motion_ratio * sway_scale) * facing

func _build_ring_points(radius: float, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_sq := segment.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(segment_start)
	var weight := clampf((point - segment_start).dot(segment) / length_sq, 0.0, 1.0)
	var closest := segment_start + segment * weight
	return point.distance_to(closest)

func _move_angle_toward(from_angle: float, to_angle: float, max_delta: float) -> float:
	var difference := angle_difference(from_angle, to_angle)
	if absf(difference) <= max_delta:
		return to_angle
	return from_angle + signf(difference) * max_delta

func _show_intent_text(label_text: String, color_value: Color, world_position: Vector2, scale_value: float = 0.84) -> void:
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = to_local(world_position) + Vector2(-42.0, -100.0)
	if popup.has_method("setup_text"):
		popup.setup_text(label_text, color_value, scale_value)
	if popup is CanvasItem:
		(popup as CanvasItem).z_index = 60
	popup.lifetime = 0.8
	effects_layer.add_child(popup)

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -40.0)
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
	state = &"dead"
	focus_ring.visible = false
	burst_ring.visible = false
	enchant_sigil.visible = false
	_set_laser_visuals_visible(false)
	blade_orbit.visible = false
	weapon.visible = false
	_clear_skill4_markers()
	Sfx.play_event(&"boss_generic_dead", global_position)
	var timer := get_tree().create_timer(0.55)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)
