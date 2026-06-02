extends Node

@export var state_name: StringName = &"Attack"
@export var priority: int = 2
@export var interruptible: bool = true

var state_machine: Node
var actor: Node
var elapsed: float = 0.0
var hit_triggered: bool = false

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	hit_triggered = false
	actor.start_attack()

func physics_update(delta: float) -> void:
	elapsed += delta
	var move_speed: float = float(actor.get_current_move_speed()) if actor.has_method("get_current_move_speed") else float(actor.move_speed)
	if actor.move_input != Vector2.ZERO:
		actor.velocity = actor.move_input.normalized() * move_speed
	else:
		actor.velocity = actor.velocity.move_toward(Vector2.ZERO, move_speed * delta * 10.0)
	if not hit_triggered and elapsed >= actor.attack_windup:
		hit_triggered = true
		actor.trigger_normal_attack_hit()

func evaluate_transitions() -> void:
	var total_duration: float = actor.attack_windup + actor.attack_hit_frame + actor.attack_recovery
	if elapsed >= total_duration:
		state_machine.transition_to(actor.get_state_request())

func exit() -> void:
	actor.finish_attack()
