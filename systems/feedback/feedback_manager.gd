extends Node

var hitstop_timer: SceneTreeTimer = null

func hitstop(duration: float = 0.045) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if duration <= 0.0 or get_tree().paused:
		return
	Engine.time_scale = 0.12
	var timer := get_tree().create_timer(duration, true, false, true)
	hitstop_timer = timer
	timer.timeout.connect(func() -> void:
		if hitstop_timer == timer:
			Engine.time_scale = 1.0
			hitstop_timer = null
	)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
