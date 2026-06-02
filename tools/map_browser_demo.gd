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

const ROOM_PROP_LAYER_PATHS := [
	"res://assets/maps/stitched_demo/props/room_01_props.png",
	"res://assets/maps/stitched_demo/props/room_02_props.png",
	"res://assets/maps/stitched_demo/props/room_03_props.png",
	"res://assets/maps/stitched_demo/props/room_04_props.png",
	"res://assets/maps/stitched_demo/props/room_09_props.png",
	"res://assets/maps/stitched_demo/props/room_10_props.png",
	"res://assets/maps/stitched_demo/props/room_11_props.png",
	"res://assets/maps/stitched_demo/props/room_12_props.png"
]

const ENEMY_PREVIEWS := [
	{
		"name": "Swordsman",
		"texture": "res://actors/enemy/textures/swordsman.png",
		"room": 1,
		"offset_ratio": Vector2(0.46, 0.70)
	},
	{
		"name": "Shield",
		"texture": "res://actors/enemy/textures/shield.png",
		"room": 2,
		"offset_ratio": Vector2(0.34, 0.68)
	},
	{
		"name": "Hunter",
		"texture": "res://actors/enemy/textures/hunter.png",
		"room": 2,
		"offset_ratio": Vector2(0.62, 0.66)
	},
	{
		"name": "Archer",
		"texture": "res://actors/enemy/textures/archer.png",
		"room": 3,
		"offset_ratio": Vector2(0.50, 0.70)
	},
	{
		"name": "Arcanist",
		"texture": "res://actors/enemy/textures/arcanist.png",
		"room": 4,
		"offset_ratio": Vector2(0.42, 0.66)
	},
	{
		"name": "Apprentice Mage",
		"texture": "res://actors/enemy/textures/apprentice_mage.png",
		"room": 4,
		"offset_ratio": Vector2(0.64, 0.66)
	}
]

const ROOM_GAP := 0.0
const PLAYER_SPEED := 520.0
const PLAYER_RADIUS := 22.0
const ENEMY_PREVIEW_SCALE := Vector2(0.82, 0.82)
const COLLISION_WALL_THICKNESS := 80.0
const COLLISION_DEBUG_VISIBLE := false
const PROP_COLLISION_DEBUG_VISIBLE := true
const RANDOM_PROP_MIN_PER_ROOM := 2
const RANDOM_PROP_MAX_PER_ROOM := 4

const WALKABLE_AREAS := [
	Rect2(0.0, 0.52, 1.0, 0.32),
	Rect2(0.0, 0.50, 1.0, 0.34),
	Rect2(0.0, 0.50, 1.0, 0.34),
	Rect2(0.0, 0.47, 1.0, 0.37),
	Rect2(0.0, 0.49, 1.0, 0.35),
	Rect2(0.0, 0.50, 1.0, 0.34),
	Rect2(0.0, 0.49, 1.0, 0.35),
	Rect2(0.0, 0.51, 1.0, 0.33)
]

