extends Node2D

const MapBrowserDemo := preload("res://tools/map_browser_demo.gd")
const RuntimeTextureLoader := preload("res://combat/runtime_texture_loader.gd")

const MAP_CAMERA_ZOOM := Vector2(1.7, 1.7)
const PROP_COLLISION_DEBUG_VISIBLE := false
const DOOR_WIDTH := 42.0
const DOOR_HEIGHT := 132.0
const DOOR_GLOW_COLOR := Color(0.66, 1.0, 0.84, 0.92)
const DOOR_FRAME_COLOR := Color(0.18, 0.22, 0.28, 0.98)
const FUNCTION_ROOM_INDICES := [4, 5, 6]
const FUNCTION_CHOICE_SOURCE_ROOM_INDEX := 3
const FUNCTION_CHOICE_Y_RATIOS := [0.28, 0.50, 0.72]
const FUNCTION_ROOM_MARKERS := {
	4: {
		"title": "CHURCH",
		"subtitle": "Rest and recover",
		"icon": "res://assets/ui/icon/ui_church.png",
		"color": Color(0.68, 0.96, 0.78, 0.96)
	},
	5: {
		"title": "ARMORY",
		"subtitle": "Quartermaster",
		"icon": "res://assets/ui/icon/ui_shield.png",
		"color": Color(0.64, 0.78, 1.0, 0.96)
	},
	6: {
		"title": "SHOP",
		"subtitle": "Merchant",
		"icon": "res://assets/ui/icon/ui_shop.png",
		"color": Color(1.0, 0.82, 0.42, 0.96)
	}
}

var world_root: Node2D = null
var spawn_marker: Marker2D = null
var encounter_marker: Marker2D = null
var reward_rng: RandomNumberGenerator = null
var map_root: Node2D = null
var map_camera: Camera2D = null
var map_cover_root: Node2D = null
var map_room_rects: Array[Rect2] = []
var map_walkable_rects: Array[Rect2] = []
var selected_function_room_index: int = -1

static func room_path_for_index(index: int) -> String:
	return MapBrowserDemo.room_path_for_index(index)


func setup(p_world_root: Node2D, p_spawn_marker: Marker2D, p_encounter_marker: Marker2D, p_rng: RandomNumberGenerator) -> void:
	world_root = p_world_root
	spawn_marker = p_spawn_marker
	encounter_marker = p_encounter_marker
	reward_rng = p_rng
	if reward_rng == null:
		reward_rng = RandomNumberGenerator.new()
		reward_rng.randomize()


func build() -> void:
	if world_root == null:
		return
	map_root = Node2D.new()
	map_root.name = "RuntimeMapRooms"
	map_root.z_index = -20
	world_root.add_child(map_root)
	_build_runtime_map_rooms()
	map_camera = Camera2D.new()
	map_camera.name = "RoomCamera2D"
	map_camera.enabled = true
	map_camera.zoom = MAP_CAMERA_ZOOM
	map_camera.position_smoothing_enabled = true
	map_camera.position_smoothing_speed = 9.0
	world_root.add_child(map_camera)


func activate_room(room_index: int, player_character: Node, move_player: bool = true) -> void:
	if map_walkable_rects.is_empty():
		return
	var clamped_index := clampi(room_index, 0, map_walkable_rects.size() - 1)
	if spawn_marker != null:
		spawn_marker.position = player_spawn_for_room(clamped_index)
	if encounter_marker != null:
		encounter_marker.position = encounter_spawn_for_room(clamped_index)
	if move_player and player_character is Node2D and spawn_marker != null and is_instance_valid(player_character):
		(player_character as Node2D).position = spawn_marker.position
	update_camera(clamped_index, player_character, true)


func update_camera(room_index: int, player_character: Node, force: bool = false) -> void:
	if map_camera == null or not (player_character is Node2D) or not is_instance_valid(player_character) or map_room_rects.is_empty():
		return
	var clamped_index := clampi(room_index, 0, map_room_rects.size() - 1)
	var target := _clamped_camera_position(clamped_index, (player_character as Node2D).global_position)
	if force:
		map_camera.position_smoothing_enabled = false
		map_camera.global_position = target
		map_camera.position_smoothing_enabled = true
	else:
		map_camera.global_position = target

func debug_camera_position() -> Vector2:
	return map_camera.global_position if map_camera != null else Vector2.ZERO


