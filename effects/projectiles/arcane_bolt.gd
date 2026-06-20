extends Area2D

const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const PLAYER_ORB_TEXTURE_PATH := "res://assets/effects/projectiles/player_staff_orb.webp"

@export var speed: float = 620.0
@export var lifetime: float = 1.5
@export var hit_radius: float = 10.0

@onready var bolt: Sprite2D = $Bolt
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
	_setup_texture_visual()
	_setup_collision_shape()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(owner_actor: Node, travel_direction: Vector2, hit_damage: float, hit_crit_rate: float, attack_label: StringName = &"attack", hit_extra_payload: Dictionary = {}) -> void:
	source = owner_actor
	direction = travel_direction.normalized() if travel_direction != Vector2.ZERO else Vector2.RIGHT
	damage = hit_damage
	crit_rate = hit_crit_rate
	attack_name = attack_label
	extra_payload = hit_extra_payload.duplicate(true)
	rotation = direction.angle()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	var previous_position := global_position
	global_position += direction * speed * delta
	if _expire_if_blocked_between(previous_position, global_position):
		return
	pulse_time += delta
	bolt.scale = Vector2.ONE * (0.72 if int(pulse_time * 16.0) % 2 == 0 else 0.66)
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

func _expire_if_blocked_between(from_position: Vector2, to_position: Vector2) -> bool:
	if expired or from_position == to_position:
		return false
	var query := PhysicsRayQueryParameters2D.create(from_position, to_position)
	query.collision_mask = 1
	query.exclude = [self]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var collider = hit.get("collider", null)
	if collider is Node and (collider as Node).is_in_group("projectile_blocker"):
		_expire_on_blocker()
		return true
	return false

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
	var flash := Sprite2D.new()
	flash.texture = TEXTURE_LOADER.load_texture(PLAYER_ORB_TEXTURE_PATH)
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.centered = true
	flash.scale = Vector2.ONE * 0.82
	flash.modulate = Color(0.82, 0.92, 1.0, 0.92)
	flash.global_position = global_position
	flash.rotation = rotation
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.8, 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.finished.connect(flash.queue_free)

func _spawn_pixel_trail() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var rune := Sprite2D.new()
	rune.texture = TEXTURE_LOADER.load_texture(PLAYER_ORB_TEXTURE_PATH)
	rune.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rune.centered = true
	rune.scale = Vector2.ONE * 0.32
	rune.modulate = Color(0.72, 0.88, 1.0, 0.34)
	rune.global_position = global_position - direction * 10.0
	scene_root.add_child(rune)
	var tween := rune.create_tween()
	tween.tween_property(rune, "scale", Vector2.ONE * 0.7, 0.12)
	tween.parallel().tween_property(rune, "modulate:a", 0.0, 0.12)
	tween.finished.connect(rune.queue_free)

func _setup_texture_visual() -> void:
	bolt.texture = TEXTURE_LOADER.load_texture(PLAYER_ORB_TEXTURE_PATH)
	bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bolt.centered = true
	bolt.scale = Vector2.ONE * 0.68

func _setup_collision_shape() -> void:
	if collision_shape == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = hit_radius
	collision_shape.shape = shape
