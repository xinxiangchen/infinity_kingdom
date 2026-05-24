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
	if not world.character_select.has_signal("quit_requested"):
		push_error("Character select is missing quit signal")
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
	if not world.run_event_panel.visible:
		push_error("Run event panel did not open")
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
		_set_layout_override(world.audio_settings_panel, test_size)
		_set_layout_override(world.settings_panel, test_size)
		_set_layout_override(world.debug_panel, test_size)
		_set_layout_override(world.audio_shortcut_hint, test_size)
		_set_layout_override(world.accessory_choice, test_size)
		_set_layout_override(world.run_event_panel, test_size)
		_set_layout_override(world.result_screen, test_size)
		await process_frame
		await process_frame
		world.audio_settings_panel.show_panel()
		await process_frame
		var audio_panel := world.audio_settings_panel.get_node("Backdrop/MarginContainer") as MarginContainer
		if not _assert_virtual_rect_fits(audio_panel, test_size, "Audio settings panel"):
			quit(1)
			return
		var audio_reset_button := world.audio_settings_panel.get_node("Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/ResetButton") as Button
		if test_size.x <= 720 and audio_reset_button.text != "Reset Mix":
			push_error("Audio settings compact label did not switch")
			quit(1)
			return
		world.audio_settings_panel.hide_panel()

		world.settings_panel.open()
		await process_frame
		var settings_panel := world.settings_panel.get_node("Backdrop/CenterContainer/PanelContainer") as PanelContainer
		if not _assert_control_fits(settings_panel, test_size, "Settings panel"):
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
		world.accessory_choice.close()
		world.run_event_panel.open("shop", 100)
		await process_frame
		var event_panel := world.run_event_panel.get_node("Backdrop/CenterContainer/PanelContainer") as PanelContainer
		if not _assert_control_fits(event_panel, test_size, "Run event panel"):
			quit(1)
			return
		world.run_event_panel.close()

	if world.result_screen == null or not world.result_screen.has_method("show_result"):
		push_error("Result screen missing")
		quit(1)
		return
	world.result_screen.show_result("victory", "Smoke Victory", "UI loaded.", "Result screen rendered.")
	await process_frame
	if not world.result_screen.visible:
		push_error("Result screen did not open")
		quit(1)
		return
	world.result_screen.visible = false
	paused = false

	world.queue_free()
	await process_frame
	quit(0)
