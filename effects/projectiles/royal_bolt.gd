extends Area2D

@export var speed: float = 440.0
@export var lifetime: float = 3.0

@onready var bolt: Polygon2D = $Bolt

var direction: Vector2 = Vector2.RIGHT
var damage: float = 18.0
var source: Node = null
var extra_payload: Dictionary = {}
var expired: bool = false
var pulse_time: float = 0.0
var trail_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(owner_actor: Node, travel_direction: Vector2, hit_damage: float, payload: Dictionary = {}) -> void:
	source = owner_actor
	direction = travel_direction.normalized() if travel_direction != Vector2.ZERO else Vector2.RIGHT
	damage = hit_damage
	extra_payload = payload.duplicate(true)
	bolt.polygon = _pixel_bolt_polygon()
	rotation = direction.angle()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	pulse_time += delta
	bolt.scale = Vector2.ONE * (1.08 if int(pulse_time * 18.0) % 2 == 0 else 0.96)
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.05
		_spawn_pixel_trail()

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	_try_hit(area.get_parent())

func _try_hit(target: Variant) -> void:
	if expired:
		return
	if target is Node and (target as Node).is_in_group("projectile_blocker"):
		_expire_on_blocker()
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

func _expire_on_blocker() -> void:
	if expired:
		return
	expired = true
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
		Vector2(-12.0, -4.0),
		Vector2(-4.0, -12.0),
		Vector2(4.0, -12.0),
		Vector2(12.0, -4.0),
		Vector2(12.0, 4.0),
		Vector2(4.0, 12.0),
		Vector2(-4.0, 12.0),
		Vector2(-12.0, 4.0)
	])
	flash.color = Color(1.0, 0.84, 0.52, 0.9)
	flash.global_position = global_position
	flash.rotation = rotation
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.7, 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.finished.connect(flash.queue_free)

func _pixel_bolt_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-12.0, -4.0),
		Vector2(-4.0, -9.0),
		Vector2(6.0, -9.0),
		Vector2(18.0, 0.0),
		Vector2(6.0, 9.0),
		Vector2(-4.0, 9.0),
		Vector2(-12.0, 4.0)
	])

func _spawn_pixel_trail() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var chip := Polygon2D.new()
	chip.color = Color(1.0, 0.78, 0.46, 0.38)
	chip.polygon = PackedVector2Array([
		Vector2(-3.0, -3.0),
		Vector2(3.0, -3.0),
		Vector2(3.0, 3.0),
		Vector2(-3.0, 3.0)
	])
	chip.global_position = global_position - direction * 10.0
	chip.rotation = rotation
	scene_root.add_child(chip)
	var tween := chip.create_tween()
	tween.tween_property(chip, "global_position", chip.global_position - direction * 8.0, 0.12)
	tween.parallel().tween_property(chip, "modulate:a", 0.0, 0.12)
	tween.finished.connect(chip.queue_free)
