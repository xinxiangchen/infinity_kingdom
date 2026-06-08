extends CharacterBody2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ENEMY_BOLT_SCENE := preload("res://effects/projectiles/enemy_bolt.tscn")
const ENEMY_WEAPON_TEXTURE_PATHS := [
	[
		"res://art/final_materials/weapons/enemy_sword_guard_sword_normal.png",
		"res://art/final_materials/weapons/enemy_sword_guard_sword_elite.png"
	],
	[
		"res://art/final_materials/weapons/enemy_shield_guard_sword_normal.png",
		"res://art/final_materials/weapons/enemy_shield_guard_sword_elite.png"
	],
	[
		"res://art/final_materials/weapons/enemy_archer_bow_normal.png",
		"res://art/final_materials/weapons/enemy_archer_bow_elite.png"
	],
	[
		"res://art/final_materials/weapons/enemy_hunter_knife_normal.png",
		"res://art/final_materials/weapons/enemy_hunter_knife_elite.png"
	],
	[
		"res://art/final_materials/weapons/enemy_apprentice_staff_normal.png",
		"res://art/final_materials/weapons/enemy_apprentice_staff_elite.png"
	],
	[
		"res://art/final_materials/weapons/enemy_arcanist_staff_normal.png",
		"res://art/final_materials/weapons/enemy_arcanist_staff_elite.png"
	]
]
const ENEMY_WEAPON_OFFSETS := [
	Vector2(17.0, 0.0),
	Vector2(17.0, 0.0),
	Vector2(18.0, 0.0),
	Vector2(16.0, 0.0),
	Vector2(22.0, 0.0),
	Vector2(22.0, 0.0)
]
const ENEMY_WEAPON_SCALES := [
	Vector2(0.46, 0.46),
	Vector2(0.46, 0.46),
	Vector2(0.46, 0.46),
	Vector2(0.44, 0.44),
	Vector2(0.46, 0.46),
	Vector2(0.48, 0.48)
]
const ARCANIST_LASER_TELEGRAPH_DURATION := 0.72
const ARCANIST_LASER_LENGTH := 360.0
const ARCANIST_LASER_WIDTH := 18.0
const ARCANIST_ELITE_LASER_WIDTH := 26.0

enum EnemyType {
	SWORDSMAN,
	SHIELD,
	ARCHER,
	HUNTER,
	APPRENTICE_MAGE,
	ARCANIST
}

@export var enemy_type: EnemyType = EnemyType.SWORDSMAN
@export var display_name: String = "Enemy"
@export var max_hp: float = 200.0
@export var defense_value: float = 60.0
@export var move_speed: float = 110.0
@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.6
@export var attack_range: float = 80.0
@export var detection_range: float = 420.0
@export var elite: bool = false
@export var elite_scale: float = 2.0

@onready var body: CanvasItem = $Body
@onready var weapon: Node2D = $Weapon
@onready var weapon_sprite: Sprite2D = get_node_or_null("Weapon/WeaponSprite")
@onready var telegraph_ring: Line2D = $TelegraphRing
@onready var telegraph_line: Line2D = $TelegraphLine
@onready var projectile_spawner: Node2D = $ProjectileSpawner
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

var target: Node2D = null
var hp: float = 0.0
var state: StringName = &"idle"
var state_time: float = 0.0
var attack_cooldown: float = 0.0
var skill_cooldown: float = 0.0
var recover_duration: float = 0.0
var action_committed: bool = false
var retreat_direction: Vector2 = Vector2.ZERO
var basic_attack_counter: int = 0
var line_direction: Vector2 = Vector2.RIGHT
var special_target_position: Vector2 = Vector2.ZERO
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0
var orbit_direction: float = 1.0
var movement_rng := RandomNumberGenerator.new()
var movement_variation_timer: float = 0.0
var movement_variation_direction: Vector2 = Vector2.ZERO
var movement_variation_strength: float = 0.0
var base_body_position: Vector2 = Vector2.ZERO
var base_weapon_position: Vector2 = Vector2.ZERO
var base_projectile_spawner_position: Vector2 = Vector2.ZERO
var visual_bob_time: float = 0.0
var death_sequence_started: bool = false

