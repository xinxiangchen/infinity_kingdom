extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ROYAL_BOLT_SCENE := preload("res://effects/projectiles/royal_bolt.tscn")

@export var phase1_hp: float = 4000.0
@export var phase2_hp: float = 4000.0
@export var defense_value: float = 220.0
@export var move_speed: float = 170.0
@export var teleport_slash_damage: float = 30.0
@export var spear_charge_damage: float = 50.0
@export var barrage_damage: float = 18.0
@export_range(0.1, 0.9, 0.05) var desperation_threshold_ratio: float = 0.35

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
var max_hp: float = 0.0
var current_phase: int = 1
var state: StringName = &"intro"
var state_time: float = 0.0
var action_committed: bool = false
var invulnerable: bool = false
var teleport_cooldown: float = 0.8
var spear_cooldown: float = 3.0
var barrage_cooldown: float = 6.0
var teleport_target_position: Vector2 = Vector2.ZERO
var charge_direction: Vector2 = Vector2.RIGHT
var charge_start_position: Vector2 = Vector2.ZERO
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0
var desperation_active: bool = false

func _ready() -> void:
	add_to_group("damageable")
	max_hp = phase1_hp
	hp = max_hp
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	teleport_marker.visible = false
	charge_line.visible = false
	phase_ring.visible = false
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func get_status_title() -> String:
	return "Grand Prince" if current_phase == 1 else "Saint Prince Yage"

func get_status_text() -> String:
	return "Phase %d%s\nHP %d / %d\nState: %s" % [
		current_phase,
		"  DESPERATE" if desperation_active else "",
		int(round(hp)),
		int(round(max_hp)),
		String(state)
	]

func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	if target == null or not is_instance_valid(target):
		_find_target()
	_update_status_timers(delta)
	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	spear_cooldown = maxf(spear_cooldown - delta, 0.0)
	barrage_cooldown = maxf(barrage_cooldown - delta, 0.0)
	state_time += delta
	_update_desperation_state()
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
		&"intro":
			_process_intro()
		&"idle":
			_process_idle(delta)
		&"teleport_mark":
			_process_teleport_mark()
		&"teleport_slash":
			_process_teleport_slash()
		&"spear_charge":
			_process_spear_charge(delta)
		&"barrage_cast":
			_process_barrage_cast()
		&"recover":
			_process_recover()
		&"phase_change":
			_process_phase_change()

func _process_intro() -> void:
	if state_time >= 1.0:
		_start_teleport_attack()

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > 0.0:
		spear.rotation = to_target.angle()
	if current_phase == 2 and _can_use_skills() and barrage_cooldown <= 0.0 and distance >= (120.0 if desperation_active else 150.0):
		_start_barrage()
		return
	if _can_use_skills() and teleport_cooldown <= 0.0:
		_start_teleport_attack()
		return
	if _can_use_skills() and spear_cooldown <= 0.0 and distance >= 110.0:
		_start_spear_charge()
		return
	if root_time_remaining <= 0.0 and distance > 80.0:
		var direction := to_target.normalized()
		var orbit := Vector2(-direction.y, direction.x) * (0.35 if current_phase == 1 else -0.35)
		global_position += (direction + orbit).normalized() * move_speed * slow_factor * delta

func _start_teleport_attack() -> void:
	state = &"teleport_mark"
	state_time = 0.0
	action_committed = false
	teleport_cooldown = 5.0 if current_phase == 1 else (2.45 if desperation_active else 3.2)
	if target != null and is_instance_valid(target):
		var side := Vector2(52.0, 0.0)
		side.x *= -1.0 if int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0
		teleport_target_position = target.global_position + side
	else:
		teleport_target_position = global_position
	teleport_marker.visible = true
	teleport_marker.global_position = teleport_target_position
	teleport_marker.rotation = 0.0
	_show_intent_text("Blink Slash", Color(1.0, 0.82, 0.68, 1.0), teleport_target_position, 0.86)
	Sfx.play_event(&"boss_twin_teleport", global_position)

