extends Area2D

@export var speed: float = 620.0
@export var lifetime: float = 1.5
@export var hit_radius: float = 18.0

@onready var bolt: Polygon2D = $Bolt
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var damage: float = 90.0
var crit_rate: float = 0.0
var source: Node = null
var attack_name: StringName = &"attack"
var expired: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("arcane_bolt_test")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(owner_actor: Node, travel_direction: Vector2, hit_damage: float, hit_crit_rate: float, attack_label: StringName = &"attack") -> void:
	source = owner_actor
	direction = travel_direction.normalized() if travel_direction != Vector2.ZERO else Vector2.RIGHT
	damage = hit_damage
	crit_rate = hit_crit_rate
	attack_name = attack_label
	rotation = direction.angle()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	pulse_time += delta
	bolt.scale = Vector2.ONE * (1.0 + sin(pulse_time * 18.0) * 0.05)
	_try_hit_overlapping_targets()

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	_try_hit(area.get_parent())

func _try_hit(target: Variant) -> void:
	if expired:
		return
	target = _resolve_damage_target(target)
	if target == null or target == source:
		return
	if not target.has_method("receive_hit"):
		return
	expired = true
	target.receive_hit(AccessoryManager.build_hit_payload(source, attack_name, damage, crit_rate))
	if source != null and source.has_method("on_attack_landed"):
		source.on_attack_landed(attack_name, target)
	_spawn_hit_flash()
	_consume_bolt()

func _try_hit_overlapping_targets() -> void:
	if expired:
		return
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == source or not (target is Node2D):
			continue
		var node_2d: Node2D = target
		if global_position.distance_to(node_2d.global_position) > hit_radius:
			continue
		_try_hit(target)
		if expired:
			return

func _resolve_damage_target(target: Variant) -> Node:
	if target == null or not (target is Node):
		return null
	var node: Node = target
	if node.has_method("receive_hit"):
		return node
	if node.get_parent() != null and node.get_parent().has_method("receive_hit"):
		return node.get_parent()
	return null

func _consume_bolt() -> void:
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	call_deferred("queue_free")

func _spawn_hit_flash() -> void:
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(-8, -4),
		Vector2(0, -14),
		Vector2(8, -4),
		Vector2(16, 0),
		Vector2(8, 4),
		Vector2(0, 14),
		Vector2(-8, 4),
		Vector2(-16, 0)
	])
	flash.color = Color(0.82, 0.92, 1.0, 0.92)
	flash.global_position = global_position
	flash.rotation = rotation
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.8, 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.finished.connect(flash.queue_free)
