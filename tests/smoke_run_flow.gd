extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui_settings := root.get_node_or_null("/root/UISettings")
	if ui_settings != null and ui_settings.has_method("set_locale"):
		ui_settings.call("set_locale", "en", false)
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
	if not (preview_waves is Array) or (preview_waves as Array).size() != 1:
		push_error("Town encounter did not build exactly one enemy wave")
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

	var empty_encounter_scene := load("res://actors/encounters/empty_encounter.tscn") as PackedScene
	if empty_encounter_scene == null:
		push_error("Empty encounter scene did not load")
		quit(1)
		return
	var empty_encounter := empty_encounter_scene.instantiate()
	var empty_state := {"cleared": false}
	empty_encounter.defeated.connect(func() -> void:
		empty_state["cleared"] = true
	)
	root.add_child(empty_encounter)
	await create_timer(0.1).timeout
	if not bool(empty_state["cleared"]):
		push_error("Empty encounter did not auto-clear")
		quit(1)
		return
	empty_encounter.queue_free()
	await process_frame

	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	run_director.reset_run()
	var event_sequence: Array[String] = []
	for _index in range(3):
		event_sequence.append(run_director.next_event_kind())
	if event_sequence.size() != 3:
		push_error("RunDirector did not build a three-step regular event deck")
		quit(1)
		return
	for event_kind in event_sequence:
		if not ["bounty", "pact", "attunement", "scout"].has(event_kind):
			push_error("RunDirector emitted an unexpected early event kind")
			quit(1)
			return
	run_director.reset_run()
	for encounter_count in range(5):
		run_director.reward_encounter(encounter_count)
	if run_director.peek_next_event_kind() != "services":
		push_error("Town services did not appear before the palace route")
		quit(1)
		return
	if run_director.next_event_kind() != "services":
		push_error("Town services were not consumed as the next event")
		quit(1)
		return
	if run_director.peek_next_event_kind() == "services":
		push_error("Town services incorrectly repeated after being consumed")
		quit(1)
		return
	run_director.reset_run()
	var route_preview: String = run_director.describe_event_route(4)
	if route_preview.find("Victory") == -1:
		push_error("RunDirector route preview did not describe the current event route")
		quit(1)
		return
	run_director.record_event_choice("bounty", "bounty_cache", "Immediate coin claimed.", "Open Purse")
	if run_director.describe_event_history(1).find("Bounty Board") == -1:
		push_error("RunDirector event history did not record the last event choice")
		quit(1)
		return
	run_director.reset_run()
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
	var xp_result: Dictionary = run_director.grant_experience(80)
	if int(xp_result.get("current_level", 1)) < 2 or int(run_director.get_state().get("hero_xp_to_next", 0)) <= 0:
		push_error("RunDirector experience did not level the hero up")
		quit(1)
		return
	run_director.record_kill(3)
	var progression_state: Dictionary = run_director.get_state()
	if int(progression_state.get("total_kills", 0)) != 3:
		push_error("RunDirector kill counter did not update")
		quit(1)
		return
	run_director.reset_run()
	progression_state = run_director.get_state()
	if int(progression_state.get("hero_level", 0)) != 1 or int(progression_state.get("hero_xp", -1)) != 0 or int(progression_state.get("total_kills", -1)) != 0:
		push_error("RunDirector progression did not reset cleanly")
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
	await process_frame
	var encounter_health_bars: Array = world.current_encounter.find_children("WorldHealthBar", "", true, false)
	if encounter_health_bars.is_empty():
		push_error("Encounter actors did not receive world health bars")
		quit(1)
		return
	var hud_run_state := world.character_hud.get("run_state_label") as Label
	if hud_run_state == null or hud_run_state.text.find("Level") == -1:
		push_error("Character HUD run state did not include progression details")
		quit(1)
		return
	var threat_value := world.battle_status.get("threat_value_label") as Label
	if threat_value == null or threat_value.text.is_empty():
		push_error("Battle status threat label did not populate after starting an encounter")
		quit(1)
		return

	if world.current_encounter != null and is_instance_valid(world.current_encounter):
		world.current_encounter.queue_free()
	var first_room_stub := Node.new()
	world.add_child(first_room_stub)
	world.current_encounter = first_room_stub
	world.player_character.global_position = world._room_exit_target(0)
	world._on_encounter_defeated()
	await create_timer(0.9).timeout
	await process_frame
	if world.run_event_panel == null or not world.run_event_panel.visible:
		push_error("Run event panel did not open after the first map encounter")
		quit(1)
		return
	world.run_event_panel.close()
	world._on_run_event_choice_made("skip")
	await create_timer(1.4).timeout
	await process_frame
	if world.encounter_index != 1:
		push_error("World did not advance to the second map encounter")
		quit(1)
		return
	if world.current_encounter == null or not is_instance_valid(world.current_encounter):
		push_error("Second map encounter did not begin after first map reward")
		quit(1)
		return

	# The final chamber is an extra encounter slot backed by FINAL_BOSS_SCENES.
	world.encounter_index = world._encounter_count() - 1
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
