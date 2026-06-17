extends SceneTree

const MapRuntime := preload("res://systems/map/map_runtime.gd")
const MapBrowserDemo := preload("res://tools/map_browser_demo.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_root := Node2D.new()
	root.add_child(world_root)

	var spawn_marker := Marker2D.new()
	var encounter_marker := Marker2D.new()
	world_root.add_child(spawn_marker)
	world_root.add_child(encounter_marker)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260608

	var map_runtime := MapRuntime.new()
	root.add_child(map_runtime)
	map_runtime.setup(world_root, spawn_marker, encounter_marker, rng)
	map_runtime.build()
	await process_frame

	var prop_root := world_root.find_child("RuntimeRoomProps", true, false)
	if prop_root == null:
		push_error("Runtime map did not create random prop root")
		quit(1)
		return

	var prop_bodies := prop_root.find_children("*Prop", "StaticBody2D", true, false)
	if prop_bodies.size() < 8:
		push_error("Runtime map created too few random props: %d" % prop_bodies.size())
		quit(1)
		return

	var collidable_prop_count := 0
	var room_rects: Array = map_runtime.get("map_room_rects")
	var walkable_rects: Array = map_runtime.get("map_walkable_rects")
	var props_by_room := {}
	for body in prop_bodies:
		var static_body := body as StaticBody2D
		var walkable_prop := bool(static_body.get_meta("walkable_prop", false))
		var collision_count := body.find_children("AlphaCollision*", "CollisionPolygon2D", true, false).size()
		if walkable_prop:
			if static_body.is_in_group("projectile_blocker") or collision_count != 0:
				push_error("Walkable ground prop unexpectedly blocks movement: %s" % body.name)
				quit(1)
				return
		else:
			if not static_body.is_in_group("projectile_blocker") or collision_count == 0:
				push_error("Random cover prop is missing collision: %s" % body.name)
				quit(1)
				return
			collidable_prop_count += 1
		var sprite := body.get_node_or_null("Sprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			push_error("Random prop is missing sprite texture: %s" % body.name)
			quit(1)
			return
		var room_index := int((body as StaticBody2D).get_meta("room_index", -1))
		if room_index < 0:
			push_error("Random prop is missing room metadata: %s" % body.name)
			quit(1)
			return
		props_by_room[room_index] = int(props_by_room.get(room_index, 0)) + 1
		var prop_size := (body as StaticBody2D).get_meta("prop_size", Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.scale) as Vector2
		if not MapBrowserDemo.is_generated_prop_size_usable(prop_size, (room_rects[room_index] as Rect2).size):
			push_error("Random prop size filter failed for %s with size %s" % [body.name, prop_size])
			quit(1)
			return
		var prop_rect := Rect2((body as StaticBody2D).global_position - prop_size * 0.5, prop_size)
		var walk_rect := walkable_rects[room_index] as Rect2
		var player_spawn := map_runtime.player_spawn_for_room(room_index)
		var encounter_spawn := map_runtime.encounter_spawn_for_room(room_index)
		if not MapBrowserDemo.is_cover_position_valid(prop_rect, walk_rect, [], player_spawn, encounter_spawn):
			push_error("Random prop blocks reserved walking lanes: %s" % body.name)
			quit(1)
			return

	if collidable_prop_count == 0:
		push_error("Runtime map did not create any collidable cover props")
		quit(1)
		return

	var manifest := MapBrowserDemo.load_generated_prop_manifest()
	var room_four_candidates := MapBrowserDemo.get_generated_prop_candidates(manifest, 3)
	var hut_candidate := _find_candidate(room_four_candidates, "Room04Prop01")
	var ground_seal_candidate := _find_candidate(room_four_candidates, "Room04Prop35")
	if hut_candidate.is_empty() or ground_seal_candidate.is_empty():
		push_error("Room 4 prop manifest is missing hut or ground seal assets")
		quit(1)
		return
	if not is_equal_approx(MapBrowserDemo.generated_prop_scale_multiplier(hut_candidate), 1.20):
		push_error("Room 4 hut scale multiplier is incorrect")
		quit(1)
		return
	for prop_key in ["0:Room01Prop01", "0:Room01Prop03", "0:Room01Prop07", "1:Room02Prop13", "1:Room02Prop15"]:
		if not is_equal_approx(float(MapBrowserDemo.GENERATED_PROP_SCALE_MULTIPLIERS.get(prop_key, 1.0)), 0.50):
			push_error("Oversized prop was not reduced by 50%%: %s" % prop_key)
			quit(1)
			return
	var hut_texture := load(String(hut_candidate.get("path", ""))) as Texture2D
	if hut_texture == null or MapBrowserDemo.build_generated_prop_collision_polygons(hut_candidate, hut_texture, Vector2.ONE).size() != 1:
		push_error("Room 4 hut did not create its reduced footprint collision")
		quit(1)
		return
	var ground_seal_texture := load(String(ground_seal_candidate.get("path", ""))) as Texture2D
	if not MapBrowserDemo.generated_prop_is_walkable(ground_seal_candidate) or not MapBrowserDemo.build_generated_prop_collision_polygons(ground_seal_candidate, ground_seal_texture, Vector2.ONE).is_empty():
		push_error("Room 4 ground seal should be fully walkable")
		quit(1)
		return

	var expected_bottom_ratios := [0.90, 0.76, 0.76, 0.76]
	for room_index in range(expected_bottom_ratios.size()):
		var room_rect := room_rects[room_index] as Rect2
		var expected_top := room_rect.position.y + room_rect.size.y * float(expected_bottom_ratios[room_index])
		var found_bottom_blocker := false
		for wall_rect in MapBrowserDemo.get_room_wall_rects(room_index, room_rect):
			if wall_rect.position.y <= expected_top + 0.5 and wall_rect.end.y >= room_rect.end.y - 0.5 and wall_rect.size.x >= room_rect.size.x * 0.70:
				found_bottom_blocker = true
				break
		if not found_bottom_blocker:
			push_error("Room %d bottom buildings are missing roof collision" % [room_index + 1])
			quit(1)
			return

	var plaza_statue := world_root.find_child("Room04Circle01", true, false) as StaticBody2D
	if plaza_statue == null or not plaza_statue.is_in_group("projectile_blocker"):
		push_error("Central plaza statue collision is missing")
		quit(1)
		return
	var statue_shape := plaza_statue.get_child(0) as CollisionShape2D if plaza_statue.get_child_count() > 0 else null
	if statue_shape == null or not (statue_shape.shape is CircleShape2D):
		push_error("Central plaza statue does not use a circular collision")
		quit(1)
		return

	var function_rect_a := room_rects[4] as Rect2
	var function_rect_b := room_rects[5] as Rect2
	var function_rect_c := room_rects[6] as Rect2
	if function_rect_a.position != function_rect_b.position or function_rect_b.position != function_rect_c.position or function_rect_a.size.distance_to(function_rect_b.size) > 2.0 or function_rect_b.size.distance_to(function_rect_c.size) > 2.0:
		push_error("The three function rooms do not share one branch slot")
		quit(1)
		return
	var branch_source := room_rects[3] as Rect2
	var chosen_room := map_runtime.function_room_choice_for_position(Vector2(branch_source.end.x, (walkable_rects[3] as Rect2).get_center().y))
	if chosen_room != 5 or not map_runtime.select_function_room(chosen_room):
		push_error("Middle function-room door did not select the armory")
		quit(1)
		return
	if world_root.find_child("MapRoom06", true, false) == null or world_root.find_child("MapRoom05", true, false) != null or world_root.find_child("MapRoom07", true, false) != null:
		push_error("Function-room branch loaded more than the chosen room")
		quit(1)
		return

	for room_index in props_by_room.keys():
		var count := int(props_by_room[room_index])
		if count > MapBrowserDemo.RANDOM_PROP_MAX_PER_ROOM:
			push_error("Room %d has too many random props: %d" % [int(room_index) + 1, count])
			quit(1)
			return

	quit(0)


func _find_candidate(candidates: Array[Dictionary], candidate_name: String) -> Dictionary:
	for candidate in candidates:
		if String(candidate.get("name", "")) == candidate_name:
			return candidate
	return {}
