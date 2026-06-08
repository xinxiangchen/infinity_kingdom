extends RefCounted


static func play_for_encounter(music: Node, next_encounter_index: int) -> void:
	if music == null:
		return
	if next_encounter_index <= 4:
		music.call("play_profile", &"town_battle")
	elif next_encounter_index == 5:
		music.call("play_profile", &"gate_guard")
	elif next_encounter_index == 6:
		music.call("play_profile", &"palace_explore")
	elif next_encounter_index == 7:
		music.call("play_profile", &"twin_princes")
	else:
		music.call("play_profile", &"emperor")


static func play_intermission(music: Node) -> void:
	if music != null:
		music.call("play_profile", &"church_intermission")
