extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const PIERCING_ARROW_SCENE := preload("res://effects/projectiles/piercing_arrow.tscn")
const MELEE_UTILS := preload("res://combat/melee_utils.gd")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const RANGER_BODY_TEXTURE_PATH := "res://actors/bosses/textures/ranger_boss.png"
const RANGER_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_ranger_blade.png"

@export var max_hp: float = 3600.0
@export var defense_value: float = 190.0
@export var move_speed: float = 210.0
@export var attack_damage: float = 42.0
@export var attack_range: float = 92.0
@export var attack_arc_degrees: float = 112.0
@export var attack_interval: float = 0.82
@export var skill1_damage: float = 68.0
@export var skill1_cooldown: float = 5.8
@export var skill1_cast_duration: float = 0.26
@export var shadow_step_duration: float = 1.18
@export var shadow_step_speed: float = 370.0
@export var shadow_step_slash_damage: float = 58.0
@export var shadow_step_heal: float = 120.0
@export var shadow_step_attack_speed_gain: float = 0.28
@export var shadow_step_speed_gain: float = 0.22
@export var shadow_step_buff_duration: float = 5.0
@export var skill2_cooldown: float = 8.4
@export var assassination_range: float = 340.0
@export var assassination_dash_speed: float = 980.0
@export var assassination_stop_distance: float = 48.0
@export var assassination_damage: float = 96.0
@export var assassination_strike_duration: float = 0.26
@export var bleed_damage_per_second: float = 18.0
@export var bleed_duration: float = 4.0
@export var execute_health_threshold: float = 0.12
@export var skill3_cooldown: float = 9.6

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
var skill1_cooldown_remaining: float = 1.8
var skill2_cooldown_remaining: float = 4.0
var skill3_cooldown_remaining: float = 6.0
var action_committed: bool = false
var invulnerable: bool = false
var line_direction: Vector2 = Vector2.RIGHT
var shadow_orbit_direction: float = 1.0
var shadow_afterimage_timer: float = 0.0
var shadow_step_buff_time_remaining: float = 0.0
var current_attack_speed_bonus: float = 0.0
var current_speed_bonus: float = 0.0
var active_skill_target: Node2D = null
var damage_applied: bool = false
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0
var body_sprite: Sprite2D = null
var weapon_sprite: Sprite2D = null
var weapon_angle_offset: float = 0.0
var visual_last_position: Vector2 = Vector2.ZERO
var visual_bob_time: float = 0.0

func _ready() -> void:
	add_to_group("damageable")
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.healed.connect(_on_healed)
	health_component.died.connect(_on_died)
	hp = max_hp
	visual_last_position = global_position
	_setup_body_visual()
	_setup_weapon_visual()
	aim_ring.visible = false
	assassination_mark.visible = false
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func get_status_title() -> String:
	return "Shadow Huntress"

