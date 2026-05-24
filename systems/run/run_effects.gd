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

static func _has_property(actor: Node, field: String) -> bool:
	for property in actor.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false
