extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ROYAL_BOLT_SCENE := preload("res://effects/projectiles/royal_bolt.tscn")
const MELEE_UTILS := preload("res://combat/melee_utils.gd")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const EMPEROR_BODY_TEXTURE_PATH := "res://actors/bosses/textures/emperor_boss.png"
const EMPEROR_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_emperor_sword.png"

@export var max_hp: float = 5000.0
@export var defense_value: float = 260.0
@export var move_speed: float = 165.0
@export var attack_damage: float = 42.0
@export var attack_range: float = 96.0
@export var attack_arc_degrees: float = 120.0
@export var attack_interval: float = 1.05
@export var phase_two_threshold: float = 2000.0
@export var phase_transition_duration: float = 0.9
@export var skill_interval_phase_one: float = 5.0
@export var skill_interval_phase_two: float = 3.0
@export var shadow_step_duration: float = 0.55
@export var shadow_step_slash_damage: float = 70.0
@export var charge_skill_damage: float = 88.0
@export var charge_distance: float = 280.0
@export var arcane_burst_damage: float = 66.0
@export var arcane_burst_radius: float = 130.0
@export var volley_damage: float = 24.0

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
var skill_cooldown: float = skill_interval_phase_one
var current_skill: StringName = &""
var line_direction: Vector2 = Vector2.RIGHT
var action_committed: bool = false
var phase_two: bool = false
var invulnerable: bool = false
var charge_start_position: Vector2 = Vector2.ZERO
var charge_direction: Vector2 = Vector2.RIGHT
var burst_center: Vector2 = Vector2.ZERO
var shadow_reposition_point: Vector2 = Vector2.ZERO
var body_sprite: Sprite2D = null
var weapon_sprite: Sprite2D = null
var weapon_angle_offset: float = deg_to_rad(64.0)

func _ready() -> void:
	add_to_group("damageable")
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	hp = max_hp
	_setup_body_visual()
	_setup_weapon_visual()
	burst_ring.visible = false
	phase_ring.visible = false
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func get_status_title() -> String:
	return "Emperor"

func get_status_text() -> String:
	return "HP %d / %d\nSkill cadence %.1fs\nState: %s" % [
		int(round(hp)),
		int(round(max_hp)),
		skill_interval_phase_two if phase_two else skill_interval_phase_one,
		String(state)
	]

func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
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
		&"basic_attack":
			_process_basic_attack()
		&"skill_shadow":
			_process_skill_shadow()
		&"skill_charge":
			_process_skill_charge(delta)
		&"skill_burst":
			_process_skill_burst()
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
	if distance > attack_range * 0.86:
		global_position += line_direction * move_speed * delta

func _start_basic_attack() -> void:
	state = &"basic_attack"
	state_time = 0.0
	action_committed = false
	attack_cooldown = attack_interval
	_animate_weapon_swing(-112.0, 38.0, 0.26)

func _process_basic_attack() -> void:
	if not action_committed and state_time >= 0.24:
		action_committed = true
		_hit_target_in_arc(attack_range, attack_damage, attack_arc_degrees)
		_spawn_slash_effect(attack_range, Color(1.0, 0.84, 0.58, 0.92))
	if state_time >= 0.58:
		_return_to_idle()

func _start_skill_cast() -> void:
	current_skill = _pick_skill()
	action_committed = false
	state_time = 0.0
	skill_cooldown = skill_interval_phase_two if phase_two else skill_interval_phase_one
	match current_skill:
		&"shadow":
			state = &"skill_shadow"
			shadow_reposition_point = global_position
			if target != null and is_instance_valid(target):
				var side := Vector2(64.0, 0.0)
				side.x *= -1.0 if int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0
				shadow_reposition_point = target.global_position + side
		&"charge":
			state = &"skill_charge"
			charge_start_position = global_position
			charge_direction = (target.global_position - global_position).normalized() if target != null else line_direction
			if charge_direction == Vector2.ZERO:
				charge_direction = Vector2.RIGHT
			_animate_weapon_swing(-124.0, -18.0, 0.32)
		&"burst":
			state = &"skill_burst"
			burst_center = target.global_position if target != null else global_position
			burst_ring.visible = true
			burst_ring.global_position = burst_center
			burst_ring.scale = Vector2.ONE * 0.4
			burst_ring.modulate = Color(0.82, 0.9, 1.0, 0.92)
		&"volley":
			state = &"skill_volley"
			_animate_weapon_swing(-44.0, 18.0, 0.24)

