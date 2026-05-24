extends CanvasLayer

signal closed

const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const MASTER_LABEL := "Master"
const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_WIDTH := 380.0
const PANEL_MAX_WIDTH := 620.0
const PANEL_MIN_BOTTOM := 460.0
const PANEL_MAX_BOTTOM := 912.0

const BUS_ORDER := [BUS_MUSIC, BUS_AMBIENCE, BUS_SFX, BUS_UI]
const BUS_LABELS := {
	BUS_MUSIC: "Music",
	BUS_AMBIENCE: "Ambience",
	BUS_SFX: "SFX",
	BUS_UI: "UI"
}

const BUS_DESCRIPTIONS := {
	BUS_MUSIC: "Chapter score and stingers",
	BUS_AMBIENCE: "Wind, hall air, and space texture",
	BUS_SFX: "Combat impacts and skill feedback",
	BUS_UI: "Menu confirms and interface sounds"
}

const BUS_SHORT_DESCRIPTIONS := {
	BUS_MUSIC: "Score and stingers",
	BUS_AMBIENCE: "Wind and space",
	BUS_SFX: "Combat feedback",
	BUS_UI: "Menu sounds"
}

@onready var title_label: Label = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var master_slider: HSlider = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MasterPanel/MarginContainer/VBoxContainer/ControlsRow/MasterSlider
@onready var master_value_label: Label = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MasterPanel/MarginContainer/VBoxContainer/ControlsRow/MasterValueLabel
@onready var rows_container: VBoxContainer = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Rows
@onready var root_margin: MarginContainer = $Backdrop/MarginContainer
@onready var master_mute_button: Button = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/MasterMuteButton
@onready var reset_button: Button = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/ResetButton
@onready var close_button: Button = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/CloseButton
@onready var button_row: HBoxContainer = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow
@onready var status_label: Label = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var hint_label: Label = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Hint
@onready var panel: PanelContainer = $Backdrop/MarginContainer/PanelContainer
@onready var master_panel: PanelContainer = $Backdrop/MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MasterPanel

var slider_map: Dictionary = {}
var value_label_map: Dictionary = {}
var mute_button_map: Dictionary = {}
var preview_button_map: Dictionary = {}
var bus_label_map: Dictionary = {}
var bus_description_map: Dictionary = {}
var bus_header_row_map: Dictionary = {}
var bus_buttons_row_map: Dictionary = {}
var suppress_slider_events: bool = false
var hint_tween: Tween = null
var layout_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	_apply_skin()
	_build_rows()
	master_slider.value_changed.connect(_on_master_slider_value_changed)
	master_mute_button.toggled.connect(_on_master_mute_toggled)
	reset_button.pressed.connect(_on_reset_pressed)
	close_button.pressed.connect(_on_close_pressed)
	visible = false
	refresh_values()
	_set_status_text("Reset restores the chapter mix. Mute keeps the current slider level in memory.")
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func _apply_skin() -> void:
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	master_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	UISkin.button_styles(master_mute_button, "thin")
	UISkin.button_styles(reset_button, "thin")
	UISkin.button_styles(close_button, "thin")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(status_label, 13, Color(0.93, 0.85, 0.68))
	UISkin.label(hint_label, 12, Color(0.84, 0.88, 0.96))

func toggle_panel() -> void:
	set_panel_visible(not visible)

func show_panel() -> void:
	set_panel_visible(true)

func hide_panel() -> void:
	set_panel_visible(false)

func is_open() -> bool:
	return visible

func set_panel_visible(is_visible: bool) -> void:
	var was_visible := visible
	visible = is_visible
	if not is_visible:
		if was_visible:
			closed.emit()
		return
	refresh_values()
	_set_status_text("Audio settings are saved locally. Drag a slider or mute a lane to adjust the chapter mix.")
	_play_hint_animation()
	master_slider.grab_focus()

func refresh_values() -> void:
	suppress_slider_events = true
	master_mute_button.button_pressed = Music.is_master_muted()
	master_mute_button.text = "Master Muted" if Music.is_master_muted() else "Master Mute"
	master_slider.value = _db_to_slider(Music.get_master_display_volume())
	_update_master_visuals()
	for bus_name in BUS_ORDER:
		if not slider_map.has(bus_name):
			continue
		var slider: HSlider = slider_map[bus_name]
		var slider_value := _db_to_slider(Music.get_bus_display_volume(StringName(bus_name)))
		slider.value = slider_value
		_update_row_visuals(bus_name)
	suppress_slider_events = false

