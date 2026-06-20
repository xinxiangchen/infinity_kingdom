extends CanvasLayer

signal closed
signal quit_requested
signal open_ending_reached

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(320, 320)
const PANEL_MAX_SIZE := Vector2(720, 560)
const OPEN_ENDING_IDLE_SECONDS := 1800.0
const CROWN_DROP_TEXTURE_PATH := "res://assets/effects/pickups/crown_drop_cutout.png"
const BROKEN_CROWN_DROP_TEXTURE_PATH := "res://assets/effects/pickups/crown_broken_cutout.png"

@onready var backdrop: TextureRect = $Backdrop
@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var panel_margin: MarginContainer = $CenterContainer/PanelContainer/MarginContainer
@onready var decoration: TextureRect = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Decoration
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var detail_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Detail
@onready var summary_panel: PanelContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryPanel
@onready var stats_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryPanel/MarginContainer/VBoxContainer/Stats
@onready var timeline_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryPanel/MarginContainer/VBoxContainer/Timeline
@onready var button_row: HBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow
@onready var continue_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/ContinueButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/QuitButton

var layout_size_override: Vector2 = Vector2.ZERO
var idle_seconds: float = 0.0
var open_ending_allowed: bool = false
var open_ending_triggered: bool = false

func _ready() -> void:
	layer = 24
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.texture = null
	backdrop.modulate = Color(1.0, 1.0, 1.0, 0.0)
	dimmer.color = Color(0.01, 0.012, 0.018, 0.42)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	UISkin.label(title_label, 34, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 17, Color(0.88, 0.90, 0.94))
	UISkin.label(detail_label, 14, Color(0.74, 0.80, 0.88))
	summary_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	UISkin.label(stats_label, 13, Color(0.92, 0.94, 0.98))
	UISkin.label(timeline_label, 12, Color(0.78, 0.84, 0.92))
	UISkin.button_styles(continue_button, "large")
	UISkin.button_styles(quit_button, "large")
	decoration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	decoration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()
	_refresh_copy()
	continue_button.pressed.connect(_close_result)
	quit_button.pressed.connect(func() -> void:
		get_tree().paused = false
		quit_requested.emit()
	)

func show_result(kind: String, title: String, subtitle: String, detail: String, summary: Dictionary = {}) -> void:
	var accent := Color(0.92, 0.88, 0.64)
	var badge_text := UIText.text("result_badge")
	var backdrop_path := "res://assets/ui/background/ending_stage_clear_bg.png"
	decoration.texture = null
	if kind == "defeat":
		accent = Color(0.98, 0.70, 0.64)
		badge_text = UIText.text("result_defeat_badge")
		backdrop_path = "res://assets/ui/background/ending_ember_extinguished_bg.png"
	elif kind == "relic":
		accent = Color(0.82, 0.94, 0.76)
		badge_text = UIText.text("result_relic_badge")
		backdrop_path = "res://assets/ui/background/ending_stage_clear_bg.png"
	elif kind == "true_ending":
		accent = Color(1.0, 0.90, 0.50)
		badge_text = "CROWN BROKEN"
		backdrop_path = "res://assets/ui/background/ending_break_crown_bg.png"
		decoration.texture = load(BROKEN_CROWN_DROP_TEXTURE_PATH) as Texture2D
	elif kind == "crown_bad":
		accent = Color(0.92, 0.62, 0.48)
		badge_text = "CROWN TAKEN"
		backdrop_path = "res://assets/ui/background/ending_crown_bad_bg.png"
		decoration.texture = load(CROWN_DROP_TEXTURE_PATH) as Texture2D
	elif kind == "escape":
		accent = Color(0.72, 0.94, 0.76)
		badge_text = "OPEN ROAD"
		backdrop_path = "res://assets/ui/background/ending_escape_bg.png"
		decoration.texture = load(CROWN_DROP_TEXTURE_PATH) as Texture2D
	elif kind == "developer_room":
		accent = Color(0.56, 0.94, 1.0)
		badge_text = "DEBUG DOOR"
	else:
		badge_text = UIText.text("result_victory_badge")
		decoration.texture = load(CROWN_DROP_TEXTURE_PATH) as Texture2D
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	backdrop.texture = load(backdrop_path) as Texture2D
	backdrop.modulate = Color(1.0, 1.0, 1.0, 0.78)
	decoration.modulate = Color.WHITE
	decoration.tooltip_text = ""
	title_label.text = title
	subtitle_label.text = subtitle
	detail_label.text = detail
	_set_decoration_badge(badge_text, accent)
	_apply_summary(summary)
	_refresh_copy()
	idle_seconds = 0.0
	open_ending_triggered = false
	open_ending_allowed = false
	visible = true
	get_tree().paused = true
	continue_button.grab_focus()

