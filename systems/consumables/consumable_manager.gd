extends Node

signal inventory_changed(slots: Array)
signal consumable_used(consumable_id: String, slot_index: int)

const MAX_SLOTS := 6
const CATALOG := {
	"bandage_pack": {
		"name": "Bandage Pack",
		"short_name": "BDG",
		"summary": "Restore 22% max health.",
		"icon": "res://assets/ui/consumable/bandage_pack.png",
		"tint": Color(0.84, 0.74, 0.64, 1.0)
	},
	"healing_vial": {
		"name": "Healing Vial",
		"short_name": "HP",
		"summary": "Restore 35% max health.",
		"icon": "res://assets/ui/consumable/first_aid_bottle.png",
		"tint": Color(0.62, 1.0, 0.72, 1.0)
	},
	"medkit": {
		"name": "Medkit",
		"short_name": "MED",
		"summary": "Restore 55% max health.",
		"icon": "res://assets/ui/consumable/medkit.png",
		"tint": Color(0.95, 0.86, 0.74, 1.0)
	},
	"armor_patch": {
		"name": "Light Armor Pack",
		"short_name": "DEF",
		"summary": "Restore 45% max defense.",
		"icon": "res://assets/ui/consumable/light_armor_pack.png",
		"tint": Color(0.52, 0.96, 0.92, 1.0)
	},
	"inspiration_ampoule": {
		"name": "Protective Candle",
		"short_name": "IN",
		"summary": "Restore 45% max inspiration.",
		"icon": "res://assets/ui/consumable/protective_candle.png",
		"tint": Color(0.46, 0.72, 1.0, 1.0)
	},
	"edge_oil": {
		"name": "Sharpening Oil",
		"short_name": "ATK",
		"summary": "Next fight: +10% attack damage.",
		"icon": "res://assets/ui/consumable/sharpening_oil.png",
		"tint": Color(1.0, 0.72, 0.46, 1.0)
	}
}
const LOCALIZED_CATALOG := {
	"zh_Hans": {
		"bandage_pack": {
			"name": "绷带包",
			"short_name": "绷带",
			"summary": "恢复 22% 最大生命。"
		},
		"healing_vial": {
			"name": "治疗药瓶",
			"short_name": "小疗",
			"summary": "恢复 35% 最大生命。"
		},
		"medkit": {
			"name": "医疗包",
			"short_name": "医疗",
			"summary": "恢复 55% 最大生命。"
		},
		"armor_patch": {
			"name": "轻甲修补包",
			"short_name": "护甲",
			"summary": "恢复 45% 最大护甲。"
		},
		"inspiration_ampoule": {
			"name": "守护蜡烛",
			"short_name": "灵感",
			"summary": "恢复 45% 最大灵感。"
		},
		"edge_oil": {
			"name": "磨锋油",
			"short_name": "攻击",
			"summary": "下一场战斗：攻击伤害 +10%。"
		}
	},
	"zh_Hant": {
		"bandage_pack": {
			"name": "繃帶包",
			"short_name": "繃帶",
			"summary": "恢復 22% 最大生命。"
		},
		"healing_vial": {
			"name": "治療藥瓶",
			"short_name": "小療",
			"summary": "恢復 35% 最大生命。"
		},
		"medkit": {
			"name": "醫療包",
			"short_name": "醫療",
			"summary": "恢復 55% 最大生命。"
		},
		"armor_patch": {
			"name": "輕甲修補包",
			"short_name": "護甲",
			"summary": "恢復 45% 最大護甲。"
		},
		"inspiration_ampoule": {
			"name": "守護蠟燭",
			"short_name": "靈感",
			"summary": "恢復 45% 最大靈感。"
		},
		"edge_oil": {
			"name": "磨鋒油",
			"short_name": "攻擊",
			"summary": "下一場戰鬥：攻擊傷害 +10%。"
		}
	}
}

var slots: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	reset_run()

func reset_run() -> void:
	slots.clear()
	for _index in range(MAX_SLOTS):
		slots.append({})
	inventory_changed.emit(get_slots())

