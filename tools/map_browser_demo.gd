extends Node2D

const ROOM_PATHS := [
	"res://assets/maps/stitched_demo/room_01_outer_entrance.png",
	"res://assets/maps/stitched_demo/room_02_street_battle_1.png",
	"res://assets/maps/stitched_demo/room_03_street_battle_2.png",
	"res://assets/maps/stitched_demo/room_04_central_plaza.png",
	"res://assets/maps/stitched_demo/room_09_elite_zone.png",
	"res://assets/maps/stitched_demo/room_10_palace_hall.png",
	"res://assets/maps/stitched_demo/room_11_palace_corridor.png",
	"res://assets/maps/stitched_demo/room_12_king_gate.png"
]

const ROOM_TITLES := [
	"01 Outer Entrance",
	"02 Street Battle 1",
	"03 Street Battle 2",
	"04 Central Plaza",
	"09 Elite Zone",
	"10 Palace Hall",
	"11 Palace Corridor",
	"12 King Gate"
]

const ROOM_GAP := 96.0
const PLAYER_SPEED := 520.0
const PLAYER_RADIUS := 22.0

var player: Node2D
var camera: Camera2D
var map_bounds := Rect2(Vector2.ZERO, Vector2.ZERO)

func _ready() -> void:
	_build_map()
	_build_player()
	_build_camera()
	_build_help_label()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		input = _fallback_keyboard_vector()
	player.position += input * PLAYER_SPEED * delta
	if map_bounds.size != Vector2.ZERO:
		player.position.x = clampf(player.position.x, map_bounds.position.x + PLAYER_RADIUS, map_bounds.end.x - PLAYER_RADIUS)
		player.position.y = clampf(player.position.y, map_bounds.position.y + PLAYER_RADIUS, map_bounds.end.y - PLAYER_RADIUS)

func _build_map() -> void:
	var map_root := Node2D.new()
	map_root.name = "StitchedMap"
	add_child(map_root)

	var x_cursor := 0.0
	var max_height := 0.0
	var previous_center := Vector2.ZERO
	for index in range(ROOM_PATHS.size()):
		var texture := load(ROOM_PATHS[index]) as Texture2D
		if texture == null:
			push_warning("Map room texture missing: %s" % ROOM_PATHS[index])
			continue

		var room := Sprite2D.new()
		room.name = "Room%02d" % [index + 1]
		room.texture = texture
		room.centered = false
		room.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		room.position = Vector2(x_cursor, 0.0)
		map_root.add_child(room)

		var size := Vector2(float(texture.get_width()), float(texture.get_height()))
		var center := room.position + size * 0.5
		_add_room_label(map_root, ROOM_TITLES[index], room.position + Vector2(24.0, 24.0))
		if index > 0:
			_add_connector(map_root, previous_center, center)
		previous_center = center

		x_cursor += size.x + ROOM_GAP
		max_height = maxf(max_height, size.y)

	map_bounds = Rect2(Vector2.ZERO, Vector2(maxf(x_cursor - ROOM_GAP, 0.0), max_height))
	_add_bounds_outline(map_root)

func _build_player() -> void:
	player = Node2D.new()
	player.name = "PlaceholderPlayer"
	player.position = Vector2(180.0, 560.0)
	add_child(player)

	var body := Polygon2D.new()
	body.name = "Body"
	body.color = Color(0.18, 0.82, 0.96, 0.96)
	body.polygon = PackedVector2Array([
		Vector2(0.0, -PLAYER_RADIUS),
		Vector2(PLAYER_RADIUS * 0.86, PLAYER_RADIUS * 0.55),
		Vector2(0.0, PLAYER_RADIUS * 0.25),
		Vector2(-PLAYER_RADIUS * 0.86, PLAYER_RADIUS * 0.55)
	])
	player.add_child(body)

	var ring := Line2D.new()
	ring.name = "GroundRing"
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(1.0, 1.0, 1.0, 0.82)
	for point_index in range(24):
		var angle := TAU * float(point_index) / 24.0
		ring.add_point(Vector2.RIGHT.rotated(angle) * (PLAYER_RADIUS + 6.0))
	player.add_child(ring)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.zoom = Vector2(0.65, 0.65)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)

func _build_help_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var label := Label.new()
	label.text = "Map Browser Demo | WASD/Arrow keys move | This is a visual stitching prototype, no collisions yet."
	label.position = Vector2(24.0, 18.0)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(label)

func _add_room_label(parent: Node, text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.z_index = 10
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 30)
	parent.add_child(label)

func _add_connector(parent: Node, from_point: Vector2, to_point: Vector2) -> void:
	var line := Line2D.new()
	line.name = "RouteConnector"
	line.width = 8.0
	line.default_color = Color(1.0, 0.82, 0.36, 0.68)
	line.add_point(from_point)
	line.add_point(to_point)
	line.z_index = 20
	parent.add_child(line)

func _add_bounds_outline(parent: Node) -> void:
	var outline := Line2D.new()
	outline.name = "MapBounds"
	outline.width = 5.0
	outline.default_color = Color(0.72, 0.88, 1.0, 0.42)
	outline.closed = true
	outline.add_point(map_bounds.position)
	outline.add_point(Vector2(map_bounds.end.x, map_bounds.position.y))
	outline.add_point(map_bounds.end)
	outline.add_point(Vector2(map_bounds.position.x, map_bounds.end.y))
	outline.z_index = 30
	parent.add_child(outline)

func _fallback_keyboard_vector() -> Vector2:
	var vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vector.y += 1.0
	return vector.normalized() if vector != Vector2.ZERO else Vector2.ZERO
