extends CanvasLayer

signal closed
signal quit_requested

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(320, 320)
const PANEL_MAX_SIZE := Vector2(720, 560)

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

func _ready() -> void:
	layer = 24
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	dimmer.color = Color(0.01, 0.012, 0.018, 0.42)
	UISkin.label(title_label, 34, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 17, Color(0.88, 0.90, 0.94))
	UISkin.label(detail_label, 14, Color(0.74, 0.80, 0.88))
	summary_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	UISkin.label(stats_label, 13, Color(0.92, 0.94, 0.98))
	UISkin.label(timeline_label, 12, Color(0.78, 0.84, 0.92))
	UISkin.button_styles(continue_button, "large")
	UISkin.button_styles(quit_button, "large")
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()
	continue_button.pressed.connect(_close_result)
	quit_button.pressed.connect(func() -> void:
		get_tree().paused = false
		quit_requested.emit()
	)

func show_result(kind: String, title: String, subtitle: String, detail: String, summary: Dictionary = {}) -> void:
	var bg_path := "res://assets/ui/background/result_success_bg.png"
	var panel_path := "res://assets/ui/result/victory_panel.png"
	var deco_path := "res://assets/ui/result/victory_decoration.png"
	if kind == "defeat":
		bg_path = "res://assets/ui/background/result_failure_bg.png"
		panel_path = "res://assets/ui/result/defeat_panel.png"
		deco_path = "res://assets/ui/result/defeat_decoration.png"
	elif kind == "relic":
		bg_path = "res://assets/ui/background/result_reincarnation_bg.png"
		panel_path = "res://assets/ui/result/reincarnation_panel.png"
		deco_path = "res://assets/ui/result/reincarnation_decoration.png"
	backdrop.texture = load(bg_path) as Texture2D
	panel.add_theme_stylebox_override("panel", UISkin.texture_style(panel_path, 40, 16))
	decoration.texture = load(deco_path) as Texture2D
	title_label.text = title
	subtitle_label.text = subtitle
	detail_label.text = detail
	_apply_summary(summary)
	visible = true
	get_tree().paused = true
	continue_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_close_result()
				get_viewport().set_input_as_handled()
			KEY_Q:
				get_tree().paused = false
				quit_requested.emit()
				get_viewport().set_input_as_handled()

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _close_result() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _apply_summary(summary: Dictionary) -> void:
	var stats_text := String(summary.get("stats", ""))
	var timeline_text := String(summary.get("timeline", ""))
	var has_summary := not stats_text.is_empty() or not timeline_text.is_empty()
	summary_panel.visible = has_summary
	stats_label.text = stats_text if not stats_text.is_empty() else "Run summary unavailable."
	timeline_label.text = timeline_text if not timeline_text.is_empty() else "No route timeline recorded."

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
