extends Node2D

signal defeated

var skip_rewards: bool = true


func _ready() -> void:
	var timer := get_tree().create_timer(0.05)
	timer.timeout.connect(_clear_empty_room)


func bind_player(_player: Node2D) -> void:
	pass


func get_status_title() -> String:
	return "Empty Room"


func get_status_text() -> String:
	return "No enemies remain in this chamber."


func _clear_empty_room() -> void:
	defeated.emit()
