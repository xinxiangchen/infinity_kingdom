extends Node

@export var state_name: StringName = &"Move"
@export var priority: int = 1
@export var interruptible: bool = true
@export var acceleration_factor: float = 12.0
@export var turn_acceleration_factor: float = 17.0
@export var brake_factor: float = 13.0

var state_machine: Node
var actor: Node

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	actor.play_animation(&"move")

func physics_update(delta: float) -> void:
	var move_speed: float = float(actor.get_current_move_speed()) if actor.has_method("get_current_move_speed") else float(actor.move_speed)
	if actor.move_input == Vector2.ZERO:
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO, move_speed * delta * brake_factor)
		return
	var target_velocity: Vector2 = actor.move_input.normalized() * move_speed
	var moving_against_velocity: bool = actor.velocity.length_squared() > 1.0 and actor.velocity.normalized().dot(target_velocity.normalized()) < 0.25
	var response: float = turn_acceleration_factor if moving_against_velocity else acceleration_factor
	actor.velocity = actor.velocity.move_toward(target_velocity, move_speed * delta * response)

func evaluate_transitions() -> void:
	state_machine.transition_to(actor.get_state_request())

func exit() -> void:
	pass
