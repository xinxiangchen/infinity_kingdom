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
	var objective_value := world.battle_status.get("objective_value_label") as Label
	if objective_value == null or objective_value.text.find("relic") == -1:
		push_error("Battle status did not switch to relic objective after character select")
		quit(1)
		return
	if world.accessory_choice == null or not world.accessory_choice.visible:
		push_error("Accessory choice did not open after character select")
		quit(1)
		return
	var accessory_preview := world.accessory_choice.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewPanel/MarginContainer/VBoxContainer/PreviewDetail") as Label
	if accessory_preview == null or accessory_preview.text.is_empty():
		push_error("Accessory choice preview did not initialize")
		quit(1)
		return

	world.active_run_event_kind = "shop"
	world.run_event_panel.open("shop", 0)
	await process_frame
	world._on_run_event_choice_made("shop_attack")
	await process_frame
	if not world.run_event_panel.visible:
		push_error("Unaffordable shop choice did not keep the event panel open")
		quit(1)
		return
	if world.encounter_index != -1:
		push_error("Unaffordable shop choice incorrectly advanced the encounter index")
		quit(1)
		return
	world.run_event_panel.close()

	var choices: Array = accessory_manager.current_choices
	if choices.is_empty():
		push_error("No accessory choices were generated")
		quit(1)
		return

	var keep_event := InputEventKey.new()
	keep_event.keycode = KEY_K
	keep_event.pressed = true
	world.accessory_choice._unhandled_input(keep_event)
	await process_frame
	if world.accessory_choice.visible:
		push_error("Accessory choice did not close after keep shortcut")
		quit(1)
		return
	if world.current_encounter == null:
		push_error("Encounter did not begin after keep shortcut")
		quit(1)
		return
	var threat_value := world.battle_status.get("threat_value_label") as Label
	if threat_value == null or threat_value.text.is_empty():
		push_error("Battle status threat label did not populate after starting an encounter")
		quit(1)
		return

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
