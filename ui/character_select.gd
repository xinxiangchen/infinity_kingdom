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
		"role": "Frontline",
		"stats": ["HP", "Armor", "Melee"],
		"summary": "Stable opener, heavy sustain, slower reposition."
	},
	{
		"id": &"ranger",
		"name": "Ranger",
		"role": "Agile",
		"stats": ["Crit", "Speed", "Burst"],
		"summary": "Fast target picks, high tempo, lower fault tolerance."
	},
	{
		"id": &"mage",
		"name": "Mage",
		"role": "Control",
		"stats": ["Range", "Skill", "Crowd"],
		"summary": "Safest spacing, strong area control, lightest body."
	}
]

var panel: PanelContainer
var panel_margin: MarginContainer
var title_label: Label
var subtitle_label: Label
var hero_detail_title: Label
var hero_detail_role: Label
var hero_detail_desc: Label
var cards_grid: GridContainer
var hero_buttons: Array[Button] = []
var primary_start_button: Button
var settings_button: Button
var gallery_button: Button
var about_button: Button
var quit_button: Button
var left_hint_label: Label
var layout_size_override: Vector2 = Vector2.ZERO
var selected_hero_index: int = 0
var detail_mode: String = "hero"

func _ready() -> void:
	_build_ui()
	if UISettings != null and UISettings.has_signal("locale_changed") and not UISettings.locale_changed.is_connected(_refresh_copy):
		UISettings.locale_changed.connect(_refresh_copy)
	_set_selected_hero(0)
	_refresh_copy()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func _build_ui() -> void:
	layer = 10

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.05, 0.06, 1.0)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	panel.name = "CharacterSelectPanel"
	panel.custom_minimum_size = Vector2(1120, 640)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 28)
	panel_margin.add_theme_constant_override("margin_top", 24)
	panel_margin.add_theme_constant_override("margin_right", 28)
	panel_margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(panel_margin)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 18)
	panel_margin.add_child(root_column)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_label, 32, UISkin.COLOR_ACCENT)
	root_column.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(subtitle_label, 14, UISkin.COLOR_MUTED)
	root_column.add_child(subtitle_label)

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 18)
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_column.add_child(main_row)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(260, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	main_row.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 16)
	left_margin.add_theme_constant_override("margin_top", 16)
	left_margin.add_theme_constant_override("margin_right", 16)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	left_panel.add_child(left_margin)

	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 12)
	left_margin.add_child(left_column)

	var logo_box := UISkin.placeholder_box(Vector2(0, 84), UIText.text("placeholder_panel"))
	left_column.add_child(logo_box)

	primary_start_button = _menu_button(UIText.text("menu_start"), func() -> void: _activate_selected_hero(), true)
	settings_button = _menu_button(UIText.text("menu_settings"), func() -> void: settings_requested.emit())
	gallery_button = _menu_button(UIText.text("menu_gallery"), func() -> void: _show_gallery_placeholder())
	about_button = _menu_button(UIText.text("menu_about"), func() -> void: _show_about_placeholder())
	quit_button = _menu_button(UIText.text("quit_game"), func() -> void: quit_requested.emit())
	for button in [primary_start_button, settings_button, gallery_button, about_button, quit_button]:
		left_column.add_child(button)

	left_hint_label = Label.new()
	left_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(left_hint_label, 11, UISkin.COLOR_MUTED)
	left_column.add_child(left_hint_label)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	main_row.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 18)
	right_margin.add_theme_constant_override("margin_top", 18)
	right_margin.add_theme_constant_override("margin_right", 18)
	right_margin.add_theme_constant_override("margin_bottom", 18)
	right_panel.add_child(right_margin)

	var right_column := VBoxContainer.new()
	right_column.add_theme_constant_override("separation", 16)
	right_margin.add_child(right_column)

	var hero_top_row := HBoxContainer.new()
	hero_top_row.add_theme_constant_override("separation", 16)
	right_column.add_child(hero_top_row)

	var portrait_box := UISkin.placeholder_box(Vector2(180, 180), UIText.text("placeholder_portrait"))
	hero_top_row.add_child(portrait_box)

	var hero_info_panel := PanelContainer.new()
	hero_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_info_panel.add_theme_stylebox_override("panel", UISkin.placeholder_box_style())
	hero_top_row.add_child(hero_info_panel)

	var hero_info_margin := MarginContainer.new()
	hero_info_margin.add_theme_constant_override("margin_left", 14)
	hero_info_margin.add_theme_constant_override("margin_top", 14)
	hero_info_margin.add_theme_constant_override("margin_right", 14)
	hero_info_margin.add_theme_constant_override("margin_bottom", 14)
	hero_info_panel.add_child(hero_info_margin)

	var hero_info_column := VBoxContainer.new()
	hero_info_column.add_theme_constant_override("separation", 8)
	hero_info_margin.add_child(hero_info_column)

	hero_detail_title = Label.new()
	UISkin.label(hero_detail_title, 24, Color.WHITE)
	hero_info_column.add_child(hero_detail_title)

	hero_detail_role = Label.new()
	UISkin.label(hero_detail_role, 14, UISkin.COLOR_ACCENT)
	hero_info_column.add_child(hero_detail_role)

	hero_detail_desc = Label.new()
	hero_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hero_detail_desc, 12, UISkin.COLOR_MUTED)
	hero_info_column.add_child(hero_detail_desc)

	var cards_panel := PanelContainer.new()
	cards_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_panel.add_theme_stylebox_override("panel", UISkin.placeholder_box_style())
	right_column.add_child(cards_panel)

	var cards_margin := MarginContainer.new()
	cards_margin.add_theme_constant_override("margin_left", 12)
	cards_margin.add_theme_constant_override("margin_top", 12)
	cards_margin.add_theme_constant_override("margin_right", 12)
	cards_margin.add_theme_constant_override("margin_bottom", 12)
	cards_panel.add_child(cards_margin)

	cards_grid = GridContainer.new()
	cards_grid.columns = 3
	cards_grid.add_theme_constant_override("h_separation", 12)
	cards_grid.add_theme_constant_override("v_separation", 12)
	cards_margin.add_child(cards_grid)

	for hero_index in range(HEROES.size()):
		var hero_button := _hero_card(HEROES[hero_index], hero_index)
		hero_buttons.append(hero_button)
		cards_grid.add_child(hero_button)

