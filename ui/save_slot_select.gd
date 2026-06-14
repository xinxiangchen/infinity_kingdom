extends CanvasLayer

signal slot_selected(slot_index: int)
signal new_slot_requested(slot_index: int)
signal quit_requested

const UISkin := preload("res://ui/ui_skin.gd")

var slot_buttons: Array[Button] = []
var delete_buttons: Array[Button] = []
var title_label: Label
var subtitle_label: Label
var detail_label: Label
var list_column: VBoxContainer
var quit_button: Button
var pending_delete_slot: int = -1


func _ready() -> void:
	layer = 12
	_build_ui()
	_refresh_slots()
	if SaveManager != null and not SaveManager.slots_changed.is_connected(_on_slots_changed):
		SaveManager.slots_changed.connect(_on_slots_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_5:
			_activate_slot(key_event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_ESCAPE:
			_cancel_delete()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_Q:
			quit_requested.emit()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.035, 0.045, 1.0)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 620)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	title_label = Label.new()
	title_label.text = _locale_text("Archives", "轮回档案", "輪迴檔案")
	UISkin.label(title_label, 34, UISkin.COLOR_ACCENT)
	column.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.text = _locale_text(
		"Choose an archive. Existing archives keep their chosen family.",
		"选择档案。已有档案会锁定创建时选择的家族。",
		"選擇檔案。既有檔案會鎖定建立時選擇的家族。"
	)
	UISkin.label(subtitle_label, 16, UISkin.COLOR_TEXT)
	column.add_child(subtitle_label)

	list_column = VBoxContainer.new()
	list_column.add_theme_constant_override("separation", 10)
	list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(list_column)
	for index in range(SaveManager.SLOT_COUNT if SaveManager != null else 5):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list_column.add_child(row)

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 72)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UISkin.button_styles(button, "large")
		button.pressed.connect(_activate_slot.bind(index))
		row.add_child(button)
		slot_buttons.append(button)

		var delete_button := Button.new()
		delete_button.text = _locale_text("Delete", "删除", "刪除")
		delete_button.custom_minimum_size = Vector2(112, 72)
		UISkin.button_styles(delete_button, "medium")
		delete_button.pressed.connect(_request_delete_slot.bind(index))
		row.add_child(delete_button)
		delete_buttons.append(delete_button)

	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = _default_detail_text()
	UISkin.label(detail_label, 13, UISkin.COLOR_MUTED)
	column.add_child(detail_label)

	quit_button = Button.new()
	quit_button.text = _locale_text("Quit", "退出游戏", "退出遊戲")
	UISkin.button_styles(quit_button, "medium")
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	column.add_child(quit_button)


func _refresh_slots() -> void:
	var slots: Array = SaveManager.list_slots() if SaveManager != null else []
	for index in range(slot_buttons.size()):
		var button := slot_buttons[index]
		var delete_button := delete_buttons[index]
		var slot: Dictionary = slots[index] if index < slots.size() else {}
		if not bool(slot.get("occupied", false)):
			button.text = "%d. %s" % [index + 1, _locale_text("Empty Archive - Create New", "空档案 - 新建", "空檔案 - 新建")]
			button.disabled = false
			delete_button.disabled = true
			delete_button.text = _locale_text("Delete", "删除", "刪除")
			continue
		var state_text := _locale_text("Active", "可继续", "可繼續")
		var ending_type := String(slot.get("ending_type", ""))
		if not ending_type.is_empty():
			state_text = _ending_label(ending_type)
			button.disabled = true
		elif bool(slot.get("dead_archive", false)):
			state_text = _locale_text("Dead Archive", "死档", "死檔")
			button.disabled = true
		elif bool(slot.get("cleared", false)):
			state_text = _locale_text("Cleared", "已通关", "已通關")
			button.disabled = false
		else:
			button.disabled = false
		button.text = "%d. %s  |  %s  |  %s %s  |  %s %d  |  %s %d/%d  |  %s %s" % [
			index + 1,
			String(slot.get("save_name", _locale_text("Archive", "档案", "檔案"))),
			state_text,
			_locale_text("Family", "家族", "家族"),
			_family_label(String(slot.get("family_id", ""))),
			_locale_text("Cycle", "轮回", "輪迴"),
			int(slot.get("reincarnation_index", 1)),
			_locale_text("Seeds", "火种", "火種"),
			int(slot.get("seeds_left", 5)),
			5,
			_locale_text("Score", "评分", "評分"),
			String(slot.get("last_score_grade", "-"))
		]
		delete_button.disabled = false
		delete_button.text = _locale_text("Confirm", "确认", "確認") if pending_delete_slot == index else _locale_text("Delete", "删除", "刪除")


func _activate_slot(slot_index: int) -> void:
	_cancel_delete()
	var slot := SaveManager.read_slot(slot_index) if SaveManager != null else {}
	if not String(slot.get("ending_type", "")).is_empty():
		return
	if bool(slot.get("dead_archive", false)):
		return
	if bool(slot.get("occupied", false)):
		slot_selected.emit(slot_index)
	else:
		new_slot_requested.emit(slot_index)


func _request_delete_slot(slot_index: int) -> void:
	var slot := SaveManager.read_slot(slot_index) if SaveManager != null else {}
	if slot.is_empty() or not bool(slot.get("occupied", false)):
		return
	if pending_delete_slot != slot_index:
		pending_delete_slot = slot_index
		detail_label.text = _locale_text(
			"Press Confirm to delete this archive. Esc cancels.",
			"再次点击确认可删除该档案。Esc 取消。",
			"再次點擊確認可刪除該檔案。Esc 取消。"
		)
		_refresh_slots()
		return
	SaveManager.delete_slot(slot_index)
	pending_delete_slot = -1
	detail_label.text = _default_detail_text()
	_refresh_slots()


func _cancel_delete() -> void:
	if pending_delete_slot < 0:
		return
	pending_delete_slot = -1
	detail_label.text = _default_detail_text()
	_refresh_slots()


func _on_slots_changed(_slots: Array) -> void:
	_refresh_slots()


func _default_detail_text() -> String:
	return _locale_text(
		"1-5 select archive. Delete requires a second confirm.",
		"按 1-5 选择档案。删除需要二次确认。",
		"按 1-5 選擇檔案。刪除需要二次確認。"
	)


func _family_label(family_id: String) -> String:
	match family_id:
		"knight":
			return _locale_text("Knight", "骑士", "騎士")
		"ranger":
			return _locale_text("Ranger", "游侠", "遊俠")
		"mage":
			return _locale_text("Mage", "法师", "法師")
		_:
			return _locale_text("Unset", "未定", "未定")


func _ending_label(ending_type: String) -> String:
	match ending_type:
		"break_crown":
			return _locale_text("Ending: Broken Crown", "结局：打碎王冠", "結局：打碎王冠")
		"ember_extinguished":
			return _locale_text("Ending: Embers Out", "结局：火种熄灭", "結局：火種熄滅")
		"escape":
			return _locale_text("Ending: Far Road", "结局：奔向远方", "結局：奔向遠方")
		"crown_bad":
			return _locale_text("Ending: Crown Taken", "结局：戴上王冠", "結局：戴上王冠")
		_:
			return _locale_text("Ending: Sealed", "结局：档案封存", "結局：檔案封存")

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		match String(UISettings.get_locale()):
			"zh_Hant":
				return zh_hant_text
			"zh_Hans":
				return zh_hans_text
	return en_text

