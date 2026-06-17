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
	save_manager.select_slot(2)

	var lineage := root.get_node_or_null("/root/LineageDirector")
	if lineage == null:
		push_error("LineageDirector autoload missing")
		quit(1)
		return
	lineage.start_or_resume_from_slot(updated, "knight")
	if int(lineage.get_state().get("current_encounter_index", -1)) != 0:
		push_error("LineageDirector should always restart a generation from the first encounter")
		quit(1)
		return
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
	if int(state.get("current_encounter_index", -1)) != 0:
		push_error("LineageDirector kept a mid-run checkpoint after death")
		quit(1)
		return
	var next_aptitude := state.get("aptitude", {}) as Dictionary
	var next_total := int(state.get("aptitude_total", 0))
	if next_total != 15:
		push_error("LineageDirector did not clamp next generation aptitude total")
		quit(1)
		return
	var source_attribute := "strength"
	if int(next_aptitude.get(source_attribute, 0)) <= 1:
		source_attribute = "agility"
	var shifted: Dictionary = lineage.apply_manual_aptitude_shift(source_attribute, "focus")
	var shifted_total := int(shifted.get("strength", 0)) + int(shifted.get("agility", 0)) + int(shifted.get("focus", 0))
	if shifted_total != next_total:
		push_error("LineageDirector manual aptitude shift changed total points")
		quit(1)
		return
	if int(shifted.get("focus", 0)) != int(next_aptitude.get("focus", 0)) + 1:
		push_error("LineageDirector did not move a manual aptitude point")
		quit(1)
		return
	lineage.complete_reincarnation()
	var completed_state: Dictionary = lineage.get_state()
	if not (completed_state.get("crowned_families", []) as Array).has("knight"):
		push_error("LineageDirector did not record the crowned family after reincarnation completion")
		quit(1)
		return
	if String(completed_state.get("family_id", "")) != "":
		push_error("LineageDirector did not clear family selection for the next reincarnation")
		quit(1)
		return
	if String(completed_state.get("current_emperor_family", "")) != "knight":
		push_error("LineageDirector did not convert the cleared family into the next emperor boss")
		quit(1)
		return
	if not (completed_state.get("disabled_families", []) as Array).has("knight"):
		push_error("LineageDirector did not expose the crowned family as disabled")
		quit(1)
		return
	if bool(lineage.can_select_family("knight")) or not bool(lineage.can_select_family("ranger")):
		push_error("LineageDirector family availability rules are wrong after first clear")
		quit(1)
		return
	var saved_after_clear: Dictionary = save_manager.read_slot(2)
	if int(saved_after_clear.get("current_encounter_index", -1)) != 0:
		push_error("LineageDirector did not clear route progress after reincarnation completion")
		quit(1)
		return
	if int(saved_after_clear.get("emperor_remaining_hp", 0)) != 5000:
		push_error("LineageDirector did not reset the next emperor hp after a completed cycle")
		quit(1)
		return
	lineage.begin_reincarnation_family("ranger")
	var second_state: Dictionary = lineage.get_state()
	if String(second_state.get("family_id", "")) != "ranger" or int(second_state.get("reincarnation_index", 0)) != 2:
		push_error("LineageDirector did not start the second reincarnation with the chosen remaining family")
		quit(1)
		return
	if String(second_state.get("current_emperor_family", "")) != "knight":
		push_error("LineageDirector changed the emperor boss when selecting the next player family")
		quit(1)
		return
	var saved_after_cycle: Dictionary = save_manager.read_slot(2)
	if (
		String(saved_after_cycle.get("crowned_families", "")) != "knight"
		or String(saved_after_cycle.get("family_id", "")) != "ranger"
		or String(saved_after_cycle.get("current_emperor_family", "")) != "knight"
	):
		push_error("SaveManager did not persist throne-cycle family fields: crowned=%s family=%s" % [
			String(saved_after_cycle.get("crowned_families", "")),
			String(saved_after_cycle.get("family_id", ""))
		])
		quit(1)
		return
	quit(0)
