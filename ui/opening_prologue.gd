extends CanvasLayer

signal finished

const UISkin := preload("res://ui/ui_skin.gd")
const PANELS := [
	{
		"image": "res://assets/ui/background/prologue/prologue_01_falling_kingdom.png",
		"title": "王国将倾",
		"body": "王都仍戴着王冠，可每一声钟响都像警告。城墙开裂，旗帜腐烂，旧王座仍在索要下一位继承者。"
	},
	{
		"image": "res://assets/ui/background/prologue/prologue_02_corrupt_throne.png",
		"title": "王冠记得",
		"body": "胜利没有拯救国王，只让王冠学会了饥饿。每一位坐上王座的人，都会把更多的自己留在那片阴影里。"
	},
	{
		"image": "res://assets/ui/background/prologue/prologue_03_three_families.png",
		"title": "三支血脉",
		"body": "钢铁、箭矢与奥术之火聚集在通往王宫的道路前。无人被许诺第二个黎明，但每个人都能为下一双手留下些什么。"
	},
	{
		"image": "res://assets/ui/background/prologue/prologue_04_bloodline_embers.png",
		"title": "五枚火种",
		"body": "一份新的档案始于五枚血脉火种。若它们尽数熄灭，这份档案便会死亡；若它们燃烧得足够有意义，下一次生命将从更高处开始。"
	}
]

var image_rect: TextureRect
var dimmer: ColorRect
var title_label: Label
var body_label: Label
var hint_label: Label
var current_index: int = 0
var layout_size_override: Vector2 = Vector2.ZERO
var transition_tween: Tween = null
var transitioning: bool = false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()


func open() -> void:
	current_index = 0
	visible = true
	get_tree().paused = true
	image_rect.modulate = Color.WHITE
	title_label.modulate = Color.WHITE
	body_label.modulate = Color.WHITE
	hint_label.modulate = Color.WHITE
	dimmer.color = Color(0.02, 0.018, 0.018, 0.46)
	_show_current_panel()
	_play_intro_fade()


func close() -> void:
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
	transitioning = false
	visible = false
	get_tree().paused = false
	finished.emit()


func _build_ui() -> void:
	image_rect = TextureRect.new()
	image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(image_rect)

	dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.02, 0.018, 0.018, 0.36)
	add_child(dimmer)

	var bottom_margin := MarginContainer.new()
	bottom_margin.anchor_left = 0.0
	bottom_margin.anchor_top = 1.0
	bottom_margin.anchor_right = 1.0
	bottom_margin.anchor_bottom = 1.0
	bottom_margin.offset_left = 72.0
	bottom_margin.offset_top = -270.0
	bottom_margin.offset_right = -72.0
	bottom_margin.offset_bottom = -54.0
	add_child(bottom_margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_margin.add_child(stack)

	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UISkin.label(title_label, 38, Color(1.0, 0.88, 0.62))
	stack.add_child(title_label)

	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.max_lines_visible = 4
	UISkin.label(body_label, 18, Color(0.90, 0.92, 0.96))
	stack.add_child(body_label)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UISkin.label(hint_label, 13, Color(0.72, 0.78, 0.86))
	stack.add_child(hint_label)


func _show_current_panel() -> void:
	current_index = clampi(current_index, 0, PANELS.size() - 1)
	var panel := PANELS[current_index] as Dictionary
	image_rect.texture = load(String(panel.get("image", ""))) as Texture2D
	title_label.text = String(panel.get("title", ""))
	body_label.text = String(panel.get("body", ""))
	hint_label.text = "Enter / Space 继续   Esc 跳过   %d / %d" % [current_index + 1, PANELS.size()]


func _advance() -> void:
	if transitioning:
		return
	if current_index >= PANELS.size() - 1:
		close()
		return
	current_index += 1
	_transition_to_current_panel()

func _play_intro_fade() -> void:
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
	transitioning = true
	image_rect.modulate.a = 0.0
	title_label.modulate.a = 0.0
	body_label.modulate.a = 0.0
	hint_label.modulate.a = 0.0
	transition_tween = create_tween()
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition_tween.set_parallel(true)
	transition_tween.tween_property(image_rect, "modulate:a", 1.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	transition_tween.tween_property(title_label, "modulate:a", 1.0, 0.28).set_delay(0.10)
	transition_tween.tween_property(body_label, "modulate:a", 1.0, 0.30).set_delay(0.16)
	transition_tween.tween_property(hint_label, "modulate:a", 1.0, 0.24).set_delay(0.22)
	transition_tween.finished.connect(func() -> void:
		transitioning = false
	)

func _transition_to_current_panel() -> void:
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
	transitioning = true
	transition_tween = create_tween()
	transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transition_tween.set_parallel(true)
	transition_tween.tween_property(image_rect, "modulate:a", 0.18, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	transition_tween.tween_property(title_label, "modulate:a", 0.0, 0.12)
	transition_tween.tween_property(body_label, "modulate:a", 0.0, 0.12)
	transition_tween.tween_property(hint_label, "modulate:a", 0.0, 0.12)
	transition_tween.set_parallel(false)
	transition_tween.tween_callback(func() -> void:
		_show_current_panel()
	)
	transition_tween.set_parallel(true)
	transition_tween.tween_property(image_rect, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	transition_tween.tween_property(title_label, "modulate:a", 1.0, 0.22).set_delay(0.04)
	transition_tween.tween_property(body_label, "modulate:a", 1.0, 0.24).set_delay(0.08)
	transition_tween.tween_property(hint_label, "modulate:a", 1.0, 0.20).set_delay(0.12)
	transition_tween.finished.connect(func() -> void:
		transitioning = false
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		_advance()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_advance()
			get_viewport().set_input_as_handled()


func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")


func _refresh_layout() -> void:
	if title_label == null:
		return
	var viewport_size := layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 860.0 or viewport_size.y < 620.0
	UISkin.label(title_label, 28 if compact else 38, Color(1.0, 0.88, 0.62))
	UISkin.label(body_label, 14 if compact else 18, Color(0.90, 0.92, 0.96))
	UISkin.label(hint_label, 11 if compact else 13, Color(0.72, 0.78, 0.86))
