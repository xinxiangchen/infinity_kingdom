extends CanvasLayer

signal resume_requested
signal audio_requested
signal settings_requested
signal restart_requested
signal quit_requested

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(340, 360)
const PANEL_MAX_SIZE := Vector2(460, 590)

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer
@onready var title_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var resume_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var audio_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/AudioButton
@onready var settings_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsButton
@onready var restart_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RestartButton
@onready var quit_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.color = Color(0.01, 0.012, 0.018, 0.68)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	UISkin.label(title_label, 30, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 14, Color(0.78, 0.84, 0.92))
	for button in [resume_button, audio_button, settings_button, restart_button, quit_button]:
		UISkin.button_styles(button, "large")
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	audio_button.pressed.connect(func() -> void: audio_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func open() -> void:
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func is_open() -> bool:
	return visible

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 140.0, PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - 160.0, PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
