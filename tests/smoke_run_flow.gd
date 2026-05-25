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
	var run_director := root.get_node_or_null("/root/RunDirector")
	if run_director == null:
		push_error("RunDirector autoload missing")
		quit(1)
		return

	var town_encounter_scene := load("res://actors/encounters/town_mob_encounter.tscn") as PackedScene
	if town_encounter_scene == null:
		push_error("Town encounter scene did not load")
		quit(1)
		return
	var encounter_player := Node2D.new()
	encounter_player.name = "EncounterSmokePlayer"
	encounter_player.add_to_group("player")
	root.add_child(encounter_player)
	var preview_encounter := town_encounter_scene.instantiate()
	root.add_child(preview_encounter)
	var preview_rng := preview_encounter.get("rng") as RandomNumberGenerator
	if preview_rng == null:
		push_error("Town encounter RNG did not initialize")
		quit(1)
		return
	preview_rng.seed = 11
	if not preview_encounter.has_method("bind_player"):
		push_error("Town encounter is missing bind_player")
		quit(1)
		return
	preview_encounter.call("bind_player", encounter_player)
	await process_frame
	var preview_waves: Variant = preview_encounter.get("active_waves")
	if not (preview_waves is Array) or (preview_waves as Array).size() != 4:
		push_error("Town encounter did not build three waves plus a final wave")
		quit(1)
		return
	var modifier_title := String(preview_encounter.call("get_modifier_title")) if preview_encounter.has_method("get_modifier_title") else ""
	var modifier_hint := String(preview_encounter.call("get_modifier_hint")) if preview_encounter.has_method("get_modifier_hint") else ""
	if modifier_title.is_empty() or modifier_hint.is_empty():
		push_error("Town encounter modifier did not initialize")
		quit(1)
		return
	if String(preview_encounter.call("get_status_text")).find("Modifier:") == -1:
		push_error("Town encounter status text did not expose the encounter modifier")
		quit(1)
		return
	preview_encounter.queue_free()
	encounter_player.queue_free()
	await process_frame

	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	run_director.reset_run()
	var event_sequence: Array[String] = []
	for _index in range(4):
		event_sequence.append(run_director.next_event_kind())
	if event_sequence.size() != 4 or event_sequence[0] != "shop":
		push_error("RunDirector did not build a four-step event deck starting with shop")
		quit(1)
		return
	for event_index in range(1, event_sequence.size()):
		if event_sequence[event_index] == "shop":
			push_error("RunDirector repeated shop before the deck was exhausted")
			quit(1)
			return
	run_director.reset_run()
	var route_preview: String = run_director.describe_event_route(4)
	if route_preview.find("Black Market") == -1 or route_preview.find("Victory") == -1:
		push_error("RunDirector route preview did not describe the current event route")
		quit(1)
		return
	run_director.set_pending_encounter_prep({"title": "Scout Smoke"})
	var pending_prep := run_director.get_state().get("pending_encounter_prep", {}) as Dictionary
	if String(pending_prep.get("title", "")) != "Scout Smoke":
		push_error("RunDirector state did not expose pending encounter prep")
		quit(1)
		return
	pending_prep = run_director.consume_pending_encounter_prep()
	if String(pending_prep.get("title", "")) != "Scout Smoke":
		push_error("RunDirector did not return the queued encounter prep")
		quit(1)
		return

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
	var hud_run_state := world.character_hud.get("run_state_label") as Label
	if hud_run_state == null or hud_run_state.text.find("Next") == -1:
		push_error("Character HUD run state did not populate")
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