func get_status_text() -> String:
	var buff_text := " | Buffed" if shadow_step_buff_time_remaining > 0.0 else ""
	return "HP %d / %d\nATK %.2fs%s\nState: %s" % [
		int(round(hp)),
		int(round(max_hp)),
		_get_attack_interval(),
		buff_text,
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
	if shadow_step_buff_time_remaining > 0.0:
		shadow_step_buff_time_remaining = maxf(shadow_step_buff_time_remaining - delta, 0.0)
		if shadow_step_buff_time_remaining <= 0.0:
			current_attack_speed_bonus = 0.0
			current_speed_bonus = 0.0
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

func _update_state(delta: float) -> void:
	match state:
		&"idle":
			_process_idle(delta)
		&"basic_attack":
			_process_basic_attack()
		&"skill1_cast":
			_process_skill1_cast()
		&"skill2_shadow":
			_process_skill2_shadow(delta)
		&"skill3_dash":
			_process_skill3_dash(delta)
		&"skill3_strike":
			_process_skill3_strike()
		&"recover":
			_process_recover()

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if to_target != Vector2.ZERO:
		line_direction = to_target.normalized()
	if _can_use_skills() and skill3_cooldown_remaining <= 0.0 and distance <= assassination_range:
		_start_skill3()
		return
	if _can_use_skills() and skill2_cooldown_remaining <= 0.0 and distance <= 220.0:
		_start_skill2()
		return
	if _can_use_skills() and skill1_cooldown_remaining <= 0.0 and distance >= 110.0:
		_start_skill1()
		return
	if attack_cooldown <= 0.0 and distance <= attack_range:
		_start_basic_attack()
		return
	if root_time_remaining > 0.0:
		return
	var speed := move_speed * (1.0 + current_speed_bonus) * slow_factor
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
	if not action_committed and state_time >= 0.18:
		action_committed = true
		_hit_target_in_arc(attack_range, attack_damage, attack_arc_degrees)
		_spawn_slash_effect(attack_range, Color(0.88, 1.0, 0.76, 0.92))
	if state_time >= 0.42:
		_enter_recover(0.16)

func _start_skill1() -> void:
	state = &"skill1_cast"
	state_time = 0.0
	action_committed = false
	skill1_cooldown_remaining = skill1_cooldown
	aim_ring.visible = true
	aim_ring.scale = Vector2.ONE * 0.42
	aim_ring.modulate = Color(0.72, 1.0, 0.86, 0.88)
	_animate_weapon_swing(-28.0, 10.0, skill1_cast_duration)

func _process_skill1_cast() -> void:
	if not action_committed and state_time >= skill1_cast_duration * 0.65:
		action_committed = true
		_fire_piercing_arrow_combo()
	if state_time >= skill1_cast_duration + 0.18:
		aim_ring.visible = false
		_enter_recover(0.18)

func _fire_piercing_arrow_combo() -> void:
	var facing_direction := line_direction if line_direction != Vector2.ZERO else Vector2.RIGHT
	_spawn_piercing_arrow(facing_direction, skill1_damage)
	if hp <= max_hp * 0.6:
		_spawn_piercing_arrow(facing_direction.rotated(deg_to_rad(-14.0)), skill1_damage * 0.6)
		_spawn_piercing_arrow(facing_direction.rotated(deg_to_rad(14.0)), skill1_damage * 0.6)
	if hp <= max_hp * 0.3:
		var timer := get_tree().create_timer(0.12)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and state != &"dead":
				_spawn_piercing_arrow(facing_direction, skill1_damage * 0.85)
		)

func _start_skill2() -> void:
	state = &"skill2_shadow"
	state_time = 0.0
	action_committed = false
	invulnerable = true
	shadow_afterimage_timer = 0.0
	skill2_cooldown_remaining = skill2_cooldown
	shadow_orbit_direction *= -1.0
	Sfx.play_event(&"ranger_skill2_roll", global_position)

func _process_skill2_shadow(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		invulnerable = false
		_enter_recover(0.12)
		return
	var progress := clampf(state_time / maxf(shadow_step_duration, 0.001), 0.0, 1.0)
	var angle := lerpf(-1.1, 1.1, progress) * shadow_orbit_direction
	var desired_position := target.global_position + Vector2.RIGHT.rotated(angle) * 126.0
	global_position = global_position.move_toward(desired_position, shadow_step_speed * delta)
	line_direction = (target.global_position - global_position).normalized()
	if line_direction == Vector2.ZERO:
		line_direction = Vector2.RIGHT
	shadow_afterimage_timer -= delta
	if shadow_afterimage_timer <= 0.0:
		shadow_afterimage_timer = 0.05
		_spawn_afterimage()
	if not action_committed and state_time >= shadow_step_duration * 0.72:
		action_committed = true
		_hit_target_in_arc(114.0, shadow_step_slash_damage, 142.0)
		_spawn_slash_effect(114.0, Color(0.76, 0.94, 1.0, 0.95))
	if state_time >= shadow_step_duration:
		invulnerable = false
		current_attack_speed_bonus = shadow_step_attack_speed_gain
		current_speed_bonus = shadow_step_speed_gain
		shadow_step_buff_time_remaining = shadow_step_buff_duration
		health_component.heal(shadow_step_heal)
		_enter_recover(0.12)

func _start_skill3() -> void:
	state = &"skill3_dash"
	state_time = 0.0
	action_committed = false
	damage_applied = false
	active_skill_target = target
	skill3_cooldown_remaining = skill3_cooldown
	assassination_mark.visible = true
	assassination_mark.scale = Vector2.ONE * 0.76
	_animate_weapon_swing(-34.0, 12.0, 0.18)
	Sfx.play_event(&"ranger_skill3_assassinate", global_position)

func _process_skill3_dash(delta: float) -> void:
	if active_skill_target == null or not is_instance_valid(active_skill_target):
		assassination_mark.visible = false
		_enter_recover(0.12)
		return
	var to_target := active_skill_target.global_position - global_position
	var distance := to_target.length()
	if distance <= assassination_stop_distance or state_time >= 0.42:
		state = &"skill3_strike"
		state_time = 0.0
		damage_applied = false
		return
	line_direction = to_target.normalized()
	if line_direction == Vector2.ZERO:
		line_direction = Vector2.RIGHT
	global_position += line_direction * assassination_dash_speed * delta
	_spawn_afterimage()

func _process_skill3_strike() -> void:
	if not damage_applied and state_time >= assassination_strike_duration * 0.42:
		damage_applied = true
		_apply_assassination_damage()
		_spawn_slash_effect(124.0, Color(1.0, 0.74, 0.68, 0.96))
	if state_time >= assassination_strike_duration:
		active_skill_target = null
		assassination_mark.visible = false
		_enter_recover(0.18)

func _apply_assassination_damage() -> void:
	if active_skill_target == null or not is_instance_valid(active_skill_target):
		return
	var damage := assassination_damage
	if _can_execute_target(active_skill_target):
		damage = 999999.0
	active_skill_target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.18
	})
	if damage < 999999.0:
		_apply_bleed(active_skill_target)

