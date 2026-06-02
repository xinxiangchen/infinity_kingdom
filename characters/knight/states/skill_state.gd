extends Node

@export var state_name: StringName = &"Skill"
@export var priority: int = 4
@export var interruptible: bool = true

var state_machine: Node
var actor: Node
var elapsed: float = 0.0

var active_skill: StringName = &""
var effect_triggered: bool = false

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	active_skill = actor.consume_queued_skill()
	effect_triggered = false
	if active_skill == &"" or active_skill != &"skill1":
		state_machine.transition_to(&"Idle")
		return

func physics_update(delta: float) -> void:
	elapsed += delta
	actor.velocity = actor.velocity.move_toward(Vector2.ZERO, actor.move_speed * delta * 10.0)

func evaluate_transitions() -> void:
	state_machine.transition_to(&"Idle")

func exit() -> void:
	pass
