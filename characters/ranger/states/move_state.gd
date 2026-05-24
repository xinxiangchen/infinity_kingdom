extends Node

@export var state_name: StringName = &"Move"
@export var priority: int = 1
@export var interruptible: bool = true

var state_machine: Node
var actor: Node

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	actor.play_animation(&"move")

func physics_update(delta: float) -> void:
	if actor.move_input == Vector2.ZERO:
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO, actor.get_effective_move_speed() * delta * 10.0)
		return
	actor.velocity = actor.move_input.normalized() * actor.get_effective_move_speed()

func evaluate_transitions() -> void:
	state_machine.transition_to(actor.get_state_request())

func exit() -> void:
	pass
