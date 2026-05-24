extends Area2D

@export var speed: float = 700.0
@export var lifetime: float = 1.4

@onready var trail: Polygon2D = $Trail

var direction: Vector2 = Vector2.RIGHT
var damage: float = 100.0
var crit_rate: float = 0.0
var source: Node = null
var attack_name: StringName = &"skill1"
var hit_targets: Array[Node] = []
var pulse_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(owner_actor: Node, travel_direction: Vector2, hit_damage: float, hit_crit_rate: float, attack_label: StringName = &"skill1") -> void:
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
	trail.scale = Vector2(1.0 + sin(pulse_time * 24.0) * 0.08, 1.0)
	trail.color = Color(1.0, 0.96, 0.72, 1.0)

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	_try_hit(area.get_parent())

func _try_hit(target: Variant) -> void:
	target = _resolve_damage_target(target)
	if target == null or target == source:
		return
	if hit_targets.has(target):
		return
	if not target.has_method("receive_hit"):
		return
	hit_targets.append(target)
	target.receive_hit(AccessoryManager.build_hit_payload(source, attack_name, damage, crit_rate))
	if source != null and source.has_method("on_attack_landed"):
		source.on_attack_landed(attack_name, target)
	_spawn_hit_flash()

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
		Vector2(-8, -3),
		Vector2(8, 0),
		Vector2(-8, 3),
		Vector2(-2, 0)
	])
	flash.color = Color(1.0, 1.0, 0.8, 0.9)
	flash.global_position = global_position
	flash.rotation = rotation
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 2.2, 0.08)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.08)
	tween.finished.connect(flash.queue_free)
