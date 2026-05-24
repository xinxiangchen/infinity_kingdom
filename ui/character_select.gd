extends CanvasLayer

signal character_selected(character_id: StringName)
signal audio_requested
signal settings_requested
signal quit_requested

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(640, 500)
const PANEL_MAX_SIZE := Vector2(1400, 820)
const HERO_CARD_MIN_WIDTH := 304.0
const HERO_CARD_MAX_WIDTH := 380.0
const HERO_CARD_GAP := 16.0
const ACTION_BUTTON_MIN_WIDTH := 190.0

const HEROES := [
	{
		"id": &"knight",
		"name": "Knight",
		"shortcut": "1",
		"role": "Frontline Vanguard",
		"desc": "High health and defense. Charge slash, shockwave, sanctuary.",
		"plan": "Best with defense, survival, and raw damage relics.",
		"opener": "Starts the run with the safest fights and strongest recovery windows.",
		"warning": "Slowest reposition. Bad movement gets punished by long boss patterns.",
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
		"shortcut": "2",
		"role": "Mobile Hunter",
		"desc": "Fast attacks and burst. Piercing arrow, shadow roll, assassination.",
		"plan": "Best with crit, speed, and tempo relics that chain kills.",
		"opener": "Can skip danger by rolling through pressure and deleting weak targets.",
		"warning": "Lowest margin for mistakes once caught in close quarters.",
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
		"shortcut": "3",
		"role": "Arcane Controller",
		"desc": "Ranged burst and control. Arcane blades, burst, silence decree.",
		"plan": "Best with skill, control, and resource relics that snowball spell uptime.",
		"opener": "Strongest crowd control and safest ranged shaping against mixed packs.",
		"warning": "Lightest health pool. Needs space before long casts.",
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

var panel: PanelContainer
var panel_margin: MarginContainer
var title_label: Label
var subtitle_label: Label
var brief_grid: GridContainer
var run_brief_label: Label
var run_controls_label: Label
var hero_detail_title: Label
var hero_detail_role: Label
var hero_detail_desc: Label
var hero_detail_plan: Label
var hero_detail_opener: Label
var hero_detail_warning: Label
var cards_scroll: ScrollContainer
var cards_grid: GridContainer
var actions_grid: GridContainer
var hero_buttons: Array[Button] = []
var selected_hero_index: int = 0
var layout_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	_build_ui()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_set_selected_hero(0)
	_queue_layout_refresh()

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

	panel = PanelContainer.new()
	panel.name = "CharacterSelectPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 34)
	panel_margin.add_theme_constant_override("margin_top", 28)
	panel_margin.add_theme_constant_override("margin_right", 34)
	panel_margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(panel_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel_margin.add_child(column)

	title_label = Label.new()
	title_label.text = "Choose Your Champion"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_label, 32, Color(0.98, 0.90, 0.66))
	column.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Pick a family style, then shape the run with relics, training, and risky bargains."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(subtitle_label, 16, Color(0.76, 0.80, 0.88))
	column.add_child(subtitle_label)

	brief_grid = GridContainer.new()
	brief_grid.name = "BriefGrid"
	brief_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_grid.add_theme_constant_override("h_separation", 12)
	brief_grid.add_theme_constant_override("v_separation", 12)
	column.add_child(brief_grid)

	var run_brief_panel := PanelContainer.new()
	run_brief_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	brief_grid.add_child(run_brief_panel)

	var run_brief_margin := MarginContainer.new()
	run_brief_margin.add_theme_constant_override("margin_left", 12)
	run_brief_margin.add_theme_constant_override("margin_top", 10)
	run_brief_margin.add_theme_constant_override("margin_right", 12)
	run_brief_margin.add_theme_constant_override("margin_bottom", 10)
	run_brief_panel.add_child(run_brief_margin)

	var run_brief_box := VBoxContainer.new()
	run_brief_box.add_theme_constant_override("separation", 5)
	run_brief_margin.add_child(run_brief_box)

	var run_brief_title := Label.new()
	run_brief_title.text = "Run Brief"
	UISkin.label(run_brief_title, 15, Color(0.98, 0.90, 0.66))
	run_brief_box.add_child(run_brief_title)

	run_brief_label = Label.new()
	run_brief_label.text = "Start with a relic, then clear Town Enemies, Judicator, Guard Formation, and Twin Princes. Shop appears first, then three more run events."
	run_brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(run_brief_label, 12, Color(0.86, 0.90, 0.98))
	run_brief_box.add_child(run_brief_label)

	run_controls_label = Label.new()
	run_controls_label.text = "1 / 2 / 3 choose hero  |  Enter confirm  |  A audio  |  S settings  |  Q quit"
	run_controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(run_controls_label, 11, Color(0.76, 0.82, 0.90))
	run_brief_box.add_child(run_controls_label)

	var hero_detail_panel := PanelContainer.new()
	hero_detail_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	brief_grid.add_child(hero_detail_panel)

	var hero_detail_margin := MarginContainer.new()
	hero_detail_margin.add_theme_constant_override("margin_left", 12)
	hero_detail_margin.add_theme_constant_override("margin_top", 10)
	hero_detail_margin.add_theme_constant_override("margin_right", 12)
	hero_detail_margin.add_theme_constant_override("margin_bottom", 10)
	hero_detail_panel.add_child(hero_detail_margin)

	var hero_detail_box := VBoxContainer.new()
	hero_detail_box.add_theme_constant_override("separation", 4)
	hero_detail_margin.add_child(hero_detail_box)

	hero_detail_title = Label.new()
	hero_detail_title.text = "Knight"
	UISkin.label(hero_detail_title, 16, Color.WHITE)
	hero_detail_box.add_child(hero_detail_title)

	hero_detail_role = Label.new()
	hero_detail_role.text = "Frontline Vanguard"
	hero_detail_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hero_detail_role, 12, Color(0.98, 0.90, 0.66))
	hero_detail_box.add_child(hero_detail_role)

	hero_detail_desc = Label.new()
	hero_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hero_detail_desc, 12, Color(0.86, 0.90, 0.98))
	hero_detail_box.add_child(hero_detail_desc)

	hero_detail_plan = Label.new()
	hero_detail_plan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hero_detail_plan, 11, Color(0.88, 0.84, 0.66))
	hero_detail_box.add_child(hero_detail_plan)

	hero_detail_opener = Label.new()
	hero_detail_opener.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hero_detail_opener, 11, Color(0.78, 0.88, 1.0))
	hero_detail_box.add_child(hero_detail_opener)

	hero_detail_warning = Label.new()
	hero_detail_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hero_detail_warning, 11, Color(1.0, 0.80, 0.74))
	hero_detail_box.add_child(hero_detail_warning)

	cards_scroll = ScrollContainer.new()
	cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.custom_minimum_size = Vector2(0, 420)
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(cards_scroll)

	cards_grid = GridContainer.new()
	cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_grid.add_theme_constant_override("h_separation", int(HERO_CARD_GAP))
	cards_grid.add_theme_constant_override("v_separation", int(HERO_CARD_GAP))
	cards_scroll.add_child(cards_grid)

	for hero_index in range(HEROES.size()):
		var hero_button := _hero_card(HEROES[hero_index], hero_index)
		hero_buttons.append(hero_button)
		cards_grid.add_child(hero_button)

	actions_grid = GridContainer.new()
	actions_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions_grid.add_theme_constant_override("h_separation", 12)
	actions_grid.add_theme_constant_override("v_separation", 12)
	column.add_child(actions_grid)
	actions_grid.add_child(_menu_button("Audio Mix", func() -> void: audio_requested.emit()))
	actions_grid.add_child(_menu_button("Settings", func() -> void: settings_requested.emit()))
	actions_grid.add_child(_menu_button("Quit Game", func() -> void: quit_requested.emit()))

