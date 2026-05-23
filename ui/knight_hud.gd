extends CanvasLayer

const UISkin := preload("res://ui/ui_skin.gd")

var player_character: Node = null

var title_label: Label
var hp_bar: TextureProgressBar
var hp_label: Label
var defense_bar: TextureProgressBar
var defense_label: Label
var inspiration_bar: TextureProgressBar
var inspiration_label: Label
var shield_label: Label
var state_label: Label
var accessory_icon: TextureRect
var accessory_name_label: Label
var accessory_summary_label: Label
var skill_slots: Dictionary = {}
var skill_icon_paths := {
	"Knight": [
		"res://assets/ui/skill/knight_charge_slash.png",
		"res://assets/ui/skill/knight_counter_shock.png",
		"res://assets/ui/skill/knight_holy_field.png"
	],
	"Ranger": [
		"res://assets/ui/skill/ranger_wind_arrow.png",
		"res://assets/ui/skill/ranger_shadow_step.png",
		"res://assets/ui/skill/ranger_hunt_rush.png"
	],
	"Mage": [
		"res://assets/ui/skill/mage_blade_whirl.png",
		"res://assets/ui/skill/mage_arcane_burst.png",
		"res://assets/ui/skill/mage_silence_decree.png"
	]
}

func _ready() -> void:
	_build_ui()
	if AccessoryManager != null and not AccessoryManager.accessory_equipped.is_connected(_on_accessory_equipped):
		AccessoryManager.accessory_equipped.connect(_on_accessory_equipped)
	_on_accessory_equipped(AccessoryManager.get_equipped_accessory())

func bind_character(target: Node) -> void:
	player_character = target
	if player_character == null:
		return
	title_label.text = "%s Combat Frame" % String(player_character.get_character_name())
	_refresh_skill_icons()
	_connect_character_signal("hp_changed", _on_hp_changed)
	_connect_character_signal("defense_changed", _on_defense_changed)
	_connect_character_signal("inspiration_changed", _on_inspiration_changed)
	_connect_character_signal("shield_changed", _on_shield_changed)
	_connect_character_signal("took_damage", _on_took_damage)
	_on_hp_changed(player_character.hp, player_character.max_hp)
	_on_defense_changed(player_character.defense, player_character.max_defense)
	_on_inspiration_changed(player_character.inspiration, player_character.max_inspiration)
	_on_shield_changed(player_character.shield)
	_on_accessory_equipped(AccessoryManager.get_equipped_accessory())

func bind_knight(target: Node) -> void:
	bind_character(target)

func _process(_delta: float) -> void:
	if player_character == null or not is_instance_valid(player_character):
		return
	state_label.text = "State  %s" % String(player_character.state_machine.get_state_name())
	_update_skill_slots()

func _build_ui() -> void:
	layer = 5
	var margin := MarginContainer.new()
	margin.anchor_top = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 18.0
	margin.offset_top = -428.0
	margin.offset_right = 470.0
	margin.offset_bottom = -18.0
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UISkin.panel_style())
	margin.add_child(panel)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 12)
	inner_margin.add_theme_constant_override("margin_top", 12)
	inner_margin.add_theme_constant_override("margin_right", 12)
	inner_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(inner_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	inner_margin.add_child(content)

	title_label = Label.new()
	title_label.text = "Character Combat Frame"
	UISkin.label(title_label, 20, Color(0.98, 0.90, 0.66))
	content.add_child(title_label)

	content.add_child(_meter("hp", "HP", Color(0.82, 0.22, 0.20)))
	content.add_child(_meter("defense", "Defense", Color(0.34, 0.68, 0.82)))
	content.add_child(_meter("inspiration", "Inspiration", Color(0.30, 0.52, 0.95)))

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 14)
	content.add_child(status_row)
	shield_label = _make_label("Shield 0", 14, Color(0.82, 0.90, 0.98))
	state_label = _make_label("State Idle", 14, Color(0.82, 0.90, 0.98))
	status_row.add_child(shield_label)
	status_row.add_child(state_label)

	var skills_panel := PanelContainer.new()
	skills_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(skills_panel)

	var skill_row := HBoxContainer.new()
	skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_row.add_theme_constant_override("separation", 8)
	skills_panel.add_child(skill_row)
	for key in ["attack", "skill1", "skill2", "skill3"]:
		var label_text := "J" if key == "attack" else ("K" if key == "skill1" else ("L" if key == "skill2" else "I"))
		var icon_path := "res://assets/ui/icon/stat_attack_pixel.png"
		if key != "attack":
			icon_path = "res://assets/ui/icon/ui_unknown.png"
		var slot_data := _skill_slot(key, label_text, icon_path)
		skill_slots[key] = slot_data
		skill_row.add_child(slot_data["root"])

	var accessory_panel := PanelContainer.new()
	accessory_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(accessory_panel)

	var accessory_row := HBoxContainer.new()
	accessory_row.add_theme_constant_override("separation", 10)
	accessory_panel.add_child(accessory_row)

	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	accessory_row.add_child(slot)

	accessory_icon = TextureRect.new()
	accessory_icon.custom_minimum_size = Vector2(52, 52)
	accessory_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	accessory_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(accessory_icon)

	var accessory_text := VBoxContainer.new()
	accessory_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accessory_row.add_child(accessory_text)
	accessory_name_label = _make_label("No Accessory", 15, Color.WHITE)
	accessory_summary_label = _make_label("Win encounters to claim relics.", 12, Color(0.72, 0.78, 0.86))
	accessory_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accessory_text.add_child(accessory_name_label)
	accessory_text.add_child(accessory_summary_label)

