extends Node

@export var state_name: StringName = &"Skill"
@export var priority: int = 4
@export var interruptible: bool = false

var state_machine: Node
var actor: Node
var elapsed: float = 0.0
var active_skill: StringName = &""

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	active_skill = actor.consume_queued_skill()
	match active_skill:
		&"skill1":
			actor.start_skill(active_skill)
			actor.play_animation(&"skill1")
		&"skill2":
			actor.start_shadow_step()
		&"skill3":
			actor.start_assassination_dash()
		_:
			state_machine.transition_to(&"Idle")

func physics_update(delta: float) -> void:
	elapsed += delta
	match active_skill:
		&"skill1":
			actor.velocity = actor.velocity.move_toward(Vector2.ZERO, actor.move_speed * delta * 12.0)
			if elapsed >= actor.skill1_cast_duration and actor.current_attack_name != &"skill1":
				actor.current_attack_name = &"skill1"
				actor.fire_piercing_arrow()
		&"skill2":
			actor.process_shadow_step(delta)
		&"skill3":
			if actor.skill3_strike_started:
				actor.process_assassination_strike(delta)
			else:
				if actor.process_assassination_dash(delta):
					actor.begin_assassination_strike()

func evaluate_transitions() -> void:
	match active_skill:
		&"skill1":
			if elapsed >= actor.skill1_cast_duration:
				state_machine.transition_to(&"Idle")
		&"skill2":
			if actor.is_shadow_step_complete():
				state_machine.transition_to(&"Idle")
		&"skill3":
			if actor.skill3_strike_started and actor.skill3_strike_elapsed >= actor.assassination_strike_duration:
				state_machine.transition_to(&"Idle")

func exit() -> void:
	if active_skill == &"skill1":
		actor.current_attack_name = &""
	elif active_skill == &"skill2":
		actor.finish_shadow_step()
	elif active_skill == &"skill3":
		actor.finish_assassination()