func _ready() -> void:
	movement_rng.randomize()
	add_to_group("damageable")
	_apply_elite_scaling()
	_setup_weapon_visual()
	if body is Node2D:
		base_body_position = (body as Node2D).position
	if weapon != null:
		base_weapon_position = weapon.position
	if projectile_spawner != null:
		base_projectile_spawner_position = projectile_spawner.position
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	hp = max_hp
	telegraph_ring.visible = false
	telegraph_line.visible = false
	_find_target()
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func receive_hit(payload: Dictionary) -> void:
	if hp <= 0.0:
		return
	var result: Dictionary = health_component.receive_hit(payload)
	var final_damage := float(result.get("damage", 0.0))
	var displayed_damage := float(result.get("total_damage", final_damage))
	if final_damage > 0.0:
		apply_control_effects(payload)
	if displayed_damage > 0.0:
		_spawn_damage_number(displayed_damage, bool(result.get("is_critical", false)))

func apply_control_effects(payload: Dictionary) -> void:
	if payload.has("silence_duration"):
		silenced_time_remaining = maxf(silenced_time_remaining, float(payload["silence_duration"]))
	if payload.has("root_duration"):
		root_time_remaining = maxf(root_time_remaining, float(payload["root_duration"]))
	if payload.has("slow_duration"):
		slow_time_remaining = maxf(slow_time_remaining, float(payload["slow_duration"]))
		slow_factor = minf(slow_factor, float(payload.get("slow_multiplier", 1.0)))

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	visual_bob_time += delta * lerpf(4.5, 9.0, clampf(velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0))
	_update_status_timers(delta)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	skill_cooldown = maxf(skill_cooldown - delta, 0.0)
	state_time += delta
	_update_targeting()
	_update_movement_variation(delta)
	_update_behavior(delta)
	move_and_slide()
	_update_visuals()

func _apply_elite_scaling() -> void:
	if not elite:
		return
	max_hp *= elite_scale
	attack_damage *= elite_scale
	if enemy_type == EnemyType.SHIELD:
		defense_value *= 2.5
	elif enemy_type == EnemyType.ARCANIST:
		defense_value *= 1.5
	else:
		defense_value *= elite_scale

func _find_target() -> void:
	var best_target: Node2D = null
	var best_distance_sq := detection_range * detection_range
	for candidate in get_tree().get_nodes_in_group("player"):
		if not _is_targetable_player(candidate):
			continue
		var candidate_node: Node2D = candidate
		var distance_sq := global_position.distance_squared_to(candidate_node.global_position)
		if distance_sq > best_distance_sq:
			continue
		best_distance_sq = distance_sq
		best_target = candidate_node
	target = best_target

func _update_targeting() -> void:
	if _is_targetable_player(target):
		var tracked_target: Node2D = target
		if global_position.distance_squared_to(tracked_target.global_position) <= _get_target_drop_range() * _get_target_drop_range():
			return
	target = null
	_find_target()

func _is_targetable_player(candidate: Variant) -> bool:
	if candidate == null or not (candidate is Node2D):
		return false
	var node: Node2D = candidate
	if not is_instance_valid(node):
		return false
	var hp_value: Variant = node.get("hp")
	if hp_value != null and float(hp_value) <= 0.0:
		return false
	return true

func _get_target_drop_range() -> float:
	return maxf(detection_range * 1.35, attack_range + 180.0)

func _update_status_timers(delta: float) -> void:
	silenced_time_remaining = maxf(silenced_time_remaining - delta, 0.0)
	root_time_remaining = maxf(root_time_remaining - delta, 0.0)
	if slow_time_remaining > 0.0:
		slow_time_remaining = maxf(slow_time_remaining - delta, 0.0)
	else:
		slow_factor = 1.0

func _update_behavior(delta: float) -> void:
	match enemy_type:
		EnemyType.SWORDSMAN:
			_update_swordsman(delta)
		EnemyType.SHIELD:
			_update_shield(delta)
		EnemyType.ARCHER:
			_update_archer(delta)
		EnemyType.HUNTER:
			_update_hunter(delta)
		EnemyType.APPRENTICE_MAGE:
			_update_apprentice(delta)
		EnemyType.ARCANIST:
			_update_arcanist(delta)

