extends CanvasLayer

signal confirmed(from_attribute: String, to_attribute: String)

const UISkin := preload("res://ui/ui_skin.gd")

const ATTRIBUTES := ["strength", "agility", "focus"]
const ATTRIBUTE_KEYS := {
	KEY_1: "strength",
	KEY_2: "agility",
	KEY_3: "focus"
}

var selected_from := "strength"
var selected_to := "agility"
var current_aptitude: Dictionary = {}
var lineage_state: Dictionary = {}
var score_data: Dictionary = {}
var title_label: Label
var score_label: Label
var from_buttons: Dictionary = {}
var to_buttons: Dictionary = {}
var confirm_button: Button

func _ready() -> void:
	layer = 24
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func open(payload: Dictionary) -> void:
	lineage_state = payload.get("lineage", {}) as Dictionary
	score_data = payload.get("score", {}) as Dictionary
	current_aptitude = lineage_state.get("aptitude", {}) as Dictionary
	selected_from = _default_from_attribute()
	selected_to = _default_to_attribute(selected_from)
	_refresh_copy()
	visible = true
	get_tree().paused = true
	confirm_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if ATTRIBUTE_KEYS.has(event.keycode):
			_select_to(String(ATTRIBUTE_KEYS[event.keycode]))
		elif event.keycode == KEY_Q:
			_select_from("strength")
		elif event.keycode == KEY_W:
			_select_from("agility")
		elif event.keycode == KEY_E:
			_select_from("focus")
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_confirm()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.01, 0.012, 0.018, 0.62)
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 520)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	title_label = Label.new()
	UISkin.label(title_label, 28, UISkin.COLOR_ACCENT)
	column.add_child(title_label)

	score_label = Label.new()
	score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(score_label, 15, UISkin.COLOR_TEXT)
	column.add_child(score_label)

	var from_label := Label.new()
	from_label.text = _locale_text("Move 1 point from", "从这里挪出 1 点", "從這裡挪出 1 點")
	UISkin.label(from_label, 14, UISkin.COLOR_MUTED)
	column.add_child(from_label)

	var from_row := HBoxContainer.new()
	from_row.add_theme_constant_override("separation", 10)
	column.add_child(from_row)
	for key in ATTRIBUTES:
		var button := _attribute_button()
		button.pressed.connect(_select_from.bind(key))
		from_row.add_child(button)
		from_buttons[key] = button

	var to_label := Label.new()
	to_label.text = _locale_text("Add 1 point to", "把 1 点加到这里", "把 1 點加到這裡")
	UISkin.label(to_label, 14, UISkin.COLOR_MUTED)
	column.add_child(to_label)

	var to_row := HBoxContainer.new()
	to_row.add_theme_constant_override("separation", 10)
	column.add_child(to_row)
	for key in ATTRIBUTES:
		var button := _attribute_button()
		button.pressed.connect(_select_to.bind(key))
		to_row.add_child(button)
		to_buttons[key] = button

	var hint := Label.new()
	hint.text = _locale_text(
		"Q/W/E choose the source. 1/2/3 choose the target. Total aptitude does not change.",
		"Q/W/E 选择扣点项，1/2/3 选择加点项。总资质点数不会改变。",
		"Q/W/E 選擇扣點項，1/2/3 選擇加點項。總資質點數不會改變。"
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hint, 13, UISkin.COLOR_MUTED)
	column.add_child(hint)

	confirm_button = Button.new()
	confirm_button.text = _locale_text("Confirm Heir", "确认继承", "確認繼承")
	UISkin.button_styles(confirm_button, "large")
	confirm_button.pressed.connect(_confirm)
	column.add_child(confirm_button)

func _attribute_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 86)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.button_styles(button, "large")
	return button

func _select_from(attribute_id: String) -> void:
	if not current_aptitude.has(attribute_id):
		return
	if int(current_aptitude.get(attribute_id, 0)) <= 1:
		return
	selected_from = attribute_id
	if selected_to == selected_from:
		selected_to = _default_to_attribute(selected_from)
	_refresh_copy()

func _select_to(attribute_id: String) -> void:
	if not current_aptitude.has(attribute_id):
		return
	if attribute_id == selected_from:
		return
	selected_to = attribute_id
	_refresh_copy()

func _refresh_copy() -> void:
	var aptitude_total := (
		int(current_aptitude.get("strength", 3))
		+ int(current_aptitude.get("agility", 3))
		+ int(current_aptitude.get("focus", 3))
	)
	title_label.text = "%s %d" % [
		_locale_text("Heir Generation", "继承者 第", "繼承者 第"),
		int(lineage_state.get("generation_index", 1))
	]
	score_label.text = "%s %s / %d  |  %s %+d  |  %s %d" % [
		_locale_text("Grade", "评分", "評分"),
		String(score_data.get("grade", "D")),
		int(score_data.get("score", 0)),
		_locale_text("Point delta", "点数修正", "點數修正"),
		_grade_delta(String(score_data.get("grade", "D"))),
		_locale_text("Total", "总点数", "總點數"),
		aptitude_total
	]
	_refresh_button_row(from_buttons, selected_from, true)
	_refresh_button_row(to_buttons, selected_to, false)
	confirm_button.disabled = selected_from == selected_to

func _refresh_button_row(buttons: Dictionary, selected_attribute: String, source_row: bool) -> void:
	for key in buttons.keys():
		var button := buttons[key] as Button
		var value := int(current_aptitude.get(key, 3))
		var suffix := ""
		if source_row and String(key) == selected_attribute:
			suffix = " -1"
		elif not source_row and String(key) == selected_attribute:
			suffix = " +1"
		button.text = "%s\n%d%s" % [_attribute_name(String(key)), value, suffix]
		button.disabled = (source_row and value <= 1) or (not source_row and String(key) == selected_from)
		button.add_theme_stylebox_override(
			"normal",
			UISkin.flat_style(
				Color(0.18, 0.16, 0.12, 0.98) if String(key) == selected_attribute else UISkin.COLOR_PANEL,
				UISkin.COLOR_ACCENT if String(key) == selected_attribute else UISkin.COLOR_BORDER_ALT,
				2,
				4
			)
		)

func _confirm() -> void:
	if selected_from == selected_to:
		return
	visible = false
	get_tree().paused = false
	confirmed.emit(selected_from, selected_to)

func _default_from_attribute() -> String:
	var best_key := "strength"
	var best_value := -1
	for key in ATTRIBUTES:
		var value := int(current_aptitude.get(key, 0))
		if value > best_value:
			best_key = key
			best_value = value
	return best_key

func _default_to_attribute(from_attribute: String) -> String:
	var best_key := ""
	var best_value := 999
	for key in ATTRIBUTES:
		if key == from_attribute:
			continue
		var value := int(current_aptitude.get(key, 0))
		if value < best_value:
			best_key = key
			best_value = value
	return best_key if not best_key.is_empty() else "agility"

func _grade_delta(grade: String) -> int:
	match grade:
		"S":
			return 3
		"A":
			return 2
		"B":
			return 1
		"C":
			return 0
		_:
			return -1

func _attribute_name(attribute_id: String) -> String:
	match attribute_id:
		"agility":
			return _locale_text("Agility", "迅捷", "迅捷")
		"focus":
			return _locale_text("Focus", "专注", "專注")
		_:
			return _locale_text("Strength", "强壮", "強壯")

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		match String(UISettings.get_locale()):
			"zh_Hant":
				return zh_hant_text
			"zh_Hans":
				return zh_hans_text
	return en_text

