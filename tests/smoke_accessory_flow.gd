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
	if not world.has_method("_on_character_selected"):
		push_error("World character selection hook missing")
		quit(1)
		return
	world._on_character_selected(&"knight")
	await process_frame
	if world.player_character == null:
		push_error("Player was not spawned")
		quit(1)
		return
	if world.current_encounter == null:
		push_error("Encounter did not start directly after character select")
		quit(1)
		return
	var accessory_manager := root.get_node_or_null("/root/AccessoryManager")
	if accessory_manager == null:
		push_error("AccessoryManager autoload missing")
		quit(1)
		return
	world._offer_accessory("Smoke Relic", "test")
	await process_frame
	if world.accessory_choice == null or not world.accessory_choice.visible:
		push_error("Accessory choice did not open when explicitly requested")
		quit(1)
		return
	var choices: Array = accessory_manager.current_choices
	if choices.is_empty():
		push_error("Accessory choices were not generated")
		quit(1)
		return
	var first_choice: Dictionary = choices[0]
	accessory_manager.equip(String(first_choice.get("id", "")), world.player_character)
	world._on_accessory_choice_made(String(first_choice.get("id", "")), false)
	await process_frame
	if world.current_encounter == null:
		push_error("Encounter was lost after accessory choice")
		quit(1)
		return
	if String(accessory_manager.get_equipped_accessory().get("id", "none")) == "none":
		push_error("Accessory did not equip")
		quit(1)
		return
	world.queue_free()
	await process_frame
	quit(0)
