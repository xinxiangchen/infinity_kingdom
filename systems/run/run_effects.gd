class_name RunEffects
extends RefCounted

const ATTUNEMENT_TAG_MAP := {
	"attack": "attune_offense",
	"crit": "attune_gambit",
	"damage": "attune_offense",
	"defense": "attune_guard",
	"power": "attune_offense",
	"resource": "attune_focus",
	"risk": "attune_gambit",
	"skill": "attune_focus",
	"speed": "attune_flow",
	"survival": "attune_guard",
	"tempo": "attune_flow"
}

const ATTUNEMENT_FILL_ORDER := [
	"attune_offense",
	"attune_focus",
	"attune_guard",
	"attune_flow",
	"attune_gambit"
]

const ATTUNEMENT_CHOICE_DATA := {
	"attune_offense": {
		"title": "Battle Temper",
		"summary": "+12% attack damage and +4% crit chance.",
		"icon": "res://assets/ui/trait/trait_damage.png"
	},
	"attune_focus": {
		"title": "Echo Circuit",
		"summary": "+10 max inspiration and faster skill recovery.",
		"icon": "res://assets/ui/trait/trait_echo.png"
	},
	"attune_guard": {
		"title": "Warden Seal",
		"summary": "+16 max defense, +6 max hp, and restore armor.",
		"icon": "res://assets/ui/icon/ui_shield.png"
	},
	"attune_flow": {
		"title": "Wind Rhythm",
		"summary": "+10% move speed, faster attacks, and more inspiration on hit.",
		"icon": "res://assets/ui/icon/stat_speed_pixel.png"
	},
	"attune_gambit": {
		"title": "Last Nerve",
		"summary": "+8% crit chance and +10% skill damage, but skills cost more inspiration.",
		"icon": "res://assets/ui/trait/trait_execute.png"
	}
}

const SCOUT_CHOICE_DATA := {
	"scout_assault": {
		"title": "Assault Route",
		"summary": "Next encounter: +14% attack damage, +6% crit chance, and +30 gold on clear.",
		"icon": "res://assets/ui/trait/trait_damage.png",
		"prep": {
			"title": "Assault Route",
			"summary": "Opening assault: +14% attack damage, +6% crit chance, and +30 gold on clear.",
			"temporary_effects": {
				"attack_damage_pct": 0.14,
				"crit_rate": 0.06
			},
			"reward_bonus": 30
		}
	},
	"scout_bulwark": {
		"title": "Bulwark Route",
		"summary": "Next encounter: full defense, +45 shield, and +10% move speed.",
		"icon": "res://assets/ui/icon/ui_shield.png",
		"prep": {
			"title": "Bulwark Route",
			"summary": "Defensive opener: restore defense, gain +45 shield, and +10% move speed.",
			"restore_defense": true,
			"shield": 45.0,
			"temporary_effects": {
				"move_speed_pct": 0.10
			},
			"clear_shield_on_end": true
		}
	},
	"scout_focus": {
		"title": "Focus Route",
		"summary": "Next encounter: full inspiration and 18% faster skill cooldowns.",
		"icon": "res://assets/ui/icon/ui_mana_flame.png",
		"prep": {
			"title": "Focus Route",
			"summary": "Prepared casting: restore inspiration and reduce skill cooldowns by 18%.",
			"restore_inspiration": true,
			"temporary_effects": {
				"skill_cooldown_pct": -0.18
			}
		}
	}
}

const HERO_TAG_PROFILES := {
	"Knight": ["defense", "survival", "power"],
	"Ranger": ["crit", "speed", "tempo", "damage"],
	"Mage": ["skill", "resource", "power"]
}

const CHOICE_TAGS := {
	"shop_attack": ["attack", "damage"],
	"shop_defense": ["defense", "survival"],
	"shop_relic": ["resource", "tempo"],
	"bounty_cache": ["resource"],
	"bounty_contract": ["resource", "tempo"],
	"bounty_tithe": ["risk", "damage"],
	"rest_heal": ["survival"],
	"rest_focus": ["defense", "resource", "skill"],
	"rest_repair": ["defense", "survival"],
	"train_crit": ["crit", "damage"],
	"train_speed": ["speed", "tempo"],
	"train_cooldown": ["skill", "tempo", "resource"],
	"train_resource": ["resource", "skill"],
	"pact_power": ["power", "damage", "risk"],
	"pact_guard": ["defense", "survival"],
	"pact_focus": ["skill", "resource", "power"],
	"scout_assault": ["damage", "crit", "tempo"],
	"scout_bulwark": ["defense", "survival", "speed"],
	"scout_focus": ["skill", "resource", "tempo"],
	"attune_offense": ["damage", "crit"],
	"attune_focus": ["skill", "resource"],
	"attune_guard": ["defense", "survival"],
	"attune_flow": ["speed", "tempo"],
	"attune_gambit": ["crit", "risk", "damage"]
}

