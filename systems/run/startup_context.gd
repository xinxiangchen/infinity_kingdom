extends Node

var pending_mode: StringName = &""
var pending_character_id: StringName = &""


func set_pending_start(mode: StringName, character_id: StringName) -> void:
	pending_mode = mode
	pending_character_id = character_id


func consume_pending_start() -> Dictionary:
	var result := {
		"mode": pending_mode,
		"character_id": pending_character_id
	}
	pending_mode = &""
	pending_character_id = &""
	return result
