extends CanvasLayer

var character: Node = null
var name_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var defense_bar: ProgressBar
var defense_label: Label
var inspiration_bar: ProgressBar
var inspiration_label: Label
var state_label: Label
var cooldown_label: Label


func _ready() -> void:
	layer = 11
	_build_ui()
	visible = false


func bind_character(target: Node) -> void:
	character = target
	visible = character != null
	if character == null:
		return
	_connect_signal("hp_changed", _on_hp_changed)
	_connect_signal("defense_changed", _on_defense_changed)
	_connect_signal("inspiration_changed", _on_inspiration_changed)
	_refresh_all()


func clear() -> void:
	character = null
	visible = false


func _process(_delta: float) -> void:
	if character == null or not is_instance_valid(character):
		return
	_refresh_runtime_fields()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.offset_left = 24.0
	panel.offset_top = 720.0
	panel.offset_right = 560.0
	panel.offset_bottom = 1040.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	name_label = _label("角色状态", 20, Color(1.0, 0.9, 0.64))
	content.add_child(name_label)
	hp_bar = _bar()
	content.add_child(hp_bar)
	hp_label = _label("HP", 14, Color(0.9, 0.92, 0.95))
	content.add_child(hp_label)
	defense_bar = _bar()
	content.add_child(defense_bar)
	defense_label = _label("Defense", 14, Color(0.9, 0.92, 0.95))
	content.add_child(defense_label)
	inspiration_bar = _bar()
	content.add_child(inspiration_bar)
	inspiration_label = _label("Inspiration", 14, Color(0.9, 0.92, 0.95))
	content.add_child(inspiration_label)
	state_label = _label("状态：-", 14, Color(0.82, 0.86, 0.92))
	content.add_child(state_label)
	cooldown_label = _label("冷却：-", 14, Color(0.82, 0.86, 0.92))
	cooldown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(cooldown_label)


func _refresh_all() -> void:
	if character == null or not is_instance_valid(character):
		return
	var character_name: String = String(character.get_character_name()) if character.has_method("get_character_name") else character.name
	name_label.text = "角色状态：%s" % character_name
	_on_hp_changed(float(character.get("hp")), float(character.get("max_hp")))
	_on_defense_changed(float(character.get("defense")), float(character.get("max_defense")))
	_on_inspiration_changed(float(character.get("inspiration")), float(character.get("max_inspiration")))
	_refresh_runtime_fields()


func _refresh_runtime_fields() -> void:
	var state_name := "-"
	var state_machine: Variant = character.get("state_machine")
	if state_machine != null and state_machine.has_method("get_state_name"):
		state_name = String(state_machine.get_state_name())
	state_label.text = "状态：%s" % state_name
	var cooldowns: Variant = character.get("cooldowns")
	if cooldowns is Dictionary:
		cooldown_label.text = "冷却：普攻 %.1f / K %.1f / L %.1f / I %.1f" % [
			float(cooldowns.get("attack", 0.0)),
			float(cooldowns.get("skill1", 0.0)),
			float(cooldowns.get("skill2", 0.0)),
			float(cooldowns.get("skill3", 0.0))
		]


func _on_hp_changed(current_hp: float, max_hp_value: float) -> void:
	hp_bar.value = _ratio(current_hp, max_hp_value)
	hp_label.text = "生命：%d / %d" % [int(round(current_hp)), int(round(max_hp_value))]


func _on_defense_changed(current_defense: float, max_defense_value: float) -> void:
	defense_bar.value = _ratio(current_defense, max_defense_value)
	defense_label.text = "防御：%d / %d" % [int(round(current_defense)), int(round(max_defense_value))]


func _on_inspiration_changed(current_inspiration: float, max_inspiration_value: float) -> void:
	inspiration_bar.value = _ratio(current_inspiration, max_inspiration_value)
	inspiration_label.text = "灵感：%d / %d" % [int(round(current_inspiration)), int(round(max_inspiration_value))]


func _connect_signal(signal_name: StringName, callable: Callable) -> void:
	if character != null and character.has_signal(signal_name) and not character.is_connected(signal_name, callable):
		character.connect(signal_name, callable)


func _ratio(current_value: float, max_value: float) -> float:
	return 0.0 if max_value <= 0.0 else clampf(current_value / max_value, 0.0, 1.0)


func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(420.0, 18.0)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	return bar


func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.072, 0.92)
	style.border_color = Color(0.72, 0.76, 0.84, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