const PROP_CANDIDATES := [
	{"room": 0, "name": "WoodCrateLeft", "source": Rect2(0.07, 0.07, 0.17, 0.18), "position": Vector2(0.16, 0.61), "collision": Vector2(0.10, 0.07)},
	{"room": 0, "name": "WoodBench", "source": Rect2(0.35, 0.35, 0.23, 0.11), "position": Vector2(0.45, 0.63), "collision": Vector2(0.19, 0.06)},
	{"room": 0, "name": "FireBrazier", "source": Rect2(0.48, 0.50, 0.10, 0.16), "position": Vector2(0.52, 0.70), "collision": Vector2(0.07, 0.06)},
	{"room": 0, "name": "StoneRubble", "source": Rect2(0.34, 0.75, 0.16, 0.12), "position": Vector2(0.40, 0.79), "collision": Vector2(0.13, 0.06)},
	{"room": 0, "name": "RightBarricade", "source": Rect2(0.75, 0.33, 0.15, 0.18), "position": Vector2(0.79, 0.62), "collision": Vector2(0.11, 0.08)},
	{"room": 1, "name": "SpikeFence", "source": Rect2(0.07, 0.34, 0.21, 0.13), "position": Vector2(0.18, 0.61), "collision": Vector2(0.18, 0.07)},
	{"room": 1, "name": "StreetBench", "source": Rect2(0.36, 0.36, 0.22, 0.10), "position": Vector2(0.45, 0.63), "collision": Vector2(0.19, 0.06)},
	{"room": 1, "name": "WoodBarricade", "source": Rect2(0.62, 0.33, 0.18, 0.14), "position": Vector2(0.66, 0.62), "collision": Vector2(0.14, 0.08)},
	{"room": 1, "name": "CampfirePile", "source": Rect2(0.78, 0.32, 0.16, 0.16), "position": Vector2(0.80, 0.62), "collision": Vector2(0.11, 0.07)},
	{"room": 1, "name": "BottomRubble", "source": Rect2(0.16, 0.73, 0.18, 0.12), "position": Vector2(0.21, 0.76), "collision": Vector2(0.13, 0.06)},
	{"room": 2, "name": "RoundWellLeft", "source": Rect2(0.05, 0.17, 0.14, 0.13), "position": Vector2(0.15, 0.56), "collision": Vector2(0.11, 0.07)},
	{"room": 2, "name": "RoundWellCenter", "source": Rect2(0.26, 0.14, 0.18, 0.14), "position": Vector2(0.38, 0.55), "collision": Vector2(0.14, 0.08)},
	{"room": 2, "name": "StoneBlock", "source": Rect2(0.50, 0.17, 0.14, 0.15), "position": Vector2(0.55, 0.56), "collision": Vector2(0.10, 0.08)},
	{"room": 2, "name": "BrokenWood", "source": Rect2(0.31, 0.65, 0.21, 0.11), "position": Vector2(0.38, 0.70), "collision": Vector2(0.16, 0.07)},
	{"room": 2, "name": "RockPile", "source": Rect2(0.63, 0.52, 0.14, 0.09), "position": Vector2(0.67, 0.65), "collision": Vector2(0.11, 0.06)},
	{"room": 3, "name": "LeftFountain", "source": Rect2(0.07, 0.44, 0.19, 0.20), "position": Vector2(0.20, 0.63), "collision": Vector2(0.16, 0.09)},
	{"room": 3, "name": "CenterFountain", "source": Rect2(0.30, 0.42, 0.20, 0.20), "position": Vector2(0.40, 0.62), "collision": Vector2(0.16, 0.10)},
	{"room": 3, "name": "BarrelCluster", "source": Rect2(0.10, 0.28, 0.20, 0.08), "position": Vector2(0.20, 0.53), "collision": Vector2(0.16, 0.06)},
	{"room": 3, "name": "StatueLine", "source": Rect2(0.59, 0.44, 0.19, 0.12), "position": Vector2(0.65, 0.61), "collision": Vector2(0.15, 0.07)},
	{"room": 3, "name": "RightPot", "source": Rect2(0.82, 0.44, 0.08, 0.11), "position": Vector2(0.84, 0.62), "collision": Vector2(0.06, 0.06)},
	{"room": 4, "name": "StonePillarLeft", "source": Rect2(0.17, 0.43, 0.08, 0.16), "position": Vector2(0.21, 0.61), "collision": Vector2(0.06, 0.08)},
	{"room": 4, "name": "StonePillarCenter", "source": Rect2(0.40, 0.42, 0.08, 0.17), "position": Vector2(0.43, 0.61), "collision": Vector2(0.06, 0.08)},
	{"room": 4, "name": "Altar", "source": Rect2(0.48, 0.56, 0.16, 0.13), "position": Vector2(0.53, 0.70), "collision": Vector2(0.13, 0.07)},
	{"room": 4, "name": "StoneBasin", "source": Rect2(0.73, 0.60, 0.13, 0.10), "position": Vector2(0.78, 0.70), "collision": Vector2(0.10, 0.06)},
	{"room": 5, "name": "PalaceColumnLeft", "source": Rect2(0.11, 0.07, 0.09, 0.30), "position": Vector2(0.17, 0.56), "collision": Vector2(0.07, 0.09)},
	{"room": 5, "name": "PalaceColumnRight", "source": Rect2(0.70, 0.07, 0.09, 0.30), "position": Vector2(0.76, 0.56), "collision": Vector2(0.07, 0.09)},
	{"room": 5, "name": "FireLine", "source": Rect2(0.07, 0.43, 0.23, 0.13), "position": Vector2(0.19, 0.62), "collision": Vector2(0.17, 0.07)},
	{"room": 5, "name": "StoneBowl", "source": Rect2(0.74, 0.46, 0.12, 0.10), "position": Vector2(0.78, 0.63), "collision": Vector2(0.09, 0.06)},
	{"room": 6, "name": "TopTableLeft", "source": Rect2(0.11, 0.03, 0.20, 0.14), "position": Vector2(0.20, 0.55), "collision": Vector2(0.16, 0.07)},
	{"room": 6, "name": "TopTableCenter", "source": Rect2(0.38, 0.03, 0.17, 0.14), "position": Vector2(0.45, 0.55), "collision": Vector2(0.14, 0.07)},
	{"room": 6, "name": "CurtainBarrier", "source": Rect2(0.48, 0.51, 0.28, 0.12), "position": Vector2(0.60, 0.70), "collision": Vector2(0.22, 0.06)},
	{"room": 6, "name": "LowerFires", "source": Rect2(0.18, 0.76, 0.19, 0.12), "position": Vector2(0.27, 0.78), "collision": Vector2(0.14, 0.06)},
	{"room": 7, "name": "ThroneLeftColumn", "source": Rect2(0.18, 0.57, 0.10, 0.16), "position": Vector2(0.24, 0.65), "collision": Vector2(0.07, 0.08)},
	{"room": 7, "name": "ThroneCenterCrate", "source": Rect2(0.45, 0.61, 0.10, 0.10), "position": Vector2(0.51, 0.68), "collision": Vector2(0.08, 0.06)},
	{"room": 7, "name": "ThroneRightColumn", "source": Rect2(0.69, 0.57, 0.10, 0.16), "position": Vector2(0.74, 0.65), "collision": Vector2(0.07, 0.08)},
	{"room": 7, "name": "BannerStand", "source": Rect2(0.83, 0.18, 0.12, 0.32), "position": Vector2(0.85, 0.61), "collision": Vector2(0.08, 0.09)}
]