func _hero_card(hero: Dictionary, hero_index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 180)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UISkin.placeholder_box_style())
	button.add_theme_stylebox_override("hover", UISkin.flat_style(Color(0.22, 0.23, 0.27), UISkin.COLOR_ACCENT, 2, 3))
	button.add_theme_stylebox_override("pressed", UISkin.flat_style(Color(0.14, 0.15, 0.18), UISkin.COLOR_ACCENT.darkened(0.2), 2, 3))
	button.focus_entered.connect(func() -> void: _set_selected_hero(hero_index))
	button.mouse_entered.connect(func() -> void: _set_selected_hero(hero_index))
	button.pressed.connect(func() -> void: _activate_hero(hero_index))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 12
	margin.offset_top = 12
	margin.offset_right = -12
	margin.offset_bottom = -12
	button.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	column.add_child(UISkin.placeholder_box(Vector2(0, 72), UIText.text("placeholder_card")))

	var name_label := Label.new()
	name_label.text = "%s  [%d]" % [String(hero["name"]), hero_index + 1]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UISkin.label(name_label, 16, Color.WHITE)
	column.add_child(name_label)

	var role_label := Label.new()
	role_label.text = String(hero["role"])
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UISkin.label(role_label, 12, UISkin.COLOR_ACCENT)
	column.add_child(role_label)

	var stats_label := Label.new()
	stats_label.text = " / ".join(hero["stats"])
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(stats_label, 11, UISkin.COLOR_MUTED)
	column.add_child(stats_label)

	UISkin.ignore_mouse_recursive(margin)
	return button

