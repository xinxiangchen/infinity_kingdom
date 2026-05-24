extends Area2D

@export var speed: float = 420.0
@export var lifetime: float = 2.4
@export var hit_radius: float = 18.0

@onready var bolt: Polygon2D = $Bolt

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var source: Node = null
var extra_payload: Dictionary = {}
var expired: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(owner_actor: Node, travel_direction: Vector2, hit_damage: float, color: Color = Color(0.95, 0.88, 0.6, 1.0), new_speed: float = speed, payload: Dictionary = {}) -> void:
	source = owner_actor
	direction = travel_direction.normalized() if travel_direction != Vector2.ZERO else Vector2.RIGHT
	damage = hit_damage
	speed = new_speed
	bolt.color = color
	extra_payload = payload.duplicate(true)
	rotation = direction.angle()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	pulse_time += delta
	bolt.scale = Vector2.ONE * (1.0 + sin(pulse_time * 20.0) * 0.05)
	_try_hit_overlapping_targets()

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	_try_hit(area.get_parent())

func _try_hit_overlapping_targets() -> void:
	if expired:
		return
	for target in get_tree().get_nodes_in_group("player"):
		if not (target is Node2D):
			continue
		var node_2d: Node2D = target
		if global_position.distance_to(node_2d.global_position) > hit_radius:
			continue
		_try_hit(target)
		if expired:
			return

func _try_hit(target: Variant) -> void:
	if expired:
		return
	target = _resolve_damage_target(target)
	if target == null or target == source:
		return
	if not target.has_method("receive_hit"):
		return
	expired = true
	var payload := {
		"source": source,
		"damage": damage,
		"crit_rate": 0.0
	}
	for key in extra_payload.keys():
		payload[key] = extra_payload[key]
	target.receive_hit(payload)
	_spawn_hit_flash()
	queue_free()

func _resolve_damage_target(target: Variant) -> Node:
	if target == null or not (target is Node):
		return null
	var node: Node = target
	if node.has_method("receive_hit"):
		return node
	if node.get_parent() != null and node.get_parent().has_method("receive_hit"):
		return node.get_parent()
	return null

func _spawn_hit_flash() -> void:
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(-7, -4),
		Vector2(0, -12),
		Vector2(7, -4),
		Vector2(12, 0),
		Vector2(7, 4),
		Vector2(0, 12),
		Vector2(-7, 4),
		Vector2(-12, 0)
	])
	flash.color = bolt.color
	flash.global_position = global_position
	flash.rotation = rotation
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.6, 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.finished.connect(flash.queue_free)
