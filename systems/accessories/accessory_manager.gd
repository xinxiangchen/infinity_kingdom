extends Node

signal accessory_equipped(accessory: Dictionary)
signal choices_generated(choices: Array[Dictionary])

const ACCESSORY_DATA_PATH := "res://systems/accessories/accessories.json"
const TAG_LABELS := {
	"attack": "Attack",
	"crit": "Crit",
	"damage": "Damage",
	"defense": "Defense",
	"power": "Power",
	"resource": "Resource",
	"risk": "Risk",
	"skill": "Skill",
	"speed": "Speed",
	"survival": "Survival",
	"tempo": "Tempo"
}

const TAG_PLAYSTYLE_HINTS := {
	"attack": "Improves repeated basic pressure and rewards staying on target.",
	"crit": "Raises burst variance and scales best with fast hit volume.",
	"damage": "Pushes direct kill speed and helps finish elite checks sooner.",
	"defense": "Restores armor value and buys room for mistakes in long fights.",
	"power": "Favors skill-centered burst windows over attrition.",
	"resource": "Feeds inspiration economy so your strongest tools come back sooner.",
	"risk": "Pays off hardest when you stay aggressive on low health.",
	"skill": "Supports cooldown, control, and direct skill conversion.",
	"speed": "Makes dodges, flanks, and reposition checks easier to pass cleanly.",
	"survival": "Stabilizes rough runs and softens recovery mistakes.",
	"tempo": "Keeps momentum rolling once you start landing skills or kills."
}

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

const DIRECT_SKILL_ATTACKS := {
	&"skill1": true,
	&"skill2": true,
	&"skill3": true
}

var equipped_accessory: Dictionary = EMPTY_ACCESSORY.duplicate(true)
var current_choices: Array[Dictionary] = []
var base_stats_by_actor: Dictionary = {}
var combat_proc_ready_at: Dictionary = {}
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
	combat_proc_ready_at.clear()
	choice_cursor = 0
	accessory_equipped.emit(equipped_accessory)

func get_equipped_accessory() -> Dictionary:
	return equipped_accessory.duplicate(true)

func get_equipped_tags() -> Array[String]:
	var tags: Array[String] = []
	for tag in equipped_accessory.get("tags", []):
		var next_tag := String(tag)
		if next_tag.is_empty() or tags.has(next_tag):
			continue
		tags.append(next_tag)
	return tags

func describe_tags(tags: Array = []) -> String:
	var source_tags := tags
	if source_tags.is_empty():
		source_tags = get_equipped_tags()
	var parts: Array[String] = []
	for tag in source_tags:
		var next_tag := String(tag)
		if next_tag.is_empty():
			continue
		parts.append(String(TAG_LABELS.get(next_tag, next_tag.capitalize())))
	return ", ".join(parts)

func describe_playstyle(tags: Array = []) -> String:
	var source_tags := tags
	if source_tags.is_empty():
		source_tags = get_equipped_tags()
	var hints: Array[String] = []
	for tag in source_tags:
		var next_tag := String(tag)
		if next_tag.is_empty():
			continue
		var hint := String(TAG_PLAYSTYLE_HINTS.get(next_tag, ""))
		if hint.is_empty() or hints.has(hint):
			continue
		hints.append(hint)
		if hints.size() >= 2:
			break
	return " ".join(hints)

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

func build_hit_payload(actor: Node, attack_name: StringName, base_damage: float, base_crit_rate: float, extra_payload: Dictionary = {}) -> Dictionary:
	var payload := {
		"source": actor,
		"damage": base_damage,
		"crit_rate": base_crit_rate
	}
	for key in extra_payload.keys():
		payload[key] = extra_payload[key]
	return enhance_hit_payload(actor, attack_name, payload)

func enhance_hit_payload(actor: Node, attack_name: StringName, payload: Dictionary) -> Dictionary:
	var enhanced := payload.duplicate(true)
	var tags := get_equipped_tags()
	if tags.is_empty():
		return enhanced
	var damage_value := float(enhanced.get("damage", 0.0))
	if tags.has("crit"):
		enhanced["crit_rate"] = float(enhanced.get("crit_rate", 0.0)) + 0.08
	if tags.has("attack") and attack_name == &"attack":
		damage_value += maxf(4.0, damage_value * 0.06)
		enhanced["damage"] = damage_value
	if tags.has("power") and _is_direct_skill_attack(attack_name):
		damage_value += maxf(8.0, damage_value * 0.08)
		enhanced["damage"] = damage_value
	if tags.has("risk") and _ratio(actor, "hp", "max_hp") <= 0.55:
		damage_value *= 1.12
		enhanced["damage"] = damage_value
	if tags.has("damage") and _is_direct_skill_attack(attack_name):
		_merge_payload_max(enhanced, "damage_multiplier", 1.12)
		_merge_payload_max(enhanced, "damage_multiplier_duration", 2.25)
	return enhanced