var player: CharacterBody2D
var camera: Camera2D
var map_bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
var room_rects: Array[Rect2] = []
var walkable_rects: Array[Rect2] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
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
	player.velocity = input * PLAYER_SPEED
	player.move_and_slide()
	if map_bounds.size != Vector2.ZERO:
		player.position.x = clampf(player.position.x, map_bounds.position.x + PLAYER_RADIUS, map_bounds.end.x - PLAYER_RADIUS)
		player.position.y = clampf(player.position.y, map_bounds.position.y + PLAYER_RADIUS, map_bounds.end.y - PLAYER_RADIUS)

func _build_map() -> void:
	var map_root := Node2D.new()
	map_root.name = "StitchedMap"
	add_child(map_root)

	room_rects.clear()
	walkable_rects.clear()
	var x_cursor := 0.0
	var max_height := 0.0
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
		var room_rect := Rect2(room.position, size)
		room_rects.append(room_rect)
		walkable_rects.append(_get_walkable_rect(index, room_rect))
		_add_room_label(map_root, ROOM_TITLES[index], room.position + Vector2(24.0, 24.0))
		_add_room_portals(map_root, index, room_rect, walkable_rects[index])

		x_cursor += size.x + ROOM_GAP
		max_height = maxf(max_height, size.y)

	map_bounds = Rect2(Vector2.ZERO, Vector2(maxf(x_cursor - ROOM_GAP, 0.0), max_height))
	_add_bounds_outline(map_root)
	_add_collision_boxes(map_root)
	_add_random_cover_props(map_root)
	_add_enemy_previews(map_root)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "PlaceholderPlayer"
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = _get_player_spawn()
	add_child(player)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	collision.shape = circle
	player.add_child(collision)

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
	label.text = "Map Browser Demo | WASD/Arrow keys move | Rough collision boxes are enabled."
	label.position = Vector2(24.0, 18.0)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(label)

