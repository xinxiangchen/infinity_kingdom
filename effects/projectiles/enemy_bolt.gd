extends Area2D

const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const BASIC_BULLET_TEXTURE_PATH := "res://assets/effects/projectiles/basic_bullet.webp"
const APPRENTICE_ORB_TEXTURE_PATH := "res://assets/effects/projectiles/apprentice_orb.webp"
const ARCANIST_MISSILE_TEXTURE_PATH := "res://assets/effects/projectiles/arcanist_missile.webp"

@export var speed: float = 420.0
@export var lifetime: float = 2.4
@export var hit_radius: float = 18.0

@onready var bolt: Sprite2D = $Bolt
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var source: Node = null
var extra_payload: Dictionary = {}
var expired: bool = false
var pulse_time: float = 0.0
var trail_timer: float = 0.0

func _ready() -> void:
	_setup_texture_visual(BASIC_BULLET_TEXTURE_PATH)
	_setup_collision_shape()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(owner_actor: Node, travel_direction: Vector2, hit_damage: float, color: Color = Color(0.95, 0.88, 0.6, 1.0), new_speed: float = speed, payload: Dictionary = {}) -> void:
	source = owner_actor
	direction = travel_direction.normalized() if travel_direction != Vector2.ZERO else Vector2.RIGHT
	damage = hit_damage
	speed = new_speed
	bolt.modulate = color
	_setup_texture_visual(_texture_for_color(color))
	extra_payload = payload.duplicate(true)
	rotation = direction.angle()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	pulse_time += delta
	var pixel_pulse := 1.08 if int(pulse_time * 18.0) % 2 == 0 else 0.96
	bolt.scale = Vector2.ONE * (0.72 * pixel_pulse)
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.055
		_spawn_pixel_trail()
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
	var flash := Sprite2D.new()
	flash.texture = bolt.texture
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.centered = true
	flash.scale = Vector2.ONE * 0.82
	flash.modulate = bolt.modulate
	flash.global_position = global_position
	flash.rotation = rotation
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.6, 0.1)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.finished.connect(flash.queue_free)

func _spawn_pixel_trail() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var chip := Sprite2D.new()
	chip.texture = bolt.texture
	chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chip.centered = true
	chip.scale = Vector2.ONE * 0.26
	chip.modulate = Color(bolt.modulate.r, bolt.modulate.g, bolt.modulate.b, 0.46)
	chip.global_position = global_position - direction * 12.0
	chip.rotation = rotation
	scene_root.add_child(chip)
	var tween := chip.create_tween()
	tween.tween_property(chip, "global_position", chip.global_position - direction * 10.0, 0.12)
	tween.parallel().tween_property(chip, "modulate:a", 0.0, 0.12)
	tween.finished.connect(chip.queue_free)

func _texture_for_color(color: Color) -> String:
	if color.r > 0.9 and color.g < 0.72:
		return ARCANIST_MISSILE_TEXTURE_PATH
	if color.b > color.r and color.b > color.g:
		return APPRENTICE_ORB_TEXTURE_PATH
	return BASIC_BULLET_TEXTURE_PATH

func _setup_texture_visual(texture_path: String) -> void:
	bolt.texture = TEXTURE_LOADER.load_texture(texture_path)
	bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bolt.centered = true
	bolt.scale = Vector2.ONE * 0.72

func _setup_collision_shape() -> void:
	if collision_shape == null:
		return
	var shape := CapsuleShape2D.new()
	shape.radius = 7.5
	shape.height = 34.0
	collision_shape.shape = shape
