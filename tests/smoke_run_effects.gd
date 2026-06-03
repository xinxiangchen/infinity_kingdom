extends SceneTree

class TestActor:
	extends Node

	var max_hp: float = 100.0
	var hp: float = 60.0
	var max_defense: float = 50.0
	var defense: float = 12.0
	var max_inspiration: float = 40.0
	var inspiration: float = 10.0
	var shield: float = 0.0
	var attack_damage: float = 20.0
	var attack_interval: float = 1.0
	var move_speed: float = 300.0
	var crit_rate: float = 0.0
	var inspiration_gain_on_attack_hit: float = 2.0
	var skill1_cost: float = 10.0
	var skill2_cost: float = 12.0
	var skill3_cost: float = 14.0
	var skill1_cooldown: float = 4.0
	var skill2_cooldown: float = 8.0
	var skill3_cooldown: float = 12.0
	var skill1_damage: float = 50.0
	var skill2_damage: float = 65.0
	var skill3_damage: float = 80.0
	var cooldowns := {
		"attack": 0.7,
		"skill1": 3.0,
		"skill2": 5.0,
		"skill3": 7.0
	}

	func heal(amount: float) -> void:
		hp = clampf(hp + amount, 0.0, max_hp)

	func emit_stat_signals() -> void:
		pass