func _get_walkable_rect(index: int, room_rect: Rect2) -> Rect2:
	var ratio: Rect2 = WALKABLE_AREAS[min(index, WALKABLE_AREAS.size() - 1)]
	return Rect2(
		room_rect.position + Vector2(room_rect.size.x * ratio.position.x, room_rect.size.y * ratio.position.y),
		Vector2(room_rect.size.x * ratio.size.x, room_rect.size.y * ratio.size.y)
	)

func _get_player_spawn() -> Vector2:
	if walkable_rects.is_empty():
		return Vector2(180.0, 560.0)
	var first_walkable := walkable_rects[0]
	return first_walkable.position + Vector2(first_walkable.size.x * 0.12, first_walkable.size.y * 0.5)

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

func _add_room_portals(parent: Node, index: int, room_rect: Rect2, walk_rect: Rect2) -> void:
	var portal_height: float = min(walk_rect.size.y * 0.72, 220.0)
	var portal_center_y: float = walk_rect.get_center().y
	var left_text: String = "START" if index == 0 else "IN"
	var right_text: String = "EXIT" if index == room_rects.size() - 1 else "OUT"
	_add_portal_marker(parent, "%s%02d" % [left_text, index + 1], Vector2(room_rect.position.x, portal_center_y), portal_height, left_text, true)
	_add_portal_marker(parent, "%s%02d" % [right_text, index + 1], Vector2(room_rect.end.x, portal_center_y), portal_height, right_text, false)

func _add_portal_marker(parent: Node, marker_name: String, position: Vector2, height: float, text: String, label_on_left: bool) -> void:
	var marker := Node2D.new()
	marker.name = "%sPortal" % marker_name
	marker.position = position
	marker.z_index = 25
	parent.add_child(marker)

	var line := Line2D.new()
	line.name = "DoorLine"
	line.width = 7.0
	line.default_color = Color(0.42, 1.0, 0.78, 0.88)
	line.add_point(Vector2(0.0, -height * 0.5))
	line.add_point(Vector2(0.0, height * 0.5))
	marker.add_child(line)

	var label := Label.new()
	label.name = "DoorLabel"
	label.text = text
	label.size = Vector2(92.0, 28.0)
	label.position = Vector2(-106.0, -height * 0.5 - 34.0) if label_on_left else Vector2(14.0, -height * 0.5 - 34.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.66, 1.0, 0.84, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 18)
	marker.add_child(label)

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

