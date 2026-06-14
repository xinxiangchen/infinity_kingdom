extends CanvasLayer

signal reward_chosen(choice: Dictionary)

const UISkin := preload("res://ui/ui_skin.gd")

var backdrop: ColorRect
var panel: PanelContainer
var title_label: Label
var detail_label: Label
var choice_row: HBoxContainer
var choices: Array[Dictionary] = []

func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func open(reward_choices: Array[Dictionary]) -> void:
	choices = reward_choices.duplicate(true)
	_rebuild_choices()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.012, 0.014, 0.020, 0.72)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 420)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	title_label = Label.new()
	title_label.text = _locale_text("Choose A Field Reward", "选择关间奖励", "選擇關間獎勵")
	UISkin.label(title_label, 28, Color(0.98, 0.90, 0.66))
	column.add_child(title_label)

	detail_label = Label.new()
	detail_label.text = _locale_text("Pick one. Status rewards last only for the next map.", "三选一。状态奖励只在下一张小地图生效。", "三選一。狀態獎勵只在下一張小地圖生效。")
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(detail_label, 14, Color(0.78, 0.84, 0.92))
	column.add_child(detail_label)

	choice_row = HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 12)
	choice_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(choice_row)

func _rebuild_choices() -> void:
	for child in choice_row.get_children():
		child.queue_free()
	for index in range(choices.size()):
		var choice := choices[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(238, 240)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = _choice_button_text(choice)
		button.icon = load(String(choice.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
		button.expand_icon = true
		button.tooltip_text = String(choice.get("summary", ""))
		UISkin.button_styles(button, "large")
		button.pressed.connect(_choose.bind(index))
		choice_row.add_child(button)

func _choice_button_text(choice: Dictionary) -> String:
	var header := String(choice.get("title", "Reward"))
	var grade := String(choice.get("grade", ""))
	if not grade.is_empty():
		header = "%s [%s]" % [header, grade]
	return "%s\n\n%s" % [header, String(choice.get("summary", ""))]

func _choose(index: int) -> void:
	if index < 0 or index >= choices.size():
		return
	var choice := choices[index].duplicate(true)
	close()
	reward_chosen.emit(choice)

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		match String(UISettings.get_locale()):
			"zh_Hant":
				return zh_hant_text
			"zh_Hans":
				return zh_hans_text
	return en_text