func _update_swordsman(delta: float) -> void:
	if _should_abort_without_target():
		return
	var distance := _refresh_target_direction()
	if state == &"attack_slash":
		velocity = Vector2.ZERO
		if not action_committed and state_time >= 0.45:
			action_committed = true
			_spawn_melee_attack_effect(attack_range + 20.0, Color(1.0, 0.78, 0.5, 0.95), 24.0, 12.0)
			_hit_target_radius(attack_range, attack_damage)
		if state_time >= 0.9:
			_enter_recover(0.3)
		return
	if state == &"recover":
		_process_recover()
		return
	if distance <= attack_range and attack_cooldown <= 0.0:
		state = &"attack_slash"
		state_time = 0.0
		action_committed = false
		attack_cooldown = attack_interval
		velocity = Vector2.ZERO
		Sfx.play_event(&"enemy_swordsman_attack", global_position)
		return
	state = &"pressure"
	_set_melee_pressure_velocity(distance, attack_range * 0.88, attack_range * 0.56, 1.0, 0.2)

func _update_shield(delta: float) -> void:
	if _should_abort_without_target():
		return
	var distance := _refresh_target_direction()
	if state == &"shield_bash":
		velocity = Vector2.ZERO
		if not action_committed and state_time >= 0.55:
			action_committed = true
			_spawn_melee_attack_effect(attack_range + 26.0, Color(0.92, 0.84, 0.64, 0.95), 30.0, 14.0, true)
			_hit_target_radius(attack_range + 8.0, attack_damage)
		if state_time >= 0.95:
			_enter_recover(0.55)
		return
	if state == &"guard_hold":
		velocity = Vector2.ZERO
		if state_time >= 0.8:
			state = &"advance"
			state_time = 0.0
		return
	if state == &"recover":
		_process_recover()
		return
	if distance <= attack_range and attack_cooldown <= 0.0:
		state = &"shield_bash"
		state_time = 0.0
		action_committed = false
		attack_cooldown = attack_interval
		_show_intent_text("Shield Bash", Color(0.98, 0.86, 0.66, 1.0), 0.86)
		Sfx.play_event(&"enemy_shield_bash", global_position)
		return
	if skill_cooldown <= 0.0 and distance <= attack_range + 40.0:
		state = &"guard_hold"
		state_time = 0.0
		skill_cooldown = 4.0
		_show_intent_text("Brace", Color(0.82, 0.90, 1.0, 1.0), 0.78)
		return
	state = &"advance"
	_set_melee_pressure_velocity(distance, attack_range * 0.92, attack_range * 0.64, 0.78, 0.1)

func _update_archer(delta: float) -> void:
	if _should_abort_without_target():
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target.length_squared() > 0.0001:
		line_direction = to_target.normalized()
	if state == &"draw_bow":
		velocity = Vector2.ZERO
		if not action_committed and state_time >= 0.55:
			action_committed = true
			_fire_projectile(attack_damage, Color(0.8, 0.92, 0.66, 1.0), 540.0)
		if state_time >= 0.82:
			_enter_recover(0.28)
		return
	if state == &"recover":
		_process_recover()
		return
	if distance <= attack_range + 120.0 and attack_cooldown <= 0.0:
		state = &"draw_bow"
		state_time = 0.0
		action_committed = false
		attack_cooldown = attack_interval
		_show_intent_text("Arrow Shot", Color(0.82, 0.96, 0.72, 1.0), 0.8)
		return
	state = &"reposition"
	_set_ranged_spacing_velocity(distance, 150.0, attack_range + 120.0, 0.7, 0.7)

