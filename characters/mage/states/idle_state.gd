extends Node

@export var state_name: StringName = &"Idle"
@export var priority: int = 0
@export var interruptible: bool = true
@export var brake_factor: float = 13.0

var state_machine: Node
var actor: Node

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	actor.play_animation(&"idle")

func physics_update(delta: float) -> void:
	var move_speed: float = float(actor.get_current_move_speed()) if actor.has_method("get_current_move_speed") else float(actor.move_speed)
	actor.velocity = actor.velocity.move_toward(Vector2.ZERO, move_speed * delta * brake_factor)

func evaluate_transitions() -> void:
	state_machine.transition_to(actor.get_state_request())

func exit() -> void:
	pass
