extends Node

signal accessory_equipped(accessory: Dictionary)
signal choices_generated(choices: Array[Dictionary])

const ACCESSORY_DATA_PATH := "res://systems/accessories/accessories.json"

const EMPTY_ACCESSORY := {
	"id": "none",
	"name": "No Accessory",
	"rarity": "Common",
	"icon": "res://assets/ui/icon/ui_unknown.png",
	"summary": "Choose a relic to shape this run.",
	"effects": {},
	"tags": []
}

const FALLBACK_ACCESSORIES := [
	{
		"id": "ember_talisman",
		"name": "Ember Talisman",
		"rarity": "Uncommon",
		"icon": "res://assets/ui/accessory/ember_talisman.png",
		"summary": "+20 max inspiration, +1 inspiration on every hit.",
		"effects": {"max_inspiration": 20.0, "inspiration_gain_on_attack_hit": 1.0},
		"tags": ["resource", "tempo"]
	},
	{
		"id": "wind_knot",
		"name": "Wind Knot",
		"rarity": "Uncommon",
		"icon": "res://assets/ui/accessory/wind_knot.png",
		"summary": "+18% move speed and slightly faster normal attacks.",
		"effects": {"move_speed_pct": 0.18, "attack_interval_pct": -0.08},
		"tags": ["speed", "attack"]
	},
	{
		"id": "wolf_pendant",
		"name": "Wolf Pendant",
		"rarity": "Rare",
		"icon": "res://assets/ui/accessory/wolf_pendant.png",
		"summary": "+15% attack damage and +6% critical chance.",
		"effects": {"attack_damage_pct": 0.15, "crit_rate": 0.06},
		"tags": ["damage", "crit"]
	},
	{
		"id": "echo_silver_ring",
		"name": "Echo Silver Ring",
		"rarity": "Rare",
		"icon": "res://assets/ui/accessory/echo_silver_ring.png",
		"summary": "Skills recover faster and basic hits restore more inspiration.",
		"effects": {"skill_cooldown_pct": -0.12, "inspiration_gain_on_attack_hit": 1.5},
		"tags": ["skill", "resource"]
	},
	{
		"id": "iron_branch_pendant",
		"name": "Iron Branch Pendant",
		"rarity": "Uncommon",
		"icon": "res://assets/ui/accessory/iron_branch_pendant.png",
		"summary": "+18 max hp, +18 max defense.",
		"effects": {"max_hp": 18.0, "max_defense": 18.0},
		"tags": ["survival", "defense"]
	},
	{
		"id": "shadow_charm",
		"name": "Shadow Charm",
		"rarity": "Rare",
		"icon": "res://assets/ui/accessory/shadow_charm.png",
		"summary": "+12% move speed, +10% critical chance.",
		"effects": {"move_speed_pct": 0.12, "crit_rate": 0.10},
		"tags": ["speed", "crit"]
	},
	{
		"id": "fate_reversal_ring",
		"name": "Fate Reversal Ring",
		"rarity": "Epic",
		"icon": "res://assets/ui/accessory/fate_reversal_ring.png",
		"summary": "+30 max hp, +12% attack damage, but skills cost more inspiration.",
		"effects": {"max_hp": 30.0, "attack_damage_pct": 0.12, "skill_cost_pct": 0.10},
		"tags": ["power", "risk"]
	},
	{
		"id": "old_king_crest",
		"name": "Old King Crest",
		"rarity": "Epic",
		"icon": "res://assets/ui/accessory/old_king_crest.png",
		"summary": "+25 max defense, +18% skill damage.",
		"effects": {"max_defense": 25.0, "skill_damage_pct": 0.18},
		"tags": ["skill", "defense"]
	},
	{
		"id": "hunter_bone_charm",
		"name": "Hunter Bone Charm",
		"rarity": "Rare",
		"icon": "res://assets/ui/accessory/hunter_bone_charm.png",
		"summary": "+10% attack damage, +14% move speed.",
		"effects": {"attack_damage_pct": 0.10, "move_speed_pct": 0.14},
		"tags": ["damage", "speed"]
	},
	{
		"id": "nameless_astrolabe",
		"name": "Nameless Astrolabe",
		"rarity": "Epic",
		"icon": "res://assets/ui/accessory/nameless_astrolabe.png",
		"summary": "+25 max inspiration, -15% skill cooldowns.",
		"effects": {"max_inspiration": 25.0, "skill_cooldown_pct": -0.15},
		"tags": ["skill", "resource"]
	},
	{
		"id": "throne_remnant",
		"name": "Throne Remnant",
		"rarity": "Legendary",
		"icon": "res://assets/ui/accessory/throne_remnant.png",
		"summary": "+20% attack and skill damage, +20 max defense.",
		"effects": {"attack_damage_pct": 0.20, "skill_damage_pct": 0.20, "max_defense": 20.0},
		"tags": ["damage", "skill", "defense"]
	}
]