func _add_collision_boxes(parent: Node) -> void:
	var collision_root := Node2D.new()
	collision_root.name = "RoomBoundaryCollision"
	collision_root.z_index = 35
	parent.add_child(collision_root)

	for index in range(walkable_rects.size()):
		var room_rect := room_rects[index]
		var walk_rect := walkable_rects[index]
		_add_blocker(collision_root, "Room%02dTopWall" % [index + 1], Rect2(room_rect.position, Vector2(room_rect.size.x, walk_rect.position.y - room_rect.position.y)))
		_add_blocker(collision_root, "Room%02dBottomWall" % [index + 1], Rect2(Vector2(room_rect.position.x, walk_rect.end.y), Vector2(room_rect.size.x, room_rect.end.y - walk_rect.end.y)))
		if index == 0:
			_add_blocker(collision_root, "RouteLeftWall", Rect2(Vector2(walk_rect.position.x - COLLISION_WALL_THICKNESS, walk_rect.position.y), Vector2(COLLISION_WALL_THICKNESS, walk_rect.size.y)))
		if index == walkable_rects.size() - 1:
			_add_blocker(collision_root, "RouteRightWall", Rect2(Vector2(walk_rect.end.x, walk_rect.position.y), Vector2(COLLISION_WALL_THICKNESS, walk_rect.size.y)))

	for index in range(1, walkable_rects.size()):
		_add_gap_collision(collision_root, index - 1, index)

func _add_gap_collision(parent: Node, previous_index: int, current_index: int) -> void:
	var previous_walkable := walkable_rects[previous_index]
	var current_walkable := walkable_rects[current_index]
	var gap_x := previous_walkable.end.x
	var gap_width := current_walkable.position.x - previous_walkable.end.x
	if gap_width <= 0.0:
		return

	var corridor_height: float = min(previous_walkable.size.y, current_walkable.size.y) * 0.58
	var corridor_center_y: float = (previous_walkable.get_center().y + current_walkable.get_center().y) * 0.5
	var corridor_top: float = corridor_center_y - corridor_height * 0.5
	var corridor_bottom: float = corridor_center_y + corridor_height * 0.5
	_add_blocker(parent, "Gap%02dTopWall" % current_index, Rect2(Vector2(gap_x, 0.0), Vector2(gap_width, corridor_top)))
	_add_blocker(parent, "Gap%02dBottomWall" % current_index, Rect2(Vector2(gap_x, corridor_bottom), Vector2(gap_width, map_bounds.end.y - corridor_bottom)))

func _add_blocker(parent: Node, blocker_name: String, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var body := StaticBody2D.new()
	body.name = blocker_name
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = rect.get_center()
	parent.add_child(body)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)

	if COLLISION_DEBUG_VISIBLE:
		var visual := Polygon2D.new()
		visual.name = "DebugFill"
		visual.color = Color(1.0, 0.22, 0.14, 0.16)
		visual.polygon = PackedVector2Array([
			Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5),
			Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
			Vector2(rect.size.x * 0.5, rect.size.y * 0.5),
			Vector2(-rect.size.x * 0.5, rect.size.y * 0.5)
		])
		body.add_child(visual)

func _add_random_cover_props(parent: Node) -> void:
	var prop_root := Node2D.new()
	prop_root.name = "RandomCoverProps"
	prop_root.z_index = 38
	parent.add_child(prop_root)

	for room_index in range(room_rects.size()):
		var candidates := _get_prop_candidates_for_room(room_index)
		if candidates.is_empty():
			continue
		candidates.shuffle()
		var count: int = min(rng.randi_range(RANDOM_PROP_MIN_PER_ROOM, RANDOM_PROP_MAX_PER_ROOM), candidates.size())
		for index in range(count):
			_add_cover_prop(prop_root, candidates[index])

func _get_prop_candidates_for_room(room_index: int) -> Array:
	var result := []
	for candidate in PROP_CANDIDATES:
		if int(candidate["room"]) == room_index:
			result.append(candidate)
	return result

