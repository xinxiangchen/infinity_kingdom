extends CanvasLayer

const UISkin := preload("res://ui/ui_skin.gd")

var root_margin: MarginContainer
var title_label: Label
var subtitle_label: Label
var detail_label: Label
var run_label: Label

func _ready() -> void:
	_build_ui()
	if RunDirector != null and not RunDirector.state_changed.is_connected(_on_run_state_changed):
		RunDirector.state_changed.connect(_on_run_state_changed)
	_on_run_state_changed(RunDirector.get_state())
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func set_message(title: String, subtitle: String = "", detail: String = "") -> void:
	if title_label == null:
		return
	title_label.text = title
	subtitle_label.text = subtitle
	detail_label.text = detail

func _build_ui() -> void:
	layer = 4
	root_margin = MarginContainer.new()
	root_margin.offset_left = 18.0
	root_margin.offset_top = 16.0
	root_margin.offset_right = 600.0
	root_margin.offset_bottom = 248.0
	root_margin.add_theme_constant_override("margin_left", 10)
	root_margin.add_theme_constant_override("margin_top", 10)
	root_margin.add_theme_constant_override("margin_right", 10)
	root_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(root_margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UISkin.panel_style())
	root_margin.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	title_label = Label.new()
	title_label.text = "Town Boss Trial"
	UISkin.label(title_label, 24, Color(0.98, 0.90, 0.66))
	content.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Pick a champion to begin."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(subtitle_label, 15, Color(0.86, 0.88, 0.92))
	content.add_child(subtitle_label)

	detail_label = Label.new()
	detail_label.text = "Controls: WASD move, J attack, K/L/I skills."
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(detail_label, 13, Color(0.70, 0.76, 0.84))
	content.add_child(detail_label)

	var run_panel := PanelContainer.new()
	run_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(run_panel)

	run_label = Label.new()
	run_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(run_label, 12, Color(0.82, 0.88, 0.96))
	run_panel.add_child(run_label)

func _on_run_state_changed(state: Dictionary) -> void:
	if run_label == null:
		return
	var next_event := String(state.get("next_event_kind", ""))
	var next_text := RunDirector.describe_event_kind(next_event) if RunDirector != null and not next_event.is_empty() else "Victory"
	run_label.text = "Gold %d   Last Reward +%d   Next %s" % [
		int(state.get("gold", 0)),
		int(state.get("last_reward_gold", 0)),
		next_text
	]

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if root_margin == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	root_margin.offset_right = minf(maxf(viewport_size.x * 0.36, 420.0), 620.0)
	root_margin.offset_bottom = minf(maxf(viewport_size.y * 0.24, 220.0), 280.0)
