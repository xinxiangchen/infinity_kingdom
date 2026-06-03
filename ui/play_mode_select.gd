extends CanvasLayer

signal normal_requested
signal debug_requested
signal back_requested

var selected_character_id: StringName = &""
var title_label: Label
var subtitle_label: Label


func _ready() -> void:
	layer = 20
	_build_ui()
	visible = false


func open(character_id: StringName) -> void:
	selected_character_id = character_id
	visible = true
	if title_label != null:
		title_label.text = "选择启动模式"
	if subtitle_label != null:
		subtitle_label.text = "已选择角色：%s。正常模式进入完整主流程；调试模式进入无地图角色测试场。" % _character_label(character_id)


func close() -> void:
	visible = false


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.02, 0.025, 0.03, 0.86)
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 320.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.66))
	content.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
	content.add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 14)
	content.add_child(button_row)

	button_row.add_child(_mode_button("正常流程", "完整地图、战斗、饰品与结算。", normal_requested.emit))
	button_row.add_child(_mode_button("角色调试", "无地图，测角色和指定敌人。", debug_requested.emit))

	var back_button := Button.new()
	back_button.text = "返回选人"
	back_button.custom_minimum_size = Vector2(180.0, 40.0)
	back_button.pressed.connect(back_requested.emit)
	content.add_child(back_button)


func _mode_button(label_text: String, hint_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [label_text, hint_text]
	button.custom_minimum_size = Vector2(240.0, 96.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.08, 0.095, 0.96)
	style.border_color = Color(0.76, 0.64, 0.38, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _character_label(character_id: StringName) -> String:
	match character_id:
		&"knight":
			return "骑士"
		&"ranger":
			return "游侠"
		&"mage":
			return "法师"
		_:
			return String(character_id)
