extends CanvasLayer

signal upgrade_purchased(upgrade_id: String)
signal pause_requested

const UISkin := preload("res://ui/ui_skin.gd")

var backdrop: ColorRect
var panel: PanelContainer
var title_label: Label
var detail_label: Label
var points_label: Label
var open_hint_label: Label
var scroll: ScrollContainer
var list_root: VBoxContainer

var active_actor: Node = null
var upgrade_buttons: Array[Button] = []

func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	if RunDirector != null and not RunDirector.state_changed.is_connected(_on_run_state_changed):
		RunDirector.state_changed.connect(_on_run_state_changed)

func bind_actor(actor: Node) -> void:
	if active_actor != null and is_instance_valid(active_actor) and active_actor.has_signal("upgrades_changed"):
		var refresh_callable := Callable(self, "_refresh_content")
		if active_actor.is_connected("upgrades_changed", refresh_callable):
			active_actor.disconnect("upgrades_changed", refresh_callable)
	active_actor = actor
	if active_actor != null and is_instance_valid(active_actor) and active_actor.has_signal("upgrades_changed"):
		var refresh_callable := Callable(self, "_refresh_content")
		if not active_actor.is_connected("upgrades_changed", refresh_callable):
			active_actor.connect("upgrades_changed", refresh_callable)
	_refresh_content()

func open() -> void:
	_refresh_content()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func has_available_upgrades() -> bool:
	if active_actor == null or not is_instance_valid(active_actor):
		return false
	if not active_actor.has_method("get_upgrade_sections") or not active_actor.has_method("is_upgrade_enabled"):
		return false
	var points := int(RunDirector.get_state().get("skill_points", 0)) if RunDirector != null else 0
	if points <= 0:
		return false
	for section_variant in active_actor.get_upgrade_sections():
		var section: Dictionary = section_variant
		for upgrade_variant in section.get("upgrades", []):
			var upgrade: Dictionary = upgrade_variant
			var upgrade_id := String(upgrade.get("id", ""))
			if upgrade_id.is_empty():
				continue
			if not bool(active_actor.is_upgrade_enabled(upgrade_id)):
				return true
	return false

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.012, 0.014, 0.020, 0.72)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 560)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	title_label = Label.new()
	title_label.text = _locale_text("Skill Tree", "技能加点", "技能加點")
	UISkin.label(title_label, 28, Color(0.98, 0.90, 0.66))
	column.add_child(title_label)

	detail_label = Label.new()
	detail_label.text = _locale_text(
		"Each level grants 1 point. Spend points to unlock upgrades. Esc opens the menu.",
		"每次升级获得 1 点技能点，最多储存 6 点。点击词条即可解锁。Esc 打开菜单。",
		"每次升級獲得 1 點技能點，最多儲存 6 點。點擊詞條即可解鎖。Esc 打開選單。"
	)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(detail_label, 14, Color(0.78, 0.84, 0.92))
	column.add_child(detail_label)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	column.add_child(top_row)

	points_label = Label.new()
	points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.label(points_label, 16, Color(0.92, 0.88, 0.64))
	top_row.add_child(points_label)

	open_hint_label = Label.new()
	open_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UISkin.label(open_hint_label, 13, Color(0.72, 0.80, 0.90))
	top_row.add_child(open_hint_label)

	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	list_root = VBoxContainer.new()
	list_root.add_theme_constant_override("separation", 10)
	list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_root)

func _refresh_content() -> void:
	_refresh_header()
	_clear_entries()
	if list_root == null:
		return
	if active_actor == null or not is_instance_valid(active_actor):
		var label := Label.new()
		label.text = _locale_text("No active hero.", "当前没有可加点角色。", "當前沒有可加點角色。")
		UISkin.label(label, 14, Color(0.82, 0.90, 0.98))
		list_root.add_child(label)
		return
	if not active_actor.has_method("get_upgrade_sections") or not active_actor.has_method("is_upgrade_enabled") or not active_actor.has_method("set_upgrade_enabled"):
		var label := Label.new()
		label.text = _locale_text("This hero has no skill tree data.", "该角色暂时没有技能树数据。", "該角色暫時沒有技能樹資料。")
		UISkin.label(label, 14, Color(0.82, 0.90, 0.98))
		list_root.add_child(label)
		return
	var sections: Array = active_actor.get_upgrade_sections()
	for section_variant in sections:
		var section: Dictionary = section_variant
		_build_section(section)

