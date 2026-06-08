extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ARCANE_BOLT_SCENE := preload("res://effects/projectiles/arcane_bolt.tscn")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const MAGE_BODY_TEXTURE_PATH := "res://actors/bosses/textures/mage_boss.png"
const MAGE_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_mage_staff.png"

@export var max_hp: float = 3300.0
@export var defense_value: float = 205.0
@export var move_speed: float = 180.0
@export var attack_damage: float = 44.0
@export var attack_interval: float = 1.0
@export var attack_targeting_range: float = 560.0
@export var skill1_damage: float = 28.0
@export var skill1_cooldown: float = 8.2
@export var blade_duration: float = 7.0
@export var blade_radius: float = 96.0
@export var blade_tick_interval: float = 0.8
@export var skill1_shield_value: float = 130.0
@export var skill2_damage: float = 92.0
@export var skill2_cooldown: float = 7.0
@export var skill2_cast_duration: float = 0.42
@export var burst_radius: float = 128.0
@export var burst_targeting_range: float = 520.0
@export var chain_burst_damage: float = 56.0
@export var skill3_cooldown: float = 6.2
@export var skill3_cast_duration: float = 0.26
@export var silence_duration: float = 2.2
@export var slow_duration: float = 3.5
@export var slow_multiplier: float = 0.55
@export var root_duration: float = 1.0

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
var shield: float = 0.0
var state: StringName = &"idle"
var state_time: float = 0.0
var recover_duration: float = 0.0
var attack_cooldown: float = 0.0
var skill1_cooldown_remaining: float = 1.2
var skill2_cooldown_remaining: float = 3.0
var skill3_cooldown_remaining: float = 4.8
var line_direction: Vector2 = Vector2.RIGHT
var action_committed: bool = false
var blades_active: bool = false
var blade_time_remaining: float = 0.0
var blade_hit_cooldowns: Dictionary = {}
var blade_nodes: Array[Polygon2D] = []
var enchant_active: bool = false
var current_skill_target: Node2D = null
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0
var body_sprite: Sprite2D = null
var weapon_sprite: Sprite2D = null
var weapon_angle_offset: float = deg_to_rad(98.0)
var orbit_direction: float = 1.0
var visual_last_position: Vector2 = Vector2.ZERO
var visual_bob_time: float = 0.0

func _ready() -> void:
	add_to_group("damageable")
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.healed.connect(_on_healed)
	health_component.shield_changed.connect(_on_shield_changed)
	health_component.died.connect(_on_died)
	hp = max_hp
	visual_last_position = global_position
	_setup_body_visual()
	_setup_weapon_visual()
	for child in blade_orbit.get_children():
		if child is Polygon2D:
			blade_nodes.append(child)
	focus_ring.visible = false
	burst_ring.visible = false
	enchant_sigil.visible = false
	blade_orbit.visible = false
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func get_status_title() -> String:
	return "Grand Arcanist"

func get_status_text() -> String:
	var shield_text := " | Shield %d" % int(round(shield)) if shield > 0.0 else ""
	return "HP %d / %d%s\nState: %s" % [
		int(round(hp)),
		int(round(max_hp)),
		shield_text,
		String(state)
	]

func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	if target == null or not _is_targetable_player(target):
		_find_target()
	_update_status_timers(delta)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	skill1_cooldown_remaining = maxf(skill1_cooldown_remaining - delta, 0.0)
	skill2_cooldown_remaining = maxf(skill2_cooldown_remaining - delta, 0.0)
	skill3_cooldown_remaining = maxf(skill3_cooldown_remaining - delta, 0.0)
	state_time += delta
	_update_blades(delta)
	_update_state(delta)
	_update_visuals()

func receive_hit(payload: Dictionary) -> void:
	if state == &"dead":
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

func _update_state(delta: float) -> void:
	match state:
		&"idle":
			_process_idle(delta)
		&"basic_attack":
			_process_basic_attack()
		&"skill1_cast":
			_process_skill1_cast()
		&"skill2_cast":
			_process_skill2_cast()
		&"skill3_cast":
			_process_skill3_cast()
		&"recover":
			_process_recover()

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target != Vector2.ZERO:
		line_direction = to_target.normalized()
	if _can_use_skills() and not enchant_active and skill3_cooldown_remaining <= 0.0:
		_start_skill3_cast()
		return
	if _can_use_skills() and skill2_cooldown_remaining <= 0.0 and distance <= burst_targeting_range:
		_start_skill2_cast()
		return
	if _can_use_skills() and not blades_active and skill1_cooldown_remaining <= 0.0 and distance <= 240.0:
		_start_skill1_cast()
		return
	if attack_cooldown <= 0.0 and distance <= attack_targeting_range:
		_start_basic_attack()
		return
	if root_time_remaining > 0.0:
		return
	var tangent := Vector2(-line_direction.y, line_direction.x) * orbit_direction
	var speed := move_speed * slow_factor
	if distance < 180.0:
		global_position -= line_direction * speed * 0.9 * delta
	elif distance > 340.0:
		global_position += line_direction * speed * 0.75 * delta
	else:
		if state_time >= 0.56:
			state_time = 0.0
			orbit_direction *= -1.0
			tangent = Vector2(-line_direction.y, line_direction.x) * orbit_direction
		global_position += tangent.normalized() * speed * 0.5 * delta