func player_spawn_for_room(room_index: int) -> Vector2:
	return room_entrance_target(room_index) + Vector2(44.0, 0.0)


func encounter_spawn_for_room(room_index: int) -> Vector2:
	if map_walkable_rects.is_empty():
		return encounter_marker.position if encounter_marker != null else Vector2.ZERO
	var walk_rect := map_walkable_rects[clampi(room_index, 0, map_walkable_rects.size() - 1)]
	if room_index == map_walkable_rects.size() - 1:
		return walk_rect.position + Vector2(walk_rect.size.x * 0.88, walk_rect.size.y * 0.46)
	var y_ratio := 0.76 if room_index <= 4 else 0.58
	return walk_rect.position + Vector2(walk_rect.size.x * 0.62, walk_rect.size.y * y_ratio)


func room_exit_target(room_index: int) -> Vector2:
	if map_walkable_rects.is_empty():
		return encounter_spawn_for_room(room_index)
	var walk_rect := map_walkable_rects[clampi(room_index, 0, map_walkable_rects.size() - 1)]
	return walk_rect.position + Vector2(walk_rect.size.x * 0.93, walk_rect.size.y * 0.54)


func room_entrance_target(room_index: int) -> Vector2:
	if map_walkable_rects.is_empty():
		return spawn_marker.position if spawn_marker != null else Vector2.ZERO
	var walk_rect := map_walkable_rects[clampi(room_index, 0, map_walkable_rects.size() - 1)]
	return walk_rect.position + Vector2(walk_rect.size.x * 0.07, walk_rect.size.y * 0.54)


func _build_runtime_map_rooms() -> void:
	map_room_rects.clear()
	map_walkable_rects.clear()
	var x_cursor := 0.0
	var function_room_x := -1.0
	for index in range(MapBrowserDemo.ROOM_PATHS.size()):
		var texture := RuntimeTextureLoader.load_texture(String(MapBrowserDemo.ROOM_PATHS[index]))
		if texture == null:
			push_warning("Missing map texture: %s" % MapBrowserDemo.ROOM_PATHS[index])
			continue
		if index == FUNCTION_ROOM_INDICES[0]:
			function_room_x = x_cursor
		var room_x := function_room_x if index in FUNCTION_ROOM_INDICES else x_cursor
		var room_rect := Rect2(Vector2(room_x, 0.0), Vector2(float(texture.get_width()), float(texture.get_height())))
		var walk_rect := _map_walkable_rect(index, room_rect)
		map_room_rects.append(room_rect)
		map_walkable_rects.append(walk_rect)
		if index not in FUNCTION_ROOM_INDICES:
			_add_runtime_room_visual(index, texture, room_rect)
			_add_runtime_room_walls(index, room_rect)
			_add_runtime_room_doors(index, room_rect, walk_rect)
		if index == FUNCTION_ROOM_INDICES[FUNCTION_ROOM_INDICES.size() - 1]:
			x_cursor = function_room_x + room_rect.size.x
		elif index not in FUNCTION_ROOM_INDICES:
			x_cursor += room_rect.size.x
	_add_runtime_room_props()


func _add_runtime_room_visual(index: int, texture: Texture2D, room_rect: Rect2) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "MapRoom%02d" % [index + 1]
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = room_rect.position
	sprite.set_meta("room_index", index)
	map_root.add_child(sprite)


func select_function_room(room_index: int) -> bool:
	if selected_function_room_index >= 0 or room_index not in FUNCTION_ROOM_INDICES:
		return false
	var texture := RuntimeTextureLoader.load_texture(String(MapBrowserDemo.ROOM_PATHS[room_index]))
	if texture == null:
		return false
	selected_function_room_index = room_index
	_add_runtime_room_visual(room_index, texture, map_room_rects[room_index])
	_add_runtime_room_walls(room_index, map_room_rects[room_index])
	_add_runtime_room_doors(room_index, map_room_rects[room_index], map_walkable_rects[room_index])
	_add_function_room_marker(room_index)
	_add_random_props_for_room(room_index)
	return true


func reset_function_room_selection() -> void:
	selected_function_room_index = -1
	if map_root != null:
		for child in map_root.get_children():
			var child_name := String(child.name)
			if child_name.begins_with("MapRoom05") or child_name.begins_with("MapRoom06") or child_name.begins_with("MapRoom07") or child_name.begins_with("Room05") or child_name.begins_with("Room06") or child_name.begins_with("Room07"):
				child.queue_free()
	if map_cover_root != null:
		for child in map_cover_root.get_children():
			if int(child.get_meta("room_index", -1)) in FUNCTION_ROOM_INDICES:
				child.queue_free()