func _hero_card(hero: Dictionary, hero_index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(320, 446)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UISkin.texture_style(UISkin.asset("choice/choice_card_normal.png"), 30, 12))
	button.add_theme_stylebox_override("hover", UISkin.texture_style(UISkin.asset("choice/choice_card_hover.png"), 30, 12))
	button.add_theme_stylebox_override("pressed", UISkin.texture_style(UISkin.asset("choice/choice_card_selected.png"), 30, 12))
	button.mouse_entered.connect(func() -> void: _set_selected_hero(hero_index))
	button.focus_entered.connect(func() -> void: _set_selected_hero(hero_index))
	button.pressed.connect(func() -> void: _activate_hero(hero_index))

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
	portrait.custom_minimum_size = Vector2(280, 168)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	desc_label.custom_minimum_size = Vector2(0, 62)
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

	var select_label := Label.new()
	select_label.text = "Press %s or click to start" % String(hero["shortcut"])
	select_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(select_label, 11, Color(0.76, 0.82, 0.90))
	box.add_child(select_label)

	UISkin.ignore_mouse_recursive(margin)
	return button

func _menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 44)
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

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _set_selected_hero(hero_index: int) -> void:
	selected_hero_index = clampi(hero_index, 0, HEROES.size() - 1)
	var hero: Dictionary = HEROES[selected_hero_index]
	hero_detail_title.text = "%s  |  Press %s" % [String(hero["name"]), String(hero["shortcut"])]
	hero_detail_role.text = String(hero["role"])
	hero_detail_role.add_theme_color_override("font_color", hero["color"])
	hero_detail_desc.text = String(hero["desc"])
	hero_detail_plan.text = "Relic plan: %s" % String(hero["plan"])
	hero_detail_opener.text = "Opening edge: %s" % String(hero["opener"])
	hero_detail_warning.text = "Watch out: %s" % String(hero["warning"])

