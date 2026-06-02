extends Node

@export var state_name: StringName = &"Skill"
@export var priority: int = 4
@export var interruptible: bool = false

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
	effect_triggered = false
	active_skill = actor.consume_queued_skill()
	match active_skill:
		&"skill1":
			actor.start_skill1_cast()
		&"skill2":
			actor.start_skill2_cast()
		&"skill3":
			actor.start_skill3_cast()
		_:
			state_machine.transition_to(&"Idle")

func physics_update(delta: float) -> void:
	elapsed += delta
	actor.velocity = actor.velocity.move_toward(Vector2.ZERO, actor.move_speed * delta * 10.0)
	if effect_triggered:
		return
	match active_skill:
		&"skill1":
			if elapsed >= actor.skill1_cast_duration * 0.55:
				effect_triggered = true
				actor.cast_skill1_blades()
		&"skill2":
			if elapsed >= actor.skill2_cast_duration * 0.6:
				effect_triggered = true
				actor.release_skill2_burst()
		&"skill3":
			if elapsed >= actor.skill3_cast_duration * 0.5:
				effect_triggered = true
				actor.apply_skill3_enchant()

func evaluate_transitions() -> void:
	var duration: float = 0.0
	match active_skill:
		&"skill1":
			duration = actor.skill1_cast_duration
		&"skill2":
			duration = actor.skill2_cast_duration
		&"skill3":
			duration = actor.skill3_cast_duration
	if elapsed >= duration:
		state_machine.transition_to(&"Idle")

func exit() -> void:
	actor.finish_skill_cast(active_skill)

