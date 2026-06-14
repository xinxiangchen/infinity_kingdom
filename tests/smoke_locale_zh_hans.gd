extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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

	var start_button := world.character_select.get("primary_start_button") as Button
	var settings_button := world.character_select.get("settings_button") as Button
	var audio_button := world.character_select.get("audio_button") as Button
	var gallery_button := world.character_select.get("gallery_button") as Button
	var about_button := world.character_select.get("about_button") as Button
	var quit_button := world.character_select.get("quit_button") as Button
	if start_button == null or start_button.text != "New Game":
		push_error("Title start button did not use the requested New Game label")
		quit(1)
		return
	if about_button == null or about_button.text != "About":
		push_error("Title about button did not use the requested About label")
		quit(1)
		return
	if settings_button == null or settings_button.text != "Setting":
		push_error("Title settings button did not use the requested Setting label")
		quit(1)
		return
	if quit_button == null or quit_button.text != "Quit":
		push_error("Title quit button did not use the requested Quit label")
		quit(1)
		return
	if audio_button == null or audio_button.visible:
		push_error("Title audio button should be hidden")
		quit(1)
		return
	if gallery_button == null or gallery_button.visible:
		push_error("Title gallery button should be hidden")
		quit(1)
		return

	if world.character_select == null or not world.character_select.has_method("_show_gallery"):
		push_error("Character select gallery API missing")
		quit(1)
		return
	world.character_select._show_gallery()
	await process_frame
	var gallery_desc := world.character_select.get("hero_detail_desc") as Label
	if gallery_desc == null or gallery_desc.text.is_empty():
		push_error("Gallery detail did not initialize in Simplified Chinese")
		quit(1)
		return
	if gallery_desc.text.find("Hero Dossier") != -1 or gallery_desc.text.find("Boss Intel") != -1:
		push_error("Gallery detail still contains English-only headings in Simplified Chinese")
		quit(1)
		return

	if world.character_select == null or not world.character_select.has_method("_show_about"):
		push_error("Character select about API missing")
		quit(1)
		return
	world.character_select._show_about()
	await process_frame
	var about_title := world.character_select.get("hero_detail_title") as Label
	if about_title == null or about_title.text != "试炼概览":
		push_error("About screen title did not localize to Simplified Chinese")
		quit(1)
		return

	world._on_character_selected(&"knight")
	await process_frame
	await process_frame

	var battle_objective := world.battle_status.get("objective_value_label") as Label
	if battle_objective == null or battle_objective.text.find("场") == -1 or battle_objective.text.find("清空战场") == -1:
		push_error("Battle status objective did not localize to Simplified Chinese")
		quit(1)
		return
	if battle_objective.text.find("Encounter") != -1 or battle_objective.text.find("clear the arena") != -1:
		push_error("Battle status objective still contains English in Simplified Chinese")
		quit(1)
		return

	var accessory_manager := root.get_node_or_null("/root/AccessoryManager")
	if accessory_manager == null:
		push_error("AccessoryManager autoload missing for locale smoke")
		quit(1)
		return
	var choices: Array = accessory_manager.generate_choices(3, world.player_character, {"source": "opening"})
	world.accessory_choice.open(choices, world.player_character, "初始饰品", 20, 20)
	await process_frame
	await process_frame
	var accessory_preview := world.accessory_choice.get_node("Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewPanel/MarginContainer/VBoxContainer/PreviewDetail") as Label
	if accessory_preview == null or accessory_preview.text.is_empty():
		push_error("Accessory preview did not initialize in Simplified Chinese")
		quit(1)
		return
	if accessory_preview.text.find("Swap:") != -1 or accessory_preview.text.find("Opening") != -1:
		push_error("Accessory preview still contains English-only guidance in Simplified Chinese")
		quit(1)
		return

	quit(0)
