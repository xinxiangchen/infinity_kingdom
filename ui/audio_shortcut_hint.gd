extends CanvasLayer

const UISkin := preload("res://ui/ui_skin.gd")

@onready var container: MarginContainer = $MarginContainer
@onready var panel: PanelContainer = $MarginContainer/PanelContainer
@onready var title_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle

var tween: Tween = null
var panel_open: bool = false
var rest_position: Vector2 = Vector2.ZERO
var layout_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	title_label.text = "F10 Audio Mix"
	subtitle_label.text = "Master / Music / Ambience / SFX"
	panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest_position = container.position
	container.modulate = Color(1.0, 1.0, 1.0, 0.0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.position = rest_position + Vector2(18.0, -10.0)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()
	show_hint(true)

func show_hint(emphasize: bool = false) -> void:
	if panel_open:
		return
	if tween != null:
		tween.kill()
	visible = true
	var pulse_scale := 1.0
	if emphasize:
		pulse_scale = 1.03
		container.modulate = Color(1.0, 1.0, 1.0, 0.0)
		container.position = rest_position + Vector2(18.0, -10.0)
		panel.scale = Vector2.ONE * 0.98
		tween = create_tween()
		tween.tween_property(container, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.28)
		tween.parallel().tween_property(container, "position", rest_position, 0.28)
		tween.parallel().tween_property(panel, "scale", Vector2.ONE * pulse_scale, 0.28)
		tween.tween_property(panel, "scale", Vector2.ONE, 0.18)
		tween.parallel().tween_property(container, "modulate", Color(1.0, 1.0, 1.0, 0.82), 0.18)
	else:
		container.modulate = Color(1.0, 1.0, 1.0, 0.82)
		container.position = rest_position
		panel.scale = Vector2.ONE
		tween = create_tween()
		tween.tween_property(panel, "scale", Vector2.ONE * 1.02, 0.16)
		tween.tween_property(panel, "scale", Vector2.ONE, 0.16)

func set_panel_open(is_open: bool) -> void:
	panel_open = is_open
	if tween != null:
		tween.kill()
	if is_open:
		visible = true
		tween = create_tween()
		tween.tween_property(container, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.16)
		tween.finished.connect(func() -> void:
			if is_instance_valid(self) and panel_open:
				visible = false
		)
	else:
		show_hint(false)

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if container == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 860.0
	container.offset_left = -clampf(viewport_size.x * (0.46 if compact else 0.32), 210.0, 366.0)
	container.offset_top = 12.0 if compact else 18.0
	container.offset_right = -10.0 if compact else -14.0
	container.offset_bottom = 92.0 if compact else 110.0
	title_label.text = "F10 Mix" if compact else "F10 Audio Mix"
	subtitle_label.text = "Master / Music / SFX" if compact else "Master / Music / Ambience / SFX"
	title_label.add_theme_font_size_override("font_size", 15 if compact else 18)
	subtitle_label.add_theme_font_size_override("font_size", 11 if compact else 12)
	rest_position = Vector2(container.offset_left, container.offset_top)
	if visible and not panel_open:
		container.position = rest_position
