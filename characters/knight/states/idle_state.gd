extends Node

@export var state_name: StringName = &"Idle"
@export var priority: int = 0
@export var interruptible: bool = true
@export var brake_factor: float = 14.0

var state_machine: Node
var actor: Node
var elapsed: float = 0.0

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	actor.play_animation(&"idle")

func physics_update(delta: float) -> void:
	elapsed += delta
	var move_speed: float = float(actor.get_current_move_speed()) if actor.has_method("get_current_move_speed") else float(actor.move_speed)
	actor.velocity = actor.velocity.move_toward(Vector2.ZERO, move_speed * delta * brake_factor)

func evaluate_transitions() -> void:
	var next_state: StringName = actor.get_state_request()
	state_machine.transition_to(next_state)

func exit() -> void:
	pass
