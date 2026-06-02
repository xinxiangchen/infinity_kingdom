extends SceneTree

const MapBrowserDemo := preload("res://tools/map_browser_demo.gd")
const OUTPUT_PATH := "res://../map_prop_runtime_preview_sheet.png"
const SHEET_COLUMNS := 2
const CELL_PADDING := 18
const TITLE_HEIGHT := 28
const PROP_OUTLINE_COLOR := Color(0.0, 0.95, 1.0, 1.0)
const WALL_OUTLINE_COLOR := Color(1.0, 0.18, 0.12, 1.0)

func _init() -> void:
	var rooms := _build_room_previews()
	if rooms.is_empty():
		quit(1)
		return

	var max_width := 0
	var max_height := 0
	for room in rooms:
		var image: Image = room["image"]
		max_width = maxi(max_width, image.get_width())
		max_height = maxi(max_height, image.get_height())

	var rows := ceili(float(rooms.size()) / float(SHEET_COLUMNS))
	var sheet := Image.create(
		SHEET_COLUMNS * max_width + (SHEET_COLUMNS + 1) * CELL_PADDING,
		rows * (max_height + TITLE_HEIGHT) + (rows + 1) * CELL_PADDING,
		false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0.055, 0.055, 0.055, 1.0))

	for index in range(rooms.size()):
		var column := index % SHEET_COLUMNS
		var row := index / SHEET_COLUMNS
		var origin := Vector2i(
			CELL_PADDING + column * (max_width + CELL_PADDING),
			CELL_PADDING + row * (max_height + TITLE_HEIGHT + CELL_PADDING)
		)
		var image: Image = rooms[index]["image"]
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), origin + Vector2i(0, TITLE_HEIGHT))

	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := sheet.save_png(output)
	print("saved map prop preview: %s error=%s" % [output, error])
	quit(0 if error == OK else 1)

func _build_room_previews() -> Array:
	var result := []
	for room_index in range(MapBrowserDemo.ROOM_PATHS.size()):
		var room_path := ProjectSettings.globalize_path(String(MapBrowserDemo.ROOM_PATHS[room_index]))
		var room_image := Image.load_from_file(room_path)
		if room_image == null:
			push_error("Missing room image: %s" % room_path)
			continue
		room_image.convert(Image.FORMAT_RGBA8)
		_draw_room_walls(room_image, room_index)
		_draw_room_props(room_image, room_index)
		result.append({"image": room_image})
	return result

func _draw_room_walls(room_image: Image, room_index: int) -> void:
	var room_rect := Rect2(Vector2.ZERO, Vector2(float(room_image.get_width()), float(room_image.get_height())))
	for wall_rect in MapBrowserDemo.get_room_wall_rects(room_index, room_rect):
		_draw_rect_outline(room_image, Rect2i(
			Vector2i(roundi(wall_rect.position.x), roundi(wall_rect.position.y)),
			Vector2i(roundi(wall_rect.size.x), roundi(wall_rect.size.y))
		), WALL_OUTLINE_COLOR, 5)

func _draw_room_props(room_image: Image, room_index: int) -> void:
	if room_index >= MapBrowserDemo.ROOM_PROP_LAYER_PATHS.size():
		return
	var prop_path := ProjectSettings.globalize_path(String(MapBrowserDemo.ROOM_PROP_LAYER_PATHS[room_index]))
	var prop_layer := Image.load_from_file(prop_path)
	if prop_layer == null:
		push_error("Missing prop layer image: %s" % prop_path)
		return
	prop_layer.convert(Image.FORMAT_RGBA8)
	var prop_texture := load(String(MapBrowserDemo.ROOM_PROP_LAYER_PATHS[room_index])) as Texture2D

	var room_size := Vector2(float(room_image.get_width()), float(room_image.get_height()))
	var texture_to_room_scale := Vector2(room_size.x / float(prop_layer.get_width()), room_size.y / float(prop_layer.get_height()))
	for candidate in MapBrowserDemo.PROP_CANDIDATES:
		if int(candidate["room"]) != room_index:
			continue
		var source_ratio: Rect2 = candidate["source"]
		var source_rect := Rect2(
			Vector2(float(prop_layer.get_width()) * source_ratio.position.x, float(prop_layer.get_height()) * source_ratio.position.y),
			Vector2(float(prop_layer.get_width()) * source_ratio.size.x, float(prop_layer.get_height()) * source_ratio.size.y)
		)
		var source_rect_i := Rect2i(
			Vector2i(roundi(source_rect.position.x), roundi(source_rect.position.y)),
			Vector2i(roundi(source_rect.size.x), roundi(source_rect.size.y))
		)
		var prop_image := prop_layer.get_region(source_rect_i)
		var world_size := Vector2i(
			maxi(1, roundi(source_rect.size.x * texture_to_room_scale.x)),
			maxi(1, roundi(source_rect.size.y * texture_to_room_scale.y))
		)
		if world_size != prop_image.get_size():
			prop_image.resize(world_size.x, world_size.y, Image.INTERPOLATE_LANCZOS)
		var position_ratio: Vector2 = candidate["position"]
		var world_position := Vector2(room_size.x * position_ratio.x, room_size.y * position_ratio.y)
		var top_left := Vector2i(roundi(world_position.x - float(world_size.x) * 0.5), roundi(world_position.y - float(world_size.y) * 0.5))
		room_image.blend_rect(prop_image, Rect2i(Vector2i.ZERO, prop_image.get_size()), top_left)

		var local_collision_rect := MapBrowserDemo.calculate_prop_collision_rect(prop_texture, source_rect, texture_to_room_scale)
		var world_collision_rect := Rect2i(
			Vector2i(roundi(world_position.x + local_collision_rect.position.x), roundi(world_position.y + local_collision_rect.position.y)),
			Vector2i(roundi(local_collision_rect.size.x), roundi(local_collision_rect.size.y))
		)
		_draw_rect_outline(room_image, world_collision_rect, PROP_OUTLINE_COLOR, 4)

func _draw_rect_outline(image: Image, rect: Rect2i, color: Color, width: int) -> void:
	for offset in range(width):
		var left := rect.position.x + offset
		var right := rect.position.x + rect.size.x - 1 - offset
		var top := rect.position.y + offset
		var bottom := rect.position.y + rect.size.y - 1 - offset
		for x in range(left, right + 1):
			_set_pixel_safe(image, x, top, color)
			_set_pixel_safe(image, x, bottom, color)
		for y in range(top, bottom + 1):
			_set_pixel_safe(image, left, y, color)
			_set_pixel_safe(image, right, y, color)

func _set_pixel_safe(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)
