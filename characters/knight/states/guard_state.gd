extends Node

@export var state_name: StringName = &"Guard"
@export var priority: int = 4
@export var interruptible: bool = false

var state_machine: Node
var actor: Node
var elapsed: float = 0.0

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	actor.play_animation(&"guard")

func physics_update(delta: float) -> void:
	elapsed += delta
	actor.velocity = actor.velocity.move_toward(Vector2.ZERO, actor.move_speed * delta * 10.0)

func evaluate_transitions() -> void:
	if elapsed >= actor.guard_duration or actor.shield <= 0.0:
		var next_state: StringName = actor.get_state_request()
		state_machine.transition_to(next_state)

func exit() -> void:
	actor.end_guard()
