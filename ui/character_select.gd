extends CanvasLayer

signal character_selected(character_id: StringName)
signal audio_requested
signal settings_requested
signal quit_requested

const UISkin := preload("res://ui/ui_skin.gd")

const HEROES := [
	{
		"id": &"knight",
		"name": "Knight",
		"role": "Frontline Vanguard",
		"desc": "High health and defense. Charge slash, shockwave, sanctuary.",
		"texture": "res://assets/heroes/knight.png",
		"color": Color(0.82, 0.58, 0.34),
		"skills": [
			"res://assets/ui/skill/knight_charge_slash.png",
			"res://assets/ui/skill/knight_counter_shock.png",
			"res://assets/ui/skill/knight_holy_field.png"
		],
		"stats": ["HP 100", "DEF 100", "SPD 200"]
	},
	{
		"id": &"ranger",
		"name": "Ranger",
		"role": "Mobile Hunter",
		"desc": "Fast attacks and burst. Piercing arrow, shadow roll, assassination.",
		"texture": "res://assets/heroes/ranger.png",
		"color": Color(0.38, 0.78, 0.56),
		"skills": [
			"res://assets/ui/skill/ranger_wind_arrow.png",
			"res://assets/ui/skill/ranger_shadow_step.png",
			"res://assets/ui/skill/ranger_hunt_rush.png"
		],
		"stats": ["HP 85", "CRIT 40%", "SPD 280"]
	},
	{
		"id": &"mage",
		"name": "Mage",
		"role": "Arcane Controller",
		"desc": "Ranged burst and control. Arcane blades, burst, silence decree.",
		"texture": "res://assets/heroes/mage.png",
		"color": Color(0.56, 0.62, 0.95),
		"skills": [
			"res://assets/ui/skill/mage_blade_whirl.png",
			"res://assets/ui/skill/mage_arcane_burst.png",
			"res://assets/ui/skill/mage_silence_decree.png"
		],
		"stats": ["HP 70", "MANA 80", "RANGE"]
	}
]

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	layer = 10
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.018, 0.022, 0.034, 0.88)
	add_child(backdrop)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = load("res://assets/ui/background/title_screen_bg.png") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.55, 0.55, 0.60, 0.58)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1240, 760)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Choose Your Champion"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UISkin.label(title, 32, Color(0.98, 0.90, 0.66))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick a family style, then claim relics between encounters to bend the run."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(0, 34)
	UISkin.label(subtitle, 16, Color(0.76, 0.80, 0.88))
	column.add_child(subtitle)

	var cards := GridContainer.new()
	cards.columns = 3
	cards.add_theme_constant_override("h_separation", 16)
	cards.add_theme_constant_override("v_separation", 16)
	cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(cards)

	for hero in HEROES:
		cards.add_child(_hero_card(hero))

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	column.add_child(button_row)
	button_row.add_child(_menu_button("Audio Mix", func() -> void: audio_requested.emit()))
	button_row.add_child(_menu_button("Settings", func() -> void: settings_requested.emit()))
	button_row.add_child(_menu_button("Quit Game", func() -> void: quit_requested.emit()))

func _hero_card(hero: Dictionary) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(360, 450)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_stylebox_override("normal", UISkin.texture_style(UISkin.asset("choice/choice_card_normal.png"), 30, 12))
	button.add_theme_stylebox_override("hover", UISkin.texture_style(UISkin.asset("choice/choice_card_hover.png"), 30, 12))
	button.add_theme_stylebox_override("pressed", UISkin.texture_style(UISkin.asset("choice/choice_card_selected.png"), 30, 12))
	button.pressed.connect(func() -> void:
		visible = false
		character_selected.emit(hero["id"])
	)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 18
	margin.offset_top = 18
	margin.offset_right = -18
	margin.offset_bottom = -18
	button.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(314, 172)
	portrait.texture = load(String(hero["texture"])) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(portrait)

	var name_label := Label.new()
	name_label.text = String(hero["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	UISkin.label(name_label, 25, Color.WHITE)
	box.add_child(name_label)

	var role_label := Label.new()
	role_label.text = String(hero["role"])
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.clip_text = true
	UISkin.label(role_label, 15, hero["color"])
	box.add_child(role_label)

	var skill_row := HBoxContainer.new()
	skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_row.add_theme_constant_override("separation", 8)
	box.add_child(skill_row)
	for skill_icon_path in hero["skills"]:
		skill_row.add_child(_icon_slot(String(skill_icon_path), Vector2(42, 42)))

	var desc_label := Label.new()
	desc_label.text = String(hero["desc"])
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(0, 58)
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UISkin.label(desc_label, 15, Color(0.78, 0.84, 0.92))
	box.add_child(desc_label)

	var stat_row := HBoxContainer.new()
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 6)
	box.add_child(stat_row)
	for stat_text in hero["stats"]:
		var stat_label := Label.new()
		stat_label.custom_minimum_size = Vector2(88, 26)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_label.text = String(stat_text)
		stat_label.add_theme_stylebox_override("normal", UISkin.texture_style(UISkin.asset("frame/tab_dark_small.png"), 20, 6))
		UISkin.label(stat_label, 12, Color(0.91, 0.86, 0.72))
		stat_row.add_child(stat_label)

	UISkin.ignore_mouse_recursive(margin)
	return button

func _menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 44)
	UISkin.button_styles(button, "thin")
	button.pressed.connect(callback)
	return button

func _icon_slot(texture_path: String, icon_size: Vector2) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(icon_size.x + 12, icon_size.y + 12)
	slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	var icon := TextureRect.new()
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(texture_path) as Texture2D
	slot.add_child(icon)
	return slot
