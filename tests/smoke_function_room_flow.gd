extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_scene := load("res://world.tscn") as PackedScene
	if world_scene == null:
		push_error("world.tscn did not load")
		quit(1)
		return
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	world._on_character_selected(&"knight")
	await process_frame
	if world.player_character == null:
		push_error("Player did not spawn")
		quit(1)
		return

	if world.current_encounter != null and is_instance_valid(world.current_encounter):
		world.current_encounter.queue_free()
		await process_frame

	world.encounter_index = 3
	world._activate_map_room(3, false)
	world.player_character.global_position = world._room_exit_target(3)
	var cleared_room_stub := Node.new()
	world.add_child(cleared_room_stub)
	world.current_encounter = cleared_room_stub
	world._on_encounter_defeated()
	await create_timer(1.0).timeout
	await process_frame

	if world.stage_reward_panel == null or not world.stage_reward_panel.visible:
		push_error("Stage reward panel did not open before function rooms")
		quit(1)
		return
	var reward_choices: Array = world.stage_reward_panel.get("choices")
	if reward_choices.is_empty():
		push_error("Stage reward panel had no choices")
		quit(1)
		return
	world._on_stage_reward_chosen(reward_choices[0])
	await process_frame

	if not bool(world.get("function_room_choice_pending")):
		push_error("Function room choice was not pending after stage reward")
		quit(1)
		return
	world.map_runtime.select_function_room(4)
	world.set("function_room_choice_pending", false)
	world.set("selected_function_room_index", 4)
	world._enter_encounter_index(4)
	await create_timer(5.2).timeout
	await process_frame

	if int(world.get("encounter_index")) != 4:
		push_error("Did not enter the selected function room encounter")
		quit(1)
		return
	if world.run_event_panel == null or not world.run_event_panel.visible:
		push_error("Function room event panel did not open")
		quit(1)
		return
	world.run_event_panel.close()
	world.set("pending_function_room_exit_next_encounter_index", -1)
	world._on_run_event_choice_made("skip")
	await create_timer(5.2).timeout
	await process_frame

	if int(world.get("encounter_index")) != 7:
		push_error("Function room did not advance to encounter 7, got %d" % int(world.get("encounter_index")))
		quit(1)
		return
	if int(world.get("active_map_room_index")) != 7:
		push_error("Function room did not activate map room 7, got %d" % int(world.get("active_map_room_index")))
		quit(1)
		return

	world.queue_free()
	await process_frame
	quit(0)