const STAT_FIELDS := [
	"max_hp",
	"max_inspiration",
	"max_defense",
	"defense",
	"move_speed",
	"attack_damage",
	"attack_interval",
	"crit_rate",
	"inspiration_gain_on_attack_hit",
	"skill1_cost",
	"skill2_cost",
	"skill3_cost",
	"skill1_cooldown",
	"skill2_cooldown",
	"skill3_cooldown",
	"skill1_damage",
	"skill2_damage",
	"skill3_damage"
]

var equipped_accessory: Dictionary = EMPTY_ACCESSORY.duplicate(true)
var current_choices: Array[Dictionary] = []
var base_stats_by_actor: Dictionary = {}
var choice_cursor: int = 0
var accessory_catalog: Array[Dictionary] = []

func _ready() -> void:
	reload_catalog()

func reload_catalog() -> void:
	accessory_catalog = _load_catalog_from_json()
	if accessory_catalog.is_empty():
		accessory_catalog = FALLBACK_ACCESSORIES.duplicate(true)

func get_catalog() -> Array[Dictionary]:
	if accessory_catalog.is_empty():
		reload_catalog()
	return accessory_catalog.duplicate(true)

func reset_run() -> void:
	equipped_accessory = EMPTY_ACCESSORY.duplicate(true)
	current_choices.clear()
	base_stats_by_actor.clear()
	choice_cursor = 0
	accessory_equipped.emit(equipped_accessory)

func get_equipped_accessory() -> Dictionary:
	return equipped_accessory.duplicate(true)

func generate_choices(count: int = 3) -> Array[Dictionary]:
	var pool := get_catalog()
	var choices: Array[Dictionary] = []
	if pool.is_empty():
		return choices
	var equipped_id := String(equipped_accessory.get("id", "none"))
	var attempts := 0
	while choices.size() < count and attempts < pool.size() * 3:
		var index := (choice_cursor + attempts * 3 + choices.size()) % pool.size()
		var candidate: Dictionary = pool[index]
		attempts += 1
		if String(candidate.get("id", "")) == equipped_id:
			continue
		var duplicate := false
		for existing in choices:
			if String(existing.get("id", "")) == String(candidate.get("id", "")):
				duplicate = true
				break
		if duplicate:
			continue
		choices.append(candidate.duplicate(true))
	choice_cursor = (choice_cursor + 2) % max(pool.size(), 1)
	current_choices = choices
	choices_generated.emit(current_choices)
	return choices

func equip(accessory_id: String, actor: Node = null) -> Dictionary:
	var accessory := get_accessory(accessory_id)
	if accessory.is_empty():
		return equipped_accessory
	equipped_accessory = accessory.duplicate(true)
	if actor != null:
		apply_to_actor(actor)
	accessory_equipped.emit(equipped_accessory)
	return equipped_accessory

func keep_current(actor: Node = null) -> Dictionary:
	if actor != null:
		apply_to_actor(actor)
	accessory_equipped.emit(equipped_accessory)
	return equipped_accessory

func get_accessory(accessory_id: String) -> Dictionary:
	if accessory_id == "none":
		return EMPTY_ACCESSORY.duplicate(true)
	for accessory in get_catalog():
		if String(accessory.get("id", "")) == accessory_id:
			return accessory.duplicate(true)
	return {}

func _load_catalog_from_json() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	if not FileAccess.file_exists(ACCESSORY_DATA_PATH):
		return catalog
	var raw := FileAccess.get_file_as_string(ACCESSORY_DATA_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Array):
		push_warning("Accessory data is not an array: %s" % ACCESSORY_DATA_PATH)
		return catalog
	for entry in parsed:
		if not (entry is Dictionary):
			continue
		var accessory: Dictionary = (entry as Dictionary).duplicate(true)
		if _is_valid_accessory(accessory):
			catalog.append(accessory)
	return catalog

func _is_valid_accessory(accessory: Dictionary) -> bool:
	for required in ["id", "name", "rarity", "icon", "summary", "effects", "tags"]:
		if not accessory.has(required):
			push_warning("Accessory missing field '%s': %s" % [required, accessory])
			return false
	return true

func apply_to_actor(actor: Node) -> void:
	if actor == null:
		return
	var hp_ratio := _ratio(actor, "hp", "max_hp")
	var defense_ratio := _ratio(actor, "defense", "max_defense")
	var current_inspiration := float(actor.get("inspiration")) if _has_property(actor, "inspiration") else 0.0
	_capture_base_stats(actor)
	_restore_base_stats(actor)
	_apply_effects(actor, equipped_accessory.get("effects", {}))
	_sync_actor_health(actor, hp_ratio, defense_ratio, current_inspiration)
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