func get_slots() -> Array[Dictionary]:
	return slots.duplicate(true)

func get_catalog() -> Dictionary:
	var output := {}
	for consumable_id in CATALOG.keys():
		output[consumable_id] = describe(String(consumable_id))
	return output

func random_consumable_id() -> String:
	var keys := CATALOG.keys()
	if keys.is_empty():
		return ""
	return String(keys[rng.randi_range(0, keys.size() - 1)])

func add_consumable(consumable_id: String, amount: int = 1) -> bool:
	if not CATALOG.has(consumable_id) or amount <= 0:
		return false
	for slot in slots:
		if String(slot.get("id", "")) == consumable_id:
			slot["amount"] = int(slot.get("amount", 0)) + amount
			inventory_changed.emit(get_slots())
			return true
	for slot in slots:
		if slot.is_empty():
			slot["id"] = consumable_id
			slot["amount"] = amount
			inventory_changed.emit(get_slots())
			return true
	return false

func use_slot(slot_index: int, actor: Node) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot := slots[slot_index]
	var consumable_id := String(slot.get("id", ""))
	if consumable_id.is_empty() or not CATALOG.has(consumable_id):
		return false
	if not _apply_consumable(consumable_id, actor):
		return false
	var next_amount := int(slot.get("amount", 1)) - 1
	if next_amount <= 0:
		slots[slot_index] = {}
	else:
		slot["amount"] = next_amount
	consumable_used.emit(consumable_id, slot_index)
	inventory_changed.emit(get_slots())
	return true

func describe(consumable_id: String) -> Dictionary:
	var data: Dictionary = (CATALOG.get(consumable_id, {}) as Dictionary).duplicate(true)
	var locale := _current_locale()
	var locale_catalog: Dictionary = LOCALIZED_CATALOG.get(locale, {}) as Dictionary
	var localized: Dictionary = locale_catalog.get(consumable_id, {}) as Dictionary
	for key in localized.keys():
		data[key] = localized[key]
	data["id"] = consumable_id
	return data

func _apply_consumable(consumable_id: String, actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	match consumable_id:
		"bandage_pack":
			return _restore_ratio(actor, "hp", "max_hp", 0.22)
		"healing_vial":
			return _restore_ratio(actor, "hp", "max_hp", 0.35)
		"medkit":
			return _restore_ratio(actor, "hp", "max_hp", 0.55)
		"armor_patch":
			return _restore_ratio(actor, "defense", "max_defense", 0.45)
		"inspiration_ampoule":
			return _restore_ratio(actor, "inspiration", "max_inspiration", 0.45)
		"edge_oil":
			var data := describe("edge_oil")
			return _queue_next_fight_prep("edge_oil", String(data.get("name", "Edge Oil")), {"attack_damage_pct": 0.10})
	return false

func _restore_ratio(actor: Node, current_field: String, max_field: String, ratio: float) -> bool:
	if not _has_property(actor, current_field) or not _has_property(actor, max_field):
		return false
	var max_value := float(actor.get(max_field))
	if max_value <= 0.0:
		return false
	actor.set(current_field, clampf(float(actor.get(current_field)) + max_value * ratio, 0.0, max_value))
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()
	return true

func _queue_next_fight_prep(consumable_id: String, title: String, effects: Dictionary) -> bool:
	if RunDirector == null:
		return false
	RunDirector.set_pending_encounter_prep({
		"choice_id": consumable_id,
		"title": title,
		"summary": _locale_text(
			"Consumable prep for the next map.",
			"消耗品备战将在下一张小地图生效。",
			"消耗品備戰將在下一張小地圖生效。"
		),
		"temporary_effects": effects
	})
	return true

func _current_locale() -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		return String(UISettings.get_locale())
	return "zh_Hans"

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	match _current_locale():
		"zh_Hant":
			return zh_hant_text
		"zh_Hans":
			return zh_hans_text
		_:
			return en_text

func _has_property(actor: Node, field: String) -> bool:
	if actor == null:
		return false
	for property in actor.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false
