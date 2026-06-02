extends Node

@export var state_name: StringName = &"Hit"
@export var priority: int = 5
@export var interruptible: bool = false

var state_machine: Node
var actor: Node
var elapsed: float = 0.0

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	actor.play_animation(&"hit")
	actor.velocity *= 0.2

func physics_update(delta: float) -> void:
	elapsed += delta
	actor.velocity = actor.velocity.move_toward(Vector2.ZERO, actor.move_speed * delta * 14.0)

func evaluate_transitions() -> void:
	if elapsed >= actor.hit_stun_duration:
		state_machine.transition_to(actor.get_state_request())

func exit() -> void:
	pass
