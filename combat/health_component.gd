extends Node

signal damaged(amount: float, current_hp: float, source: Node)
signal healed(amount: float, current_hp: float)
signal shield_changed(current_shield: float)
signal defense_changed(current_defense: float, max_defense: float)
signal armor_break_applied(multiplier: float, duration: float)
signal knocked_up(duration: float)
signal died

@export var max_hp: float = 100.0
@export var defense: float = 0.0
@export var defense_regen_delay: float = 8.0
@export_range(0.0, 1.0, 0.01) var defense_regen_percent_per_second: float = 0.1
@export var damage_flash_color: Color = Color(1.0, 0.55, 0.55, 1.0)

var hp: float = 0.0
var shield: float = 0.0
var damage_taken_multiplier: float = 1.0
var owner_damage_reduction: float = 0.0
var max_defense: float = 0.0
var defense_regen_timer: float = 0.0

func _ready() -> void:
	hp = max_hp
	max_defense = defense

func setup(values_max_hp: float, values_defense: float) -> void:
	max_hp = values_max_hp
	max_defense = values_defense
	defense = values_defense
	hp = max_hp
	defense_regen_timer = 0.0
	defense_changed.emit(defense, max_defense)

func _process(delta: float) -> void:
	if hp <= 0.0:
		return
	if defense >= max_defense:
		defense_regen_timer = 0.0
		return
	if defense_regen_timer > 0.0:
		defense_regen_timer = maxf(defense_regen_timer - delta, 0.0)
		return
	var regen_amount := max_defense * defense_regen_percent_per_second * delta
	if regen_amount <= 0.0:
		return
	defense = minf(defense + regen_amount, max_defense)
	defense_changed.emit(defense, max_defense)

func set_damage_reduction(value: float) -> void:
	owner_damage_reduction = clampf(value, 0.0, 0.95)

func set_shield(value: float) -> void:
	shield = maxf(value, 0.0)
	shield_changed.emit(shield)

func apply_shield(value: float) -> void:
	shield += maxf(value, 0.0)
	shield_changed.emit(shield)

func clear_shield() -> void:
	shield = 0.0
	shield_changed.emit(shield)

func restore_defense_full() -> void:
	defense = max_defense
	defense_regen_timer = 0.0
	defense_changed.emit(defense, max_defense)

func heal(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = clampf(hp + amount, 0.0, max_hp)
	healed.emit(amount, hp)

func receive_hit(payload: Dictionary) -> Dictionary:
	var source_value: Variant = payload.get("source", null)
	var source: Node = null
	if is_instance_valid(source_value) and source_value is Node:
		source = source_value
	if _is_owner_cheat_protected():
		return {
			"damage": 0.0,
			"hp_damage": 0.0,
			"defense_damage": 0.0,
			"shield_damage": 0.0,
			"total_damage": 0.0,
			"is_critical": false,
			"remaining_hp": hp,
			"source": source
		}
	var incoming_damage := float(payload.get("damage", 0.0))
	var crit_rate := float(payload.get("crit_rate", 0.0))
	var is_critical := randf() < crit_rate
	var damage_to_defense: float = 0.0
	var damage_to_shield: float = 0.0
	if is_critical:
		incoming_damage *= 1.5
	incoming_damage *= damage_taken_multiplier
	var final_damage := incoming_damage
	final_damage *= maxf(1.0 - owner_damage_reduction, 0.0)
	defense_regen_timer = defense_regen_delay
	if defense > 0.0:
		damage_to_defense = minf(defense, final_damage)
		defense -= damage_to_defense
		final_damage -= damage_to_defense
		defense_changed.emit(defense, max_defense)
	if shield > 0.0:
		damage_to_shield = minf(shield, final_damage)
		shield -= damage_to_shield
		final_damage -= damage_to_shield
		shield_changed.emit(shield)
	var total_damage := damage_to_defense + damage_to_shield + final_damage
	if final_damage > 0.0:
		hp = maxf(hp - final_damage, 0.0)
		damaged.emit(final_damage, hp, source)
	if payload.has("damage_multiplier"):
		var multiplier := float(payload["damage_multiplier"])
		var duration := float(payload.get("damage_multiplier_duration", 0.0))
		if multiplier > 1.0 and duration > 0.0:
			apply_armor_break(multiplier, duration)
	if payload.has("knock_up_duration"):
		var knock_up_duration := float(payload["knock_up_duration"])
		if knock_up_duration > 0.0:
			knocked_up.emit(knock_up_duration)
	var result := {
		"damage": final_damage,
		"hp_damage": final_damage,
		"defense_damage": damage_to_defense,
		"shield_damage": damage_to_shield,
		"total_damage": total_damage,
		"is_critical": is_critical,
		"remaining_hp": hp,
		"source": source
	}
	if hp <= 0.0:
		died.emit()
		result["died"] = true
	return result

func _is_owner_cheat_protected() -> bool:
	if CheatMode == null or not bool(CheatMode.infinite_hp):
		return false
	var holder := get_parent()
	return holder != null and holder.is_in_group("player")

func apply_armor_break(multiplier: float, duration: float) -> void:
	damage_taken_multiplier = multiplier
	armor_break_applied.emit(multiplier, duration)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		damage_taken_multiplier = 1.0
	)
