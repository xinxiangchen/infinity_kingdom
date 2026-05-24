extends SceneTree

class TestActor:
	extends Node

	var max_hp: float = 100.0
	var hp: float = 60.0
	var max_defense: float = 50.0
	var defense: float = 12.0
	var max_inspiration: float = 40.0
	var inspiration: float = 10.0
	var attack_damage: float = 20.0
	var move_speed: float = 300.0
	var crit_rate: float = 0.0
	var skill1_cooldown: float = 4.0
	var skill2_cooldown: float = 8.0
	var skill3_cooldown: float = 12.0

	func heal(amount: float) -> void:
		hp = clampf(hp + amount, 0.0, max_hp)

	func emit_stat_signals() -> void:
		pass

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
	run_director.reset_run()
	if run_director.peek_next_event_kind() != "shop":
		push_error("Run event deck did not start with shop")
		quit(1)
		return
	var actor := TestActor.new()
	root.add_child(actor)
	var base_damage := float(actor.attack_damage)
	var base_speed := float(actor.move_speed)
	var base_crit := float(actor.crit_rate)
	var base_hp := float(actor.max_hp)
	var high_reward := int(run_director.reward_encounter(0, actor))
	if high_reward <= 35:
		push_error("Performance reward bonus was not applied")
		quit(1)
		return
	run_director.reset_run()
	run_effects.apply_choice("shop_attack", actor)
	run_effects.apply_choice("train_speed", actor)
	run_effects.apply_choice("train_crit", actor)
	run_effects.apply_choice("train_resource", actor)
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
	var modified_damage := float(actor.attack_damage)
	accessory_manager.equip("iron_branch_pendant", actor)
	run_effects.refresh_persistent_modifiers(actor)
	if float(actor.attack_damage) < modified_damage - 0.01:
		push_error("Run modifiers were lost after accessory reapply")
		quit(1)
		return
	actor.queue_free()
	quit(0)
