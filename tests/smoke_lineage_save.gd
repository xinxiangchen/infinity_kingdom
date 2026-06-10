extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_manager := root.get_node_or_null("/root/SaveManager")
	if save_manager == null:
		push_error("SaveManager autoload missing")
		quit(1)
		return
	save_manager.save_path = "user://ik_saves_smoke.dat"
	save_manager.active_slot_index = -1
	save_manager.active_slot = {}
	save_manager._ensure_save_file()

	var slot: Dictionary = save_manager.create_slot(2, "Smoke Archive", "knight")
	if slot.is_empty() or not bool(slot.get("occupied", false)):
		push_error("SaveManager did not create a fixed record slot")
		quit(1)
		return
	save_manager.update_slot_patch(2, {
		"generation_index": 3,
		"seeds_left": 2,
		"current_encounter_index": 4,
		"last_score": 73,
		"last_score_grade": "A",
		"strength": 6,
		"agility": 4,
		"focus": 5
	})
	var updated: Dictionary = save_manager.read_slot(2)
	if int(updated.get("generation_index", 0)) != 3:
		push_error("SaveManager did not update generation by random access")
		quit(1)
		return
	if int(updated.get("seeds_left", 0)) != 2 or String(updated.get("last_score_grade", "")) != "A":
		push_error("SaveManager did not update seed/score fields by random access")
		quit(1)
		return
	if int(updated.get("strength", 0)) != 6 or int(updated.get("focus", 0)) != 5:
		push_error("SaveManager did not update aptitude fields")
		quit(1)
		return
	save_manager.create_slot(1, "Delete Smoke", "mage")
	save_manager.delete_slot(1)
	var deleted_slot: Dictionary = save_manager.read_slot(1)
	if bool(deleted_slot.get("occupied", true)) or not String(deleted_slot.get("family_id", "")).is_empty():
		push_error("SaveManager did not delete a single fixed record slot")
		quit(1)
		return

	var lineage := root.get_node_or_null("/root/LineageDirector")
	if lineage == null:
		push_error("LineageDirector autoload missing")
		quit(1)
		return
	lineage.start_or_resume_from_slot(updated, "knight")
	var payload: Dictionary = lineage.consume_death({
		"cleared_encounters": 4,
		"total_encounters": 9,
		"kills": 10,
		"level": 3,
		"gold": 80
	})
	var state := payload.get("lineage", {}) as Dictionary
	if int(state.get("generation_index", 0)) != 4 or int(state.get("seeds_left", 0)) != 1:
		push_error("LineageDirector did not consume death into the next generation")
		quit(1)
		return
	var aptitude: Dictionary = lineage.apply_manual_aptitude_bonus("focus")
	if int(aptitude.get("focus", 0)) < 3:
		push_error("LineageDirector did not apply manual aptitude point")
		quit(1)
		return
	quit(0)