func _process_teleport_mark() -> void:
	teleport_marker.rotation += 0.18
	if state_time >= 0.35:
		state = &"teleport_slash"
		state_time = 0.0
		action_committed = false
		global_position = teleport_target_position
		teleport_marker.visible = false

func _process_teleport_slash() -> void:
	if not action_committed and state_time >= 0.08:
		action_committed = true
		_hit_target_in_radius(84.0, teleport_slash_damage)
	if state_time >= 0.28:
		_enter_recover(0.4 if current_phase == 1 else (0.16 if desperation_active else 0.24))

func _start_spear_charge() -> void:
	state = &"spear_charge"
	state_time = 0.0
	action_committed = false
	spear_cooldown = 4.8 if desperation_active else 6.0
	charge_start_position = global_position
	charge_direction = (target.global_position - global_position).normalized() if target != null else Vector2.RIGHT
	if charge_direction == Vector2.ZERO:
		charge_direction = Vector2.RIGHT
	charge_line.visible = true
	charge_line.global_position = global_position
	charge_line.rotation = charge_direction.angle()
	_show_intent_text("Spear Charge", Color(1.0, 0.76, 0.58, 1.0), global_position, 0.88)
	Sfx.play_event(&"boss_twin_charge", global_position)

func _process_spear_charge(delta: float) -> void:
	if state_time < 1.0:
		charge_line.global_position = global_position
		return
	if state_time < 1.35:
		global_position += charge_direction * 480.0 * slow_factor * delta
		charge_line.global_position = global_position
		if not action_committed:
			action_committed = true
			_hit_target_in_line(spear_charge_damage, 220.0, 38.0)
	else:
		charge_line.visible = false
		_enter_recover(2.0)

func _start_barrage() -> void:
	state = &"barrage_cast"
	state_time = 0.0
	action_committed = false
	barrage_cooldown = 5.8 if desperation_active else 8.0
	_show_intent_text("Royal Barrage", Color(1.0, 0.86, 0.62, 1.0), global_position, 0.9)
	Sfx.play_event(&"boss_twin_barrage", global_position)

func _process_barrage_cast() -> void:
	if not action_committed and state_time >= 0.35:
		action_committed = true
		_fire_barrage()
	if state_time >= 0.82:
		_enter_recover(0.42 if desperation_active else 0.7)

func _process_recover() -> void:
	if state_time >= 0.7:
		state = &"idle"
		state_time = 0.0

func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	if duration > 0.0:
		barrage_cooldown = maxf(barrage_cooldown, duration)
	charge_line.visible = false
	teleport_marker.visible = false

func _process_phase_change() -> void:
	phase_ring.visible = true
	phase_ring.rotation += 0.12
	if state_time >= 1.2:
		invulnerable = false
		phase_ring.visible = false
		state = &"idle"
		state_time = 0.0

func _fire_barrage() -> void:
	if target == null or not is_instance_valid(target):
		return
	var base_direction := (target.global_position - global_position).normalized()
	var first_wave := [-18.0, -9.0, 0.0, 9.0, 18.0]
	if desperation_active:
		first_wave = [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]
	_spawn_barrage_wave(base_direction, first_wave, barrage_damage)
	if desperation_active:
		var timer := get_tree().create_timer(0.18)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and target != null and is_instance_valid(target):
				var second_direction := (target.global_position - global_position).normalized()
				_spawn_barrage_wave(second_direction, [-12.0, 0.0, 12.0], barrage_damage * 0.8)
		)

