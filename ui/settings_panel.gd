extends CanvasLayer

signal closed

const UISkin := preload("res://ui/ui_skin.gd")

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer
@onready var panel_margin: MarginContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer
@onready var title_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var status_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Status
@onready var hint_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Hint
@onready var fullscreen_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FullscreenButton
@onready var window_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WindowButton
@onready var vsync_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/VSyncButton
@onready var close_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton

var layout_size_override: Vector2 = Vector2.ZERO
var language_buttons: Dictionary = {}
var language_header_label: Label

func _ready() -> void:
	layer = 28
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.color = Color(0.01, 0.012, 0.018, 0.72)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	_build_language_row()
	for button in [fullscreen_button, window_button, vsync_button, close_button]:
		UISkin.button_styles(button, "large")
	fullscreen_button.pressed.connect(_set_fullscreen)
	window_button.pressed.connect(_set_windowed)
	vsync_button.pressed.connect(_toggle_vsync)
	close_button.pressed.connect(close)
	if UISettings != null and UISettings.has_signal("locale_changed") and not UISettings.locale_changed.is_connected(_refresh_copy):
		UISettings.locale_changed.connect(_refresh_copy)
	_refresh_copy()
	_refresh_status()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func _build_language_row() -> void:
	var root_column := $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer as VBoxContainer
	var language_panel := PanelContainer.new()
	language_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	root_column.add_child(language_panel)
	root_column.move_child(language_panel, 3)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	language_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	language_header_label = Label.new()
	UISkin.label(language_header_label, 13, UISkin.COLOR_ACCENT)
	column.add_child(language_header_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	for locale in UISettings.LOCALES:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 38)
		UISkin.button_styles(button, "thin")
		button.pressed.connect(func() -> void: UISettings.set_locale(locale))
		row.add_child(button)
		language_buttons[locale] = button

func open() -> void:
	visible = true
	get_tree().paused = true
	_refresh_status()
	_refresh_copy()
	_grab_default_focus()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_C:
				close()
			KEY_F:
				_set_fullscreen()
			KEY_W:
				_set_windowed()
			KEY_V:
				_toggle_vsync()
			_:
				return
		get_viewport().set_input_as_handled()

func _set_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_status()
	_grab_default_focus()

func _set_windowed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_refresh_status()
	_grab_default_focus()

func _toggle_vsync() -> void:
	var next_mode := DisplayServer.VSYNC_DISABLED if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else DisplayServer.VSYNC_ENABLED
	DisplayServer.window_set_vsync_mode(next_mode)
	_refresh_status()

func _refresh_copy(_locale: String = "") -> void:
	title_label.text = UIText.text("settings_title")
	hint_label.text = UIText.text("settings_hint")
	fullscreen_button.text = UIText.text("settings_mode_fullscreen")
	window_button.text = UIText.text("settings_mode_windowed")
	close_button.text = UIText.text("settings_close")
	language_header_label.text = "%s  |  %s: %s" % [
		UIText.text("settings_language"),
		UIText.text("language_current"),
		UISettings.get_language_label()
	]
	for locale in language_buttons.keys():
		var button := language_buttons[locale] as Button
		button.text = UISettings.get_language_label(String(locale))
		button.button_pressed = String(locale) == UISettings.get_locale()
	_refresh_status()

func _refresh_status() -> void:
	var fullscreen_active := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var vsync_active := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	status_label.text = "%s  |  %s" % [
		UIText.text("settings_status_fullscreen") if fullscreen_active else UIText.text("settings_status_windowed"),
		UIText.text("settings_vsync_on") if vsync_active else UIText.text("settings_vsync_off")
	]
	vsync_button.text = UIText.text("settings_vsync_off") if vsync_active else UIText.text("settings_vsync_on")
	fullscreen_button.disabled = fullscreen_active
	window_button.disabled = not fullscreen_active

func _grab_default_focus() -> void:
	if not fullscreen_button.disabled:
		fullscreen_button.grab_focus()
	elif not window_button.disabled:
		window_button.grab_focus()
	else:
		close_button.grab_focus()

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact := viewport_size.x < 860.0 or viewport_size.y < 620.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (72.0 if compact else 160.0), 360.0, 620.0),
		clampf(viewport_size.y - (84.0 if compact else 180.0), 360.0, 560.0)
	)
	panel_margin.add_theme_constant_override("margin_left", 22 if compact else 34)
	panel_margin.add_theme_constant_override("margin_top", 20 if compact else 32)
	panel_margin.add_theme_constant_override("margin_right", 22 if compact else 34)
	panel_margin.add_theme_constant_override("margin_bottom", 20 if compact else 32)
	UISkin.label(title_label, 24 if compact else 28, UISkin.COLOR_ACCENT)
	UISkin.label(status_label, 12 if compact else 13, UISkin.COLOR_MUTED)
	UISkin.label(hint_label, 10 if compact else 11, UISkin.COLOR_MUTED)
	for button in [fullscreen_button, window_button, vsync_button, close_button]:
		button.custom_minimum_size.y = 48.0 if compact else 56.0
