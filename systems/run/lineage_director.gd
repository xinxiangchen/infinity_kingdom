extends Node

signal state_changed(state: Dictionary)
signal respawn_ready(payload: Dictionary)
signal archive_dead(payload: Dictionary)

const MAX_SEEDS := 5
const BASE_APTITUDE_TOTAL := 9

var family_id: String = ""
var generation_index: int = 1
var reincarnation_index: int = 1
var seeds_left: int = MAX_SEEDS
var current_encounter_index: int = 0
var current_aptitude := {
	"strength": 3,
	"agility": 3,
	"focus": 3
}
var last_score: Dictionary = {}

func start_or_resume_from_slot(slot: Dictionary, selected_family_id: String = "") -> void:
	if slot.is_empty():
		return
	family_id = String(slot.get("family_id", ""))
	if family_id.is_empty():
		family_id = selected_family_id
	reincarnation_index = int(slot.get("reincarnation_index", 1))
	generation_index = int(slot.get("generation_index", 1))
	seeds_left = int(slot.get("seeds_left", MAX_SEEDS))
	current_encounter_index = int(slot.get("current_encounter_index", 0))
	current_aptitude = {
		"strength": int(slot.get("strength", 3)),
		"agility": int(slot.get("agility", 3)),
		"focus": int(slot.get("focus", 3))
	}
	last_score = {
		"score": int(slot.get("last_score", 0)),
		"grade": String(slot.get("last_score_grade", ""))
	}
	if SaveManager != null and SaveManager.active_slot_index >= 0 and not family_id.is_empty():
		SaveManager.update_active_slot_patch({"family_id": family_id})
	_emit_state()

func begin_new_lineage(selected_family_id: String) -> void:
	family_id = selected_family_id
	reincarnation_index = 1
	generation_index = 1
	seeds_left = MAX_SEEDS
	current_encounter_index = 0
	current_aptitude = {"strength": 3, "agility": 3, "focus": 3}
	last_score.clear()
	if SaveManager != null and SaveManager.active_slot_index >= 0:
		SaveManager.update_active_slot_patch({
			"family_id": family_id,
			"reincarnation_index": reincarnation_index,
			"generation_index": generation_index,
			"seeds_left": seeds_left,
			"current_encounter_index": current_encounter_index,
			"strength": current_aptitude["strength"],
			"agility": current_aptitude["agility"],
			"focus": current_aptitude["focus"],
			"dead_archive": false
		})
	_emit_state()

func record_checkpoint(encounter_index: int) -> void:
	current_encounter_index = maxi(encounter_index, 0)
	if SaveManager != null and SaveManager.active_slot_index >= 0:
		SaveManager.update_active_slot_patch({"current_encounter_index": current_encounter_index})
	_emit_state()

func consume_death(death_summary: Dictionary) -> Dictionary:
	var score_data := score_generation(death_summary)
	last_score = score_data
	seeds_left = maxi(seeds_left - 1, 0)
	var patch := {
		"seeds_left": seeds_left,
		"last_score": int(score_data.get("score", 0)),
		"last_score_grade": String(score_data.get("grade", "D")),
		"total_deaths": int(SaveManager.get_active_slot().get("total_deaths", 0)) + 1 if SaveManager != null else 0
	}
	if seeds_left <= 0:
		patch["dead_archive"] = true
		if SaveManager != null and SaveManager.active_slot_index >= 0:
			SaveManager.update_active_slot_patch(patch)
		var dead_payload := {
			"lineage": get_state(),
			"score": score_data,
			"death_summary": death_summary
		}
		archive_dead.emit(dead_payload)
		_emit_state()
		return dead_payload
	generation_index += 1
	current_aptitude = generate_next_aptitude(score_data)
	patch["generation_index"] = generation_index
	patch["strength"] = current_aptitude["strength"]
	patch["agility"] = current_aptitude["agility"]
	patch["focus"] = current_aptitude["focus"]
	if SaveManager != null and SaveManager.active_slot_index >= 0:
		SaveManager.update_active_slot_patch(patch)
	var payload := {
		"lineage": get_state(),
		"score": score_data,
		"aptitude": current_aptitude.duplicate(true),
		"death_summary": death_summary
	}
	respawn_ready.emit(payload)
	_emit_state()
	return payload

func score_generation(summary: Dictionary) -> Dictionary:
	var cleared := int(summary.get("cleared_encounters", 0))
	var total_encounters := maxi(int(summary.get("total_encounters", 1)), 1)
	var kills := int(summary.get("kills", 0))
	var level := int(summary.get("level", 1))
	var gold := int(summary.get("gold", 0))
	var progress_score := int(round(48.0 * clampf(float(cleared) / float(total_encounters), 0.0, 1.0)))
	var combat_score := mini(kills * 2, 24)
	var growth_score := mini(maxi(level - 1, 0) * 5, 15)
	var economy_score := mini(int(round(float(gold) / 18.0)), 13)
	var score := clampi(progress_score + combat_score + growth_score + economy_score, 0, 100)
	var grade := "D"
	if score >= 88:
		grade = "S"
	elif score >= 72:
		grade = "A"
	elif score >= 52:
		grade = "B"
	elif score >= 32:
		grade = "C"
	return {
		"score": score,
		"grade": grade,
		"progress_score": progress_score,
		"combat_score": combat_score,
		"growth_score": growth_score,
		"economy_score": economy_score
	}

