extends CanvasLayer

signal closed

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(340, 300)
const PANEL_MAX_SIZE := Vector2(470, 452)

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer
@onready var panel_margin: MarginContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer
@onready var title_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var status_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Status
@onready var fullscreen_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FullscreenButton
@onready var window_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WindowButton
@onready var vsync_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VSyncButton
@onready var close_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton

var layout_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 28
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.color = Color(0.01, 0.012, 0.018, 0.62)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_label, 28, Color(0.98, 0.90, 0.66))
	UISkin.label(status_label, 13, Color(0.76, 0.82, 0.90))
	for button in [fullscreen_button, window_button, vsync_button, close_button]:
		UISkin.button_styles(button, "large")
	fullscreen_button.pressed.connect(_set_fullscreen)
	window_button.pressed.connect(_set_windowed)
	vsync_button.pressed.connect(_toggle_vsync)
	close_button.pressed.connect(close)
	_refresh_status()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh_status()
	fullscreen_button.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _set_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_status()

func _set_windowed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_refresh_status()

func _toggle_vsync() -> void:
	var next_mode := DisplayServer.VSYNC_DISABLED if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else DisplayServer.VSYNC_ENABLED
	DisplayServer.window_set_vsync_mode(next_mode)
	_refresh_status()

func _refresh_status() -> void:
	var mode := "Fullscreen" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "Windowed"
	var vsync := "VSync On" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "VSync Off"
	status_label.text = "%s | %s" % [mode, vsync]
	vsync_button.text = "Turn VSync Off" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "Turn VSync On"

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 860.0 or viewport_size.y < 620.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (72.0 if compact else 160.0), PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - (84.0 if compact else 180.0), PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
	panel_margin.add_theme_constant_override("margin_left", 22 if compact else 34)
	panel_margin.add_theme_constant_override("margin_top", 20 if compact else 32)
	panel_margin.add_theme_constant_override("margin_right", 22 if compact else 34)
	panel_margin.add_theme_constant_override("margin_bottom", 20 if compact else 32)
	UISkin.label(title_label, 24 if compact else 28, Color(0.98, 0.90, 0.66))
	UISkin.label(status_label, 12 if compact else 13, Color(0.76, 0.82, 0.90))
	for button in [fullscreen_button, window_button, vsync_button, close_button]:
		button.custom_minimum_size.y = 48.0 if compact else 56.0
