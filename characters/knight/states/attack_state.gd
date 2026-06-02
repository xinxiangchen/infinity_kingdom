extends Node

@export var state_name: StringName = &"Attack"
@export var priority: int = 2
@export var interruptible: bool = true

var state_machine: Node
var actor: Node
var elapsed: float = 0.0

var hit_triggered: bool = false
var hit_window_closed: bool = false

func setup(machine: Node, state_actor: Node) -> void:
	state_machine = machine
	actor = state_actor

func enter() -> void:
	elapsed = 0.0
	hit_triggered = false
	hit_window_closed = false
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
	if not hit_window_closed and elapsed >= actor.attack_windup + actor.attack_hit_frame:
		hit_window_closed = true

func evaluate_transitions() -> void:
	var total_duration: float = actor.attack_windup + actor.attack_hit_frame + actor.attack_recovery
	if elapsed >= total_duration:
		var next_state: StringName = actor.get_state_request()
		state_machine.transition_to(next_state)

func exit() -> void:
	actor.finish_attack()
