extends CharacterBody2D

signal defeated

@export var max_hp: float = 220.0
@export var defense: float = 20.0
@export var move_speed: float = 110.0
@export var attack_damage: float = 22.0
@export var attack_range: float = 62.0
@export var attack_interval: float = 1.9
@export var detection_range: float = 320.0

@onready var body: Polygon2D = $Body
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const BASIC_ATTACK_WARNING_DELAY := 1.0
const BASIC_ATTACK_WARNING_VISIBLE_TIME := 0.8

var target: Node2D = null
var attack_cooldown: float = 0.0
var base_position: Vector2 = Vector2.ZERO
var knock_up_remaining: float = 0.0
var knock_up_total: float = 0.0
var attack_windup_remaining: float = 0.0
var attack_warning_spawned: bool = false

func _ready() -> void:
	base_position = position
	add_to_group("damageable")
	health_component.setup(max_hp, defense)
	health_component.damaged.connect(_on_damaged)
	health_component.knocked_up.connect(_on_knocked_up)
	health_component.died.connect(_on_died)
	_find_target()

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if knock_up_remaining > 0.0:
		_update_knock_up(delta)
		return
	if target == null or not is_instance_valid(target):
		_find_target()
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if attack_windup_remaining > 0.0:
			if not attack_warning_spawned:
				_show_attack_warning()
				attack_warning_spawned = true
			attack_windup_remaining = maxf(attack_windup_remaining - delta, 0.0)
			if attack_windup_remaining <= 0.0:
				attack_target()
		elif attack_cooldown <= 0.0:
			attack_cooldown = attack_interval
			attack_windup_remaining = BASIC_ATTACK_WARNING_DELAY
			attack_warning_spawned = false
	else:
		attack_windup_remaining = 0.0
		attack_warning_spawned = false
		if distance <= detection_range:
			var direction := (target.global_position - global_position).normalized()
			velocity = direction * move_speed
			if absf(direction.x) > 0.01:
				body.scale.x = -1.0 if direction.x < 0.0 else 1.0
		else:
			velocity = Vector2.ZERO
	move_and_slide()
	base_position = position

func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		target = null
		return
	target = players[0]

func attack_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > attack_range + 8.0:
		return
	if not target.has_method("receive_hit"):
		return
	var payload := {
		"source": self,
		"damage": attack_damage,
		"crit_rate": 0.0
	}
	target.receive_hit(payload)

func receive_hit(payload: Dictionary) -> void:
	var result: Dictionary = health_component.receive_hit(payload)
	var source: Variant = result.get("source", null)
	if source is Node2D:
		target = source
	var damage := float(result.get("damage", 0.0))
	if damage > 0.0:
		_spawn_damage_number(damage, bool(result.get("is_critical", false)))

func _on_damaged(_amount: float, _remaining_hp: float, _source: Node) -> void:
	body.color = Color(1.0, 0.55, 0.55, 1.0)
	var timer := get_tree().create_timer(0.14)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.color = Color(0.85, 0.4, 0.2, 1.0)
	)

func _on_knocked_up(duration: float) -> void:
	knock_up_total = duration
	knock_up_remaining = duration

func _update_knock_up(delta: float) -> void:
	knock_up_remaining = maxf(knock_up_remaining - delta, 0.0)
	var progress := 1.0 - knock_up_remaining / maxf(knock_up_total, 0.001)
	var offset := sin(progress * PI) * 24.0
	position.y = base_position.y - offset
	if knock_up_remaining <= 0.0:
		position = base_position

func _on_died() -> void:
	defeated.emit()
	queue_free()

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -34.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _show_attack_warning() -> void:
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = Vector2(-8.0, -52.0)
	if popup.has_method("setup_text"):
		popup.setup_text("!", Color(1.0, 0.95, 0.56, 1.0), 0.92)
	popup.lifetime = BASIC_ATTACK_WARNING_VISIBLE_TIME
	effects_layer.add_child(popup)
