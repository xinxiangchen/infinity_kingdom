extends SceneTree

const KNIGHT_SCENE := preload("res://characters/knight/knight.tscn")
const RunEffects := preload("res://systems/run/run_effects.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var knight := KNIGHT_SCENE.instantiate()
	root.add_child(knight)
	await process_frame
	RunDirector.reset_run()
	var base_damage := float(knight.attack_damage)
	var base_speed := float(knight.move_speed)
	var base_crit := float(knight.crit_rate)
	RunEffects.apply_choice("shop_attack", knight)
	RunEffects.apply_choice("train_speed", knight)
	RunEffects.apply_choice("train_crit", knight)
	if float(knight.attack_damage) <= base_damage:
		push_error("shop_attack did not increase damage")
		quit(1)
		return
	if float(knight.move_speed) <= base_speed:
		push_error("train_speed did not increase move speed")
		quit(1)
		return
	if float(knight.crit_rate) <= base_crit:
		push_error("train_crit did not increase crit rate")
		quit(1)
		return
	var modified_damage := float(knight.attack_damage)
	AccessoryManager.equip("iron_branch_pendant", knight)
	RunEffects.refresh_persistent_modifiers(knight)
	if float(knight.attack_damage) < modified_damage - 0.01:
		push_error("Run modifiers were lost after accessory reapply")
		quit(1)
		return
	knight.queue_free()
	await process_frame
	quit(0)