func _update_hunter(delta: float) -> void:
	if _should_abort_without_target():
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target.length_squared() > 0.0001:
		line_direction = to_target.normalized()
	if state == &"dash_in":
		velocity = Vector2.ZERO if root_time_remaining > 0.0 else line_direction * move_speed * 2.6 * slow_factor
		if distance <= attack_range + 10.0 or state_time >= 0.28:
			state = &"attack_cut"
			state_time = 0.0
			action_committed = false
			velocity = Vector2.ZERO
		return
	if state == &"attack_cut":
		if not action_committed and state_time >= 0.12:
			action_committed = true
			_spawn_melee_attack_effect(attack_range + 12.0, Color(1.0, 0.68, 0.66, 0.95), 18.0, 10.0)
			_hit_target_radius(attack_range + 6.0, attack_damage)
			retreat_direction = -line_direction
		if state_time >= 0.28:
			state = &"retreat"
			state_time = 0.0
		return
	if state == &"retreat":
		velocity = Vector2.ZERO if root_time_remaining > 0.0 else retreat_direction * move_speed * 1.4 * slow_factor
		if state_time >= 0.35:
			_enter_recover(0.18)
		return
	if state == &"recover":
		_process_recover()
		return
	if skill_cooldown <= 0.0 and distance <= 200.0 and _can_use_skills():
		state = &"dash_in"
		state_time = 0.0
		skill_cooldown = 3.0
		_show_intent_text("Pounce", Color(1.0, 0.74, 0.70, 1.0), 0.84)
		Sfx.play_event(&"enemy_hunter_dash", global_position)
		return
	state = &"stalk"
	_set_melee_pressure_velocity(distance, 142.0, attack_range * 0.62, 0.92, 0.46)

func _update_apprentice(delta: float) -> void:
	if _should_abort_without_target():
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target.length_squared() > 0.0001:
		line_direction = to_target.normalized()
	if state == &"cast_bolt":
		velocity = Vector2.ZERO
		if not action_committed and state_time >= 0.55:
			action_committed = true
			_fire_projectile(attack_damage, Color(0.72, 0.84, 1.0, 1.0), 420.0)
		if state_time >= 0.9:
			_enter_recover(0.45)
		return
	if state == &"recover":
		_process_recover()
		return
	if distance <= 280.0 and attack_cooldown <= 0.0:
		state = &"cast_bolt"
		state_time = 0.0
		action_committed = false
		attack_cooldown = attack_interval
		_show_intent_text("Frost Bolt", Color(0.78, 0.88, 1.0, 1.0), 0.8)
		return
	state = &"move"
	_set_ranged_spacing_velocity(distance, 180.0, 280.0, 0.62, 0.54)

func _update_arcanist(delta: float) -> void:
	if _should_abort_without_target():
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target.length_squared() > 0.0001 and state != &"skill_mark" and state != &"skill_laser":
		line_direction = to_target.normalized()
	if state == &"basic_cast":
		velocity = Vector2.ZERO
		if not action_committed and state_time >= 0.48:
			action_committed = true
			_fire_projectile(attack_damage, Color(1.0, 0.78, 0.48, 1.0), 500.0)
			basic_attack_counter += 1
		if state_time >= 0.78:
			_enter_recover(0.22)
		return
	if state == &"skill_mark":
		velocity = Vector2.ZERO
		telegraph_line.visible = true
		telegraph_line.global_position = global_position
		telegraph_line.rotation = line_direction.angle()
		_update_laser_telegraph()
		if state_time >= ARCANIST_LASER_TELEGRAPH_DURATION:
			state = &"skill_laser"
			state_time = 0.0
			action_committed = false
		return
	if state == &"skill_laser":
		velocity = Vector2.ZERO
		if not action_committed:
			action_committed = true
			var laser_length := _laser_blocked_length(ARCANIST_LASER_LENGTH)
			_update_laser_telegraph(laser_length)
			_hit_target_line(18.0 if not elite else 30.0, laser_length, ARCANIST_LASER_WIDTH if not elite else ARCANIST_ELITE_LASER_WIDTH)
			telegraph_line.default_color = Color(1.0, 0.58, 0.36, 0.95)
		if state_time >= 0.12:
			telegraph_line.visible = false
			telegraph_line.default_color = Color(1.0, 0.78, 0.46, 0.8)
			_enter_recover(0.45)
		return
	if state == &"recover":
		_process_recover()
		return
	if basic_attack_counter >= 3 and skill_cooldown <= 0.0 and _can_use_skills():
		if to_target.length_squared() > 0.0001:
			line_direction = to_target.normalized()
		state = &"skill_mark"
		state_time = 0.0
		action_committed = false
		skill_cooldown = 5.4
		basic_attack_counter = 0
		telegraph_line.visible = true
		_update_laser_telegraph()
		_show_intent_text("Silence Beam", Color(1.0, 0.78, 0.56, 1.0), 0.88)
		Sfx.play_event(&"enemy_arcanist_cast", global_position)
		return
	if distance <= 320.0 and attack_cooldown <= 0.0:
		state = &"basic_cast"
		state_time = 0.0
		action_committed = false
		attack_cooldown = attack_interval
		return
	state = &"move_float"
	_set_ranged_spacing_velocity(distance, 210.0, 320.0, 0.55, 0.72)

