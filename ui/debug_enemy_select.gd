extends CanvasLayer

signal enemy_selected(enemy_id: StringName, elite: bool)

var elite_check: CheckBox

const ENEMY_OPTIONS := [
	{"id": &"dummy", "label": "训练假人"},
	{"id": &"swordsman", "label": "剑兵"},
	{"id": &"shield", "label": "盾卫"},
	{"id": &"archer", "label": "弓手"},
	{"id": &"hunter", "label": "猎手"},
	{"id": &"apprentice", "label": "学徒法师"},
	{"id": &"arcanist", "label": "秘术师"},
	{"id": &"judicator_boss", "label": "Boss：审判官"},
	{"id": &"twin_princes_boss", "label": "Boss：双子王子"},
	{"id": &"ranger_boss", "label": "Boss：影猎者"},
	{"id": &"mage_boss", "label": "Boss：大奥术师"},
	{"id": &"emperor_boss", "label": "Boss：皇帝"}
]


func _ready() -> void:
	layer = 12
	_build_ui()
	visible = false


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.offset_left = 24.0
	panel.offset_top = 92.0
	panel.offset_right = 340.0
	panel.offset_bottom = 610.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var title := Label.new()
	title.text = "测试敌人"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.64))
	content.add_child(title)

	var hint := Label.new()
	hint.text = "选择后会刷新右侧目标。Boss 不受精英勾选影响。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	content.add_child(hint)

	elite_check = CheckBox.new()
	elite_check.text = "小怪使用精英版"
	content.add_child(elite_check)

	for option in ENEMY_OPTIONS:
		var button := Button.new()
		button.text = String(option["label"])
		button.custom_minimum_size = Vector2(260.0, 36.0)
		var enemy_id: StringName = option["id"]
		button.pressed.connect(func() -> void:
			enemy_selected.emit(enemy_id, elite_check.button_pressed)
		)
		content.add_child(button)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.065, 0.078, 0.92)
	style.border_color = Color(0.52, 0.66, 0.78, 0.68)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
