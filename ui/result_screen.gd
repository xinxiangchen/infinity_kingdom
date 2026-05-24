extends CanvasLayer

signal closed

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(320, 320)
const PANEL_MAX_SIZE := Vector2(620, 470)

@onready var backdrop: TextureRect = $Backdrop
@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var panel_margin: MarginContainer = $CenterContainer/PanelContainer/MarginContainer
@onready var decoration: TextureRect = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Decoration
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var detail_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Detail
@onready var continue_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	layer = 24
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	dimmer.color = Color(0.01, 0.012, 0.018, 0.42)
	UISkin.label(title_label, 34, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 17, Color(0.88, 0.90, 0.94))
	UISkin.label(detail_label, 14, Color(0.74, 0.80, 0.88))
	UISkin.button_styles(continue_button, "large")
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()
	continue_button.pressed.connect(func() -> void:
		visible = false
		get_tree().paused = false
		closed.emit()
	)

func show_result(kind: String, title: String, subtitle: String, detail: String) -> void:
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
	visible = true
	get_tree().paused = true
	continue_button.grab_focus()

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 900.0 or viewport_size.y < 620.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 112.0, PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - 112.0, PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
	panel_margin.add_theme_constant_override("margin_left", 28 if compact else 44)
	panel_margin.add_theme_constant_override("margin_top", 26 if compact else 34)
	panel_margin.add_theme_constant_override("margin_right", 28 if compact else 44)
	panel_margin.add_theme_constant_override("margin_bottom", 26 if compact else 34)
	decoration.custom_minimum_size.y = clampf(viewport_size.y * 0.14, 64.0, 108.0)
	detail_label.custom_minimum_size.y = 64.0 if compact else 80.0
	continue_button.custom_minimum_size.y = 52.0 if compact else 58.0
	UISkin.label(title_label, 28 if compact else 34, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 15 if compact else 17, Color(0.88, 0.90, 0.94))
	UISkin.label(detail_label, 13 if compact else 14, Color(0.74, 0.80, 0.88))