func _start_basic_attack() -> void:
	state = &"basic_attack"
	state_time = 0.0
	action_committed = false
	attack_cooldown = attack_interval
	focus_ring.visible = true
	_animate_weapon_swing(-56.0, 18.0, 0.24)
	Sfx.play_event(&"mage_attack", global_position)

func _process_basic_attack() -> void:
	if not action_committed and state_time >= 0.24:
		action_committed = true
		_fire_arcane_bolt(attack_damage)
	if state_time >= 0.48:
		_enter_recover(0.16)

func _start_skill1_cast() -> void:
	state = &"skill1_cast"
	state_time = 0.0
	action_committed = false
	skill1_cooldown_remaining = skill1_cooldown
	_animate_weapon_swing(-34.0, 14.0, 0.28)
	Sfx.play_event(&"mage_skill1_blades", global_position)

func _process_skill1_cast() -> void:
	if not action_committed and state_time >= 0.28:
		action_committed = true
		_activate_arcane_blades()
	if state_time >= 0.46:
		_enter_recover(0.16)

func _activate_arcane_blades() -> void:
	blades_active = true
	blade_time_remaining = blade_duration
	blade_hit_cooldowns.clear()
	blade_orbit.visible = true
	health_component.set_shield(skill1_shield_value)

func _start_skill2_cast() -> void:
	state = &"skill2_cast"
	state_time = 0.0
	action_committed = false
	skill2_cooldown_remaining = skill2_cooldown
	current_skill_target = target
	burst_ring.visible = true
	burst_ring.scale = Vector2.ONE * 0.4
	_animate_weapon_swing(-26.0, 12.0, skill2_cast_duration)
	Sfx.play_event(&"mage_skill2_burst", global_position)

func _process_skill2_cast() -> void:
	if current_skill_target != null and is_instance_valid(current_skill_target):
		burst_ring.global_position = current_skill_target.global_position
	if burst_ring.visible:
		burst_ring.scale = Vector2.ONE * (0.4 + minf(state_time * 1.35, 0.72))
	if not action_committed and state_time >= skill2_cast_duration * 0.62:
		action_committed = true
		var center := current_skill_target.global_position if current_skill_target != null and is_instance_valid(current_skill_target) else global_position + line_direction * 110.0
		_release_arcane_burst(center)
	if state_time >= skill2_cast_duration + 0.2:
		burst_ring.visible = false
		current_skill_target = null
		_enter_recover(0.18)

func _release_arcane_burst(center: Vector2) -> void:
	var extra_payload := _consume_enchant_payload()
	_apply_burst_damage(center, burst_radius, skill2_damage, extra_payload)
	_show_burst_effect(center, burst_radius)
	if hp <= max_hp * 0.5:
		var timer := get_tree().create_timer(0.18)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and state != &"dead":
				_apply_burst_damage(center, burst_radius * 0.72, chain_burst_damage, {})
				_show_burst_effect(center, burst_radius * 0.72)
		)

func _start_skill3_cast() -> void:
	state = &"skill3_cast"
	state_time = 0.0
	action_committed = false
	skill3_cooldown_remaining = skill3_cooldown
	_animate_weapon_swing(-42.0, 10.0, skill3_cast_duration)
	Sfx.play_event(&"mage_skill3_enchant", global_position)

func _process_skill3_cast() -> void:
	if not action_committed and state_time >= skill3_cast_duration * 0.55:
		action_committed = true
		enchant_active = true
		enchant_sigil.visible = true
	if state_time >= skill3_cast_duration + 0.12:
		_enter_recover(0.12)

func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	recover_duration = duration
	focus_ring.visible = false

func _process_recover() -> void:
	if state_time >= recover_duration:
		state = &"idle"
		state_time = 0.0

func _can_use_skills() -> bool:
	return silenced_time_remaining <= 0.0

func _fire_arcane_bolt(damage: float) -> void:
	var direction := line_direction if line_direction != Vector2.ZERO else Vector2.RIGHT
	var bolt := ARCANE_BOLT_SCENE.instantiate()
	bolt.global_position = projectile_spawner.global_position
	get_tree().current_scene.add_child(bolt)
	bolt.setup(self, direction, damage, 0.0, &"attack", _consume_enchant_payload())

