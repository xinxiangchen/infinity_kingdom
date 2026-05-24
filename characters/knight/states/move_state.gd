extends Node

@export var state_name: StringName = &"Move"
@export var priority: int = 1
@export var interruptible: bool = true

var state_machine: Node
var actor: Node
var elapsed: float = 0.0

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	actor.play_animation(&"move")

func physics_update(delta: float) -> void:
	elapsed += delta
	if actor.move_input == Vector2.ZERO:
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO, actor.get_effective_move_speed() * delta * 10.0)
		return
	actor.velocity = actor.move_input.normalized() * actor.get_effective_move_speed()

func evaluate_transitions() -> void:
	var next_state: StringName = actor.get_state_request()
	state_machine.transition_to(next_state)

func exit() -> void:
	pass