func function_room_choice_for_position(world_position: Vector2) -> int:
	if selected_function_room_index >= 0 or map_room_rects.size() <= FUNCTION_CHOICE_SOURCE_ROOM_INDEX:
		return selected_function_room_index
	var source_rect := map_room_rects[FUNCTION_CHOICE_SOURCE_ROOM_INDEX]
	if world_position.x < source_rect.end.x - 46.0:
		return -1
	var walk_rect := map_walkable_rects[FUNCTION_CHOICE_SOURCE_ROOM_INDEX]
	var best_index := 0
	var best_distance := INF
	for choice_index in range(FUNCTION_CHOICE_Y_RATIOS.size()):
		var choice_y := walk_rect.position.y + walk_rect.size.y * float(FUNCTION_CHOICE_Y_RATIOS[choice_index])
		var distance := absf(world_position.y - choice_y)
		if distance < best_distance:
			best_distance = distance
			best_index = choice_index
	return int(FUNCTION_ROOM_INDICES[best_index])


func _map_walkable_rect(index: int, room_rect: Rect2) -> Rect2:
	var ratio: Rect2 = MapBrowserDemo.WALKABLE_AREAS[min(index, MapBrowserDemo.WALKABLE_AREAS.size() - 1)]
	return Rect2(
		room_rect.position + Vector2(room_rect.size.x * ratio.position.x, room_rect.size.y * ratio.position.y),
		Vector2(room_rect.size.x * ratio.size.x, room_rect.size.y * ratio.size.y)
	)


func _add_runtime_room_walls(index: int, room_rect: Rect2) -> void:
	var wall_rects := MapBrowserDemo.get_room_wall_rects(index, room_rect)
	for wall_index in range(wall_rects.size()):
		_add_runtime_wall("Room%02dWall%02d" % [index + 1, wall_index + 1], wall_rects[wall_index])
	var circle_collisions := MapBrowserDemo.get_room_circle_collisions(index, room_rect)
	for circle_index in range(circle_collisions.size()):
		_add_runtime_circle_wall("Room%02dCircle%02d" % [index + 1, circle_index + 1], circle_collisions[circle_index])


func _add_runtime_wall(wall_name: String, rect: Rect2) -> void:
	if map_root == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.name = wall_name
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("projectile_blocker")
	body.position = rect.get_center()
	map_root.add_child(body)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)

func _add_runtime_circle_wall(wall_name: String, data: Dictionary) -> void:
	if map_root == null:
		return
	var radius := float(data.get("radius", 0.0))
	if radius <= 0.0:
		return
	var body := StaticBody2D.new()
	body.name = wall_name
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("projectile_blocker")
	body.position = data.get("center", Vector2.ZERO) as Vector2
	map_root.add_child(body)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)


func _add_runtime_room_doors(room_index: int, room_rect: Rect2, walk_rect: Rect2) -> void:
	if map_root == null:
		return
	var entrance_center := Vector2(room_rect.position.x + 10.0, walk_rect.get_center().y)
	var exit_center := Vector2(room_rect.end.x - 10.0, walk_rect.get_center().y)
	if room_index > 0:
		_add_door_marker("Room%02dEntrance" % [room_index + 1], entrance_center, true)
	if room_index == FUNCTION_CHOICE_SOURCE_ROOM_INDEX:
		for choice_index in range(FUNCTION_CHOICE_Y_RATIOS.size()):
			var choice_center := Vector2(exit_center.x, walk_rect.position.y + walk_rect.size.y * float(FUNCTION_CHOICE_Y_RATIOS[choice_index]))
			_add_door_marker("FunctionChoice%02d" % [choice_index + 1], choice_center, false)
	elif room_index < MapBrowserDemo.ROOM_PATHS.size() - 1:
		_add_door_marker("Room%02dExit" % [room_index + 1], exit_center, false)