func _consume_enchant_payload() -> Dictionary:
	if not enchant_active:
		return {}
	enchant_active = false
	enchant_sigil.visible = false
	return _build_control_payload()

func _apply_burst_damage(center: Vector2, radius: float, damage: float, extra_payload: Dictionary) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if not _is_targetable_player(player):
			continue
		var node_2d: Node2D = player
		if center.distance_to(node_2d.global_position) > radius:
			continue
		var payload := {
			"source": self,
			"damage": damage,
			"crit_rate": 0.0
		}
		for key in extra_payload.keys():
			payload[key] = extra_payload[key]
		node_2d.receive_hit(payload)

func _build_control_payload() -> Dictionary:
	return {
		"silence_duration": silence_duration,
		"slow_duration": slow_duration,
		"slow_multiplier": slow_multiplier,
		"root_duration": root_duration
	}

func _update_blades(delta: float) -> void:
	if not blades_active:
		return
	blade_time_remaining = maxf(blade_time_remaining - delta, 0.0)
	blade_orbit.visible = true
	blade_orbit.rotation += delta * 2.8
	for key in blade_hit_cooldowns.keys():
		blade_hit_cooldowns[key] = maxf(float(blade_hit_cooldowns[key]) - delta, 0.0)
	for index in range(blade_nodes.size()):
		var angle := blade_orbit.rotation + TAU * float(index) / float(max(blade_nodes.size(), 1))
		blade_nodes[index].position = Vector2.RIGHT.rotated(angle) * 34.0
	for player in get_tree().get_nodes_in_group("player"):
		if not _is_targetable_player(player):
			continue
		var node_2d: Node2D = player
		if global_position.distance_to(node_2d.global_position) > blade_radius:
			continue
		var key := node_2d.get_instance_id()
		if float(blade_hit_cooldowns.get(key, 0.0)) > 0.0:
			continue
		blade_hit_cooldowns[key] = blade_tick_interval
		node_2d.receive_hit({
			"source": self,
			"damage": skill1_damage,
			"crit_rate": 0.0
		})
	if blade_time_remaining <= 0.0:
		blades_active = false
		blade_orbit.visible = false
		blade_hit_cooldowns.clear()

func _show_burst_effect(center: Vector2, radius: float) -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.closed = true
	ring.default_color = Color(0.78, 0.9, 1.0, 0.88)
	ring.points = _build_ring_points(radius, 18)
	ring.global_position = center
	get_tree().current_scene.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.18, 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.finished.connect(ring.queue_free)

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

func _animate_weapon_swing(start_degrees: float, end_degrees: float, duration: float) -> void:
	weapon_angle_offset = deg_to_rad(start_degrees)
	var tween := create_tween()
	tween.tween_property(self, "weapon_angle_offset", deg_to_rad(end_degrees), maxf(duration, 0.01))

func _update_visuals() -> void:
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target != Vector2.ZERO:
			line_direction = to_target.normalized()
	var body_tint := Color.WHITE
	if silenced_time_remaining > 0.0:
		body_tint = Color(0.9, 0.82, 1.0, 1.0)
	elif enchant_active:
		body_tint = Color(1.0, 0.95, 0.86, 1.0)
	elif blades_active:
		body_tint = Color(0.9, 0.96, 1.0, 1.0)
	_set_body_tint(body_tint)
	focus_ring.visible = state == &"basic_attack"
	if focus_ring.visible:
		focus_ring.rotation = line_direction.angle()
		focus_ring.scale = Vector2.ONE * (0.9 + 0.08 * sin(Time.get_ticks_msec() * 0.008))
	burst_ring.default_color = Color(0.78, 0.9, 1.0, 0.9)
	enchant_sigil.visible = enchant_active
	if enchant_sigil.visible:
		enchant_sigil.rotation += 0.08
		enchant_sigil.scale = Vector2.ONE * (0.96 + 0.08 * sin(Time.get_ticks_msec() * 0.008))
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

func _on_healed(_amount: float, current_hp: float) -> void:
	hp = current_hp

func _on_shield_changed(current_shield: float) -> void:
	shield = current_shield

func _on_died() -> void:
	if state == &"dead":
		return
	hp = 0.0
	state = &"dead"
	focus_ring.visible = false
	burst_ring.visible = false
	enchant_sigil.visible = false
	blade_orbit.visible = false
	weapon.visible = false
	Sfx.play_event(&"boss_generic_dead", global_position)
	var timer := get_tree().create_timer(0.55)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)
