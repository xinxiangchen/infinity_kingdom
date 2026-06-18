extends Area2D

const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const BOLT_TEXTURE_PATH := "res://assets/effects/projectiles/boss_bullet_red.webp"

@export var speed: float = 300.0
@export var lifetime: float = 3.0

@onready var bolt: Sprite2D = $Bolt
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var damage: float = 30.0
var source: Node = null
var expired: bool = false

func _ready() -> void:
	add_to_group("enemy_projectile")
	z_index = 90
	_setup_visual()
	_setup_collision_shape()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func setup(owner_actor: Node, travel_direction: Vector2, hit_damage: float, new_speed: float = speed) -> void:
	source = owner_actor
	direction = travel_direction.normalized() if travel_direction != Vector2.ZERO else Vector2.RIGHT
	damage = hit_damage
	speed = new_speed
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	var previous_position := global_position
	global_position += direction * speed * delta
	if _expire_if_blocked_between(previous_position, global_position):
		return

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
	if source != null and not is_instance_valid(source):
		source = null
	if target == null or target == source:
		return
	if not target.has_method("receive_hit"):
		return
	expired = true
	target.receive_hit({
		"source": source,
		"damage": damage,
		"crit_rate": 0.0
	})
	_spawn_hit_flash()
	queue_free()

func _expire_on_blocker() -> void:
	if expired:
		return
	expired = true
	_spawn_hit_flash()
	queue_free()

func _expire_if_blocked_between(from_position: Vector2, to_position: Vector2) -> bool:
	if expired or from_position == to_position:
		return false
	var query := PhysicsRayQueryParameters2D.create(from_position, to_position)
	query.collision_mask = 1
	query.exclude = [self]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var collider: Variant = hit.get("collider", null)
	if collider is Node and (collider as Node).is_in_group("projectile_blocker"):
		_expire_on_blocker()
		return true
	return false

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
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var flash := Sprite2D.new()
	flash.texture = bolt.texture
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.centered = true
	flash.scale = Vector2.ONE * 1.15
	flash.modulate = Color(1.0, 0.42, 0.3, 0.9)
	flash.global_position = global_position
	flash.rotation = rotation
	scene_root.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.55, 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.finished.connect(flash.queue_free)

func _setup_visual() -> void:
	bolt.texture = TEXTURE_LOADER.load_texture(BOLT_TEXTURE_PATH)
	bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bolt.centered = true
	bolt.scale = Vector2.ONE * 0.78
	bolt.z_index = 91

func _setup_collision_shape() -> void:
	if collision_shape == null:
		return
	var shape := CapsuleShape2D.new()
	shape.radius = 7.0
	shape.height = 32.0
	collision_shape.rotation = PI * 0.5
	collision_shape.shape = shape
