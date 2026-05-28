extends CanvasLayer

signal resume_requested
signal audio_requested
signal settings_requested
signal restart_requested
signal quit_requested

const RunEffects := preload("res://systems/run/run_effects.gd")
const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(340, 360)
const PANEL_MAX_SIZE := Vector2(460, 590)

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer
@onready var panel_margin: MarginContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer
@onready var title_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var run_summary_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RunPanel/MarginContainer/VBoxContainer/RunSummary
@onready var encounter_summary_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RunPanel/MarginContainer/VBoxContainer/EncounterSummary
@onready var relic_summary_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RunPanel/MarginContainer/VBoxContainer/RelicSummary
@onready var resume_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var audio_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/AudioButton
@onready var settings_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsButton
@onready var restart_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RestartButton
@onready var quit_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var hint_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Hint

var target_world: Node = null
var layout_size_override: Vector2 = Vector2.ZERO
var confirm_action: StringName = &""

func _ready() -> void:
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.color = Color(0.01, 0.012, 0.018, 0.68)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	run_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encounter_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relic_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_label, 30, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 14, Color(0.78, 0.84, 0.92))
	UISkin.label(run_summary_label, 12, Color(0.90, 0.92, 0.98))
	UISkin.label(encounter_summary_label, 12, Color(0.78, 0.84, 0.92))
	UISkin.label(relic_summary_label, 11, Color(0.88, 0.84, 0.66))
	UISkin.label(hint_label, 11, Color(0.74, 0.80, 0.88))
	for button in [resume_button, audio_button, settings_button, restart_button, quit_button]:
		UISkin.button_styles(button, "large")
	resume_button.pressed.connect(_on_resume_pressed)
	audio_button.pressed.connect(_on_audio_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	resume_button.focus_entered.connect(func() -> void: _on_button_focus(&"resume"))
	audio_button.focus_entered.connect(func() -> void: _on_button_focus(&"audio"))
	settings_button.focus_entered.connect(func() -> void: _on_button_focus(&"settings"))
	restart_button.focus_entered.connect(func() -> void: _on_button_focus(&"restart"))
	quit_button.focus_entered.connect(func() -> void: _on_button_focus(&"quit"))
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()
	_refresh_context()
	_refresh_subtitle()
	_refresh_button_labels()

func bind_world(world: Node) -> void:
	target_world = world

func _process(_delta: float) -> void:
	if visible:
		_refresh_context()

func open() -> void:
	_clear_confirm_state()
	visible = true
	get_tree().paused = true
	_refresh_context()
	_refresh_subtitle()
	_refresh_button_labels()
	resume_button.grab_focus()

func close() -> void:
	_clear_confirm_state()
	visible = false
	get_tree().paused = false

func is_open() -> bool:
	return visible

func suspend() -> void:
	_clear_confirm_state()
	visible = false

func resume_from_submenu() -> void:
	visible = true
	get_tree().paused = true
	_refresh_context()
	_refresh_subtitle()
	_refresh_button_labels()
	resume_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if confirm_action != &"":
					_clear_confirm_state()
				else:
					_on_resume_pressed()
				get_viewport().set_input_as_handled()
			KEY_F10, KEY_A:
				_on_audio_pressed()
				get_viewport().set_input_as_handled()
			KEY_S:
				_on_settings_pressed()
				get_viewport().set_input_as_handled()
			KEY_R:
				_on_restart_pressed()
				get_viewport().set_input_as_handled()
			KEY_Q:
				_on_quit_pressed()
				get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	_clear_confirm_state()
	resume_requested.emit()

func _on_audio_pressed() -> void:
	_clear_confirm_state()
	audio_requested.emit()

func _on_settings_pressed() -> void:
	_clear_confirm_state()
	settings_requested.emit()

func _on_restart_pressed() -> void:
	if confirm_action == &"restart":
		_clear_confirm_state()
		restart_requested.emit()
		return
	confirm_action = &"restart"
	_refresh_button_labels()
	_refresh_subtitle()
	restart_button.grab_focus()

func _on_quit_pressed() -> void:
	if confirm_action == &"quit":
		_clear_confirm_state()
		quit_requested.emit()
		return
	confirm_action = &"quit"
	_refresh_button_labels()
	_refresh_subtitle()
	quit_button.grab_focus()

func _on_button_focus(button_key: StringName) -> void:
	if confirm_action == &"restart" and button_key != &"restart":
		_clear_confirm_state()
	elif confirm_action == &"quit" and button_key != &"quit":
		_clear_confirm_state()
	_refresh_subtitle()

func _clear_confirm_state() -> void:
	if confirm_action == &"":
		return
	confirm_action = &""
	_refresh_button_labels()
	_refresh_subtitle()

func _refresh_button_labels() -> void:
	resume_button.text = UIText.text("battle_resume")
	audio_button.text = UIText.text("audio_mix")
	settings_button.text = UIText.text("menu_settings")
	restart_button.text = UIText.text("pause_restart_confirm_button") if confirm_action == &"restart" else UIText.text("pause_restart_button")
	quit_button.text = UIText.text("pause_quit_confirm_button") if confirm_action == &"quit" else UIText.text("pause_quit_button")

func _refresh_subtitle() -> void:
	if confirm_action == &"restart":
		subtitle_label.text = UIText.text("pause_restart_confirm")
		return
	if confirm_action == &"quit":
		subtitle_label.text = UIText.text("pause_quit_confirm")
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == audio_button:
		subtitle_label.text = UIText.text("pause_audio_desc")
	elif focus_owner == settings_button:
		subtitle_label.text = UIText.text("pause_settings_desc")
	elif focus_owner == restart_button:
		subtitle_label.text = UIText.text("pause_restart_desc")
	elif focus_owner == quit_button:
		subtitle_label.text = UIText.text("pause_quit_desc")
	else:
		subtitle_label.text = UIText.text("pause_resume_desc")

func _refresh_context() -> void:
	var hero_name := _locale_text("No Champion", "未选择角色", "未選擇角色")
	var run_state := RunDirector.get_state()
	var gold_value := int(run_state.get("gold", 0))
	var cleared_value := int(run_state.get("cleared_encounters", 0))
	var reward_flat_bonus := int(run_state.get("reward_flat_bonus", 0))
	var reward_multiplier := float(run_state.get("reward_multiplier", 1.0))
	var next_kind := RunDirector.describe_event_kind(RunDirector.peek_next_event_kind())
	var route_preview := RunDirector.describe_event_route(3)
	var pending_prep := run_state.get("pending_encounter_prep", {}) as Dictionary
	var recent_events_text := RunDirector.describe_event_history(2)
	var encounter_name := _locale_text("No active encounter", "当前没有战斗", "當前沒有戰鬥")
	var active_prep: Dictionary = {}
	if target_world != null and is_instance_valid(target_world):
		var player: Node = target_world.get("player_character")
		if player != null and is_instance_valid(player) and player.has_method("get_character_name"):
			hero_name = _hero_display_name(String(player.get_character_name()))
		if bool(target_world.get("waiting_for_accessory_choice")):
			encounter_name = _locale_text("Relic offering in progress", "正在选择饰品", "正在選擇飾品")
		else:
			var encounter: Node = target_world.get("current_encounter")
			if encounter != null and is_instance_valid(encounter):
				if encounter.has_method("get_status_title"):
					encounter_name = String(encounter.get_status_title())
				else:
					encounter_name = String(encounter.name)
		active_prep = target_world.get("active_encounter_prep") as Dictionary
	var bounty_text := ""
	if reward_flat_bonus > 0:
		bounty_text += _locale_text("  |  +%d gold", "  |  +%d 金币", "  |  +%d 金幣") % reward_flat_bonus
	if reward_multiplier > 1.001:
		bounty_text += _locale_text("  |  x%.2f reward", "  |  x%.2f 奖励", "  |  x%.2f 獎勵") % reward_multiplier
	run_summary_label.text = "%s %s  |  %s %d  |  %s %d  |  %s %d  |  %s %d%s" % [
		_locale_text("Hero", "角色", "角色"),
		hero_name,
		_locale_text("Gold", "金币", "金幣"),
		gold_value,
		_locale_text("Cleared", "完成", "完成"),
		cleared_value,
		_locale_text("Level", "等级", "等級"),
		int(run_state.get("hero_level", 1)),
		_locale_text("Kills", "击杀", "擊殺"),
		int(run_state.get("total_kills", 0)),
		bounty_text
	]
	var prep_parts: Array[String] = []
	if not active_prep.is_empty():
		prep_parts.append(_locale_text("Active prep %s", "已生效准备：%s", "已生效準備：%s") % RunEffects.prep_title(active_prep))
	elif not pending_prep.is_empty():
		prep_parts.append(_locale_text("Queued prep %s", "已排队准备：%s", "已排隊準備：%s") % RunEffects.prep_title(pending_prep))
	encounter_summary_label.text = "%s %s  |  %s %s\n%s %s%s" % [
		_locale_text("Current", "当前", "當前"),
		encounter_name,
		_locale_text("Next", "下一步", "下一步"),
		next_kind if not next_kind.is_empty() else _locale_text("Victory", "胜利", "勝利"),
		UIText.text("event_route_label"),
		route_preview,
		("\n%s" % "  |  ".join(prep_parts)) if not prep_parts.is_empty() else ""
	]
	var equipped_accessory: Dictionary = AccessoryManager.get_equipped_accessory()
	var accessory_name := String(equipped_accessory.get("name", _locale_text("No Accessory", "无饰品", "無飾品")))
	var accessory_tags := AccessoryManager.describe_tags(equipped_accessory.get("tags", []))
	relic_summary_label.text = "%s %s%s" % [
		_locale_text("Relic", "饰品", "飾品"),
		accessory_name,
		("  |  %s" % accessory_tags) if not accessory_tags.is_empty() else ""
	]
	if not (run_state.get("event_history", []) as Array).is_empty():
		relic_summary_label.text += "\n%s %s" % [_locale_text("Recent", "最近", "最近"), recent_events_text]
	title_label.text = UIText.text("pause_title")
	hint_label.text = UIText.text("pause_hint")

func _current_locale() -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		return String(UISettings.get_locale())
	return "zh_Hans"

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	match _current_locale():
		"zh_Hant":
			return zh_hant_text
		"zh_Hans":
			return zh_hans_text
		_:
			return en_text

func _hero_display_name(hero_name: String) -> String:
	match hero_name:
		"Knight":
			return _locale_text("Knight", "骑士", "騎士")
		"Ranger":
			return _locale_text("Ranger", "游侠", "遊俠")
		"Mage":
			return _locale_text("Mage", "法师", "法師")
		_:
			return hero_name

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 860.0 or viewport_size.y < 640.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (72.0 if compact else 140.0), PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - (72.0 if compact else 160.0), PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
	panel_margin.add_theme_constant_override("margin_left", 22 if compact else 34)
	panel_margin.add_theme_constant_override("margin_top", 20 if compact else 32)
	panel_margin.add_theme_constant_override("margin_right", 22 if compact else 34)
	panel_margin.add_theme_constant_override("margin_bottom", 20 if compact else 32)
	UISkin.label(title_label, 24 if compact else 30, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 12 if compact else 14, Color(0.78, 0.84, 0.92))
	UISkin.label(run_summary_label, 11 if compact else 12, Color(0.90, 0.92, 0.98))
	UISkin.label(encounter_summary_label, 11 if compact else 12, Color(0.78, 0.84, 0.92))
	UISkin.label(relic_summary_label, 10 if compact else 11, Color(0.88, 0.84, 0.66))
	UISkin.label(hint_label, 10 if compact else 11, Color(0.74, 0.80, 0.88))
	for button in [resume_button, audio_button, settings_button, restart_button, quit_button]:
		button.custom_minimum_size.y = 48.0 if compact else 58.0