class ControlTarget:
	extends Node

	var applied_effects: Dictionary = {}

	func apply_control_effects(payload: Dictionary) -> void:
		for key in payload.keys():
			applied_effects[key] = payload[key]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_effects := load("res://systems/run/run_effects.gd")
	if run_effects == null:
		push_error("RunEffects script did not load")
		quit(1)
		return
	var run_director := root.get_node_or_null("/root/RunDirector")
	var accessory_manager := root.get_node_or_null("/root/AccessoryManager")
	if run_director == null or accessory_manager == null:
		push_error("Required run autoloads are missing")
		quit(1)
		return
	accessory_manager.reset_run()
	run_director.reset_run()
	var first_event: String = String(run_director.peek_next_event_kind())
	if not ["bounty", "pact", "attunement", "scout"].has(first_event):
		push_error("Run event deck did not start with a regular route event")
		quit(1)
		return
	var actor := TestActor.new()
	var control_target := ControlTarget.new()
	root.add_child(actor)
	root.add_child(control_target)
	var base_damage := float(actor.attack_damage)
	var base_speed := float(actor.move_speed)
	var base_crit := float(actor.crit_rate)
	var base_hp := float(actor.max_hp)
	var high_reward := int(run_director.reward_encounter(0, actor))
	if high_reward <= 12:
		push_error("Performance reward bonus was not applied")
		quit(1)
		return
	run_director.reset_run()
	run_effects.apply_choice("shop_attack", actor)
	run_effects.apply_choice("train_speed", actor)
	run_effects.apply_choice("train_crit", actor)
	run_effects.apply_choice("train_resource", actor)
	run_effects.apply_choice("forge_edge", actor)
	run_effects.apply_choice("forge_focus", actor)
	if float(actor.skill1_cost) >= 10.0:
		push_error("forge_focus did not reduce skill cost")
		quit(1)
		return
	run_effects.apply_choice("rest_repair", actor)
	run_effects.apply_choice("pact_power", actor)
	run_effects.apply_choice("pact_focus", actor)
	if float(actor.attack_damage) <= base_damage:
		push_error("shop_attack did not increase damage")
		quit(1)
		return
	if float(actor.move_speed) <= base_speed:
		push_error("train_speed did not increase move speed")
		quit(1)
		return
	if float(actor.crit_rate) <= base_crit:
		push_error("train_crit did not increase crit rate")
		quit(1)
		return
	if float(actor.max_inspiration) <= 40.0:
		push_error("train_resource did not increase max inspiration")
		quit(1)
		return
	if float(actor.attack_interval) >= 1.0:
		push_error("forge_edge did not improve attack cadence")
		quit(1)
		return
	if float(actor.max_hp) < base_hp - 4.0:
		push_error("pact_focus reduced max hp too heavily")
		quit(1)
		return
	if float(actor.max_hp) >= 108.0:
		push_error("pact_focus did not reduce max hp after rest_repair")
		quit(1)
		return
	if float(actor.max_hp) <= 90.0:
		push_error("rest_repair did not keep max hp in a healthy range")
		quit(1)
		return
	accessory_manager.equip("wolf_pendant", actor)
	var attunement_choices: Array = run_effects.attunement_choices()
	var attunement_ids := {}
	for choice in attunement_choices:
		attunement_ids[String((choice as Dictionary).get("id", ""))] = true
	if not attunement_ids.has("attune_offense") or not attunement_ids.has("attune_gambit"):
		push_error("Attunement choices did not reflect equipped relic tags")
		quit(1)
		return
	var forge_choices: Array = run_effects.forge_choices(actor)
	if forge_choices.size() != 3:
		push_error("Forge choices did not produce three offers")
		quit(1)
		return
	var forge_ids := {}
	for choice in forge_choices:
		forge_ids[String((choice as Dictionary).get("id", ""))] = true
	if not forge_ids.has("forge_edge") and not forge_ids.has("forge_flow"):
		push_error("Forge choices did not reflect the current offensive relic route")
		quit(1)
		return
	var before_attunement_damage := float(actor.attack_damage)
	run_effects.apply_choice("attune_offense", actor)
	if float(actor.attack_damage) <= before_attunement_damage:
		push_error("attune_offense did not increase attack damage")
		quit(1)
		return
	var persistent_damage := float(actor.attack_damage)
	run_effects.apply_choice("scout_assault", actor)
	var pending_prep: Dictionary = run_director.peek_pending_encounter_prep()
	if String(pending_prep.get("title", "")) != "Assault Route":
		push_error("Scout assault did not queue the correct encounter prep")
		quit(1)
		return
	run_effects.activate_encounter_prep(actor, pending_prep)
	if float(actor.attack_damage) <= persistent_damage:
		push_error("Scout assault prep did not increase attack damage for the encounter")
		quit(1)
		return
	if int(pending_prep.get("reward_bonus", 0)) <= 0:
		push_error("Scout assault prep did not include its reward bonus")
		quit(1)
		return
	run_effects.refresh_persistent_modifiers(actor)
	if not is_equal_approx(float(actor.attack_damage), persistent_damage):
		push_error("Encounter prep cleanup did not restore persistent attack damage")
		quit(1)
		return
	run_effects.apply_choice("scout_bulwark", actor)
	pending_prep = run_director.peek_pending_encounter_prep()
	actor.defense = 3.0
	actor.shield = 0.0
	run_effects.activate_encounter_prep(actor, pending_prep)
	if float(actor.defense) < float(actor.max_defense):
		push_error("Scout bulwark did not restore defense")
		quit(1)
		return
	if float(actor.shield) <= 0.0:
		push_error("Scout bulwark did not grant shield")
		quit(1)
		return
	run_effects.clear_shield(actor)
	if float(actor.shield) > 0.0:
		push_error("Shield cleanup did not clear the encounter shield")
		quit(1)
		return
	run_effects.apply_choice("scout_focus", actor)
	pending_prep = run_director.consume_pending_encounter_prep()
	actor.inspiration = 2.0
	var base_cooldown := float(actor.skill1_cooldown)
	run_effects.activate_encounter_prep(actor, pending_prep)
	if float(actor.inspiration) < float(actor.max_inspiration):
		push_error("Scout focus did not restore inspiration")
		quit(1)
		return
	if float(actor.skill1_cooldown) >= base_cooldown:
		push_error("Scout focus did not reduce skill cooldowns")
		quit(1)
		return
	run_effects.refresh_persistent_modifiers(actor)
	accessory_manager.equip("iron_branch_pendant", actor)
	run_effects.refresh_persistent_modifiers(actor)
	if float(actor.attack_damage) <= base_damage:
		push_error("Run modifiers were lost after accessory reapply")
		quit(1)
		return
	if float(actor.max_defense) <= 50.0:
		push_error("New accessory stats were not applied after re-equip")
		quit(1)
		return
	accessory_manager.equip("wolf_pendant", actor)
	var skill_payload: Dictionary = accessory_manager.build_hit_payload(actor, &"skill2", 40.0, 0.1)
	if float(skill_payload.get("crit_rate", 0.0)) <= 0.1:
		push_error("Crit relic did not improve combat payload crit chance")
		quit(1)
		return
	if float(skill_payload.get("damage_multiplier", 1.0)) <= 1.0:
		push_error("Damage relic did not add a combat payload rider")
		quit(1)
		return
	accessory_manager.equip("wind_knot", actor)
	control_target.applied_effects.clear()
	actor.cooldowns["attack"] = 0.7
	accessory_manager.apply_on_hit_effects(actor, &"attack", control_target)
	if float(actor.cooldowns["attack"]) >= 0.7:
		push_error("Attack relic did not refund basic attack cooldown")
		quit(1)
		return
	if float(control_target.applied_effects.get("slow_duration", 0.0)) <= 0.0:
		push_error("Speed relic did not apply slow control")
		quit(1)
		return
	accessory_manager.equip("old_king_crest", actor)
	control_target.applied_effects.clear()
	actor.defense = 8.0
	accessory_manager.apply_on_hit_effects(actor, &"skill2", control_target)
	if float(control_target.applied_effects.get("silence_duration", 0.0)) <= 0.0:
		push_error("Skill relic did not apply silence control")
		quit(1)
		return
	if float(actor.defense) <= 8.0:
		push_error("Defense relic did not restore defense on skill hit")
		quit(1)
		return
	accessory_manager.equip("ember_talisman", actor)
	actor.inspiration = 5.0
	actor.cooldowns["skill1"] = 3.0
	accessory_manager.apply_on_hit_effects(actor, &"skill1", control_target)
	if float(actor.inspiration) <= 5.0:
		push_error("Resource relic did not restore inspiration on hit")
		quit(1)
		return
	if float(actor.cooldowns["skill1"]) >= 3.0:
		push_error("Tempo relic did not refund skill cooldown")
		quit(1)
		return
	accessory_manager.equip("iron_branch_pendant", actor)
	actor.hp = 20.0
	actor.defense = 0.0
	accessory_manager.apply_on_hit_effects(actor, &"skill2", control_target)
	if float(actor.hp) <= 20.0:
		push_error("Survival relic did not heal low-health actor on hit")
		quit(1)
		return
	actor.queue_free()
	control_target.queue_free()
	quit(0)