func _should_abort_without_target() -> bool:
	if not _is_targetable_player(target):
		velocity = Vector2.ZERO
		state = &"idle"
		telegraph_ring.visible = false
		telegraph_line.visible = false
		return true
	return false

func _refresh_target_direction() -> float:
	if target == null or not is_instance_valid(target):
		return INF
	var to_target := target.global_position - global_position
	if to_target.length_squared() > 0.0001:
		line_direction = to_target.normalized()
	return to_target.length()

func _set_melee_pressure_velocity(distance: float, preferred_distance: float, minimum_distance: float, speed_factor: float, orbit_strength: float) -> void:
	if root_time_remaining > 0.0:
		velocity = Vector2.ZERO
		return
	var final_speed := move_speed * speed_factor * slow_factor
	if distance > preferred_distance:
		velocity = _blend_wander(line_direction * final_speed, final_speed)
		return
	if distance < minimum_distance:
		velocity = _blend_wander(-line_direction * final_speed * 0.75, final_speed)
		return
	var tangent := Vector2(-line_direction.y, line_direction.x) * orbit_direction
	if tangent == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	if state_time >= 0.38:
		state_time = 0.0
		orbit_direction *= -1.0
		tangent = Vector2(-line_direction.y, line_direction.x) * orbit_direction
	velocity = _blend_wander(tangent.normalized() * final_speed * orbit_strength, final_speed)

func _set_ranged_spacing_velocity(distance: float, preferred_min: float, preferred_max: float, speed_factor: float, strafe_strength: float) -> void:
	if root_time_remaining > 0.0:
		velocity = Vector2.ZERO
		return
	var final_speed := move_speed * speed_factor * slow_factor
	if distance > preferred_max:
		velocity = _blend_wander(line_direction * final_speed, final_speed)
		return
	if distance < preferred_min:
		velocity = _blend_wander(-line_direction * final_speed, final_speed)
		return
	var strafe := Vector2(-line_direction.y, line_direction.x) * orbit_direction
	if strafe == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	if state_time >= 0.52:
		state_time = 0.0
		orbit_direction *= -1.0
		strafe = Vector2(-line_direction.y, line_direction.x) * orbit_direction
	velocity = _blend_wander(strafe.normalized() * final_speed * strafe_strength, final_speed)

func _update_movement_variation(delta: float) -> void:
	movement_variation_timer -= delta
	if movement_variation_timer > 0.0:
		return
	movement_variation_timer = movement_rng.randf_range(0.32, 0.84)
	movement_variation_direction = Vector2.RIGHT.rotated(movement_rng.randf_range(-PI, PI))
	movement_variation_strength = movement_rng.randf_range(0.06, 0.18)

func _blend_wander(base_velocity: Vector2, max_speed: float) -> Vector2:
	if movement_variation_direction == Vector2.ZERO or max_speed <= 0.0:
		return base_velocity
	var mixed := base_velocity + movement_variation_direction * max_speed * movement_variation_strength
	return mixed.limit_length(max_speed)

func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	recover_duration = duration
	velocity = Vector2.ZERO
	telegraph_ring.visible = false

func _process_recover() -> void:
	velocity = Vector2.ZERO
	if state_time >= recover_duration:
		state = &"idle"
		state_time = 0.0

func _can_use_skills() -> bool:
	return silenced_time_remaining <= 0.0

