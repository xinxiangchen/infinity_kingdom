extends Node

@export var state_name: StringName = &"Dodge"
@export var priority: int = 4
@export var interruptible: bool = false

var state_machine: Node
var actor: Node

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	actor.start_dodge()

func physics_update(delta: float) -> void:
	if actor.process_dodge(delta):
		state_machine.transition_to(&"Idle")

func evaluate_transitions() -> void:
	if actor.is_dodge_complete():
		state_machine.transition_to(&"Idle")

func exit() -> void:
	actor.finish_dodge()
