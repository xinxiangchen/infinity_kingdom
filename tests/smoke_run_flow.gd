extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_scene := load("res://world.tscn") as PackedScene
	if world_scene == null:
		push_error("world.tscn did not load")
		quit(1)
		return

	var accessory_manager := root.get_node_or_null("/root/AccessoryManager")
	if accessory_manager == null:
		push_error("AccessoryManager autoload missing")
		quit(1)
		return

	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	world._on_character_selected(&"knight")
	await process_frame
	if world.player_character == null:
		push_error("Player was not spawned for run flow test")
		quit(1)
		return

	var choices: Array = accessory_manager.current_choices
	if choices.is_empty():
		push_error("No accessory choices were generated")
		quit(1)
		return

	if world.accessory_choice != null and world.accessory_choice.visible:
		world.accessory_choice.close()
	var first_choice: Dictionary = choices[0]
	accessory_manager.equip(String(first_choice.get("id", "")), world.player_character)
	world._on_accessory_choice_made(String(first_choice.get("id", "")), false)
	await process_frame

	world.encounter_index = world.ENCOUNTER_SCENES.size() - 1
	var stub_encounter := Node.new()
	world.add_child(stub_encounter)
	world.current_encounter = stub_encounter
	world._on_encounter_defeated()
	await create_timer(1.3).timeout
	await process_frame

	if world.run_event_panel != null and world.run_event_panel.visible:
		push_error("Run event panel opened after the final encounter")
		quit(1)
		return
	if world.result_screen == null or not world.result_screen.visible:
		push_error("Victory result screen did not appear after the final encounter")
		quit(1)
		return
	if world.character_select == null or not world.character_select.visible:
		push_error("Character select did not return after victory")
		quit(1)
		return

	world.queue_free()
	await process_frame
	quit(0)
