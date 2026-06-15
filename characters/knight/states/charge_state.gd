extends Node

@export var state_name: StringName = &"Charge"
@export var priority: int = 3
@export var interruptible: bool = true

var state_machine: Node
var actor: Node
var elapsed: float = 0.0

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	actor.start_charge()

func physics_update(delta: float) -> void:
	elapsed += delta
	var move_speed: float = float(actor.get_current_move_speed()) if actor.has_method("get_current_move_speed") else float(actor.move_speed)
	actor.velocity = actor.velocity.move_toward(Vector2.ZERO, move_speed * delta * 8.0)

func evaluate_transitions() -> void:
	if elapsed >= actor.charge_duration:
		state_machine.transition_to(&"Dash")

func exit() -> void:
	pass
