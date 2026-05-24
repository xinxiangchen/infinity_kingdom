extends SceneTree

const PLAYER_SCENES := [
	"res://characters/knight/knight.tscn",
	"res://characters/ranger/ranger.tscn",
	"res://characters/mage/mage.tscn"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for scene_path in PLAYER_SCENES:
		var player_scene := load(scene_path) as PackedScene
		if player_scene == null:
			push_error("Failed to load player scene: %s" % scene_path)
			quit(1)
			return
		var actor := player_scene.instantiate()
		root.add_child(actor)
		await process_frame
		if not actor.has_method("apply_control_effects") or not actor.has_method("get_effective_move_speed"):
			push_error("Player is missing control effect methods: %s" % scene_path)
			quit(1)
			return
		actor.inspiration = float(actor.max_inspiration)
		actor.cooldowns["skill1"] = 0.0
		actor.cooldowns["skill2"] = 0.0
		actor.cooldowns["skill3"] = 0.0
		if not actor.can_cast_skill(&"skill1"):
			push_error("Player could not cast skill1 before control effects: %s" % scene_path)
			quit(1)
			return
		actor.apply_control_effects({"silence_duration": 1.2})
		if actor.can_cast_skill(&"skill1"):
			push_error("Silence did not block skill casting: %s" % scene_path)
			quit(1)
			return
		actor.apply_control_effects({"slow_duration": 1.2, "slow_multiplier": 0.5})
		if float(actor.get_effective_move_speed()) >= float(actor.move_speed):
			push_error("Slow did not reduce effective move speed: %s" % scene_path)
			quit(1)
			return
		actor.apply_control_effects({"root_duration": 0.6})
		if not actor.has_method("is_rooted") or not bool(actor.is_rooted()):
			push_error("Root did not apply correctly: %s" % scene_path)
			quit(1)
			return
		if not actor.has_method("clear_control_effects"):
			push_error("Player is missing clear_control_effects: %s" % scene_path)
			quit(1)
			return
		actor.clear_control_effects(true, true, true)
		if not String(actor.get_control_status_text()).is_empty():
			push_error("Control effects were not cleared: %s" % scene_path)
			quit(1)
			return
		if float(actor.get_effective_move_speed()) < float(actor.move_speed):
			push_error("Move speed did not recover after clear: %s" % scene_path)
			quit(1)
			return
		if not actor.can_cast_skill(&"skill1"):
			push_error("Skill casting did not recover after clear: %s" % scene_path)
			quit(1)
			return
		actor.apply_control_effects({"root_duration": 0.6})
		if String(actor.get_control_status_text()).find("Rooted") == -1:
			push_error("Control status text did not include rooted: %s" % scene_path)
			quit(1)
			return
		if actor.has_signal("control_status_changed") and String(actor.get_control_status_text()).is_empty():
			push_error("Control status signal state stayed empty: %s" % scene_path)
			quit(1)
			return
		actor.queue_free()
		await process_frame
	quit(0)