func _meter(meter_id: String, label_text: String, _fill_color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var label := _make_label("%s 0 / 0" % label_text, 13, Color(0.86, 0.88, 0.92))
	box.add_child(label)
	var bar := TextureProgressBar.new()
	bar.custom_minimum_size = Vector2(386, 22)
	UISkin.texture_bar(bar, meter_id)
	box.add_child(bar)
	match meter_id:
		"hp":
			hp_bar = bar
			hp_label = label
		"defense":
			defense_bar = bar
			defense_label = label
		"inspiration":
			inspiration_bar = bar
			inspiration_label = label
	return box

func _skill_slot(key: String, hotkey: String, icon_path: String) -> Dictionary:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(92, 76)
	root.add_theme_stylebox_override("panel", UISkin.texture_style(UISkin.asset("frame/icon_slot_dark.png"), 22, 5))

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	root.add_child(stack)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(icon)

	var label := Label.new()
	label.text = "%s Ready" % hotkey
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	UISkin.label(label, 11, Color(0.86, 0.88, 0.92))
	stack.add_child(label)

	return {"root": root, "icon": icon, "label": label, "hotkey": hotkey, "key": key}

func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	UISkin.label(label, size, color)
	return label

func _connect_character_signal(signal_name: String, callable: Callable) -> void:
	if not player_character.has_signal(signal_name):
		return
	if not player_character.is_connected(StringName(signal_name), callable):
		player_character.connect(StringName(signal_name), callable)

func _on_hp_changed(current_hp: float, max_hp_value: float) -> void:
	hp_bar.value = 0.0 if max_hp_value <= 0.0 else clampf(current_hp / max_hp_value, 0.0, 1.0)
	hp_label.text = "HP %d / %d" % [int(round(current_hp)), int(round(max_hp_value))]

func _on_inspiration_changed(current_inspiration: float, max_inspiration_value: float) -> void:
	inspiration_bar.value = 0.0 if max_inspiration_value <= 0.0 else clampf(current_inspiration / max_inspiration_value, 0.0, 1.0)
	inspiration_label.text = "Inspiration %d / %d" % [int(round(current_inspiration)), int(round(max_inspiration_value))]

func _on_defense_changed(current_defense: float, max_defense_value: float) -> void:
	defense_bar.value = 0.0 if max_defense_value <= 0.0 else clampf(current_defense / max_defense_value, 0.0, 1.0)
	defense_label.text = "Defense %d / %d" % [int(round(current_defense)), int(round(max_defense_value))]

func _on_shield_changed(current_shield: float) -> void:
	shield_label.text = "Shield %d" % int(round(current_shield))

func _on_took_damage(_amount: float, _remaining_hp: float) -> void:
	if player_character != null and is_instance_valid(player_character):
		_on_shield_changed(player_character.shield)

func _on_accessory_equipped(accessory: Dictionary) -> void:
	if accessory_icon == null:
		return
	accessory_icon.texture = load(String(accessory.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
	accessory_name_label.text = String(accessory.get("name", "No Accessory"))
	accessory_summary_label.text = String(accessory.get("summary", ""))

func _refresh_skill_icons() -> void:
	if player_character == null or not is_instance_valid(player_character):
		return
	var character_name := String(player_character.get_character_name())
	var icons: Array = skill_icon_paths.get(character_name, [])
	for index in range(icons.size()):
		var slot_key := "skill%d" % (index + 1)
		if not skill_slots.has(slot_key):
			continue
		var slot: Dictionary = skill_slots[slot_key]
		var icon: TextureRect = slot["icon"]
		icon.texture = load(String(icons[index])) as Texture2D

func _update_skill_slots() -> void:
	if player_character == null or not is_instance_valid(player_character):
		return
	for key in skill_slots.keys():
		var slot: Dictionary = skill_slots[key]
		var label: Label = slot["label"]
		var cooldown := float(player_character.cooldowns.get(key, 0.0))
		if cooldown <= 0.05:
			label.text = "%s Ready" % String(slot["hotkey"])
			label.modulate = Color(0.78, 1.0, 0.78)
		else:
			label.text = "%s %.1f" % [String(slot["hotkey"]), cooldown]
			label.modulate = Color(1.0, 0.80, 0.62)