func _build_section(section: Dictionary) -> void:
	var section_panel := PanelContainer.new()
	section_panel.add_theme_stylebox_override("panel", UISkin.choice_panel_style())
	list_root.add_child(section_panel)

	var section_margin := MarginContainer.new()
	section_margin.add_theme_constant_override("margin_left", 16)
	section_margin.add_theme_constant_override("margin_top", 14)
	section_margin.add_theme_constant_override("margin_right", 16)
	section_margin.add_theme_constant_override("margin_bottom", 14)
	section_panel.add_child(section_margin)

	var section_column := VBoxContainer.new()
	section_column.add_theme_constant_override("separation", 8)
	section_margin.add_child(section_column)

	var section_title := Label.new()
	section_title.text = String(section.get("title", _locale_text("Skill", "技能", "技能")))
	UISkin.label(section_title, 18, Color(0.90, 0.92, 0.98))
	section_column.add_child(section_title)

	for upgrade_variant in section.get("upgrades", []):
		var upgrade: Dictionary = upgrade_variant
		var entry := _build_upgrade_entry(upgrade)
		section_column.add_child(entry)

func _build_upgrade_entry(upgrade: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var upgrade_id := String(upgrade.get("id", ""))
	var upgrade_label := String(upgrade.get("label", upgrade_id))
	var upgrade_description := String(upgrade.get("description", ""))
	var learned := active_actor != null and is_instance_valid(active_actor) and active_actor.has_method("is_upgrade_enabled") and bool(active_actor.is_upgrade_enabled(upgrade_id))
	var points := int(RunDirector.get_state().get("skill_points", 0)) if RunDirector != null else 0

	var button := Button.new()
	button.text = "%s%s" % [upgrade_label, _locale_text("  [Learned]", "  [已解锁]", "  [已解鎖]") if learned else ""]
	button.tooltip_text = upgrade_description
	button.disabled = learned or points <= 0
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.button_styles(button, "thin")
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))
	row.add_child(button)
	upgrade_buttons.append(button)

	var description_label := Label.new()
	description_label.text = upgrade_description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(description_label, 12, Color(0.78, 0.84, 0.92))
	row.add_child(description_label)

	return row

func _clear_entries() -> void:
	upgrade_buttons.clear()
	if list_root == null:
		return
	for child in list_root.get_children():
		child.queue_free()

func _refresh_header() -> void:
	if points_label == null:
		return
	var state := RunDirector.get_state() if RunDirector != null else {}
	var points := int(state.get("skill_points", 0))
	var max_points := int(state.get("max_skill_points", 6))
	points_label.text = _locale_text(
		"Skill Points: %d / %d",
		"技能点：%d / %d",
		"技能點：%d / %d"
	) % [points, max_points]
	if open_hint_label != null:
		open_hint_label.text = _locale_text(
			"Hotkey: U",
			"快捷键：U",
			"快捷鍵：U"
		)

func _on_upgrade_pressed(upgrade_id: String) -> void:
	if upgrade_id.is_empty():
		return
	if active_actor == null or not is_instance_valid(active_actor):
		return
	if not active_actor.has_method("is_upgrade_enabled") or not active_actor.has_method("set_upgrade_enabled"):
		return
	if bool(active_actor.is_upgrade_enabled(upgrade_id)):
		return
	if RunDirector == null or not RunDirector.can_spend_skill_point(1):
		return
	active_actor.set_upgrade_enabled(upgrade_id, true)
	if not RunDirector.spend_skill_point(1):
		active_actor.set_upgrade_enabled(upgrade_id, false)
		return
	upgrade_purchased.emit(upgrade_id)
	_refresh_content()

func _on_run_state_changed(_state: Dictionary) -> void:
	_refresh_header()
	if visible:
		_refresh_content()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			pause_requested.emit()
			get_viewport().set_input_as_handled()

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		match String(UISettings.get_locale()):
			"zh_Hant":
				return zh_hant_text
			"zh_Hans":
				return zh_hans_text
	return en_text