func _add_door_marker(marker_name: String, center: Vector2, left_side: bool) -> void:
	var marker := Node2D.new()
	marker.name = marker_name
	marker.position = center
	marker.z_index = 8
	map_root.add_child(marker)

	var frame := Polygon2D.new()
	frame.color = DOOR_FRAME_COLOR
	frame.polygon = PackedVector2Array([
		Vector2(-DOOR_WIDTH * 0.5, -DOOR_HEIGHT * 0.5),
		Vector2(DOOR_WIDTH * 0.5, -DOOR_HEIGHT * 0.5),
		Vector2(DOOR_WIDTH * 0.5, DOOR_HEIGHT * 0.5),
		Vector2(-DOOR_WIDTH * 0.5, DOOR_HEIGHT * 0.5)
	])
	marker.add_child(frame)

	var inner := Polygon2D.new()
	inner.color = Color(0.10, 0.13, 0.18, 0.94)
	inner.polygon = PackedVector2Array([
		Vector2(-DOOR_WIDTH * 0.32, -DOOR_HEIGHT * 0.42),
		Vector2(DOOR_WIDTH * 0.32, -DOOR_HEIGHT * 0.42),
		Vector2(DOOR_WIDTH * 0.32, DOOR_HEIGHT * 0.42),
		Vector2(-DOOR_WIDTH * 0.32, DOOR_HEIGHT * 0.42)
	])
	marker.add_child(inner)

	var glow := Line2D.new()
	glow.width = 4.0
	glow.default_color = DOOR_GLOW_COLOR
	glow.points = PackedVector2Array([
		Vector2(0.0, -DOOR_HEIGHT * 0.42),
		Vector2(0.0, DOOR_HEIGHT * 0.42)
	])
	marker.add_child(glow)

	var cap := Polygon2D.new()
	cap.color = DOOR_GLOW_COLOR.darkened(0.34)
	cap.position = Vector2(-6.0 if left_side else 6.0, -DOOR_HEIGHT * 0.5 - 10.0)
	cap.polygon = PackedVector2Array([
		Vector2(-12.0, -4.0),
		Vector2(12.0, -4.0),
		Vector2(20.0, 4.0),
		Vector2(-20.0, 4.0)
	])
	marker.add_child(cap)

func _add_function_room_marker(room_index: int) -> void:
	if map_root == null or room_index not in FUNCTION_ROOM_MARKERS or room_index >= map_walkable_rects.size():
		return
	var marker_data := FUNCTION_ROOM_MARKERS[room_index] as Dictionary
	var walk_rect := map_walkable_rects[room_index]
	var marker := Node2D.new()
	marker.name = "FunctionRoomMarker%02d" % [room_index + 1]
	marker.position = walk_rect.position + Vector2(walk_rect.size.x * 0.50, walk_rect.size.y * 0.40)
	marker.z_index = 10
	marker.set_meta("room_index", room_index)
	map_root.add_child(marker)

	var glow := Polygon2D.new()
	glow.color = (marker_data.get("color", Color.WHITE) as Color).darkened(0.55)
	glow.polygon = PackedVector2Array([
		Vector2(-92.0, -52.0),
		Vector2(92.0, -52.0),
		Vector2(108.0, 0.0),
		Vector2(92.0, 52.0),
		Vector2(-92.0, 52.0),
		Vector2(-108.0, 0.0)
	])
	marker.add_child(glow)

	var icon_texture := RuntimeTextureLoader.load_texture(String(marker_data.get("icon", "")))
	if icon_texture != null:
		var icon := Sprite2D.new()
		icon.name = "Icon"
		icon.texture = icon_texture
		icon.centered = true
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.scale = Vector2.ONE * 2.4
		icon.position = Vector2(0.0, -12.0)
		marker.add_child(icon)

	var title := Label.new()
	title.name = "Title"
	title.text = String(marker_data.get("title", "ROOM"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	title.size = Vector2(210.0, 32.0)
	title.position = Vector2(-105.0, 34.0)
	marker.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = String(marker_data.get("subtitle", ""))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94))
	subtitle.size = Vector2(210.0, 24.0)
	subtitle.position = Vector2(-105.0, 62.0)
	marker.add_child(subtitle)

func _add_runtime_room_props() -> void:
	if map_root == null:
		return
	map_cover_root = Node2D.new()
	map_cover_root.name = "RuntimeRoomProps"
	map_cover_root.z_index = 6
	map_root.add_child(map_cover_root)
	for room_index in range(map_room_rects.size()):
		if room_index in FUNCTION_ROOM_INDICES:
			continue
		_add_random_props_for_room(room_index)


