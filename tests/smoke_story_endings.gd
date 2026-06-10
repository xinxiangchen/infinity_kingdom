extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cheat_mode := root.get_node_or_null("/root/CheatMode")
	if cheat_mode == null:
		push_error("CheatMode autoload missing")
		quit(1)
		return
	var ending_director := root.get_node_or_null("/root/EndingDirector")
	if ending_director == null:
		push_error("EndingDirector autoload missing")
		quit(1)
		return

	cheat_mode.reset_session()
	var sequence := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_LEFT, KEY_RIGHT, KEY_RIGHT, KEY_A, KEY_A, KEY_B, KEY_B]
	for keycode in sequence:
		cheat_mode.input_key(keycode)
	if not bool(cheat_mode.enabled) or not bool(cheat_mode.infinite_hp):
		push_error("Cheat sequence did not enable infinite HP")
		quit(1)
		return

	ending_director.reset_run()
	ending_director.record_final_boss_defeated()
	if not bool(ending_director.can_break_crown()):
		push_error("No-damage victory did not qualify for crown break")
		quit(1)
		return

	ending_director.reset_run()
	ending_director.record_player_damage()
	ending_director.record_church_baptism()
	ending_director.record_final_boss_defeated()
	if not bool(ending_director.can_break_crown()):
		push_error("Baptism with no later damage did not qualify for crown break")
		quit(1)
		return
	ending_director.record_player_damage()
	if bool(ending_director.can_break_crown()):
		push_error("Damage after baptism incorrectly kept crown break qualification")
		quit(1)
		return

	ending_director.reset_run()
	ending_director.record_developer_skill(&"skill1")
	ending_director.record_developer_skill(&"skill2")
	ending_director.record_developer_skill(&"skill3")
	if not bool(ending_director.developer_room_ready()):
		push_error("Three developer skill marks did not unlock developer-room readiness")
		quit(1)
		return

	var prologue_script := load("res://ui/opening_prologue.gd") as Script
	if prologue_script == null:
		push_error("Opening prologue script did not load")
		quit(1)
		return

	var health_script := load("res://combat/health_component.gd") as Script
	if health_script == null:
		push_error("HealthComponent script did not load")
		quit(1)
		return
	cheat_mode.reset_session()
	for keycode in sequence:
		cheat_mode.input_key(keycode)
	var holder := Node.new()
	holder.add_to_group("player")
	root.add_child(holder)
	var health: Node = health_script.new()
	holder.add_child(health)
	health.set("hp", 10.0)
	health.set("max_hp", 10.0)
	var result: Dictionary = health.call("receive_hit", {"damage": 999.0})
	if bool(result.get("died", false)) or float(result.get("damage", 0.0)) > 0.0:
		push_error("CheatMode did not prevent lethal HealthComponent damage")
		quit(1)
		return
	holder.queue_free()

	quit(0)
