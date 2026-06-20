extends Node

signal state_changed(state: Dictionary)

const EVENT_POOL := [
	"bounty",
	"pact",
	"attunement",
	"scout"
]

const DEFAULT_EVENTS_PER_RUN := 3
const SERVICES_TRIGGER_THRESHOLD := 5

const EVENT_KIND_LABELS := {
	"en": {
		"shop": "Black Market",
		"services": "Town Crossroads",
		"church": "Church Refuge",
		"armory": "Royal Armory",
		"bounty": "Bounty Board",
		"rest": "Church Refuge",
		"training": "Training Drill",
		"forge": "Ember Forge",
		"pact": "Forbidden Pact",
		"attunement": "Relic Resonance",
		"scout": "Scout Report",
		"victory": "Victory",
		"unknown": "Unknown",
		"event": "Event",
		"choice": "Choice",
		"history_empty": "No event choices yet."
	},
	"zh_Hans": {
		"shop": "商店",
		"services": "城镇岔路",
		"church": "教堂",
		"armory": "军需库",
		"bounty": "悬赏栏",
		"rest": "教堂休整",
		"training": "训练场",
		"forge": "锻造台",
		"pact": "禁忌契约",
		"attunement": "饰品共鸣",
		"scout": "侦查情报",
		"victory": "胜利",
		"unknown": "未知",
		"event": "事件",
		"choice": "选择",
		"history_empty": "暂时还没有事件选择记录。"
	},
	"zh_Hant": {
		"shop": "商店",
		"services": "城鎮岔路",
		"church": "教堂",
		"armory": "軍需庫",
		"bounty": "懸賞欄",
		"rest": "教堂休整",
		"training": "訓練場",
		"forge": "鍛造台",
		"pact": "禁忌契約",
		"attunement": "飾品共鳴",
		"scout": "偵查情報",
		"victory": "勝利",
		"unknown": "未知",
		"event": "事件",
		"choice": "選擇",
		"history_empty": "暫時還沒有事件選擇記錄。"
	}
}

var gold: int = 0
var cleared_encounters: int = 0
var event_cursor: int = 0
var run_modifiers: Dictionary = {}
var last_reward_gold: int = 0
var event_deck: Array[String] = []
var reward_flat_bonus: int = 0
var reward_multiplier: float = 1.0
var pending_encounter_prep: Dictionary = {}
var events_per_run: int = DEFAULT_EVENTS_PER_RUN
var event_history: Array[Dictionary] = []
var reward_history: Array[int] = []
var hero_level: int = 1
var hero_xp: int = 0
var hero_xp_to_next: int = 45
var skill_points: int = 0
var max_skill_points: int = 6
var total_kills: int = 0
var town_service_consumed: bool = false
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
	reward_flat_bonus = 0
	reward_multiplier = 1.0
	pending_encounter_prep.clear()
	event_history.clear()
	reward_history.clear()
	hero_level = 1
	hero_xp = 0
	hero_xp_to_next = _xp_needed_for_level(hero_level)
	skill_points = 0
	total_kills = 0
	town_service_consumed = false
	_emit_state()

func mark_town_services_consumed() -> void:
	if town_service_consumed:
		return
	town_service_consumed = true
	_emit_state()

func reward_encounter(encounter_index: int, actor: Node = null) -> int:
	cleared_encounters += 1
	var base_reward: int = 12 + maxi(encounter_index, 0) * 6
	var performance_bonus: int = _performance_bonus(actor)
	last_reward_gold = int(round((base_reward + performance_bonus) * reward_multiplier)) + reward_flat_bonus
	gold += last_reward_gold
	reward_history.append(last_reward_gold)
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

func grant_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	_emit_state()

func grant_experience(amount: int) -> Dictionary:
	var granted := maxi(amount, 0)
	var previous_level := hero_level
	if granted <= 0:
		return {
			"granted": 0,
			"previous_level": previous_level,
			"current_level": hero_level,
			"levels_gained": 0,
			"skill_points_gained": 0,
			"xp": hero_xp,
			"xp_to_next": hero_xp_to_next
		}
	hero_xp += granted
	var levels_gained := 0
	while hero_xp >= hero_xp_to_next:
		hero_xp -= hero_xp_to_next
		hero_level += 1
		levels_gained += 1
		hero_xp_to_next = _xp_needed_for_level(hero_level)
	var skill_points_gained := grant_skill_points(levels_gained)
	_emit_state()
	return {
		"granted": granted,
		"previous_level": previous_level,
		"current_level": hero_level,
		"levels_gained": levels_gained,
		"skill_points_gained": skill_points_gained,
		"xp": hero_xp,
		"xp_to_next": hero_xp_to_next
	}

func grant_skill_points(amount: int) -> int:
	var granted := maxi(amount, 0)
	if granted <= 0:
		return 0
	var previous_points := skill_points
	skill_points = mini(skill_points + granted, max_skill_points)
	return skill_points - previous_points

func spend_skill_point(amount: int = 1) -> bool:
	var cost := maxi(amount, 0)
	if cost <= 0:
		return true
	if skill_points < cost:
		return false
	skill_points -= cost
	_emit_state()
	return true

func can_spend_skill_point(amount: int = 1) -> bool:
	return skill_points >= maxi(amount, 0)

func record_kill(amount: int = 1) -> void:
	var granted := maxi(amount, 0)
	if granted <= 0:
		return
	total_kills += granted
	_emit_state()

func next_event_kind() -> String:
	if not town_service_consumed and cleared_encounters >= SERVICES_TRIGGER_THRESHOLD:
		town_service_consumed = true
		event_cursor += 1
		_emit_state()
		return "services"
	if event_deck.is_empty():
		event_deck = _build_event_deck()
	var kind := str(event_deck.pop_front())
	event_cursor += 1
	_emit_state()
	return kind