func _apply_bleed(target_node: Node) -> void:
	var ticks := int(floor(bleed_duration))
	for tick in range(ticks):
		var timer := get_tree().create_timer(float(tick + 1))
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and is_instance_valid(target_node) and target_node.has_method("receive_hit"):
				target_node.receive_hit({
					"source": self,
					"damage": bleed_damage_per_second,
					"crit_rate": 0.0
				})
		)

func _can_execute_target(target_node: Node) -> bool:
	if target_node == null:
		return false
	var target_hp := float(target_node.get("hp"))
	var target_max_hp := float(target_node.get("max_hp"))
	return target_max_hp > 0.0 and target_hp <= target_max_hp * execute_health_threshold

func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	recover_duration = duration
	aim_ring.visible = false

func _process_recover() -> void:
	if state_time >= recover_duration:
		state = &"idle"
		state_time = 0.0

func _can_use_skills() -> bool:
	return silenced_time_remaining <= 0.0

func _get_attack_interval() -> float:
	return attack_interval / (1.0 + current_attack_speed_bonus)

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

func _spawn_piercing_arrow(direction: Vector2, damage: float) -> void:
	var arrow := PIERCING_ARROW_SCENE.instantiate()
	arrow.global_position = projectile_spawner.global_position
	get_tree().current_scene.add_child(arrow)
	arrow.setup(self, direction, damage, 0.1)

func _spawn_slash_effect(radius: float, color: Color) -> void:
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

func _spawn_afterimage() -> void:
	var ghost := Polygon2D.new()
	ghost.polygon = body.polygon
	ghost.color = Color(0.64, 1.0, 0.86, 0.18)
	ghost.global_position = global_position
	ghost.rotation = body.rotation
	ghost.scale = body.scale
	get_tree().current_scene.add_child(ghost)
	var tween := create_tween()
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
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target != Vector2.ZERO:
			line_direction = to_target.normalized()
	var body_tint := Color.WHITE
	if silenced_time_remaining > 0.0:
		body_tint = Color(0.9, 0.82, 1.0, 1.0)
	elif shadow_step_buff_time_remaining > 0.0:
		body_tint = Color(1.0, 0.94, 0.84, 1.0)
	_set_body_tint(body_tint)
	body.modulate = Color(1.0, 1.0, 1.0, 0.36) if invulnerable else Color.WHITE
	aim_ring.visible = state == &"skill1_cast"
	if aim_ring.visible:
		aim_ring.rotation = line_direction.angle()
		aim_ring.scale = Vector2.ONE * (0.82 + 0.18 * minf(state_time / maxf(skill1_cast_duration, 0.01), 1.0))
		aim_ring.modulate = Color(0.72, 1.0, 0.86, 0.78)
	assassination_mark.visible = active_skill_target != null and is_instance_valid(active_skill_target) and state != &"dead"
	if assassination_mark.visible:
		assassination_mark.global_position = active_skill_target.global_position
		assassination_mark.rotation += 0.16
	assassination_mark.modulate = Color(1.0, 0.48, 0.42, 0.9)
	weapon.position = line_direction * 18.0 + Vector2(0.0, -2.0)
	weapon.rotation = _weapon_guard_rotation(line_direction, -38.0) + weapon_angle_offset
	projectile_spawner.position = line_direction * 28.0
	_apply_agile_body_motion()
	visual_last_position = global_position

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
	aim_ring.visible = false
	assassination_mark.visible = false
	weapon.visible = false
	Sfx.play_event(&"boss_generic_dead", global_position)
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)