static func apply_choice(choice_id: String, actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var persistent_changed := false
	var restore_defense_after_refresh := false
	match choice_id:
		"shop_attack":
			RunDirector.add_run_modifier("attack_damage", 0.0, 1.10)
			persistent_changed = true
		"shop_defense":
			RunDirector.add_run_modifier("max_defense", 12.0)
			persistent_changed = true
			restore_defense_after_refresh = true
		"shop_relic":
			pass
		"bounty_cache":
			RunDirector.grant_gold(40)
		"bounty_contract":
			RunDirector.add_reward_flat_bonus(18)
		"bounty_tithe":
			RunDirector.add_reward_multiplier(1.28)
			RunDirector.add_run_modifier("max_hp", -10.0, 1.0, 28.0)
			persistent_changed = true
		"rest_heal":
			heal_percent(actor, 0.45)
		"rest_focus":
			restore_defense(actor)
			restore_inspiration(actor)
		"rest_repair":
			RunDirector.add_run_modifier("max_hp", 8.0)
			persistent_changed = true
			restore_defense_after_refresh = true
		"train_crit":
			RunDirector.add_run_modifier("crit_rate", 0.05)
			persistent_changed = true
		"train_speed":
			RunDirector.add_run_modifier("move_speed", 0.0, 1.08)
			persistent_changed = true
		"train_cooldown":
			for field in ["skill1_cooldown", "skill2_cooldown", "skill3_cooldown"]:
				RunDirector.add_run_modifier(field, 0.0, 0.94, 0.0)
			persistent_changed = true
		"train_resource":
			RunDirector.add_run_modifier("max_inspiration", 12.0)
			persistent_changed = true
		"pact_power":
			RunDirector.add_run_modifier("attack_damage", 0.0, 1.18)
			for field in ["skill1_damage", "skill2_damage", "skill3_damage"]:
				RunDirector.add_run_modifier(field, 0.0, 1.10, 0.0)
			for field in ["skill1_cost", "skill2_cost", "skill3_cost"]:
				RunDirector.add_run_modifier(field, 0.0, 1.12, 0.0)
			persistent_changed = true
		"pact_guard":
			RunDirector.add_run_modifier("max_defense", 28.0)
			RunDirector.add_run_modifier("move_speed", 0.0, 0.90, 0.0)
			persistent_changed = true
			restore_defense_after_refresh = true
		"pact_focus":
			RunDirector.add_run_modifier("max_inspiration", 20.0)
			RunDirector.add_run_modifier("max_hp", -12.0, 1.0, 30.0)
			for field in ["skill1_cooldown", "skill2_cooldown", "skill3_cooldown"]:
				RunDirector.add_run_modifier(field, 0.0, 0.92, 0.0)
			persistent_changed = true
		"scout_assault", "scout_bulwark", "scout_focus":
			RunDirector.set_pending_encounter_prep(_scout_prep_for_choice(choice_id))
		"attune_offense":
			RunDirector.add_run_modifier("attack_damage", 0.0, 1.12)
			RunDirector.add_run_modifier("crit_rate", 0.04)
			persistent_changed = true
		"attune_focus":
			RunDirector.add_run_modifier("max_inspiration", 10.0)
			for field in ["skill1_cooldown", "skill2_cooldown", "skill3_cooldown"]:
				RunDirector.add_run_modifier(field, 0.0, 0.92, 0.0)
			persistent_changed = true
		"attune_guard":
			RunDirector.add_run_modifier("max_defense", 16.0)
			RunDirector.add_run_modifier("max_hp", 6.0)
			persistent_changed = true
			restore_defense_after_refresh = true
		"attune_flow":
			RunDirector.add_run_modifier("move_speed", 0.0, 1.10)
			RunDirector.add_run_modifier("attack_interval", 0.0, 0.94, 0.15)
			RunDirector.add_run_modifier("inspiration_gain_on_attack_hit", 0.8)
			persistent_changed = true
		"attune_gambit":
			RunDirector.add_run_modifier("crit_rate", 0.08)
			for field in ["skill1_damage", "skill2_damage", "skill3_damage"]:
				RunDirector.add_run_modifier(field, 0.0, 1.10, 0.0)
			for field in ["skill1_cost", "skill2_cost", "skill3_cost"]:
				RunDirector.add_run_modifier(field, 0.0, 1.08, 0.0)
			persistent_changed = true
	if persistent_changed:
		refresh_persistent_modifiers(actor)
	if restore_defense_after_refresh:
		restore_defense(actor)
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

static func refresh_persistent_modifiers(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	AccessoryManager.apply_to_actor(actor)
	RunDirector.apply_run_modifiers(actor)

static func can_pay(choice_id: String, gold: int) -> bool:
	return gold >= cost_for(choice_id)

static func cost_for(choice_id: String) -> int:
	match choice_id:
		"shop_attack":
			return 45
		"shop_defense":
			return 40
		"shop_relic":
			return 55
		_:
			return 0

static func summary(choice_id: String) -> String:
	match choice_id:
		"shop_attack":
			return "Sharpening Oil applied."
		"shop_defense":
			return "Armor reinforced."
		"shop_relic":
			return "A hidden relic cache is marked."
		"bounty_cache":
			return "Immediate gold claimed."
		"bounty_contract":
			return "Future bounty payments improved."
		"bounty_tithe":
			return "High-risk contract signed."
		"rest_heal":
			return "Health restored."
		"rest_focus":
			return "Inspiration and defense restored."
		"rest_repair":
			return "Armor repaired and vitality improved."
		"train_crit":
			return "Precision training complete."
		"train_speed":
			return "Footwork training complete."
		"train_cooldown":
			return "Skill rhythm improved."
		"train_resource":
			return "Inspiration capacity expanded."
		"pact_power":
			return "Blood Price accepted."
		"pact_guard":
			return "Iron Oath accepted."
		"pact_focus":
			return "Astral Debt accepted."
		"scout_assault":
			return "Assault route prepared."
		"scout_bulwark":
			return "Bulwark route prepared."
		"scout_focus":
			return "Focus route prepared."
		"attune_offense":
			return "Battle Temper attuned."
		"attune_focus":
			return "Echo Circuit attuned."
		"attune_guard":
			return "Warden Seal attuned."
		"attune_flow":
			return "Wind Rhythm attuned."
		"attune_gambit":
			return "Last Nerve attuned."
		_:
			return "You move on."

static func display_name(choice_id: String) -> String:
	match choice_id:
		"shop_attack":
			return "Sharpening Oil"
		"shop_defense":
			return "Light Armor Pack"
		"shop_relic":
			return "Relic Map"
		"bounty_cache":
			return "Open Purse"
		"bounty_contract":
			return "Steady Contract"
		"bounty_tithe":
			return "Risk Contract"
		"rest_heal":
			return "Medkit"
		"rest_focus":
			return "Protective Candle"
		"rest_repair":
			return "Field Repair"
		"train_crit":
			return "Precision"
		"train_speed":
			return "Footwork"
		"train_cooldown":
			return "Rhythm"
		"train_resource":
			return "Focus Drill"
		"pact_power":
			return "Blood Price"
		"pact_guard":
			return "Iron Oath"
		"pact_focus":
			return "Astral Debt"
		"skip":
			return "Skip"
	if ATTUNEMENT_CHOICE_DATA.has(choice_id):
		return String((ATTUNEMENT_CHOICE_DATA.get(choice_id, {}) as Dictionary).get("title", choice_id))
	if SCOUT_CHOICE_DATA.has(choice_id):
		return String((SCOUT_CHOICE_DATA.get(choice_id, {}) as Dictionary).get("title", choice_id))
	return choice_id.capitalize()

static func attunement_choices() -> Array[Dictionary]:
	var categories: Array[String] = []
	for tag in AccessoryManager.get_equipped_tags():
		var choice_id := String(ATTUNEMENT_TAG_MAP.get(String(tag), ""))
		if choice_id.is_empty() or categories.has(choice_id):
			continue
		categories.append(choice_id)
	for fallback in ATTUNEMENT_FILL_ORDER:
		if categories.size() >= 3:
			break
		if categories.has(fallback):
			continue
		categories.append(fallback)
	var choices: Array[Dictionary] = []
	for choice_id in categories:
		if choices.size() >= 3:
			break
		var data: Dictionary = (ATTUNEMENT_CHOICE_DATA.get(choice_id, {}) as Dictionary).duplicate(true)
		if data.is_empty():
			continue
		data["id"] = choice_id
		data["cost"] = 0
		choices.append(data)
	return choices

static func scout_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for choice_id in ["scout_assault", "scout_bulwark", "scout_focus"]:
		var data: Dictionary = (SCOUT_CHOICE_DATA.get(choice_id, {}) as Dictionary).duplicate(true)
		if data.is_empty():
			continue
		data["id"] = choice_id
		data["cost"] = 0
		choices.append(data)
	return choices

static func choice_tags(choice_id: String) -> Array[String]:
	var tags: Array[String] = []
	for tag in CHOICE_TAGS.get(choice_id, []):
		var next_tag := String(tag)
		if next_tag.is_empty() or tags.has(next_tag):
			continue
		tags.append(next_tag)
	return tags

static func evaluate_choice(choice_id: String, actor: Node = null) -> Dictionary:
	if choice_id == "skip":
		return {
			"label": "Hold",
			"color": Color(0.76, 0.82, 0.90),
			"reason": "Passing keeps the current route and build unchanged."
		}
	var relic_tags := AccessoryManager.get_equipped_tags()
	var hero_name := _hero_name(actor)
	var hero_tags: Array[String] = []
	for tag in HERO_TAG_PROFILES.get(hero_name, []):
		var next_tag := String(tag)
		if next_tag.is_empty() or hero_tags.has(next_tag):
			continue
		hero_tags.append(next_tag)
	var effect_tags := choice_tags(choice_id)
	var relic_matches: Array[String] = []
	var hero_matches: Array[String] = []
	for tag in effect_tags:
		if relic_tags.has(tag) and not relic_matches.has(tag):
			relic_matches.append(tag)
		if hero_tags.has(tag) and not hero_matches.has(tag):
			hero_matches.append(tag)

	var hp_ratio := _ratio(actor, "hp", "max_hp")
	var defense_ratio := _ratio(actor, "defense", "max_defense")
	var inspiration_ratio := _ratio(actor, "inspiration", "max_inspiration")
	var score := relic_matches.size() * 2 + hero_matches.size()
	var reasons: Array[String] = []
	if not relic_matches.is_empty():
		reasons.append("Matches relic tags: %s." % AccessoryManager.describe_tags(relic_matches))
	if not hero_matches.is_empty() and not hero_name.is_empty():
		reasons.append("Plays well with %s's preferred lane." % hero_name)
	if choice_id == "rest_heal" and hp_ratio <= 0.55:
		score += 3
		reasons.append("Your health margin is low enough that raw healing is premium.")
	if choice_id == "rest_focus" and (defense_ratio <= 0.35 or inspiration_ratio <= 0.35):
		score += 2
		reasons.append("You are short on armor or inspiration for the next check.")
	if choice_id == "scout_assault" and hp_ratio >= 0.70:
		score += 2
		reasons.append("Your health buffer is healthy enough to cash in on a fast opener.")
	if choice_id == "scout_bulwark" and (hp_ratio <= 0.55 or defense_ratio <= 0.35):
		score += 3
		reasons.append("This covers a weak defensive start and buys room to stabilize.")
	if choice_id == "scout_focus" and inspiration_ratio <= 0.45:
		score += 2
		reasons.append("Your inspiration economy is low enough that a reset is meaningful.")
	if choice_id == "shop_defense" and defense_ratio <= 0.40:
		score += 2
		reasons.append("Defense is already thin, so armor value is immediate.")
	if choice_id == "train_resource" and inspiration_ratio <= 0.40:
		score += 2
		reasons.append("Your hero is running close to inspiration pressure.")
	if choice_id == "shop_relic" and AccessoryManager.get_equipped_tags().is_empty():
		score += 2
		reasons.append("An extra relic is strongest when your build identity is still thin.")
	if choice_id in ["bounty_tithe", "pact_power", "attune_gambit"] and hp_ratio <= 0.42:
		score -= 3
		reasons.append("This stacks risk while your current health buffer is already narrow.")
	if choice_id == "pact_guard" and hero_name == "Ranger":
		score -= 1
		reasons.append("The move-speed tax cuts into Ranger's cleanest advantage.")

	var label := "Flexible"
	var color := Color(0.80, 0.88, 1.0)
	if score >= 5:
		label = "Best Now"
		color = Color(0.78, 0.96, 0.82)
	elif score >= 2:
		label = "Strong Fit"
		color = Color(0.92, 0.90, 0.66)
	elif score >= 0:
		label = "Flexible"
		color = Color(0.80, 0.88, 1.0)
	else:
		label = "Risky"
		color = Color(1.0, 0.76, 0.70)

	return {
		"label": label,
		"color": color,
		"reason": reasons[0] if not reasons.is_empty() else "Keeps the run moving without a special synergy hook."
	}

static func activate_encounter_prep(actor: Node, prep: Dictionary) -> void:
	if actor == null or not is_instance_valid(actor) or prep.is_empty():
		return
	if bool(prep.get("restore_defense", false)):
		restore_defense(actor)
	if bool(prep.get("restore_inspiration", false)):
		restore_inspiration(actor)
	apply_shield(actor, float(prep.get("shield", 0.0)))
	apply_temporary_effects(actor, prep.get("temporary_effects", {}) as Dictionary)
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

static func apply_temporary_effects(actor: Node, effects: Dictionary) -> void:
	if actor == null or not is_instance_valid(actor) or effects.is_empty():
		return
	for key in effects.keys():
		var value := float(effects[key])
		match String(key):
			"max_hp", "max_inspiration", "max_defense", "defense", "move_speed", "attack_damage", "crit_rate", "inspiration_gain_on_attack_hit":
				_apply_actor_flat(actor, String(key), value)
			"move_speed_pct":
				_apply_actor_percent(actor, "move_speed", value)
			"attack_damage_pct":
				_apply_actor_percent(actor, "attack_damage", value)
			"attack_interval_pct":
				_scale_actor(actor, "attack_interval", 1.0 + value, 0.15)
			"skill_cooldown_pct":
				for field in ["skill1_cooldown", "skill2_cooldown", "skill3_cooldown"]:
					_scale_actor(actor, field, 1.0 + value, 0.0)
			"skill_cost_pct":
				for field in ["skill1_cost", "skill2_cost", "skill3_cost"]:
					_scale_actor(actor, field, 1.0 + value, 0.0)
			"skill_damage_pct":
				for field in ["skill1_damage", "skill2_damage", "skill3_damage"]:
					_scale_actor(actor, field, 1.0 + value, 0.0)

static func apply_shield(actor: Node, amount: float) -> void:
	if actor == null or not is_instance_valid(actor) or amount <= 0.0:
		return
	var health_component := _health_component(actor)
	if health_component != null and health_component.has_method("apply_shield"):
		health_component.apply_shield(amount)
	elif _has_property(actor, "shield"):
		actor.shield = float(actor.get("shield")) + amount
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

static func clear_shield(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var health_component := _health_component(actor)
	if health_component != null and health_component.has_method("clear_shield"):
		health_component.clear_shield()
	elif _has_property(actor, "shield"):
		actor.shield = 0.0
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

static func heal_percent(actor: Node, percent: float) -> void:
	if not _has_property(actor, "max_hp") or not actor.has_method("heal"):
		return
	actor.heal(float(actor.max_hp) * percent)

static func restore_defense(actor: Node) -> void:
	var health_component: Node = actor.get("health_component") if _has_property(actor, "health_component") else null
	if health_component != null and health_component.has_method("restore_defense_full"):
		health_component.restore_defense_full()
	if _has_property(actor, "defense") and _has_property(actor, "max_defense"):
		actor.defense = actor.max_defense

static func restore_inspiration(actor: Node) -> void:
	if _has_property(actor, "inspiration") and _has_property(actor, "max_inspiration"):
		actor.inspiration = actor.max_inspiration

static func _apply_actor_flat(actor: Node, field: String, amount: float) -> void:
	if not _has_property(actor, field):
		return
	actor.set(field, float(actor.get(field)) + amount)

static func _apply_actor_percent(actor: Node, field: String, percent: float) -> void:
	if not _has_property(actor, field):
		return
	actor.set(field, float(actor.get(field)) * (1.0 + percent))

static func _scale_actor(actor: Node, field: String, multiplier: float, floor_value: float = -INF) -> void:
	if not _has_property(actor, field):
		return
	var next_value := float(actor.get(field)) * multiplier
	if floor_value != -INF:
		next_value = maxf(next_value, floor_value)
	actor.set(field, next_value)

static func _has_property(actor: Node, field: String) -> bool:
	for property in actor.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false

static func _ratio(actor: Node, current_field: String, max_field: String) -> float:
	if actor == null or not is_instance_valid(actor):
		return 1.0
	if not _has_property(actor, current_field) or not _has_property(actor, max_field):
		return 1.0
	var max_value := float(actor.get(max_field))
	if max_value <= 0.0:
		return 1.0
	return clampf(float(actor.get(current_field)) / max_value, 0.0, 1.0)

static func _hero_name(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor) or not actor.has_method("get_character_name"):
		return ""
	return String(actor.get_character_name())

static func _health_component(actor: Node) -> Node:
	if actor == null:
		return null
	return actor.get("health_component") if _has_property(actor, "health_component") else actor.get_node_or_null("HealthComponent")

static func _scout_prep_for_choice(choice_id: String) -> Dictionary:
	var data := SCOUT_CHOICE_DATA.get(choice_id, {}) as Dictionary
	if data.is_empty():
		return {}
	return (data.get("prep", {}) as Dictionary).duplicate(true)