func peek_next_event_kind() -> String:
	if not town_service_consumed and cleared_encounters >= SERVICES_TRIGGER_THRESHOLD:
		return "services"
	if event_deck.is_empty():
		return ""
	return str(event_deck[0])

func get_upcoming_events(limit: int = -1) -> Array[String]:
	var events: Array[String] = []
	for event_kind in event_deck:
		events.append(str(event_kind))
		if limit > 0 and events.size() >= limit:
			break
	return events

func describe_event_route(limit: int = 4, include_victory: bool = true) -> String:
	var parts: Array[String] = []
	var remaining_limit := limit
	if not town_service_consumed and cleared_encounters >= SERVICES_TRIGGER_THRESHOLD and remaining_limit != 0:
		parts.append(describe_event_kind("services"))
		if remaining_limit > 0:
			remaining_limit -= 1
	for event_kind in get_upcoming_events(remaining_limit):
		parts.append(describe_event_kind(event_kind))
	if include_victory:
		parts.append(_locale_text("victory"))
	return " -> ".join(parts)

func describe_event_kind(kind: String) -> String:
	return _locale_text(kind if EVENT_KIND_LABELS["en"].has(kind) else "unknown")

func configure_event_count(count: int) -> void:
	events_per_run = maxi(count, 1)
	_emit_state()

func set_pending_encounter_prep(prep: Dictionary) -> void:
	pending_encounter_prep = prep.duplicate(true)
	_emit_state()

func peek_pending_encounter_prep() -> Dictionary:
	return pending_encounter_prep.duplicate(true)

func consume_pending_encounter_prep() -> Dictionary:
	var prep := pending_encounter_prep.duplicate(true)
	pending_encounter_prep.clear()
	_emit_state()
	return prep

func record_event_choice(event_kind: String, choice_id: String, summary: String, choice_name: String = "") -> void:
	event_history.append({
		"kind": event_kind,
		"event_name": describe_event_kind(event_kind),
		"choice_id": choice_id,
		"choice_name": choice_name if not choice_name.is_empty() else choice_id,
		"summary": summary
	})
	_emit_state()

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

func add_reward_flat_bonus(amount: int) -> void:
	if amount == 0:
		return
	reward_flat_bonus += amount
	_emit_state()

func add_reward_multiplier(multiplier: float) -> void:
	if is_equal_approx(multiplier, 1.0):
		return
	reward_multiplier *= multiplier
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

func get_event_history() -> Array[Dictionary]:
	return event_history.duplicate(true)

func get_reward_history() -> Array[int]:
	return reward_history.duplicate()

func describe_event_history(limit: int = 3) -> String:
	if event_history.is_empty():
		return _locale_text("history_empty")
	var parts: Array[String] = []
	var start_index := maxi(event_history.size() - maxi(limit, 1), 0)
	for index in range(start_index, event_history.size()):
		var entry := event_history[index]
		parts.append("%s: %s" % [
			String(entry.get("event_name", _locale_text("event"))),
			String(entry.get("choice_name", _locale_text("choice")))
		])
	return "  /  ".join(parts)

func get_state() -> Dictionary:
	return {
		"gold": gold,
		"cleared_encounters": cleared_encounters,
		"event_cursor": event_cursor,
		"events_per_run": events_per_run,
		"last_reward_gold": last_reward_gold,
		"next_event_kind": peek_next_event_kind(),
		"event_deck": event_deck.duplicate(),
		"run_modifiers": get_run_modifiers(),
		"reward_flat_bonus": reward_flat_bonus,
		"reward_multiplier": reward_multiplier,
		"pending_encounter_prep": peek_pending_encounter_prep(),
		"event_history": get_event_history(),
		"reward_history": get_reward_history(),
		"hero_level": hero_level,
		"hero_xp": hero_xp,
		"hero_xp_to_next": hero_xp_to_next,
		"skill_points": skill_points,
		"max_skill_points": max_skill_points,
		"total_kills": total_kills,
		"town_service_consumed": town_service_consumed
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
		bonus += 6
	elif hp_ratio >= 0.45:
		bonus += 3
	if defense_ratio >= 0.60:
		bonus += 4
	return bonus

func _build_event_deck() -> Array[String]:
	var pool: Array[String] = []
	pool.append_array(EVENT_POOL)
	var deck: Array[String] = []
	while deck.size() < events_per_run and not pool.is_empty():
		var next_index := rng.randi_range(0, pool.size() - 1)
		deck.append(pool[next_index])
		pool.remove_at(next_index)
	return deck

func _xp_needed_for_level(level: int) -> int:
	var normalized_level := maxi(level, 1)
	return 45 + maxi(normalized_level - 1, 0) * 18 + maxi(normalized_level - 2, 0) * 8

func _ratio(actor: Node, current_field: String, max_field: String) -> float:
	if not _has_property(actor, current_field) or not _has_property(actor, max_field):
		return 0.0
	var max_value := float(actor.get(max_field))
	if max_value <= 0.0:
		return 0.0
	return clampf(float(actor.get(current_field)) / max_value, 0.0, 1.0)

func _current_locale() -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		return String(UISettings.get_locale())
	return "zh_Hans"

func _locale_text(key: String) -> String:
	var locale_map := EVENT_KIND_LABELS.get(_current_locale(), EVENT_KIND_LABELS["en"]) as Dictionary
	return String(locale_map.get(key, EVENT_KIND_LABELS["en"].get(key, key)))
