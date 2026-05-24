extends Node

signal state_changed(state: Dictionary)

const EVENT_POOL := [
	"rest",
	"training",
	"pact"
]

var gold: int = 0
var cleared_encounters: int = 0
var event_cursor: int = 0
var run_modifiers: Dictionary = {}
var last_reward_gold: int = 0
var event_deck: Array[String] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func reset_run() -> void:
	gold = 0
	cleared_encounters = 0
	event_cursor = 0
	run_modifiers.clear()
	last_reward_gold = 0
	event_deck = _build_event_deck()
	_emit_state()

func reward_encounter(encounter_index: int, actor: Node = null) -> int:
	cleared_encounters += 1
	var base_reward: int = 35 + maxi(encounter_index, 0) * 15
	var performance_bonus: int = _performance_bonus(actor)
	last_reward_gold = base_reward + performance_bonus
	gold += last_reward_gold
	_emit_state()
	return last_reward_gold

func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	_emit_state()
	return true

func next_event_kind() -> String:
	if event_deck.is_empty():
		event_deck = _build_event_deck()
	var kind := String(event_deck.pop_front())
	event_cursor += 1
	_emit_state()
	return kind

func peek_next_event_kind() -> String:
	if event_deck.is_empty():
		return ""
	return String(event_deck[0])

func describe_event_kind(kind: String) -> String:
	match kind:
		"shop":
			return "Black Market"
		"rest":
			return "Church Refuge"
		"training":
			return "Training Drill"
		"pact":
			return "Forbidden Pact"
		_:
			return "Unknown"

func add_run_modifier(field: String, add_value: float = 0.0, multiplier: float = 1.0, floor_value: float = -INF) -> void:
	if field.is_empty():
		return
	var modifier: Dictionary = run_modifiers.get(field, {
		"add": 0.0,
		"multiplier": 1.0,
		"floor": -INF
	})
	modifier["add"] = float(modifier.get("add", 0.0)) + add_value
	modifier["multiplier"] = float(modifier.get("multiplier", 1.0)) * multiplier
	if floor_value != -INF:
		modifier["floor"] = maxf(float(modifier.get("floor", -INF)), floor_value)
	run_modifiers[field] = modifier
	_emit_state()

func apply_run_modifiers(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	for field in run_modifiers.keys():
		if not _has_property(actor, String(field)):
			continue
		var modifier: Dictionary = run_modifiers[field]
		var next_value := (float(actor.get(String(field))) + float(modifier.get("add", 0.0))) * float(modifier.get("multiplier", 1.0))
		var floor_value := float(modifier.get("floor", -INF))
		if floor_value != -INF:
			next_value = maxf(next_value, floor_value)
		actor.set(String(field), next_value)
	_sync_actor_stat_components(actor)
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

func get_run_modifiers() -> Dictionary:
	return run_modifiers.duplicate(true)

func get_state() -> Dictionary:
	return {
		"gold": gold,
		"cleared_encounters": cleared_encounters,
		"event_cursor": event_cursor,
		"last_reward_gold": last_reward_gold,
		"next_event_kind": peek_next_event_kind(),
		"event_deck": event_deck.duplicate(),
		"run_modifiers": get_run_modifiers()
	}

func _emit_state() -> void:
	state_changed.emit(get_state())

func _sync_actor_stat_components(actor: Node) -> void:
	var health_component: Node = actor.get("health_component") if _has_property(actor, "health_component") else null
	if health_component == null:
		return
	if _has_property(actor, "max_hp"):
		health_component.max_hp = float(actor.max_hp)
		if _has_property(actor, "hp"):
			health_component.hp = clampf(float(actor.hp), 0.0, float(actor.max_hp))
	if _has_property(actor, "max_defense"):
		health_component.max_defense = float(actor.max_defense)
		if _has_property(actor, "defense"):
			health_component.defense = clampf(float(actor.defense), 0.0, float(actor.max_defense))

func _has_property(actor: Node, field: String) -> bool:
	for property in actor.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false

func _performance_bonus(actor: Node) -> int:
	if actor == null or not is_instance_valid(actor):
		return 0
	var hp_ratio: float = _ratio(actor, "hp", "max_hp")
	var defense_ratio: float = _ratio(actor, "defense", "max_defense")
	var bonus: int = 0
	if hp_ratio >= 0.75:
		bonus += 12
	elif hp_ratio >= 0.45:
		bonus += 6
	if defense_ratio >= 0.60:
		bonus += 8
	return bonus

func _build_event_deck() -> Array[String]:
	var pool: Array[String] = ["rest", "training", "pact"]
	var deck: Array[String] = ["shop"]
	while not pool.is_empty():
		var next_index := rng.randi_range(0, pool.size() - 1)
		deck.append(pool[next_index])
		pool.remove_at(next_index)
	return deck

func _ratio(actor: Node, current_field: String, max_field: String) -> float:
	if not _has_property(actor, current_field) or not _has_property(actor, max_field):
		return 0.0
	var max_value := float(actor.get(max_field))
	if max_value <= 0.0:
		return 0.0
	return clampf(float(actor.get(current_field)) / max_value, 0.0, 1.0)