func apply_on_hit_effects(actor: Node, attack_name: StringName, target: Node) -> void:
	if actor == null:
		return
	var tags := get_equipped_tags()
	if tags.is_empty():
		return
	if tags.has("resource") and _consume_combat_proc(actor, "resource_flow", 0.18):
		_grant_inspiration(actor, 1.0 if _is_direct_skill_attack(attack_name) else 0.5)
	if tags.has("attack") and attack_name == &"attack":
		_refund_cooldown(actor, "attack", 0.08)
	if tags.has("tempo") and _is_direct_skill_attack(attack_name):
		_refund_cooldown(actor, String(attack_name), 0.32)
	if tags.has("skill") and _is_direct_skill_attack(attack_name) and _consume_combat_proc(actor, "skill_silence", 0.55):
		_try_apply_target_control(target, {"silence_duration": 1.0})
	if tags.has("speed") and (attack_name == &"attack" or attack_name == &"skill1") and _consume_combat_proc(actor, "speed_slow", 0.35):
		_try_apply_target_control(target, {"slow_duration": 1.15, "slow_multiplier": 0.82})
	if tags.has("defense") and _is_direct_skill_attack(attack_name) and _consume_combat_proc(actor, "defense_guard", 0.55):
		_restore_defense_or_shield(actor, 10.0, 10.0)
	if tags.has("survival") and _ratio(actor, "hp", "max_hp") <= 0.5 and _consume_combat_proc(actor, "survival_heal", 1.2):
		_heal_actor(actor, 4.0)

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
	if actor == null:
		return false
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

func _is_direct_skill_attack(attack_name: StringName) -> bool:
	return DIRECT_SKILL_ATTACKS.has(attack_name)

func _merge_payload_max(payload: Dictionary, key: String, value: float) -> void:
	payload[key] = maxf(float(payload.get(key, 0.0)), value)

func _consume_combat_proc(actor: Node, proc_name: String, cooldown: float) -> bool:
	if actor == null:
		return false
	var proc_key := "%s:%s" % [actor.get_instance_id(), proc_name]
	var now := Time.get_ticks_msec() * 0.001
	if now < float(combat_proc_ready_at.get(proc_key, 0.0)):
		return false
	combat_proc_ready_at[proc_key] = now + cooldown
	return true

func _grant_inspiration(actor: Node, amount: float) -> void:
	if amount <= 0.0:
		return
	if actor.has_method("gain_inspiration"):
		actor.gain_inspiration(amount)
		return
	if not _has_property(actor, "inspiration") or not _has_property(actor, "max_inspiration"):
		return
	actor.inspiration = clampf(float(actor.inspiration) + amount, 0.0, float(actor.max_inspiration))
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

func _refund_cooldown(actor: Node, cooldown_key: String, amount: float) -> void:
	if amount <= 0.0 or not _has_property(actor, "cooldowns"):
		return
	var cooldowns_value: Variant = actor.get("cooldowns")
	if not (cooldowns_value is Dictionary):
		return
	var cooldowns: Dictionary = cooldowns_value
	if not cooldowns.has(cooldown_key):
		return
	cooldowns[cooldown_key] = maxf(float(cooldowns[cooldown_key]) - amount, 0.0)
	actor.set("cooldowns", cooldowns)

func _restore_defense_or_shield(actor: Node, defense_amount: float, shield_amount: float) -> void:
	var health_component := _get_health_component(actor)
	if health_component != null:
		var current_defense := float(health_component.get("defense"))
		var max_defense_value := float(health_component.get("max_defense"))
		if max_defense_value > 0.0 and current_defense < max_defense_value:
			health_component.defense = minf(current_defense + defense_amount, max_defense_value)
			health_component.defense_changed.emit(float(health_component.defense), max_defense_value)
			return
		if health_component.has_method("apply_shield"):
			health_component.apply_shield(shield_amount)
			return
	if _has_property(actor, "defense") and _has_property(actor, "max_defense"):
		if float(actor.defense) < float(actor.max_defense):
			actor.defense = minf(float(actor.defense) + defense_amount, float(actor.max_defense))
		elif _has_property(actor, "shield"):
			actor.shield = float(actor.get("shield")) + shield_amount
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

func _heal_actor(actor: Node, amount: float) -> void:
	if amount <= 0.0:
		return
	if actor.has_method("heal"):
		actor.heal(amount)
		return
	if not _has_property(actor, "hp") or not _has_property(actor, "max_hp"):
		return
	actor.hp = clampf(float(actor.hp) + amount, 0.0, float(actor.max_hp))
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

func _try_apply_target_control(target: Node, payload: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_control_effects"):
		target.apply_control_effects(payload)

func _get_health_component(actor: Node) -> Node:
	if actor == null:
		return null
	return actor.get_node_or_null("HealthComponent")