func _hit_target_in_radius(radius: float, damage: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > radius:
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
	var end_position := global_position + charge_direction * length
	if _distance_to_segment(target.global_position, start_position, end_position) > width:
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.0
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

func _update_desperation_state() -> void:
	if desperation_active or current_phase != 2 or hp > max_hp * desperation_threshold_ratio:
		return
	desperation_active = true
	move_speed *= 1.08
	teleport_cooldown = minf(teleport_cooldown, 1.0)
	spear_cooldown = minf(spear_cooldown, 1.5)
	barrage_cooldown = minf(barrage_cooldown, 1.6)
	phase_ring.visible = true
	phase_ring.rotation = 0.0
	_show_intent_text("Desperate", Color(1.0, 0.66, 0.50, 1.0), global_position, 0.94)
	Sfx.play_event(&"boss_twin_barrage", global_position, 2.0)

func _update_visuals() -> void:
	var base_color := Color(0.84, 0.82, 0.88, 1.0) if current_phase == 1 else Color(0.95, 0.76, 0.58, 1.0)
	if silenced_time_remaining > 0.0:
		base_color = Color(0.72, 0.64, 0.92, 1.0)
	elif desperation_active:
		base_color = Color(1.0, 0.62, 0.46, 1.0)
	body.color = base_color
	phase_ring.default_color = Color(1.0, 0.64, 0.42, 0.9) if desperation_active else (Color(1.0, 0.82, 0.56, 0.85) if current_phase == 2 else Color(0.82, 0.86, 1.0, 0.8))
	if target != null and is_instance_valid(target):
		spear.rotation = (target.global_position - global_position).angle()
	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.01)
	if teleport_marker.visible:
		teleport_marker.scale = Vector2.ONE * (0.92 + 0.08 * pulse)
		teleport_marker.width = 3.0 + 0.8 * pulse
		teleport_marker.modulate = Color(1.0, 1.0, 1.0, 0.76 + 0.14 * pulse)
	if charge_line.visible:
		charge_line.width = 3.6 + 1.0 * pulse
		charge_line.modulate = Color(1.0, 1.0, 1.0, 0.74 + 0.16 * pulse)
	if phase_ring.visible:
		phase_ring.scale = Vector2.ONE * (0.94 + 0.08 * pulse)
		phase_ring.width = 3.4 + 1.0 * pulse
		phase_ring.modulate = Color(1.0, 1.0, 1.0, 0.74 + 0.16 * pulse)

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -44.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _show_intent_text(label_text: String, color_value: Color, world_position: Vector2, scale_value: float = 0.84) -> void:
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = to_local(world_position) + Vector2(-42.0, -56.0)
	if popup.has_method("setup_text"):
		popup.setup_text(label_text, color_value, scale_value)
	effects_layer.add_child(popup)

func _on_damaged(_amount: float, remaining_hp: float, _source: Node) -> void:
	hp = remaining_hp
	body.color = Color(1.0, 0.58, 0.58, 1.0)
	var timer := get_tree().create_timer(0.12)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and state != &"dead":
			_update_visuals()
	)

func _on_died() -> void:
	if current_phase == 1:
		_show_intent_text("Phase Two", Color(1.0, 0.88, 0.62, 1.0), global_position, 0.94)
		current_phase = 2
		desperation_active = false
		max_hp = phase2_hp
		hp = max_hp
		invulnerable = true
		teleport_cooldown = 1.0
		spear_cooldown = 2.4
		barrage_cooldown = 3.2
		state = &"phase_change"
		state_time = 0.0
		health_component.setup(max_hp, defense_value)
		return
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

func _spawn_barrage_wave(base_direction: Vector2, angles: Array, damage: float) -> void:
	var payload := {
		"slow_duration": 0.9 if not desperation_active else 1.15,
		"slow_multiplier": 0.78 if not desperation_active else 0.72
	}
	for angle_offset in angles:
		var bolt := ROYAL_BOLT_SCENE.instantiate()
		bolt.global_position = projectile_spawner.global_position
		get_tree().current_scene.add_child(bolt)
		bolt.setup(self, base_direction.rotated(deg_to_rad(float(angle_offset))), damage, payload)
