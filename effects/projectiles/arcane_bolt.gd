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
var extra_payload: Dictionary = {}
var expired: bool = false
var pulse_time: float = 0.0
var trail_timer: float = 0.0

func _ready() -> void:
	add_to_group("arcane_bolt_test")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(owner_actor: Node, travel_direction: Vector2, hit_damage: float, hit_crit_rate: float, attack_label: StringName = &"attack", hit_extra_payload: Dictionary = {}) -> void:
	source = owner_actor
	direction = travel_direction.normalized() if travel_direction != Vector2.ZERO else Vector2.RIGHT
	damage = hit_damage
	crit_rate = hit_crit_rate
	attack_name = attack_label
	extra_payload = hit_extra_payload.duplicate(true)
	bolt.polygon = _pixel_bolt_polygon()
	rotation = direction.angle()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	pulse_time += delta
	bolt.scale = Vector2.ONE * (1.06 if int(pulse_time * 16.0) % 2 == 0 else 0.94)
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.045
		_spawn_pixel_trail()
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
	if target is Node and (target as Node).is_in_group("projectile_blocker"):
		_expire_on_blocker()
		return
	target = _resolve_damage_target(target)
	if target == null or target == source:
		return
	if not target.has_method("receive_hit"):
		return
	expired = true
	var payload := AccessoryManager.build_hit_payload(source, attack_name, damage, crit_rate)
	for key in extra_payload.keys():
		payload[key] = extra_payload[key]
	target.receive_hit(payload)
	if source != null and source.has_method("on_attack_landed"):
		source.on_attack_landed(attack_name, target)
	_spawn_hit_flash()
	_consume_bolt()

func _expire_on_blocker() -> void:
	if expired:
		return
	expired = true
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
		Vector2(-14.0, -4.0),
		Vector2(-4.0, -14.0),
		Vector2(4.0, -14.0),
		Vector2(14.0, -4.0),
		Vector2(14.0, 4.0),
		Vector2(4.0, 14.0),
		Vector2(-4.0, 14.0),
		Vector2(-14.0, 4.0)
	])
	flash.color = Color(0.82, 0.92, 1.0, 0.92)
	flash.global_position = global_position
	flash.rotation = rotation
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.8, 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.finished.connect(flash.queue_free)

func _pixel_bolt_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-16.0, -4.0),
		Vector2(-6.0, -10.0),
		Vector2(4.0, -10.0),
		Vector2(12.0, -4.0),
		Vector2(18.0, 0.0),
		Vector2(12.0, 4.0),
		Vector2(4.0, 10.0),
		Vector2(-6.0, 10.0),
		Vector2(-16.0, 4.0),
		Vector2(-10.0, 0.0)
	])

func _spawn_pixel_trail() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var rune := Polygon2D.new()
	rune.color = Color(0.72, 0.88, 1.0, 0.34)
	rune.polygon = PackedVector2Array([
		Vector2(-3.0, -5.0),
		Vector2(3.0, -5.0),
		Vector2(5.0, 0.0),
		Vector2(3.0, 5.0),
		Vector2(-3.0, 5.0),
		Vector2(-5.0, 0.0)
	])
	rune.global_position = global_position - direction * 10.0
	scene_root.add_child(rune)
	var tween := rune.create_tween()
	tween.tween_property(rune, "scale", Vector2.ONE * 0.7, 0.12)
	tween.parallel().tween_property(rune, "modulate:a", 0.0, 0.12)
	tween.finished.connect(rune.queue_free)
