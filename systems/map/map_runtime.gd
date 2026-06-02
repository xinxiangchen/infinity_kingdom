extends Node2D

const MapBrowserDemo := preload("res://tools/map_browser_demo.gd")

const MAP_CAMERA_ZOOM := Vector2(1.7, 1.7)
const COVER_COLLISION_DEBUG_VISIBLE := true
const COVER_PROP_MIN_PER_ROOM := 2
const COVER_PROP_MAX_PER_ROOM := 4

var world_root: Node2D = null
var spawn_marker: Marker2D = null
var encounter_marker: Marker2D = null
var reward_rng: RandomNumberGenerator = null
var map_root: Node2D = null
var map_camera: Camera2D = null
var map_prop_root: Node2D = null
var map_room_rects: Array[Rect2] = []
var map_walkable_rects: Array[Rect2] = []


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


func activate_room(room_index: int, player_character: Node) -> void:
	if map_walkable_rects.is_empty():
		return
	var clamped_index := clampi(room_index, 0, map_walkable_rects.size() - 1)
	if spawn_marker != null:
		spawn_marker.position = player_spawn_for_room(clamped_index)
	if encounter_marker != null:
		encounter_marker.position = encounter_spawn_for_room(clamped_index)
	if player_character is Node2D and spawn_marker != null and is_instance_valid(player_character):
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


func player_spawn_for_room(room_index: int) -> Vector2:
	if map_walkable_rects.is_empty():
		return spawn_marker.position if spawn_marker != null else Vector2.ZERO
	var walk_rect := map_walkable_rects[clampi(room_index, 0, map_walkable_rects.size() - 1)]
	return walk_rect.position + Vector2(walk_rect.size.x * 0.14, walk_rect.size.y * 0.54)


func encounter_spawn_for_room(room_index: int) -> Vector2:
	if map_walkable_rects.is_empty():
		return encounter_marker.position if encounter_marker != null else Vector2.ZERO
	var walk_rect := map_walkable_rects[clampi(room_index, 0, map_walkable_rects.size() - 1)]
	var y_ratio: float = 0.76 if room_index <= 4 else 0.58
	return walk_rect.position + Vector2(walk_rect.size.x * 0.56, walk_rect.size.y * y_ratio)


func _build_runtime_map_rooms() -> void:
	map_room_rects.clear()
	map_walkable_rects.clear()
	var x_cursor := 0.0
	for index in range(MapBrowserDemo.ROOM_PATHS.size()):
		var texture := load(String(MapBrowserDemo.ROOM_PATHS[index])) as Texture2D
		if texture == null:
			push_warning("Missing map texture: %s" % MapBrowserDemo.ROOM_PATHS[index])
			continue
		var sprite := Sprite2D.new()
		sprite.name = "MapRoom%02d" % [index + 1]
		sprite.texture = texture
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position = Vector2(x_cursor, 0.0)
		map_root.add_child(sprite)
		var room_rect := Rect2(sprite.position, Vector2(float(texture.get_width()), float(texture.get_height())))
		map_room_rects.append(room_rect)
		map_walkable_rects.append(_map_walkable_rect(index, room_rect))
		_add_runtime_room_walls(index, room_rect)
		x_cursor += room_rect.size.x
	_add_runtime_cover_props()


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


func _add_runtime_cover_props() -> void:
	if map_root == null:
		return
	map_prop_root = Node2D.new()
	map_prop_root.name = "RuntimeCoverProps"
	map_prop_root.z_index = 5
	map_root.add_child(map_prop_root)
	for room_index in range(map_room_rects.size()):
		var candidates := _get_cover_candidates_for_room(room_index)
		if candidates.is_empty():
			continue
		candidates.shuffle()
		var count: int = min(reward_rng.randi_range(COVER_PROP_MIN_PER_ROOM, COVER_PROP_MAX_PER_ROOM), candidates.size())
		for index in range(count):
			_add_runtime_cover_prop(candidates[index])


func _get_cover_candidates_for_room(room_index: int) -> Array:
	var result := []
	for candidate in MapBrowserDemo.PROP_CANDIDATES:
		if int(candidate["room"]) == room_index:
			result.append(candidate)
	return result


func _add_runtime_cover_prop(candidate: Dictionary) -> void:
	var room_index := int(candidate["room"])
	if map_prop_root == null or room_index < 0 or room_index >= map_room_rects.size() or room_index >= MapBrowserDemo.ROOM_PROP_LAYER_PATHS.size():
		return
	var texture := load(String(MapBrowserDemo.ROOM_PROP_LAYER_PATHS[room_index])) as Texture2D
	if texture == null:
		push_warning("Missing cover prop layer: %s" % MapBrowserDemo.ROOM_PROP_LAYER_PATHS[room_index])
		return
	var room_rect := map_room_rects[room_index]
	var source_ratio: Rect2 = candidate["source"]
	var source_rect := Rect2(
		Vector2(float(texture.get_width()) * source_ratio.position.x, float(texture.get_height()) * source_ratio.position.y),
		Vector2(float(texture.get_width()) * source_ratio.size.x, float(texture.get_height()) * source_ratio.size.y)
	)
	var texture_to_room_scale := Vector2(room_rect.size.x / float(texture.get_width()), room_rect.size.y / float(texture.get_height()))
	var position_ratio: Vector2 = candidate["position"]
	var collision_rect := MapBrowserDemo.calculate_prop_collision_rect(texture, source_rect, texture_to_room_scale)
	var body := StaticBody2D.new()
	body.name = "%sCover" % String(candidate["name"])
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("projectile_blocker")
	map_prop_root.add_child(body)
	body.global_position = room_rect.position + Vector2(room_rect.size.x * position_ratio.x, room_rect.size.y * position_ratio.y)
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
	shape.position = collision_rect.get_center()
	var rectangle := RectangleShape2D.new()
	rectangle.size = collision_rect.size
	shape.shape = rectangle
	body.add_child(shape)
	_add_cover_collision_debug(body, collision_rect)


func _add_cover_collision_debug(parent: Node, rect: Rect2) -> void:
	if not COVER_COLLISION_DEBUG_VISIBLE:
		return
	var outline := Line2D.new()
	outline.name = "CoverCollisionDebug"
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