func _activate_selected_hero() -> void:
	_activate_hero(selected_hero_index)

func _activate_hero(hero_index: int) -> void:
	var safe_index := clampi(hero_index, 0, HEROES.size() - 1)
	_set_selected_hero(safe_index)
	visible = false
	character_selected.emit(HEROES[safe_index]["id"])

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_set_selected_hero(0)
				if not hero_buttons.is_empty():
					hero_buttons[0].grab_focus()
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				if hero_buttons.size() > 1:
					_set_selected_hero(1)
					hero_buttons[1].grab_focus()
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				if hero_buttons.size() > 2:
					_set_selected_hero(2)
					hero_buttons[2].grab_focus()
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_UP:
				_set_selected_hero(posmod(selected_hero_index - 1, HEROES.size()))
				hero_buttons[selected_hero_index].grab_focus()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_DOWN:
				_set_selected_hero(posmod(selected_hero_index + 1, HEROES.size()))
				hero_buttons[selected_hero_index].grab_focus()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate_selected_hero()
				get_viewport().set_input_as_handled()
			KEY_A:
				audio_requested.emit()
				get_viewport().set_input_as_handled()
			KEY_S:
				settings_requested.emit()
				get_viewport().set_input_as_handled()
			KEY_Q:
				quit_requested.emit()
				get_viewport().set_input_as_handled()

func _refresh_layout() -> void:
	if panel == null or cards_grid == null or actions_grid == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 980.0 or viewport_size.y < 700.0
	var very_compact: bool = viewport_size.x < 840.0 or viewport_size.y < 620.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (40.0 if very_compact else 72.0), PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - (40.0 if very_compact else 72.0), PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
	panel_margin.add_theme_constant_override("margin_left", 20 if compact else 34)
	panel_margin.add_theme_constant_override("margin_top", 18 if compact else 28)
	panel_margin.add_theme_constant_override("margin_right", 20 if compact else 34)
	panel_margin.add_theme_constant_override("margin_bottom", 18 if compact else 28)
	UISkin.label(title_label, 26 if compact else 32, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 14 if compact else 16, Color(0.76, 0.80, 0.88))
	UISkin.label(run_brief_label, 11 if compact else 12, Color(0.86, 0.90, 0.98))
	UISkin.label(run_controls_label, 10 if compact else 11, Color(0.76, 0.82, 0.90))
	UISkin.label(hero_detail_title, 14 if compact else 16, Color.WHITE)
	UISkin.label(hero_detail_role, 11 if compact else 12, hero_detail_role.get_theme_color("font_color"))
	UISkin.label(hero_detail_desc, 11 if compact else 12, Color(0.86, 0.90, 0.98))
	UISkin.label(hero_detail_plan, 10 if compact else 11, Color(0.88, 0.84, 0.66))
	UISkin.label(hero_detail_opener, 10 if compact else 11, Color(0.78, 0.88, 1.0))
	UISkin.label(hero_detail_warning, 10 if compact else 11, Color(1.0, 0.80, 0.74))
	brief_grid.columns = 1 if compact else 2
	cards_scroll.custom_minimum_size.y = 296.0 if very_compact else (348.0 if compact else 420.0)

	var cards_width := maxf(cards_scroll.size.x, panel.custom_minimum_size.x - 96.0)
	var columns := clampi(int(floor((cards_width + HERO_CARD_GAP) / (HERO_CARD_MIN_WIDTH + HERO_CARD_GAP))), 1, 3)
	cards_grid.columns = columns

	var stretched_width := clampf(
		(cards_width - HERO_CARD_GAP * float(max(columns - 1, 0))) / float(columns),
		HERO_CARD_MIN_WIDTH,
		HERO_CARD_MAX_WIDTH
	)
	for button in hero_buttons:
		button.custom_minimum_size = Vector2(stretched_width, 384.0 if very_compact else (408.0 if compact else 446.0))

	var action_button_width := 160.0 if compact else ACTION_BUTTON_MIN_WIDTH
	var action_width := maxf(panel.custom_minimum_size.x - 120.0, action_button_width)
	actions_grid.columns = clampi(int(floor((action_width + 12.0) / (action_button_width + 12.0))), 1, 3)
	for child in actions_grid.get_children():
		if child is Button:
			var action_button := child as Button
			action_button.custom_minimum_size = Vector2(action_button_width, 40.0 if compact else 44.0)