func _build_rows() -> void:
	for bus_name in BUS_ORDER:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
		rows_container.add_child(panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)

		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		margin.add_child(column)

		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 12)
		column.add_child(header_row)

		var label := Label.new()
		label.custom_minimum_size = Vector2(82.0, 0.0)
		label.text = String(BUS_LABELS[bus_name])
		UISkin.label(label, 14, Color(0.98, 0.90, 0.66))
		header_row.add_child(label)

		var description := Label.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.modulate = Color(0.78, 0.84, 0.92, 0.92)
		description.text = String(BUS_DESCRIPTIONS[bus_name])
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UISkin.label(description, 12, Color(0.78, 0.84, 0.92))
		header_row.add_child(description)

		var controls_column := VBoxContainer.new()
		controls_column.add_theme_constant_override("separation", 8)
		column.add_child(controls_column)

		var slider_row := HBoxContainer.new()
		slider_row.add_theme_constant_override("separation", 12)
		controls_column.add_child(slider_row)

		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value_changed.connect(_on_slider_value_changed.bind(bus_name))
		slider_row.add_child(slider)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(106.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = "100% | 0.0 dB"
		UISkin.label(value_label, 12, Color(0.86, 0.88, 0.92))
		slider_row.add_child(value_label)

		var buttons_row := HBoxContainer.new()
		buttons_row.add_theme_constant_override("separation", 10)
		buttons_row.alignment = BoxContainer.ALIGNMENT_END
		controls_column.add_child(buttons_row)

		var mute_button := Button.new()
		mute_button.custom_minimum_size = Vector2(72.0, 34.0)
		mute_button.toggle_mode = true
		mute_button.toggled.connect(_on_mute_toggled.bind(bus_name))
		UISkin.button_styles(mute_button, "thin")
		buttons_row.add_child(mute_button)

		var preview_button := Button.new()
		preview_button.custom_minimum_size = Vector2(82.0, 34.0)
		preview_button.text = "Preview"
		preview_button.pressed.connect(_on_preview_pressed.bind(bus_name))
		UISkin.button_styles(preview_button, "thin")
		buttons_row.add_child(preview_button)

		slider_map[bus_name] = slider
		value_label_map[bus_name] = value_label
		mute_button_map[bus_name] = mute_button
		preview_button_map[bus_name] = preview_button
		bus_label_map[bus_name] = label
		bus_description_map[bus_name] = description
		bus_header_row_map[bus_name] = header_row
		bus_buttons_row_map[bus_name] = buttons_row

func _on_master_slider_value_changed(value: float) -> void:
	if suppress_slider_events:
		_update_master_visuals()
		return
	Music.set_master_volume(_slider_to_db(value))
	_update_master_visuals()
	_set_status_text("%s output set to %d%% (%s)." % [
		MASTER_LABEL,
		int(round(value)),
		_format_db(Music.get_master_display_volume())
	])

func _on_slider_value_changed(value: float, bus_name: String) -> void:
	if suppress_slider_events:
		_update_row_visuals(bus_name)
		return
	Music.set_bus_volume(StringName(bus_name), _slider_to_db(value))
	_update_row_visuals(bus_name)
	_set_status_text("%s lane set to %d%% (%s)." % [
		String(BUS_LABELS[bus_name]),
		int(round(value)),
		_format_db(Music.get_bus_display_volume(StringName(bus_name)))
	])

func _on_mute_toggled(pressed: bool, bus_name: String) -> void:
	if suppress_slider_events:
		return
	Music.set_bus_muted(StringName(bus_name), pressed)
	_update_row_visuals(bus_name)
	if pressed:
		_set_status_text("%s muted. Preset level remains at %d%%." % [
			String(BUS_LABELS[bus_name]),
			int(round(_db_to_slider(Music.get_bus_display_volume(StringName(bus_name)))))
		])
	else:
		_set_status_text("%s restored to %s." % [
			String(BUS_LABELS[bus_name]),
			_format_db(Music.get_bus_display_volume(StringName(bus_name)))
		])
	if Sfx != null:
		Sfx.play_event(&"ui_confirm")

func _on_preview_pressed(bus_name: String) -> void:
	if Music.is_master_muted():
		_set_status_text("Master mute is enabled. Disable it before auditioning the mix.")
		return
	if Music.is_bus_muted(StringName(bus_name)):
		_set_status_text("%s is muted. Unmute that lane to hear its preview." % String(BUS_LABELS[bus_name]))
		return
	var played := Music.preview_bus(StringName(bus_name))
	if played:
		_set_status_text("Previewing %s lane at %s." % [
			String(BUS_LABELS[bus_name]),
			_format_db(Music.get_bus_display_volume(StringName(bus_name)))
		])
	else:
		_set_status_text("No preview source is available for %s right now." % String(BUS_LABELS[bus_name]))

func _on_master_mute_toggled(pressed: bool) -> void:
	if suppress_slider_events:
		return
	Music.set_master_muted(pressed)
	refresh_values()
	if pressed:
		_set_status_text("All audio is muted at the Master bus.")
	else:
		_set_status_text("Master audio restored. Bus balances remain unchanged.")
	_update_master_visuals()
	for bus_name in BUS_ORDER:
		_update_row_visuals(bus_name)
	if Sfx != null and not pressed:
		Sfx.play_event(&"ui_confirm")

func _on_reset_pressed() -> void:
	Music.reset_bus_settings()
	refresh_values()
	_set_status_text("Chapter defaults restored for Master, Music, Ambience, SFX, and UI.")
	if Sfx != null:
		Sfx.play_event(&"ui_confirm")

func _on_close_pressed() -> void:
	hide_panel()
	if Sfx != null:
		Sfx.play_event(&"ui_confirm")

func _update_row_visuals(bus_name: String) -> void:
	if not slider_map.has(bus_name):
		return
	var slider: HSlider = slider_map[bus_name]
	var mute_button: Button = mute_button_map[bus_name]
	var preview_button: Button = preview_button_map[bus_name]
	var is_muted := Music.is_bus_muted(StringName(bus_name))
	var display_db := Music.get_bus_display_volume(StringName(bus_name))
	var slider_value := slider.value
	suppress_slider_events = true
	mute_button.button_pressed = is_muted
	mute_button.text = "Muted" if is_muted else "Mute"
	suppress_slider_events = false
	preview_button.disabled = is_muted or Music.is_master_muted()
	_update_value_label(bus_name, slider_value, display_db, is_muted)

func _update_master_visuals() -> void:
	var is_muted := Music.is_master_muted()
	var display_db := Music.get_master_display_volume()
	var slider_value := master_slider.value
	master_value_label.text = "%d%% | %s" % [int(round(slider_value)), _format_db(display_db)]
	if is_muted:
		master_value_label.text = "%d%% | Muted" % int(round(slider_value))
	elif absf(display_db - Music.get_default_master_volume()) <= 0.15:
		master_value_label.text = "%d%% | Default" % int(round(slider_value))

func _update_value_label(bus_name: String, slider_value: float, display_db: float, is_muted: bool) -> void:
	if not value_label_map.has(bus_name):
		return
	var value_label: Label = value_label_map[bus_name]
	var text := "%d%% | %s" % [int(round(slider_value)), _format_db(display_db)]
	if is_muted:
		text = "%d%% | Muted" % int(round(slider_value))
	elif _is_default_mix(bus_name, display_db):
		text = "%d%% | Default" % int(round(slider_value))
	value_label.text = text

func _is_default_mix(bus_name: String, display_db: float) -> bool:
	return absf(display_db - Music.get_default_bus_volume(StringName(bus_name))) <= 0.15 and not Music.is_bus_muted(StringName(bus_name))

func _set_status_text(text: String) -> void:
	status_label.text = text

func _play_hint_animation() -> void:
	if hint_tween != null:
		hint_tween.kill()
	hint_label.modulate = Color(0.84, 0.88, 0.96, 0.38)
	hint_label.scale = Vector2.ONE * 0.98
	hint_tween = create_tween()
	hint_tween.tween_property(hint_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)
	hint_tween.parallel().tween_property(hint_label, "scale", Vector2.ONE * 1.03, 0.22)
	hint_tween.tween_property(hint_label, "scale", Vector2.ONE, 0.18)
	hint_tween.parallel().tween_property(hint_label, "modulate", Color(0.84, 0.88, 0.96, 1.0), 0.18)

func _format_db(volume_db: float) -> String:
	if volume_db <= -39.0:
		return "Muted"
	return "%+.1f dB" % volume_db

func _db_to_slider(volume_db: float) -> float:
	if volume_db <= -39.0:
		return 0.0
	return clampf(db_to_linear(volume_db) * 100.0, 0.0, 100.0)

func _slider_to_db(slider_value: float) -> float:
	if slider_value <= 0.0:
		return -40.0
	return linear_to_db(slider_value / 100.0)

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if root_margin == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 1040.0 or viewport_size.y < 720.0
	var very_compact: bool = viewport_size.x < 820.0 or viewport_size.y < 620.0
	var panel_width := clampf(viewport_size.x * (0.46 if very_compact else 0.38), 300.0, PANEL_MAX_WIDTH)
	var top_offset := 18.0 if very_compact else (28.0 if compact else 52.0)
	root_margin.offset_left = -panel_width
	root_margin.offset_right = -12.0 if very_compact else -18.0
	root_margin.offset_top = top_offset
	root_margin.offset_bottom = clampf(viewport_size.y - (12.0 if very_compact else 18.0), 332.0, PANEL_MAX_BOTTOM)
	root_margin.add_theme_constant_override("margin_left", 8 if very_compact else 10)
	root_margin.add_theme_constant_override("margin_top", 8 if very_compact else 10)
	root_margin.add_theme_constant_override("margin_right", 8 if very_compact else 10)
	root_margin.add_theme_constant_override("margin_bottom", 8 if very_compact else 10)
	UISkin.label(title_label, 20 if very_compact else (22 if compact else 24), Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 12 if very_compact else 13, Color(0.88, 0.90, 0.95))
	UISkin.label(status_label, 12 if compact else 13, Color(0.93, 0.85, 0.68))
	UISkin.label(hint_label, 11 if compact else 12, Color(0.84, 0.88, 0.96))
	master_value_label.custom_minimum_size = Vector2(90.0 if very_compact else (98.0 if compact else 122.0), 0.0)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER if compact else BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8 if compact else 12)
	master_mute_button.custom_minimum_size = Vector2(0.0, 34.0 if compact else 38.0)
	reset_button.custom_minimum_size = Vector2(0.0, 34.0 if compact else 38.0)
	close_button.custom_minimum_size = Vector2(0.0, 34.0 if compact else 38.0)
	master_mute_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_mute_button.text = "Master Off" if very_compact and Music.is_master_muted() else ("Master Mute" if not very_compact and not Music.is_master_muted() else ("Master On" if very_compact else "Master Muted"))
	reset_button.text = "Reset" if very_compact else ("Reset Mix" if compact else "Chapter Default")
	close_button.text = "Close"
	hint_label.text = "F10 toggle  |  Esc close" if very_compact else "F10 toggle panel  |  Esc close"
	for bus_name in BUS_ORDER:
		if bus_label_map.has(bus_name):
			var bus_label: Label = bus_label_map[bus_name]
			bus_label.custom_minimum_size = Vector2(60.0 if very_compact else (72.0 if compact else 82.0), 0.0)
			UISkin.label(bus_label, 13 if compact else 14, Color(0.98, 0.90, 0.66))
		if bus_description_map.has(bus_name):
			var description: Label = bus_description_map[bus_name]
			description.text = String(BUS_SHORT_DESCRIPTIONS[bus_name]) if very_compact else String(BUS_DESCRIPTIONS[bus_name])
			UISkin.label(description, 11 if compact else 12, Color(0.78, 0.84, 0.92))
		if bus_header_row_map.has(bus_name):
			var header_row: HBoxContainer = bus_header_row_map[bus_name]
			header_row.add_theme_constant_override("separation", 8 if compact else 12)
		if value_label_map.has(bus_name):
			var value_label: Label = value_label_map[bus_name]
			value_label.custom_minimum_size = Vector2(84.0 if very_compact else (94.0 if compact else 106.0), 0.0)
			UISkin.label(value_label, 11 if compact else 12, Color(0.86, 0.88, 0.92))
		if mute_button_map.has(bus_name):
			var mute_button: Button = mute_button_map[bus_name]
			mute_button.custom_minimum_size = Vector2(0.0, 32.0 if compact else 34.0)
			mute_button.text = "Off" if very_compact and Music.is_bus_muted(StringName(bus_name)) else ("On" if very_compact else ("Muted" if Music.is_bus_muted(StringName(bus_name)) else "Mute"))
		if preview_button_map.has(bus_name):
			var preview_button: Button = preview_button_map[bus_name]
			preview_button.custom_minimum_size = Vector2(0.0, 32.0 if compact else 34.0)
			preview_button.text = "Test" if very_compact else "Preview"
		if bus_buttons_row_map.has(bus_name):
			var buttons_row: HBoxContainer = bus_buttons_row_map[bus_name]
			buttons_row.add_theme_constant_override("separation", 8 if compact else 10)
			buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER if very_compact else BoxContainer.ALIGNMENT_END
