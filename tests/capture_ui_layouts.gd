extends SceneTree

const OUTPUT_DIR := "res://.tmp/ui_review"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var ui_settings := root.get_node_or_null("/root/UISettings")
	if ui_settings != null and ui_settings.has_method("set_locale"):
		ui_settings.call("set_locale", "zh_Hans", false)
	var world_scene := load("res://world.tscn") as PackedScene
	if world_scene == null:
		push_error("world.tscn did not load")
		quit(1)
		return
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	await _capture_world(world, Vector2i(1280, 720), "title_menu_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "title_menu_zh_hans_720x540.png")
	if world.character_select != null and world.character_select.has_method("_show_gallery"):
		world.character_select._show_gallery()
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "title_gallery_zh_hans_1280x720.png")
	if world.character_select != null and world.character_select.has_method("_show_about"):
		world.character_select._show_about()
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "title_about_zh_hans_1280x720.png")

	if world.character_select != null and world.character_select.has_method("_show_hero_select"):
		world.character_select._show_hero_select()
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "title_select_zh_hans_1280x720.png")

	if world.has_method("_on_character_selected"):
		world._on_character_selected(&"knight")
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "relic_offer_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "relic_offer_zh_hans_720x540.png")
	if world.accessory_choice != null and world.accessory_choice.has_method("_on_keep_pressed"):
		world.accessory_choice._on_keep_pressed()
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "battle_ui_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "battle_ui_zh_hans_720x540.png")
	if world.pause_menu != null and world.pause_menu.has_method("open"):
		world.pause_menu.open()
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "pause_menu_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "pause_menu_zh_hans_720x540.png")
	if world.pause_menu != null and world.pause_menu.has_method("close"):
		world.pause_menu.close()
	await process_frame
	await process_frame
	if world.audio_settings_panel != null and world.audio_settings_panel.has_method("show_panel"):
		world.audio_settings_panel.show_panel()
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "audio_settings_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "audio_settings_zh_hans_720x540.png")
	if world.audio_settings_panel != null and world.audio_settings_panel.has_method("hide_panel"):
		world.audio_settings_panel.hide_panel()
	await process_frame
	await process_frame
	if world.settings_panel != null and world.settings_panel.has_method("open"):
		world.settings_panel.open()
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "settings_panel_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "settings_panel_zh_hans_720x540.png")
	if world.settings_panel != null and world.settings_panel.has_method("close"):
		world.settings_panel.close()
	await process_frame
	await process_frame
	if world.run_event_panel != null and world.run_event_panel.has_method("open"):
		world.run_event_panel.open("forge", 100)
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "forge_event_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "forge_event_zh_hans_720x540.png")
	if world.run_event_panel != null and world.run_event_panel.has_method("close"):
		world.run_event_panel.close()
	if world.run_event_panel != null and world.run_event_panel.has_method("open"):
		world.run_event_panel.open("services", 100)
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "services_event_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "services_event_zh_hans_720x540.png")
	if world.run_event_panel != null and world.run_event_panel.has_method("close"):
		world.run_event_panel.close()
	if world.inventory_panel != null and world.inventory_panel.has_method("open"):
		world.inventory_panel.open(world.player_character)
	await process_frame
	await process_frame
	await _capture_world(world, Vector2i(1280, 720), "inventory_panel_zh_hans_1280x720.png")
	await _capture_world(world, Vector2i(720, 540), "inventory_panel_zh_hans_720x540.png")

	world.queue_free()
	await process_frame
	quit(0)

func _capture_world(world: Node, viewport_size: Vector2i, filename: String) -> void:
	root.size = viewport_size
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(viewport_size)
	_set_layout_override(world.character_select, viewport_size)
	_set_layout_override(world.pause_menu, viewport_size)
	_set_layout_override(world.audio_settings_panel, viewport_size)
	_set_layout_override(world.settings_panel, viewport_size)
	_set_layout_override(world.debug_panel, viewport_size)
	_set_layout_override(world.audio_shortcut_hint, viewport_size)
	_set_layout_override(world.accessory_choice, viewport_size)
	_set_layout_override(world.run_event_panel, viewport_size)
	_set_layout_override(world.result_screen, viewport_size)
	_set_layout_override(world.battle_status, viewport_size)
	_set_layout_override(world.character_hud, viewport_size)
	_set_layout_override(world.inventory_panel, viewport_size)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Viewport capture failed for %s" % filename)
		return
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))

func _set_layout_override(target: Object, viewport_size: Vector2i) -> void:
	if target == null:
		return
	target.set("layout_size_override", Vector2(viewport_size))
	if target.has_method("_queue_layout_refresh"):
		target.call("_queue_layout_refresh")