func describe_effects(accessory: Dictionary) -> String:
	var effects: Dictionary = accessory.get("effects", {})
	if effects.is_empty():
		return "No active stat change."
	var parts: Array[String] = []
	for key in effects.keys():
		var value := float(effects[key])
		parts.append(_format_effect(String(key), value))
	return ", ".join(parts)

func _capture_base_stats(actor: Node) -> void:
	var actor_id := actor.get_instance_id()
	if base_stats_by_actor.has(actor_id):
		return
	var stats := {}
	for field in STAT_FIELDS:
		if _has_property(actor, field):
			stats[field] = actor.get(field)
	base_stats_by_actor[actor_id] = stats

func _restore_base_stats(actor: Node) -> void:
	var actor_id := actor.get_instance_id()
	if not base_stats_by_actor.has(actor_id):
		return
	var stats: Dictionary = base_stats_by_actor[actor_id]
	for field in stats.keys():
		if _has_property(actor, String(field)):
			actor.set(field, stats[field])

func _apply_effects(actor: Node, effects: Dictionary) -> void:
	for key in effects.keys():
		var value := float(effects[key])
		match String(key):
			"max_hp", "max_inspiration", "max_defense", "defense", "move_speed", "attack_damage", "crit_rate", "inspiration_gain_on_attack_hit":
				_add(actor, String(key), value)
			"move_speed_pct":
				_scale(actor, "move_speed", 1.0 + value)
			"attack_damage_pct":
				_scale(actor, "attack_damage", 1.0 + value)
			"attack_interval_pct":
				_scale(actor, "attack_interval", 1.0 + value, 0.15)
			"skill_cooldown_pct":
				for field in ["skill1_cooldown", "skill2_cooldown", "skill3_cooldown"]:
					_scale(actor, field, 1.0 + value, 0.0)
			"skill_cost_pct":
				for field in ["skill1_cost", "skill2_cost", "skill3_cost"]:
					_scale(actor, field, 1.0 + value, 0.0)
			"skill_damage_pct":
				for field in ["skill1_damage", "skill2_damage", "skill3_damage"]:
					_scale(actor, field, 1.0 + value, 0.0)

func _sync_actor_health(actor: Node, hp_ratio: float, defense_ratio: float, current_inspiration: float) -> void:
	if _has_property(actor, "max_hp") and _has_property(actor, "hp"):
		actor.hp = clampf(float(actor.max_hp) * hp_ratio, 0.0, float(actor.max_hp))
		if actor.hp <= 0.0:
			actor.hp = float(actor.max_hp)
	if _has_property(actor, "max_inspiration") and _has_property(actor, "inspiration"):
		actor.inspiration = minf(current_inspiration, float(actor.max_inspiration))
	if _has_property(actor, "max_defense"):
		if _has_property(actor, "defense"):
			actor.defense = clampf(float(actor.max_defense) * defense_ratio, 0.0, float(actor.max_defense))
		var health_component: Node = actor.get("health_component") if _has_property(actor, "health_component") else null
		if health_component != null and health_component.has_method("setup"):
			health_component.setup(float(actor.max_hp), float(actor.max_defense))
			if _has_property(actor, "hp"):
				health_component.hp = float(actor.hp)
			if _has_property(actor, "defense"):
				health_component.defense = float(actor.defense)

func _add(actor: Node, field: String, value: float) -> void:
	if not _has_property(actor, field):
		return
	actor.set(field, float(actor.get(field)) + value)

func _scale(actor: Node, field: String, multiplier: float, floor_value: float = -INF) -> void:
	if not _has_property(actor, field):
		return
	var next_value := float(actor.get(field)) * multiplier
	if floor_value != -INF:
		next_value = maxf(next_value, floor_value)
	actor.set(field, next_value)

func _has_property(actor: Node, field: String) -> bool:
	for property in actor.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false

func _ratio(actor: Node, current_field: String, max_field: String) -> float:
	if not _has_property(actor, current_field) or not _has_property(actor, max_field):
		return 1.0
	var max_value := float(actor.get(max_field))
	if max_value <= 0.0:
		return 1.0
	return clampf(float(actor.get(current_field)) / max_value, 0.0, 1.0)

func _format_effect(key: String, value: float) -> String:
	var label := key.replace("_pct", "").replace("_", " ").capitalize()
	if key.ends_with("_pct"):
		return "%s %+d%%" % [label, int(round(value * 100.0))]
	if key == "crit_rate":
		return "%s %+d%%" % [label, int(round(value * 100.0))]
	var sign := "+" if value >= 0.0 else ""
	return "%s %s%.1f" % [label, sign, value]
