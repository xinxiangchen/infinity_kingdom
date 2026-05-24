extends CanvasLayer

signal resume_requested
signal audio_requested
signal settings_requested
signal restart_requested
signal quit_requested

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(340, 360)
const PANEL_MAX_SIZE := Vector2(460, 590)
const BUTTON_DESCRIPTIONS := {
	"resume": "Return to the fight immediately.",
	"audio": "Adjust the current chapter mix without leaving the run.",
	"settings": "Switch fullscreen and sync options.",
	"restart": "Return to champion select and reset this run.",
	"quit": "Close the game client."
}

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
	restart_button.text = "Confirm Select" if confirm_action == &"restart" else "Champion Select"
	quit_button.text = "Confirm Quit" if confirm_action == &"quit" else "Quit Game"

func _refresh_subtitle() -> void:
	if confirm_action == &"restart":
		subtitle_label.text = "Press Champion Select again to abandon this run. Esc cancels."
		return
	if confirm_action == &"quit":
		subtitle_label.text = "Press Quit Game again to close the client. Esc cancels."
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == audio_button:
		subtitle_label.text = BUTTON_DESCRIPTIONS["audio"]
	elif focus_owner == settings_button:
		subtitle_label.text = BUTTON_DESCRIPTIONS["settings"]
	elif focus_owner == restart_button:
		subtitle_label.text = BUTTON_DESCRIPTIONS["restart"]
	elif focus_owner == quit_button:
		subtitle_label.text = BUTTON_DESCRIPTIONS["quit"]
	else:
		subtitle_label.text = BUTTON_DESCRIPTIONS["resume"]

func _refresh_context() -> void:
	var hero_name := "No Champion"
	var gold_value := int(RunDirector.gold)
	var cleared_value := int(RunDirector.cleared_encounters)
	var reward_flat_bonus := int(RunDirector.get_state().get("reward_flat_bonus", 0))
	var reward_multiplier := float(RunDirector.get_state().get("reward_multiplier", 1.0))
	var next_kind := RunDirector.describe_event_kind(RunDirector.peek_next_event_kind())
	var encounter_name := "No active encounter"
	if target_world != null and is_instance_valid(target_world):
		var player: Node = target_world.get("player_character")
		if player != null and is_instance_valid(player) and player.has_method("get_character_name"):
			hero_name = String(player.get_character_name())
		if bool(target_world.get("waiting_for_accessory_choice")):
			encounter_name = "Relic offering in progress"
		else:
			var encounter: Node = target_world.get("current_encounter")
			if encounter != null and is_instance_valid(encounter):
				if encounter.has_method("get_status_title"):
					encounter_name = String(encounter.get_status_title())
				else:
					encounter_name = String(encounter.name)
	var bounty_text := ""
	if reward_flat_bonus > 0:
		bounty_text += "  |  +%d gold" % reward_flat_bonus
	if reward_multiplier > 1.001:
		bounty_text += "  |  x%.2f reward" % reward_multiplier
	run_summary_label.text = "Hero %s  |  Gold %d  |  Cleared %d%s" % [hero_name, gold_value, cleared_value, bounty_text]
	encounter_summary_label.text = "Current %s  |  Next %s" % [encounter_name, next_kind if not next_kind.is_empty() else "Victory"]
	var equipped_accessory: Dictionary = AccessoryManager.get_equipped_accessory()
	var accessory_name := String(equipped_accessory.get("name", "No Accessory"))
	var accessory_tags := AccessoryManager.describe_tags(equipped_accessory.get("tags", []))
	relic_summary_label.text = "Relic %s%s" % [
		accessory_name,
		("  |  %s" % accessory_tags) if not accessory_tags.is_empty() else ""
	]
	hint_label.text = "Esc resume  |  A/F10 audio  |  S settings  |  R select  |  Q quit"

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
