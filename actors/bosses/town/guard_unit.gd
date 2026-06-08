extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")

@export var max_hp: float = 800.0
@export var defense_value: float = 120.0
@export var move_speed: float = 92.0
@export var attack_damage: float = 20.0
@export var attack_interval: float = 2.0
@export var attack_range: float = 82.0
@export var skill1_damage: float = 10.0
@export var skill1_cooldown: float = 6.0
@export var skill2_damage: float = 20.0
@export var skill2_cooldown: float = 8.0

@onready var body: Polygon2D = $Body
@onready var sword: Polygon2D = $Sword
@onready var aura_ring: Line2D = $AuraRing
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

var target: Node2D = null
var hp: float = 0.0
var mobile_guard: bool = false
var immune: bool = true
var lane_origin: Vector2 = Vector2.ZERO
var lane_axis: Vector2 = Vector2.UP
var lane_extent: float = 48.0
var lane_offset: float = 0.0
var lane_direction: float = 1.0
var state: StringName = &"idle"
var state_time: float = 0.0
var attack_cooldown: float = 0.0
var skill1_cooldown_remaining: float = 0.0
var skill2_cooldown_remaining: float = 0.0
var recover_duration: float = 0.0
var leap_start_position: Vector2 = Vector2.ZERO
var leap_target_position: Vector2 = Vector2.ZERO
var action_committed: bool = false
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0

func _ready() -> void:
	add_to_group("damageable")
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	hp = max_hp
	lane_origin = global_position
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func setup_lane(is_mobile_guard: bool, origin: Vector2, axis: Vector2) -> void:
	mobile_guard = is_mobile_guard
	lane_origin = origin
	lane_axis = axis.normalized() if axis != Vector2.ZERO else Vector2.UP
	global_position = lane_origin

func set_lane_extent(value: float) -> void:
	lane_extent = value

func set_immune(active: bool) -> void:
	immune = active
	aura_ring.visible = active

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	skill1_cooldown_remaining = maxf(skill1_cooldown_remaining - delta, 0.0)
	skill2_cooldown_remaining = maxf(skill2_cooldown_remaining - delta, 0.0)
	_update_status_timers(delta)
	state_time += delta
	if target == null or not is_instance_valid(target):
		_find_target()
	_update_state(delta)
	_update_visuals()

func receive_hit(payload: Dictionary) -> void:
	if immune or hp <= 0.0:
		aura_ring.visible = true
		aura_ring.default_color = Color(0.72, 0.9, 1.0, 0.95)
		var timer := get_tree().create_timer(0.1)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self):
				_update_visuals()
		)
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
	var players := get_tree().get_nodes_in_group("player")
	target = players[0] if not players.is_empty() else null

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
		&"skill_1_jump":
			_process_jump_attack()
		&"skill_2_sweep":
			_process_sweep_attack()
		&"recover":
			_process_recover()
		&"dead":
			return

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > 0.0:
		sword.rotation = _sword_visual_rotation(to_target)
	if _can_use_skills() and skill2_cooldown_remaining <= 0.0 and distance <= 190.0:
		_start_sweep()
		return
	if _can_use_skills() and skill1_cooldown_remaining <= 0.0 and distance <= 160.0:
		_start_jump()
		return
	if attack_cooldown <= 0.0 and distance <= attack_range:
		_start_basic_attack()
		return
	if mobile_guard and root_time_remaining <= 0.0:
		lane_offset += lane_direction * move_speed * slow_factor * delta
		if absf(lane_offset) >= lane_extent:
			lane_offset = clampf(lane_offset, -lane_extent, lane_extent)
			lane_direction *= -1.0
		global_position = lane_origin + lane_axis * lane_offset

func _start_basic_attack() -> void:
	state = &"basic_attack"
	state_time = 0.0
	action_committed = false
	attack_cooldown = attack_interval
	if Sfx != null:
		Sfx.play_event(&"enemy_swordsman_attack", global_position, -2.0)

func _process_basic_attack() -> void:
	if not action_committed and state_time >= 0.35:
		action_committed = true
		_hit_target(attack_range, attack_damage)
	if state_time >= 0.72:
		_enter_recover(0.28)

func _start_jump() -> void:
	state = &"skill_1_jump"
	state_time = 0.0
	action_committed = false
	skill1_cooldown_remaining = skill1_cooldown
	leap_start_position = global_position
	leap_target_position = target.global_position if target != null else global_position
	if Sfx != null:
		Sfx.play_event(&"enemy_hunter_dash", global_position, -1.0)

func _process_jump_attack() -> void:
	var progress := clampf(state_time / 0.38, 0.0, 1.0)
	global_position = leap_start_position.lerp(leap_target_position, progress) + Vector2(0.0, -sin(progress * PI) * 72.0)
	if not action_committed and progress >= 1.0:
		action_committed = true
		global_position = leap_target_position
		_hit_target(86.0, skill1_damage)
	if state_time >= 0.48:
		_enter_recover(2.0)

func _start_sweep() -> void:
	state = &"skill_2_sweep"
	state_time = 0.0
	action_committed = false
	skill2_cooldown_remaining = skill2_cooldown
	if Sfx != null:
		Sfx.play_event(&"enemy_shield_bash", global_position, -1.5)

func _process_sweep_attack() -> void:
	if not action_committed and state_time >= 2.0:
		action_committed = true
		_hit_target(106.0, skill2_damage)
	if state_time >= 2.18:
		_enter_recover(2.0)

func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	recover_duration = duration

func _process_recover() -> void:
	if state_time >= recover_duration:
		state = &"idle"
		state_time = 0.0

func _hit_target(radius: float, damage: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > radius:
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.0
	})

func _can_use_skills() -> bool:
	return silenced_time_remaining <= 0.0

func _update_visuals() -> void:
	var base_color := Color(0.56, 0.66, 0.78, 1.0) if mobile_guard else Color(0.48, 0.58, 0.7, 1.0)
	if state == &"skill_2_sweep":
		base_color = Color(0.88, 0.72, 0.48, 1.0)
	elif silenced_time_remaining > 0.0:
		base_color = Color(0.72, 0.64, 0.92, 1.0)
	body.color = base_color
	aura_ring.visible = immune
	aura_ring.default_color = Color(0.8, 0.92, 1.0, 0.75) if immune else Color(1.0, 0.84, 0.5, 0.0)
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 0.0001:
			sword.rotation = _sword_visual_rotation(to_target)

func _sword_visual_rotation(direction: Vector2) -> float:
	var facing := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var side_sign := -1.0 if facing.x < -0.05 else 1.0
	var guard_degrees := -44.0
	if state == &"basic_attack":
		var attack_progress := clampf(state_time / 0.42, 0.0, 1.0)
		guard_degrees = lerpf(-52.0, 18.0, attack_progress)
	elif state == &"skill_2_sweep":
		var sweep_progress := clampf(state_time / 2.0, 0.0, 1.0)
		guard_degrees = lerpf(-60.0, 24.0, sweep_progress)
	return facing.angle() + deg_to_rad(guard_degrees * side_sign)

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -34.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _on_damaged(_amount: float, remaining_hp: float, _source: Node) -> void:
	hp = remaining_hp
	if Sfx != null:
		Sfx.play_event(&"enemy_generic_hit", global_position, -5.0)
	body.color = Color(1.0, 0.58, 0.58, 1.0)
	var timer := get_tree().create_timer(0.1)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and hp > 0.0:
			_update_visuals()
	)

func _on_died() -> void:
	hp = 0.0
	state = &"dead"
	if Sfx != null:
		Sfx.play_event(&"enemy_generic_dead", global_position, -3.0)
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)
