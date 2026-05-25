extends SceneTree

func _set_layout_override(target: Object, viewport_size: Vector2i) -> void:
	if target == null:
		return
	target.set("layout_size_override", Vector2(viewport_size))
	if target.has_method("_queue_layout_refresh"):
		target.call("_queue_layout_refresh")

func _assert_control_fits(control: Control, viewport_size: Vector2i, label_text: String) -> bool:
	if control == null:
		push_error("%s missing" % label_text)
		return false
	var effective_size := control.custom_minimum_size
	if effective_size.x <= 0.0 or effective_size.y <= 0.0:
		effective_size = control.size
	if effective_size.x > float(viewport_size.x) + 0.5 or effective_size.y > float(viewport_size.y) + 0.5:
		push_error("%s exceeded viewport %s: %s" % [label_text, str(viewport_size), str(effective_size)])
		return false
	return true

func _assert_virtual_rect_fits(control: Control, viewport_size: Vector2i, label_text: String) -> bool:
	if control == null:
		push_error("%s missing" % label_text)
		return false
	var left := float(viewport_size.x) * control.anchor_left + control.offset_left
	var top := float(viewport_size.y) * control.anchor_top + control.offset_top
	var right := float(viewport_size.x) * control.anchor_right + control.offset_right
	var bottom := float(viewport_size.y) * control.anchor_bottom + control.offset_bottom
	if left < -0.5 or top < -0.5:
		push_error("%s started outside viewport %s: (%s, %s, %s, %s)" % [label_text, str(viewport_size), str(left), str(top), str(right), str(bottom)])
		return false
	if right > float(viewport_size.x) + 0.5 or bottom > float(viewport_size.y) + 0.5:
		push_error("%s exceeded viewport %s: (%s, %s, %s, %s)" % [label_text, str(viewport_size), str(left), str(top), str(right), str(bottom)])
		return false
	return true

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

	if world.character_select == null or not world.character_select.visible:
		push_error("Character select did not initialize")
		quit(1)
		return
	if world.battle_status == null or not world.battle_status.has_method("set_context"):
		push_error("Battle status did not initialize its context API")
		quit(1)
		return
	var objective_value := world.battle_status.get("objective_value_label") as Label
	var threat_value := world.battle_status.get("threat_value_label") as Label
	var status_run_label := world.battle_status.get("run_label") as Label
	if objective_value == null or objective_value.text.find("champion") == -1:
		push_error("Battle status objective did not describe champion selection")
		quit(1)
		return
	if threat_value == null or threat_value.text.is_empty():
		push_error("Battle status threat label is empty")
		quit(1)
		return
	if status_run_label == null or status_run_label.text.is_empty():
		push_error("Battle status run summary is empty")
		quit(1)
		return
	if not world.character_select.has_signal("quit_requested"):
		push_error("Character select is missing quit signal")
		quit(1)
		return
	if not world.character_select.has_method("_set_selected_hero"):
		push_error("Character select is missing hero detail selection")
		quit(1)
		return
	world.character_select._set_selected_hero(1)
	await process_frame
	var selected_title := world.character_select.get("hero_detail_title") as Label
	if selected_title == null or selected_title.text.find("Ranger") == -1:
		push_error("Character select detail panel did not update to Ranger")
		quit(1)
		return

	if world.pause_menu == null or not world.pause_menu.has_method("open"):
		push_error("Pause menu missing")
		quit(1)
		return
	world.pause_menu.open()
	await process_frame
	if not world.pause_menu.visible:
		push_error("Pause menu did not open")
		quit(1)
		return
	if not world.pause_menu.has_signal("quit_requested"):
		push_error("Pause menu is missing quit signal")
		quit(1)
		return
	world.pause_menu.close()

	world.pause_menu.open()
	await process_frame
	if world.has_method("_on_pause_audio_requested"):
		world._on_pause_audio_requested()
		await process_frame
		if not world.audio_settings_panel.visible or world.pause_menu.visible:
			push_error("Pause audio flow did not switch to audio panel")
			quit(1)
			return
		world.audio_settings_panel.hide_panel()
		await process_frame
		if not world.pause_menu.visible:
			push_error("Pause menu did not return after closing audio panel")
			quit(1)
			return
		world.pause_menu.close()

	world.pause_menu.open()
	await process_frame
	if world.has_method("_on_pause_settings_requested"):
		world._on_pause_settings_requested()
		await process_frame
		if not world.settings_panel.visible or world.pause_menu.visible:
			push_error("Pause settings flow did not switch to settings panel")
			quit(1)
			return
		var settings_hint := world.settings_panel.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Hint") as Label
		if settings_hint == null or settings_hint.text.find("Esc") == -1 or settings_hint.text.find("F") == -1:
			push_error("Settings panel shortcut hint did not initialize")
			quit(1)
			return
		var close_settings_event := InputEventKey.new()
		close_settings_event.keycode = KEY_ESCAPE
		close_settings_event.pressed = true
		world.settings_panel._unhandled_input(close_settings_event)
		await process_frame
		await process_frame
		if not world.pause_menu.visible:
			push_error("Pause menu did not return after keyboard-closing settings panel")
			quit(1)
			return
		world.pause_menu.close()

	if world.audio_settings_panel == null or not world.audio_settings_panel.has_method("show_panel"):
		push_error("Audio settings panel missing")
		quit(1)
		return
	world.audio_settings_panel.show_panel()
	await process_frame
	if not world.audio_settings_panel.visible:
		push_error("Audio settings panel did not open")
		quit(1)
		return
	world.audio_settings_panel.hide_panel()

	if world.settings_panel == null or not world.settings_panel.has_method("open"):
		push_error("Settings panel missing")
		quit(1)
		return
	world.settings_panel.open()
	await process_frame
	if not world.settings_panel.visible:
		push_error("Settings panel did not open")
		quit(1)
		return
	world.settings_panel.close()

	if world.run_event_panel == null or not world.run_event_panel.has_method("open"):
		push_error("Run event panel missing")
		quit(1)
		return
	world.run_event_panel.open("shop", 100)
	await process_frame
	await process_frame
	if not world.run_event_panel.visible:
		push_error("Run event panel did not open")
		quit(1)
		return
	var build_summary := world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContextPanel/MarginContainer/VBoxContainer/BuildSummary") as Label
	var rule_summary_label := world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContextPanel/MarginContainer/VBoxContainer/RuleSummary") as Label
	var detail_label := world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Detail") as Label
	if build_summary == null or build_summary.text.is_empty():
		push_error("Run event panel build summary is empty")
		quit(1)
		return
	if detail_label == null or detail_label.text.is_empty():
		push_error("Run event panel detail preview is empty")
		quit(1)
		return
	if detail_label.text.find("Fit") == -1:
		push_error("Run event panel detail preview is missing build fit guidance")
		quit(1)
		return
	if rule_summary_label == null or rule_summary_label.text.find("Route") == -1:
		push_error("Run event panel rule summary is missing route preview")
		quit(1)
		return
	var event_footer := world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Footer") as Label
	if event_footer == null or event_footer.text.find("Esc") == -1:
		push_error("Run event panel footer is missing skip shortcut text")
		quit(1)
		return
	world.run_event_panel.close()
	world.run_event_panel.open("attunement", 100)
	await process_frame
	if not world.run_event_panel.visible:
		push_error("Attunement panel did not open")
		quit(1)
		return
	world.run_event_panel.close()
	world.run_event_panel.open("scout", 100)
	await process_frame
	if not world.run_event_panel.visible:
		push_error("Scout panel did not open")
		quit(1)
		return
	var scout_choice_row := world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChoiceScroll/ChoiceRow") as GridContainer
	if scout_choice_row == null or scout_choice_row.get_child_count() < 4:
		push_error("Scout panel did not build its choice cards")
		quit(1)
		return
	if detail_label == null or detail_label.text.find("Fit") == -1:
		push_error("Scout panel detail preview did not initialize build fit guidance")
		quit(1)
		return
	world.run_event_panel.close()
	world.run_event_panel.open("training", 100)
	await process_frame
	var training_choice_row := world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChoiceScroll/ChoiceRow") as GridContainer
	var training_has_skip := false
	for child in training_choice_row.get_children():
		if child is Button and String((child as Button).get_meta("choice_id", "")) == "skip":
			training_has_skip = true
			break
	if not training_has_skip:
		push_error("Training panel is missing an explicit skip choice")
		quit(1)
		return
	world.run_event_panel.close()
	world.run_event_panel.open("bounty", 100)
	await process_frame
	if not world.run_event_panel.visible:
		push_error("Bounty panel did not open")
		quit(1)
		return
	world.run_event_panel.close()

	if world.accessory_choice == null or not world.accessory_choice.has_signal("reroll_requested"):
		push_error("Accessory choice is missing reroll signal")
		quit(1)
		return
	var accessory_manager := root.get_node_or_null("/root/AccessoryManager")
	if accessory_manager == null:
		push_error("AccessoryManager missing for UI smoke")
		quit(1)
		return
	accessory_manager.reset_run()
	var test_sizes := [Vector2i(720, 540), Vector2i(1024, 720)]
	for test_size in test_sizes:
		_set_layout_override(world.character_select, test_size)
		_set_layout_override(world.pause_menu, test_size)
		_set_layout_override(world.audio_settings_panel, test_size)
		_set_layout_override(world.settings_panel, test_size)
		_set_layout_override(world.debug_panel, test_size)
		_set_layout_override(world.audio_shortcut_hint, test_size)
		_set_layout_override(world.accessory_choice, test_size)
		_set_layout_override(world.run_event_panel, test_size)
		_set_layout_override(world.result_screen, test_size)
		_set_layout_override(world.battle_status, test_size)
		_set_layout_override(world.character_hud, test_size)
		await process_frame
		await process_frame
		var character_panel := world.character_select.get("panel") as PanelContainer
		if not _assert_control_fits(character_panel, test_size, "Character select panel"):
			quit(1)
			return
		world.pause_menu.open()
		await process_frame
		var pause_panel := world.pause_menu.get_node("Backdrop/CenterContainer/PanelContainer") as PanelContainer
		if not _assert_control_fits(pause_panel, test_size, "Pause menu panel"):
			quit(1)
			return
		world.pause_menu.close()

		world.audio_settings_panel.show_panel()
		await process_frame
		var audio_panel := world.audio_settings_panel.get_node("Backdrop/MarginContainer") as MarginContainer
		if not _assert_virtual_rect_fits(audio_panel, test_size, "Audio settings panel"):
			quit(1)
			return
		var audio_reset_button := world.audio_settings_panel.get_node("Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/ResetButton") as Button
		if test_size.x <= 720 and audio_reset_button.text != "Reset":
			push_error("Audio settings compact label did not switch")
			quit(1)
			return
		var audio_preview_button := world.audio_settings_panel.get("preview_button_map").get("Music") as Button
		if test_size.x <= 720 and audio_preview_button != null and audio_preview_button.text != "Test":
			push_error("Audio settings compact preview label did not switch")
			quit(1)
			return
		world.audio_settings_panel.hide_panel()

		world.settings_panel.open()
		await process_frame
		var settings_panel := world.settings_panel.get_node("Backdrop/CenterContainer/PanelContainer") as PanelContainer
		if not _assert_control_fits(settings_panel, test_size, "Settings panel"):
			quit(1)
			return
		var settings_hint := world.settings_panel.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Hint") as Label
		if settings_hint == null or settings_hint.text.find("Esc") == -1:
			push_error("Settings panel hint label is missing close shortcut text")
			quit(1)
			return
		world.settings_panel.close()

		if world.debug_panel != null and world.debug_panel.has_method("toggle"):
			world.debug_panel.toggle()
			await process_frame
			var debug_panel := world.debug_panel.get_node("MarginContainer") as MarginContainer
			if not _assert_virtual_rect_fits(debug_panel, test_size, "Debug panel"):
				quit(1)
				return
			world.debug_panel.toggle()

		if world.audio_shortcut_hint != null:
			var hint_title := world.audio_shortcut_hint.get_node("MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Title") as Label
			if test_size.x <= 720 and hint_title.text != "F10 Mix":
				push_error("Audio shortcut hint compact title did not switch")
				quit(1)
				return
			if test_size.x > 720 and hint_title.text != "F10 Audio Mix":
				push_error("Audio shortcut hint full title did not restore")
				quit(1)
				return

		var choices: Array = accessory_manager.generate_choices(3)
		world.accessory_choice.open(choices, null, "Responsive Relic", 20, 50)
		await process_frame
		var accessory_panel := world.accessory_choice.get_node("Backdrop/CenterContainer/PanelContainer") as PanelContainer
		if not _assert_control_fits(accessory_panel, test_size, "Accessory choice panel"):
			quit(1)
			return
		var preview_detail := world.accessory_choice.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewPanel/MarginContainer/VBoxContainer/PreviewDetail") as Label
		var accessory_footer := world.accessory_choice.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Footer") as Label
		if preview_detail == null or preview_detail.text.is_empty():
			push_error("Accessory choice preview detail is empty")
			quit(1)
			return
		if accessory_footer == null or accessory_footer.text.find("keep") == -1:
			push_error("Accessory choice footer is missing keep shortcut text")
			quit(1)
			return
		world.accessory_choice.close()
		world.run_event_panel.open("shop", 100)
		await process_frame
		var event_panel := world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer") as PanelContainer
		if not _assert_control_fits(event_panel, test_size, "Run event panel"):
			quit(1)
			return
		world.run_event_panel.close()
		world.run_event_panel.open("scout", 100)
		await process_frame
		event_panel = world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer") as PanelContainer
		if not _assert_control_fits(event_panel, test_size, "Scout event panel"):
			quit(1)
			return
		world.run_event_panel.close()

		var status_margin := world.battle_status.get("root_margin") as MarginContainer
		if not _assert_virtual_rect_fits(status_margin, test_size, "Battle status panel"):
			quit(1)
			return
		var hud_margin := world.character_hud.get("root_margin") as MarginContainer
		if not _assert_virtual_rect_fits(hud_margin, test_size, "Character HUD panel"):
			quit(1)
			return
		var hud_skill_grid := world.character_hud.get("skill_grid") as GridContainer
		if test_size.x <= 720 and hud_skill_grid != null and hud_skill_grid.columns != 2:
			push_error("Character HUD compact skill grid did not switch to two columns")
			quit(1)
			return
		if test_size.x > 720 and hud_skill_grid != null and hud_skill_grid.columns != 4:
			push_error("Character HUD full skill grid did not restore to four columns")
			quit(1)
			return

	if world.result_screen == null or not world.result_screen.has_method("show_result"):
		push_error("Result screen missing")
		quit(1)
		return
	if not world.result_screen.has_signal("quit_requested"):
		push_error("Result screen is missing quit signal")
		quit(1)
		return
	world.result_screen.show_result(
		"victory",
		"Smoke Victory",
		"UI loaded.",
		"Result screen rendered.",
		{
			"stats": "Hero Knight  |  Relic Wolf Pendant  |  Gold 120",
			"timeline": "Black Market -> Sharpening Oil  /  Scout Report -> Focus Route"
		}
	)
	await process_frame
	if not world.result_screen.visible:
		push_error("Result screen did not open")
		quit(1)
		return
	var result_stats := world.result_screen.get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryPanel/MarginContainer/VBoxContainer/Stats") as Label
	var result_timeline := world.result_screen.get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryPanel/MarginContainer/VBoxContainer/Timeline") as Label
	if result_stats == null or result_stats.text.find("Relic") == -1:
		push_error("Result screen stats summary did not initialize")
		quit(1)
		return
	if result_timeline == null or result_timeline.text.find("Scout Report") == -1:
		push_error("Result screen route timeline did not initialize")
		quit(1)
		return
	world.result_screen.visible = false
	paused = false

	world.queue_free()
	await process_frame
	quit(0)