func _process(delta: float) -> void:
	if not visible or not open_ending_allowed or open_ending_triggered:
		return
	idle_seconds += delta
	if idle_seconds >= OPEN_ENDING_IDLE_SECONDS:
		_show_open_ending()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		idle_seconds = 0.0
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_close_result()
				var viewport := get_viewport()
				if viewport != null:
					viewport.set_input_as_handled()
			KEY_Q:
				get_tree().paused = false
				quit_requested.emit()
				var viewport := get_viewport()
				if viewport != null:
					viewport.set_input_as_handled()

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _close_result() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _show_open_ending() -> void:
	open_ending_triggered = true
	open_ending_allowed = false
	open_ending_reached.emit()
	title_label.text = "No Crown"
	subtitle_label.text = "The heir waits, then turns away from the throne."
	detail_label.text = "After thirty quiet minutes, no one claims the crown. The loop remains behind as the archive walks out into an unwritten road."
	_set_decoration_badge("OPEN ROAD", Color(0.78, 0.94, 0.78))
	_apply_summary({
		"stats": "Ending Open  |  Crown abandoned  |  Throne unclaimed",
		"timeline": "Final boss defeated  /  Thirty minutes of silence  /  Freedom chosen"
	})

func _apply_summary(summary: Dictionary) -> void:
	var stats_text := String(summary.get("stats", ""))
	var timeline_text := String(summary.get("timeline", ""))
	var has_summary := not stats_text.is_empty() or not timeline_text.is_empty()
	summary_panel.visible = has_summary
	stats_label.text = stats_text if not stats_text.is_empty() else UIText.text("result_summary_missing")
	timeline_label.text = timeline_text if not timeline_text.is_empty() else UIText.text("result_timeline_missing")

func _refresh_copy() -> void:
	continue_button.text = UIText.text("result_continue")
	quit_button.text = UIText.text("result_quit")

func _set_decoration_badge(text_value: String, accent: Color) -> void:
	for child in decoration.get_children():
		child.queue_free()
	var badge_panel := PanelContainer.new()
	badge_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_panel.offset_left = 0.0
	badge_panel.offset_top = 0.0
	badge_panel.offset_right = 0.0
	badge_panel.offset_bottom = 0.0
	var fill_color := accent.darkened(0.82)
	if decoration.texture != null:
		fill_color.a = 0.24
	badge_panel.add_theme_stylebox_override(
		"panel",
		UISkin.flat_style(fill_color, accent, 1, 3, Vector4(12, 10, 12, 10))
	)
	decoration.add_child(badge_panel)
	var badge_label := Label.new()
	badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge_label.text = text_value
	UISkin.label(badge_label, 16, accent.lightened(0.1))
	badge_panel.add_child(badge_label)

func _refresh_layout() -> void:
	if panel == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 900.0 or viewport_size.y < 620.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 112.0, PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - 112.0, PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
	panel_margin.add_theme_constant_override("margin_left", 28 if compact else 44)
	panel_margin.add_theme_constant_override("margin_top", 26 if compact else 34)
	panel_margin.add_theme_constant_override("margin_right", 28 if compact else 44)
	panel_margin.add_theme_constant_override("margin_bottom", 26 if compact else 34)
	decoration.custom_minimum_size.y = clampf(viewport_size.y * (0.12 if compact else 0.14), 58.0, 108.0)
	detail_label.custom_minimum_size.y = 42.0 if compact else 56.0
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10 if compact else 12)
	continue_button.custom_minimum_size = Vector2(0.0, 52.0 if compact else 58.0)
	quit_button.custom_minimum_size = Vector2(0.0, 52.0 if compact else 58.0)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.label(title_label, 28 if compact else 34, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 15 if compact else 17, Color(0.88, 0.90, 0.94))
	UISkin.label(detail_label, 13 if compact else 14, Color(0.74, 0.80, 0.88))
	UISkin.label(stats_label, 11 if compact else 13, Color(0.92, 0.94, 0.98))
	UISkin.label(timeline_label, 10 if compact else 12, Color(0.78, 0.84, 0.92))