func _menu_button(text: String, callback: Callable, highlighted: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	UISkin.button_styles(button, "large" if highlighted else "medium")
	button.pressed.connect(callback)
	return button

func _set_selected_hero(hero_index: int) -> void:
	detail_mode = "hero"
	selected_hero_index = clampi(hero_index, 0, HEROES.size() - 1)
	var hero: Dictionary = HEROES[selected_hero_index]
	hero_detail_title.text = String(hero["name"])
	hero_detail_role.text = String(hero["role"])
	hero_detail_desc.text = "%s\n%s" % [String(hero["summary"]), UIText.text("char_actions")]

func _activate_selected_hero() -> void:
	_activate_hero(selected_hero_index)

func _activate_hero(hero_index: int) -> void:
	var safe_index := clampi(hero_index, 0, HEROES.size() - 1)
	visible = false
	character_selected.emit(HEROES[safe_index]["id"])

func _show_about_placeholder() -> void:
	detail_mode = "about"
	hero_detail_title.text = UIText.text("about_title")
	hero_detail_role.text = UIText.text("placeholder_panel")
	hero_detail_desc.text = UIText.text("char_about_placeholder")

func _show_gallery_placeholder() -> void:
	detail_mode = "gallery"
	hero_detail_title.text = UIText.text("gallery_title")
	hero_detail_role.text = UIText.text("placeholder_panel")
	hero_detail_desc.text = UIText.text("char_gallery_placeholder")

func _refresh_copy(_locale: String = "") -> void:
	title_label.text = UIText.text("menu_title")
	subtitle_label.text = UIText.text("char_select_subtitle")
	primary_start_button.text = UIText.text("menu_start")
	settings_button.text = UIText.text("menu_settings")
	gallery_button.text = UIText.text("menu_gallery")
	about_button.text = UIText.text("menu_about")
	quit_button.text = UIText.text("menu_quit")
	left_hint_label.text = UIText.text("char_hint")
	match detail_mode:
		"gallery":
			_show_gallery_placeholder()
		"about":
			_show_about_placeholder()
		_:
			_set_selected_hero(selected_hero_index)

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if panel == null or cards_grid == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact := viewport_size.x < 1100.0 or viewport_size.y < 760.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (48.0 if compact else 96.0), 680.0, 1320.0),
		clampf(viewport_size.y - (48.0 if compact else 96.0), 500.0, 760.0)
	)
	panel_margin.add_theme_constant_override("margin_left", 18 if compact else 28)
	panel_margin.add_theme_constant_override("margin_top", 16 if compact else 24)
	panel_margin.add_theme_constant_override("margin_right", 18 if compact else 28)
	panel_margin.add_theme_constant_override("margin_bottom", 16 if compact else 24)
	UISkin.label(title_label, 24 if compact else 32, UISkin.COLOR_ACCENT)
	UISkin.label(subtitle_label, 12 if compact else 14, UISkin.COLOR_MUTED)
	UISkin.label(hero_detail_title, 20 if compact else 24, Color.WHITE)
	UISkin.label(hero_detail_role, 12 if compact else 14, UISkin.COLOR_ACCENT)
	UISkin.label(hero_detail_desc, 11 if compact else 12, UISkin.COLOR_MUTED)
	cards_grid.columns = 1 if viewport_size.x < 860.0 else 3
	for hero_button in hero_buttons:
		hero_button.custom_minimum_size.y = 156.0 if compact else 180.0

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_set_selected_hero(0)
			KEY_2, KEY_KP_2:
				_set_selected_hero(1)
			KEY_3, KEY_KP_3:
				_set_selected_hero(2)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate_selected_hero()
			KEY_S:
				settings_requested.emit()
			KEY_G:
				_show_gallery_placeholder()
			KEY_A:
				_show_about_placeholder()
			KEY_Q:
				quit_requested.emit()
			_:
				return
		get_viewport().set_input_as_handled()