func _add_random_props_for_room(room_index: int) -> void:
	var manifest := MapBrowserDemo.load_generated_prop_manifest()
	var candidates := MapBrowserDemo.get_generated_prop_candidates(manifest, room_index)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var count: int = min(reward_rng.randi_range(MapBrowserDemo.RANDOM_PROP_MIN_PER_ROOM, MapBrowserDemo.RANDOM_PROP_MAX_PER_ROOM), candidates.size())
	var placed_rects: Array[Rect2] = []
	var placed := 0
	for candidate in candidates:
		if placed >= count:
			break
		if _try_add_generated_room_prop(room_index, candidate, placed_rects):
			placed += 1


func _room_prop_candidates(room_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_candidate in MapBrowserDemo.PROP_CANDIDATES:
		var candidate := raw_candidate as Dictionary
		if int(candidate.get("room", -1)) != room_index:
			continue
		result.append(candidate.duplicate(true))
	return result


func _try_add_generated_room_prop(room_index: int, candidate: Dictionary, placed_rects: Array[Rect2]) -> bool:
	if map_cover_root == null:
		return false
	if room_index < 0 or room_index >= map_room_rects.size() or room_index >= map_walkable_rects.size():
		return false
	var texture := RuntimeTextureLoader.load_texture(String(candidate.get("path", "")))
	if texture == null:
		return false
	var room_rect := map_room_rects[room_index]
	var source_size := candidate.get("source_size", [texture.get_width(), texture.get_height()]) as Array
	var source_width := maxf(1.0, float(source_size[0]))
	var source_height := maxf(1.0, float(source_size[1]))
	var texture_to_room_scale := Vector2(room_rect.size.x / source_width, room_rect.size.y / source_height)
	texture_to_room_scale *= MapBrowserDemo.RANDOM_PROP_WORLD_SCALE * MapBrowserDemo.generated_prop_scale_multiplier(candidate)
	var prop_size := Vector2(float(texture.get_width()) * texture_to_room_scale.x, float(texture.get_height()) * texture_to_room_scale.y)
	if not MapBrowserDemo.is_generated_prop_size_usable(prop_size, room_rect.size):
		return false

	for attempt in range(MapBrowserDemo.RANDOM_PROP_PLACEMENT_ATTEMPTS):
		var position := MapBrowserDemo.random_cover_position_for_room(reward_rng, map_walkable_rects[room_index], prop_size)
		var prop_rect := Rect2(position - prop_size * 0.5, prop_size)
		if not MapBrowserDemo.is_cover_position_valid(prop_rect, map_walkable_rects[room_index], placed_rects, player_spawn_for_room(room_index), encounter_spawn_for_room(room_index)):
			continue
		placed_rects.append(prop_rect.grow(20.0))
		_add_generated_room_prop(room_index, candidate, texture, texture_to_room_scale, position)
		return true
	return false


func _add_generated_room_prop(room_index: int, candidate: Dictionary, texture: Texture2D, texture_to_room_scale: Vector2, world_position: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Room%02d%sProp" % [room_index + 1, String(candidate.get("name", "Generated")).replace(" ", "")]
	body.collision_layer = 1
	body.collision_mask = 2
	var walkable_prop := MapBrowserDemo.generated_prop_is_walkable(candidate)
	if walkable_prop:
		body.collision_layer = 0
		body.collision_mask = 0
	else:
		body.add_to_group("projectile_blocker")
	body.position = world_position
	body.set_meta("room_index", room_index)
	body.set_meta("prop_key", MapBrowserDemo.generated_prop_key(candidate))
	body.set_meta("prop_size", Vector2(float(texture.get_width()) * texture_to_room_scale.x, float(texture.get_height()) * texture_to_room_scale.y))
	body.set_meta("walkable_prop", walkable_prop)
	map_cover_root.add_child(body)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.scale = texture_to_room_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = true
	body.add_child(sprite)

	var polygons := MapBrowserDemo.build_generated_prop_collision_polygons(candidate, texture, texture_to_room_scale)
	for index in range(polygons.size()):
		var shape := CollisionPolygon2D.new()
		shape.name = "AlphaCollision%02d" % [index + 1]
		shape.polygon = polygons[index]
		body.add_child(shape)
		_add_prop_collision_polygon_debug(body, polygons[index])


func _add_room_prop(room_index: int, candidate: Dictionary) -> void:
	if map_cover_root == null:
		return
	if room_index < 0 or room_index >= map_room_rects.size() or room_index >= MapBrowserDemo.ROOM_PROP_LAYER_PATHS.size():
		return
	var texture := RuntimeTextureLoader.load_texture(String(MapBrowserDemo.ROOM_PROP_LAYER_PATHS[room_index]))
	if texture == null:
		push_warning("Missing prop layer texture: %s" % MapBrowserDemo.ROOM_PROP_LAYER_PATHS[room_index])
		return

	var room_rect := map_room_rects[room_index]
	var source_ratio := candidate.get("source", Rect2(0.0, 0.0, 1.0, 1.0)) as Rect2
	var source_rect := Rect2(
		Vector2(float(texture.get_width()) * source_ratio.position.x, float(texture.get_height()) * source_ratio.position.y),
		Vector2(float(texture.get_width()) * source_ratio.size.x, float(texture.get_height()) * source_ratio.size.y)
	)
	var texture_to_room_scale := Vector2(room_rect.size.x / float(texture.get_width()), room_rect.size.y / float(texture.get_height()))
	var prop_ratio := candidate.get("position", Vector2.ZERO) as Vector2
	var world_position := room_rect.position + Vector2(room_rect.size.x * prop_ratio.x, room_rect.size.y * prop_ratio.y)
	var collision_rect := MapBrowserDemo.calculate_prop_collision_rect(texture, source_rect, texture_to_room_scale)
	var collision_ratio := candidate.get("collision", Vector2.ZERO) as Vector2
	if collision_ratio != Vector2.ZERO:
		var desired_collision_size := Vector2(
			maxf(24.0, room_rect.size.x * collision_ratio.x),
			maxf(18.0, room_rect.size.y * collision_ratio.y)
		)
		collision_rect = Rect2(
			Vector2(
				collision_rect.get_center().x - desired_collision_size.x * 0.5,
				collision_rect.end.y - desired_collision_size.y
			),
			desired_collision_size
		)

	var body := StaticBody2D.new()
	body.name = "Room%02d%sProp" % [room_index + 1, String(candidate.get("name", "Cover")).replace(" ", "")]
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("projectile_blocker")
	body.position = world_position
	map_cover_root.add_child(body)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = source_rect
	sprite.scale = texture_to_room_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = true
	body.add_child(sprite)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.position = collision_rect.get_center()
	var rectangle := RectangleShape2D.new()
	rectangle.size = collision_rect.size
	shape.shape = rectangle
	body.add_child(shape)

	_add_prop_collision_debug(body, collision_rect)


func _add_prop_collision_polygon_debug(parent: Node, polygon: PackedVector2Array) -> void:
	if not PROP_COLLISION_DEBUG_VISIBLE:
		return
	var outline := Line2D.new()
	outline.name = "PropCollisionDebug"
	outline.width = 2.5
	outline.closed = true
	outline.default_color = Color(0.25, 0.9, 1.0, 0.72)
	outline.points = polygon
	parent.add_child(outline)


func _add_prop_collision_debug(parent: Node, rect: Rect2) -> void:
	if not PROP_COLLISION_DEBUG_VISIBLE:
		return
	var outline := Line2D.new()
	outline.name = "PropCollisionDebug"
	outline.width = 2.5
	outline.closed = true
	outline.default_color = Color(0.25, 0.9, 1.0, 0.72)
	outline.add_point(rect.position)
	outline.add_point(Vector2(rect.end.x, rect.position.y))
	outline.add_point(rect.end)
	outline.add_point(Vector2(rect.position.x, rect.end.y))
	parent.add_child(outline)


func _clamped_camera_position(room_index: int, target: Vector2) -> Vector2:
	var room_rect := map_room_rects[clampi(room_index, 0, map_room_rects.size() - 1)]
	var viewport_size := Vector2(get_viewport_rect().size)
	var visible_size := Vector2(viewport_size.x / MAP_CAMERA_ZOOM.x, viewport_size.y / MAP_CAMERA_ZOOM.y)
	var half_size := visible_size * 0.5
	var min_x := room_rect.position.x + half_size.x
	var max_x := room_rect.end.x - half_size.x
	var min_y := room_rect.position.y + half_size.y
	var max_y := room_rect.end.y - half_size.y
	var clamped := target
	clamped.x = room_rect.get_center().x if min_x > max_x else clampf(target.x, min_x, max_x)
	clamped.y = room_rect.get_center().y if min_y > max_y else clampf(target.y, min_y, max_y)
	return clamped
