extends Node

@export var state_name: StringName = &"Idle"
@export var priority: int = 0
@export var interruptible: bool = true

var state_machine: Node
var actor: Node

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	actor.velocity = Vector2.ZERO
	actor.play_animation(&"idle")

func physics_update(delta: float) -> void:
	actor.velocity = actor.velocity.move_toward(Vector2.ZERO, actor.move_speed * delta * 8.0)

func evaluate_transitions() -> void:
	state_machine.transition_to(actor.get_state_request())

func exit() -> void:
	pass
