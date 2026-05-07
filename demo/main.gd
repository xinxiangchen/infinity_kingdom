extends Node2D

@onready var manager: GameManager = $GameManager
@onready var player: PlayerController = $PlayerController
@onready var status_label: Label = $CanvasLayer/StatusLabel

func _ready() -> void:
	manager.team_name = "CPP Coursework Team"
	manager.add_score(10)
	status_label.text = manager.get_status_text()

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.move_input = input_dir
	status_label.text = "%s | pos=%s" % [manager.get_status_text(), str(player.global_position)]

	if Input.is_action_just_pressed("ui_accept"):
		manager.add_score(1)
		status_label.text = manager.get_status_text()