func _spawn_melee_attack_effect(radius: float, color: Color, spread: float, forward_offset: float, heavy: bool = false) -> void:
	if effects_layer == null:
		return
	var slash := Line2D.new()
	slash.antialiased = false
	slash.width = 12.0 if heavy else 8.0
	slash.default_color = color
	slash.position = line_direction * forward_offset
	slash.rotation = line_direction.angle()
	var reach := maxf(radius * 0.72, 44.0)
	slash.points = PackedVector2Array([
		Vector2(-6.0, -spread * 0.52),
		Vector2(reach * 0.22, -spread),
		Vector2(reach * 0.62, -spread * 0.28),
		Vector2(reach, 0.0),
		Vector2(reach * 0.62, spread * 0.28),
		Vector2(reach * 0.22, spread),
		Vector2(-6.0, spread * 0.52)
	])
	slash.scale = Vector2.ONE * 0.92
	effects_layer.add_child(slash)

	var spark := Polygon2D.new()
	spark.color = color.lightened(0.12)
	spark.position = line_direction * (forward_offset + reach * 0.82)
	spark.rotation = line_direction.angle()
	spark.polygon = PackedVector2Array([
		Vector2(-8.0, -4.0),
		Vector2(0.0, -10.0),
		Vector2(14.0, -2.0),
		Vector2(20.0, 0.0),
		Vector2(14.0, 2.0),
		Vector2(0.0, 10.0),
		Vector2(-8.0, 4.0)
	])
	spark.scale = Vector2.ONE * 0.72
	effects_layer.add_child(spark)

	var slash_tween := slash.create_tween()
	slash_tween.tween_property(slash, "scale", Vector2.ONE * 1.18, 0.14)
	slash_tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.14)
	slash_tween.finished.connect(slash.queue_free)

	var spark_tween := spark.create_tween()
	spark_tween.tween_property(spark, "scale", Vector2.ONE * (1.4 if heavy else 1.2), 0.12)
	spark_tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.12)
	spark_tween.finished.connect(spark.queue_free)

func _show_intent_text(label_text: String, color_value: Color, scale_value: float = 0.8) -> void:
	if effects_layer == null:
		return
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = Vector2(-38.0, -56.0)
	if popup.has_method("setup_text"):
		popup.setup_text(label_text, color_value, scale_value)
	effects_layer.add_child(popup)

func _hit_target_radius(radius: float, damage: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > radius:
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.0
	})

func _hit_target_line(damage: float, length: float, width: float) -> void:
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

func _update_laser_telegraph(length: float = ARCANIST_LASER_LENGTH) -> void:
	if telegraph_line == null:
		return
	var visible_length := _laser_blocked_length(length)
	telegraph_line.global_position = global_position
	telegraph_line.rotation = line_direction.angle()
	telegraph_line.points = PackedVector2Array([Vector2.ZERO, Vector2(visible_length, 0.0)])

func _laser_blocked_length(length: float) -> float:
	var world := get_world_2d()
	if world == null:
		return length
	var start_position := global_position
	var end_position := global_position + line_direction * length
	var query := PhysicsRayQueryParameters2D.create(start_position, end_position, 1)
	query.exclude = _laser_raycast_excludes()
	var result := world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return length
	var collider := result.get("collider", null) as Node
	if collider != null and collider.is_in_group("projectile_blocker"):
		return maxf(0.0, start_position.distance_to(result.get("position", end_position)))
	return length

func _laser_raycast_excludes() -> Array[RID]:
	var excludes: Array[RID] = []
	if self is CollisionObject2D:
		excludes.append((self as CollisionObject2D).get_rid())
	if target is CollisionObject2D:
		excludes.append((target as CollisionObject2D).get_rid())
	for node in get_tree().get_nodes_in_group("damageable"):
		if node is CollisionObject2D:
			excludes.append((node as CollisionObject2D).get_rid())
	return excludes

