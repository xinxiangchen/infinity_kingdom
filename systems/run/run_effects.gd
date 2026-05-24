class_name RunEffects
extends RefCounted

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
		_:
			return "You move on."

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
