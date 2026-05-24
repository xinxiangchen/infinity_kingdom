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

	if world.accessory_choice == null or not world.accessory_choice.has_signal("reroll_requested"):
		push_error("Accessory choice is missing reroll signal")
		quit(1)
		return

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