func _distance_to_segment(point: Vector2, start_position: Vector2, end_position: Vector2) -> float:
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(start_position)
	var weight := clampf((point - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := start_position + segment * weight
	return point.distance_to(closest_point)

func _fire_projectile(damage: float, color: Color, new_speed: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var scene_root := get_tree().current_scene if get_tree() != null else null
	if scene_root == null or projectile_spawner == null or not is_instance_valid(projectile_spawner):
		return
	var payload := {}
	match enemy_type:
		EnemyType.ARCHER:
			Sfx.play_event(&"enemy_archer_shot", global_position)
			if elite:
				payload["slow_duration"] = 0.8
				payload["slow_multiplier"] = 0.82
		EnemyType.APPRENTICE_MAGE:
			Sfx.play_event(&"enemy_apprentice_cast", global_position)
			payload["slow_duration"] = 1.0
			payload["slow_multiplier"] = 0.76
		EnemyType.ARCANIST:
			Sfx.play_event(&"enemy_arcanist_cast", global_position)
			payload["silence_duration"] = 0.85 if not elite else 1.1
			if elite:
				payload["slow_duration"] = 0.7
				payload["slow_multiplier"] = 0.84
	var projectile := ENEMY_BOLT_SCENE.instantiate()
	projectile.global_position = projectile_spawner.global_position
	scene_root.add_child(projectile)
	projectile.setup(self, (target.global_position - projectile_spawner.global_position).normalized(), damage, color, new_speed, payload)

func _update_visuals() -> void:
	if death_sequence_started:
		return
	var color := Color(0.82, 0.4, 0.24, 1.0)
	match enemy_type:
		EnemyType.SWORDSMAN:
			color = Color(0.78, 0.42, 0.28, 1.0)
		EnemyType.SHIELD:
			color = Color(0.52, 0.64, 0.78, 1.0)
		EnemyType.ARCHER:
			color = Color(0.38, 0.68, 0.44, 1.0)
		EnemyType.HUNTER:
			color = Color(0.58, 0.28, 0.28, 1.0)
		EnemyType.APPRENTICE_MAGE:
			color = Color(0.52, 0.58, 0.92, 1.0)
		EnemyType.ARCANIST:
			color = Color(0.62, 0.42, 0.82, 1.0)
	if elite:
		color = color.lerp(Color(1.0, 0.82, 0.46, 1.0), 0.35)
	if silenced_time_remaining > 0.0:
		color = Color(0.72, 0.64, 0.92, 1.0)
	_set_body_tint(color)
	telegraph_ring.visible = state == &"draw_bow" or state == &"cast_bolt" or state == &"basic_cast"
	telegraph_ring.default_color = color.lightened(0.25)
	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.008)
	telegraph_ring.scale = Vector2.ONE * (0.92 + 0.08 * pulse)
	telegraph_ring.width = 2.2 + 0.6 * pulse
	telegraph_ring.modulate = Color(1.0, 1.0, 1.0, 0.74 + 0.18 * pulse)
	if telegraph_line.visible:
		telegraph_line.width = 3.2 + 0.8 * pulse
		telegraph_line.modulate = Color(1.0, 1.0, 1.0, 0.72 + 0.18 * pulse)
	var motion_ratio := clampf(velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0)
	var bob_strength := 1.2 + motion_ratio * 3.2
	if state != &"idle" and state != &"recover":
		bob_strength += 0.9
	var bob := sin(visual_bob_time) * bob_strength
	var sway := sin(visual_bob_time * 0.56 + motion_ratio) * (0.015 + motion_ratio * 0.05)
	if body is Node2D:
		var body_node := body as Node2D
		body_node.position = base_body_position + Vector2(0.0, bob)
		body_node.rotation = sway
		body_node.scale.x = -absf(body_node.scale.x) if line_direction.x < -0.05 else absf(body_node.scale.x)
	if weapon != null:
		weapon.visible = hp > 0.0
		if target != null and is_instance_valid(target):
			weapon.position = base_weapon_position + Vector2(0.0, bob * 0.35)
			weapon.rotation = _weapon_visual_rotation(line_direction) + sway * 0.45
			if projectile_spawner != null:
				projectile_spawner.position = Vector2(
					26.0 if target.global_position.x >= global_position.x else -26.0,
					base_projectile_spawner_position.y + bob * 0.16
				)

func _weapon_visual_rotation(direction: Vector2) -> float:
	var facing := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var side_sign := -1.0 if facing.x < -0.05 else 1.0
	var guard_degrees := -24.0
	match enemy_type:
		EnemyType.SWORDSMAN:
			if state == &"attack_slash":
				var slash_progress := clampf(state_time / 0.55, 0.0, 1.0)
				guard_degrees = lerpf(-42.0, 14.0, slash_progress)
			else:
				guard_degrees = -46.0
		EnemyType.SHIELD:
			if state == &"shield_bash":
				var bash_progress := clampf(state_time / 0.5, 0.0, 1.0)
				guard_degrees = lerpf(-38.0, 10.0, bash_progress)
			else:
				guard_degrees = -42.0
		EnemyType.HUNTER:
			if state == &"attack_cut":
				var cut_progress := clampf(state_time / 0.22, 0.0, 1.0)
				guard_degrees = lerpf(-30.0, 12.0, cut_progress)
			else:
				guard_degrees = -34.0
		_:
			guard_degrees = -22.0
	return facing.angle() + deg_to_rad(guard_degrees * side_sign)

func _setup_weapon_visual() -> void:
	if weapon == null:
		return
	weapon.visible = true
	weapon.z_index = 3
	if weapon is Polygon2D:
		(weapon as Polygon2D).color = Color(1.0, 1.0, 1.0, 0.0)
	if weapon_sprite == null:
		weapon_sprite = Sprite2D.new()
		weapon_sprite.name = "WeaponSprite"
		weapon.add_child(weapon_sprite)
	var type_index := clampi(int(enemy_type), 0, ENEMY_WEAPON_TEXTURE_PATHS.size() - 1)
	var variant_index := 1 if elite else 0
	weapon_sprite.texture = load(String(ENEMY_WEAPON_TEXTURE_PATHS[type_index][variant_index])) as Texture2D
	weapon_sprite.position = ENEMY_WEAPON_OFFSETS[type_index]
	weapon_sprite.scale = ENEMY_WEAPON_SCALES[type_index]
	weapon_sprite.centered = true
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.z_index = 1
	if body is Sprite2D:
		(body as Sprite2D).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -34.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _on_damaged(_amount: float, remaining_hp: float, _source: Node) -> void:
	hp = remaining_hp
	Sfx.play_event(&"enemy_generic_hit", global_position, -4.0)
	_set_body_tint(Color(1.0, 0.58, 0.58, 1.0))
	var timer := get_tree().create_timer(0.12)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and hp > 0.0:
			_update_visuals()
	)

func _set_body_tint(color: Color) -> void:
	if body == null:
		return
	if body is Polygon2D:
		(body as Polygon2D).color = color
	else:
		body.modulate = color

func _on_died() -> void:
	if death_sequence_started:
		return
	hp = 0.0
	death_sequence_started = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	telegraph_ring.visible = false
	telegraph_line.visible = false
	if has_node("CollisionShape2D"):
		var collision_shape := $CollisionShape2D as CollisionShape2D
		if collision_shape != null:
			collision_shape.set_deferred("disabled", true)
	if weapon != null:
		weapon.visible = true
	Sfx.play_event(&"enemy_generic_dead", global_position)
	_spawn_death_burst()
	var fall_sign := -1.0 if line_direction.x < 0.0 else 1.0
	if body is Node2D:
		var body_node := body as Node2D
		var start_position := body_node.position
		var start_scale := body_node.scale
		var body_tween := create_tween()
		body_tween.tween_property(body_node, "rotation", 0.34 * fall_sign, 0.18)
		body_tween.parallel().tween_property(body_node, "position", start_position + Vector2(-10.0 * fall_sign, 12.0), 0.18)
		body_tween.parallel().tween_property(body_node, "scale", start_scale * Vector2(1.06, 0.82), 0.18)
		body_tween.tween_property(body_node, "modulate:a", 0.0, 0.24)
	if weapon != null:
		var weapon_tween := create_tween()
		weapon_tween.tween_property(weapon, "rotation", weapon.rotation + 0.9 * fall_sign, 0.16)
		weapon_tween.parallel().tween_property(weapon, "position", weapon.position + Vector2(-8.0 * fall_sign, 10.0), 0.16)
		weapon_tween.parallel().tween_property(weapon, "modulate:a", 0.0, 0.22)
	var timer := get_tree().create_timer(0.42)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)

func _spawn_death_burst() -> void:
	if effects_layer == null:
		return
	for index in range(4):
		var shard := Polygon2D.new()
		shard.color = Color(1.0, 0.84, 0.64, 0.92)
		shard.polygon = PackedVector2Array([
			Vector2(-4.0, -4.0),
			Vector2(4.0, -4.0),
			Vector2(4.0, 4.0),
			Vector2(-4.0, 4.0)
		])
		shard.position = Vector2.ZERO
		effects_layer.add_child(shard)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 4.0 + 0.3)
		var tween := shard.create_tween()
		tween.tween_property(shard, "position", direction * 18.0, 0.18)
		tween.parallel().tween_property(shard, "rotation", direction.angle(), 0.18)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.18)
		tween.finished.connect(shard.queue_free)