func _add_cover_prop(parent: Node, candidate: Dictionary) -> void:
	var room_index := int(candidate["room"])
	if room_index < 0 or room_index >= room_rects.size() or room_index >= ROOM_PROP_LAYER_PATHS.size():
		return

	var texture := load(String(ROOM_PROP_LAYER_PATHS[room_index])) as Texture2D
	if texture == null:
		push_warning("Prop layer texture missing: %s" % ROOM_PROP_LAYER_PATHS[room_index])
		return

	var room_rect := room_rects[room_index]
	var source_ratio: Rect2 = candidate["source"]
	var source_rect := Rect2(
		Vector2(float(texture.get_width()) * source_ratio.position.x, float(texture.get_height()) * source_ratio.position.y),
		Vector2(float(texture.get_width()) * source_ratio.size.x, float(texture.get_height()) * source_ratio.size.y)
	)
	var texture_to_room_scale := Vector2(room_rect.size.x / float(texture.get_width()), room_rect.size.y / float(texture.get_height()))
	var prop_position_ratio: Vector2 = candidate["position"]
	var collision_ratio: Vector2 = candidate["collision"]
	var world_position := room_rect.position + Vector2(room_rect.size.x * prop_position_ratio.x, room_rect.size.y * prop_position_ratio.y)
	var collision_size := Vector2(room_rect.size.x * collision_ratio.x, room_rect.size.y * collision_ratio.y)

	var body := StaticBody2D.new()
	body.name = "%sCover" % String(candidate["name"])
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = world_position
	parent.add_child(body)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = source_rect
	sprite.scale = texture_to_room_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 1
	body.add_child(sprite)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = collision_size
	shape.shape = rectangle
	body.add_child(shape)

	if PROP_COLLISION_DEBUG_VISIBLE:
		_add_collision_debug_outline(body, collision_size)

func _add_collision_debug_outline(parent: Node, size: Vector2) -> void:
	var outline := Line2D.new()
	outline.name = "CollisionDebugOutline"
	outline.width = 3.0
	outline.closed = true
	outline.default_color = Color(0.25, 0.9, 1.0, 0.82)
	outline.add_point(Vector2(-size.x * 0.5, -size.y * 0.5))
	outline.add_point(Vector2(size.x * 0.5, -size.y * 0.5))
	outline.add_point(Vector2(size.x * 0.5, size.y * 0.5))
	outline.add_point(Vector2(-size.x * 0.5, size.y * 0.5))
	parent.add_child(outline)

func _add_enemy_previews(parent: Node) -> void:
	var enemy_root := Node2D.new()
	enemy_root.name = "EnemyMaterialPreview"
	enemy_root.z_index = 40
	parent.add_child(enemy_root)

	for preview in ENEMY_PREVIEWS:
		var room_index := int(preview["room"])
		if room_index < 0 or room_index >= room_rects.size():
			push_warning("Enemy preview room index out of range: %s" % room_index)
			continue

		var texture := load(String(preview["texture"])) as Texture2D
		if texture == null:
			push_warning("Enemy preview texture missing: %s" % preview["texture"])
			continue

		var room_rect := room_rects[room_index]
		var offset_ratio := preview["offset_ratio"] as Vector2
		var position := room_rect.position + Vector2(room_rect.size.x * offset_ratio.x, room_rect.size.y * offset_ratio.y)
		_add_enemy_preview(enemy_root, String(preview["name"]), texture, position)

func _add_enemy_preview(parent: Node, display_name: String, texture: Texture2D, position: Vector2) -> void:
	var preview := Node2D.new()
	preview.name = "%sPreview" % display_name.replace(" ", "")
	preview.position = position
	parent.add_child(preview)

	var ring := Line2D.new()
	ring.name = "GroundRing"
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.78, 0.34, 0.86)
	for point_index in range(28):
		var angle := TAU * float(point_index) / 28.0
		ring.add_point(Vector2(cos(angle) * 52.0, sin(angle) * 24.0))
	preview.add_child(ring)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.position = Vector2(0.0, -58.0)
	sprite.scale = ENEMY_PREVIEW_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.add_child(sprite)

	var label := Label.new()
	label.name = "NameLabel"
	label.text = display_name
	label.position = Vector2(-72.0, 32.0)
	label.size = Vector2(144.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.74, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 18)
	preview.add_child(label)

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