func _pick_skill() -> StringName:
	var pool: Array[StringName] = [&"shadow", &"charge", &"burst", &"volley"]
	return pool[randi() % pool.size()]

func _process_skill_shadow() -> void:
	invulnerable = true
	body.modulate = Color(0.72, 0.8, 1.0, 0.34)
	if state_time >= shadow_step_duration * 0.6 and not action_committed:
		action_committed = true
		global_position = shadow_reposition_point
		if target != null and is_instance_valid(target):
			line_direction = (target.global_position - global_position).normalized()
			if line_direction == Vector2.ZERO:
				line_direction = Vector2.RIGHT
		_animate_weapon_swing(-138.0, 46.0, 0.18)
		_hit_target_in_arc(112.0, shadow_step_slash_damage, 145.0)
		_spawn_slash_effect(112.0, Color(0.8, 0.9, 1.0, 0.95))
	if state_time >= shadow_step_duration:
		invulnerable = false
		_return_to_idle()

func _process_skill_charge(delta: float) -> void:
	if state_time < 0.26:
		return
	global_position += charge_direction * (charge_distance / 0.26) * delta
	if not action_committed:
		action_committed = true
		_hit_target_in_arc(130.0, charge_skill_damage, 95.0)
		_spawn_slash_effect(130.0, Color(1.0, 0.78, 0.56, 0.95))
	if state_time >= 0.56:
		_return_to_idle()

func _process_skill_burst() -> void:
	if burst_ring.visible:
		burst_ring.scale = Vector2.ONE * (0.4 + minf(state_time * 1.5, 0.75))
	if not action_committed and state_time >= 0.42:
		action_committed = true
		_apply_burst_damage()
	if state_time >= 0.58:
		burst_ring.visible = false
		_return_to_idle()

func _apply_burst_damage() -> void:
	_spawn_burst_effect()
	if target == null or not is_instance_valid(target):
		return
	if burst_center.distance_to(target.global_position) > arcane_burst_radius:
		return
	target.receive_hit({
		"source": self,
		"damage": arcane_burst_damage,
		"crit_rate": 0.0
	})

func _process_skill_volley() -> void:
	if not action_committed and state_time >= 0.24:
		action_committed = true
		_fire_volley()
	if state_time >= 0.52:
		_return_to_idle()

func _fire_volley() -> void:
	if target == null or not is_instance_valid(target):
		return
	var base_direction := (target.global_position - projectile_spawner.global_position).normalized()
	for angle_offset in [-10.0, 0.0, 10.0]:
		var bolt := ROYAL_BOLT_SCENE.instantiate()
		bolt.global_position = projectile_spawner.global_position
		get_tree().current_scene.add_child(bolt)
		bolt.setup(self, base_direction.rotated(deg_to_rad(angle_offset)), volley_damage)

func _start_phase_transition() -> void:
	phase_two = true
	invulnerable = true
	state = &"phase_transition"
	state_time = 0.0
	action_committed = false
	phase_ring.visible = true
	phase_ring.scale = Vector2.ONE * 0.6

func _process_phase_transition() -> void:
	phase_ring.rotation += 0.16
	phase_ring.scale = Vector2.ONE * (0.6 + minf(state_time * 0.55, 0.5))
	if state_time >= phase_transition_duration:
		invulnerable = false
		phase_ring.visible = false
		skill_cooldown = 0.4
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

func _spawn_slash_effect(radius: float, color: Color) -> void:
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

func _spawn_burst_effect() -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.closed = true
	ring.default_color = Color(0.82, 0.92, 1.0, 0.9)
	ring.points = _build_ring_points(arcane_burst_radius, 20)
	ring.global_position = burst_center
	get_tree().current_scene.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.18, 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.finished.connect(ring.queue_free)

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
	body_sprite.scale = Vector2.ONE * 0.40
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
	weapon_sprite.scale = Vector2.ONE * 0.42
	weapon_sprite.position = Vector2(-40.0, 8.0)
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
	if invulnerable:
		body.modulate = Color(1.0, 1.0, 1.0, 0.8)
	else:
		body.modulate = Color.WHITE
	phase_ring.default_color = Color(1.0, 0.84, 0.52, 0.88)
	weapon.position = line_direction * 22.0 + Vector2(0.0, 0.0)
	weapon.rotation = line_direction.angle() + weapon_angle_offset
	projectile_spawner.position = line_direction * 24.0

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