func generate_next_aptitude(score_data: Dictionary) -> Dictionary:
	var score := int(score_data.get("score", 0))
	var total := 7
	if score >= 88:
		total = 15
	elif score >= 72:
		total = 13
	elif score >= 52:
		total = 11
	elif score >= 32:
		total = 9
	var next := {"strength": 2, "agility": 2, "focus": 2}
	var remaining := maxi(total - 6, 0)
	var weights := _family_weights()
	while remaining > 0:
		var pick := _weighted_pick(weights)
		next[pick] = int(next[pick]) + 1
		remaining -= 1
	return next

func apply_aptitude_to_actor(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var strength := int(current_aptitude.get("strength", 3))
	var agility := int(current_aptitude.get("agility", 3))
	var focus := int(current_aptitude.get("focus", 3))
	var family_bonus := _family_bonus()
	_apply_add(actor, "max_hp", strength * 8.0 * family_bonus.get("strength", 1.0))
	_apply_add(actor, "max_defense", strength * 5.0 * family_bonus.get("strength", 1.0))
	_apply_mul(actor, "move_speed", 1.0 + agility * 0.025 * family_bonus.get("agility", 1.0))
	_apply_mul(actor, "attack_interval", maxf(0.72, 1.0 - agility * 0.015 * family_bonus.get("agility", 1.0)))
	_apply_add(actor, "crit_rate", agility * 0.01 * family_bonus.get("agility", 1.0))
	_apply_add(actor, "max_inspiration", focus * 5.0 * family_bonus.get("focus", 1.0))
	for field in ["skill1_cooldown", "skill2_cooldown", "skill3_cooldown"]:
		_apply_mul(actor, field, maxf(0.72, 1.0 - focus * 0.015 * family_bonus.get("focus", 1.0)))
	for field in ["skill1_damage", "skill2_damage", "skill3_damage"]:
		_apply_mul(actor, field, 1.0 + focus * 0.015 * family_bonus.get("focus", 1.0))
	if _has_property(actor, "hp") and _has_property(actor, "max_hp"):
		actor.set("hp", float(actor.get("max_hp")))
	if _has_property(actor, "defense") and _has_property(actor, "max_defense"):
		actor.set("defense", float(actor.get("max_defense")))
	if _has_property(actor, "inspiration") and _has_property(actor, "max_inspiration"):
		actor.set("inspiration", float(actor.get("max_inspiration")))
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

func apply_manual_aptitude_bonus(attribute_id: String) -> Dictionary:
	if not current_aptitude.has(attribute_id):
		return current_aptitude.duplicate(true)
	current_aptitude[attribute_id] = int(current_aptitude[attribute_id]) + 1
	if SaveManager != null and SaveManager.active_slot_index >= 0:
		SaveManager.update_active_slot_patch({
			"strength": int(current_aptitude.get("strength", 3)),
			"agility": int(current_aptitude.get("agility", 3)),
			"focus": int(current_aptitude.get("focus", 3))
		})
	_emit_state()
	return current_aptitude.duplicate(true)

func complete_reincarnation() -> Dictionary:
	reincarnation_index += 1
	generation_index = 1
	seeds_left = MAX_SEEDS
	current_encounter_index = 0
	last_score.clear()
	if SaveManager != null and SaveManager.active_slot_index >= 0:
		var active := SaveManager.get_active_slot()
		SaveManager.update_active_slot_patch({
			"cleared": true,
			"reincarnation_index": reincarnation_index,
			"generation_index": generation_index,
			"seeds_left": seeds_left,
			"current_encounter_index": current_encounter_index,
			"total_runs": int(active.get("total_runs", 1)) + 1
		})
	_emit_state()
	return get_state()

func get_state() -> Dictionary:
	return {
		"family_id": family_id,
		"reincarnation_index": reincarnation_index,
		"generation_index": generation_index,
		"seeds_left": seeds_left,
		"max_seeds": MAX_SEEDS,
		"current_encounter_index": current_encounter_index,
		"aptitude": current_aptitude.duplicate(true),
		"last_score": last_score.duplicate(true)
	}

func _emit_state() -> void:
	state_changed.emit(get_state())

func _family_weights() -> Dictionary:
	match family_id:
		"knight":
			return {"strength": 1.55, "agility": 0.8, "focus": 0.95}
		"ranger":
			return {"strength": 0.85, "agility": 1.55, "focus": 0.9}
		"mage":
			return {"strength": 0.85, "agility": 0.9, "focus": 1.55}
		_:
			return {"strength": 1.0, "agility": 1.0, "focus": 1.0}

func _family_bonus() -> Dictionary:
	match family_id:
		"knight":
			return {"strength": 1.15, "agility": 1.0, "focus": 1.0}
		"ranger":
			return {"strength": 1.0, "agility": 1.15, "focus": 1.0}
		"mage":
			return {"strength": 1.0, "agility": 1.0, "focus": 1.15}
		_:
			return {"strength": 1.0, "agility": 1.0, "focus": 1.0}

func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for value in weights.values():
		total += float(value)
	var roll := randf() * total
	for key in weights.keys():
		roll -= float(weights[key])
		if roll <= 0.0:
			return String(key)
	return "strength"

func _apply_add(actor: Node, field: String, amount: float) -> void:
	if not _has_property(actor, field):
		return
	actor.set(field, float(actor.get(field)) + amount)

func _apply_mul(actor: Node, field: String, multiplier: float) -> void:
	if not _has_property(actor, field):
		return
	actor.set(field, float(actor.get(field)) * multiplier)

func _has_property(actor: Node, field: String) -> bool:
	for property in actor.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false
