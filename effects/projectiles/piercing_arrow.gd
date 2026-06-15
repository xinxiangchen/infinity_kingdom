extends Area2D

const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const ARROW_TEXTURE_PATH := "res://assets/effects/projectiles/arrow.webp"

@export var speed: float = 700.0
@export var lifetime: float = 1.4

@onready var trail: Sprite2D = $Trail

var direction: Vector2 = Vector2.RIGHT
var damage: float = 100.0
var crit_rate: float = 0.0
var source: Node = null
var attack_name: StringName = &"skill1"
var hit_targets: Array[Node] = []
var pulse_time: float = 0.0
var expired: bool = false
var trail_timer: float = 0.0

func _ready() -> void:
	_setup_texture_visual()
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
	var previous_position := global_position
	global_position += direction * speed * delta
	if _expire_if_blocked_between(previous_position, global_position):
		return
	pulse_time += delta
	trail.scale = Vector2.ONE * (0.82 if int(pulse_time * 20.0) % 2 == 0 else 0.76)
	trail.modulate = Color(1.0, 0.96, 0.72, 1.0)
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.035
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
	if hit_targets.has(target):
		return
	if not target.has_method("receive_hit"):
		return
	hit_targets.append(target)
	target.receive_hit(AccessoryManager.build_hit_payload(source, attack_name, damage, crit_rate))
	if source != null and source.has_method("on_attack_landed"):
		source.on_attack_landed(attack_name, target)
	_spawn_hit_flash()

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
	var collider = hit.get("collider", null)
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
	var flash := Sprite2D.new()
	flash.texture = TEXTURE_LOADER.load_texture(ARROW_TEXTURE_PATH)
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.centered = true
	flash.scale = Vector2.ONE * 0.92
	flash.modulate = Color(1.0, 1.0, 0.8, 0.9)
	flash.global_position = global_position
	flash.rotation = rotation
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 2.2, 0.08)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.08)
	tween.finished.connect(flash.queue_free)

func _spawn_pixel_trail() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var chip := Polygon2D.new()
	chip.color = Color(1.0, 0.94, 0.64, 0.38)
	chip.polygon = PackedVector2Array([
		Vector2(-3.0, -2.0),
		Vector2(3.0, -2.0),
		Vector2(3.0, 2.0),
		Vector2(-3.0, 2.0)
	])
	chip.global_position = global_position - direction * 16.0
	chip.rotation = rotation
	scene_root.add_child(chip)
	var tween := chip.create_tween()
	tween.tween_property(chip, "global_position", chip.global_position - direction * 12.0, 0.1)
	tween.parallel().tween_property(chip, "modulate:a", 0.0, 0.1)
	tween.finished.connect(chip.queue_free)

func _setup_texture_visual() -> void:
	trail.texture = TEXTURE_LOADER.load_texture(ARROW_TEXTURE_PATH)
	trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trail.centered = true
	trail.scale = Vector2.ONE * 0.78
