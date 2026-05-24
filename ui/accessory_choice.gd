extends CanvasLayer

signal accessory_choice_made(accessory_id: String, kept_current: bool)
signal reroll_requested

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(340, 420)
const PANEL_MAX_SIZE := Vector2(1120, 736)
const CARD_MIN_WIDTH := 296.0
const CARD_GAP := 14.0

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer
@onready var panel_margin: MarginContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer
@onready var title_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var current_row: PanelContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentRow
@onready var current_margin: MarginContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentRow/CurrentMargin
@onready var current_icon_slot: PanelContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentRow/CurrentMargin/CurrentContent/IconSlot
@onready var current_icon: TextureRect = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentRow/CurrentMargin/CurrentContent/IconSlot/Icon
@onready var current_name_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentRow/CurrentMargin/CurrentContent/Text/Name
@onready var current_summary_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentRow/CurrentMargin/CurrentContent/Text/Summary
@onready var choices_scroll: ScrollContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChoicesScroll
@onready var choices_row: GridContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChoicesScroll/ChoicesRow
@onready var button_row: HBoxContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow
@onready var keep_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/KeepButton
@onready var reroll_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/RerollButton

var active_choices: Array[Dictionary] = []
var active_actor: Node = null
var active_reroll_cost: int = 0
var layout_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	_apply_skin()
	keep_button.pressed.connect(_on_keep_pressed)
	reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func open(choices: Array[Dictionary], actor: Node, reason: String = "Relic Offering", reroll_cost: int = 0, gold: int = 0) -> void:
	active_choices = choices
	active_actor = actor
	active_reroll_cost = reroll_cost
	title_label.text = reason
	subtitle_label.text = "Equip one relic. The current relic is replaced immediately."
	reroll_button.text = "Reroll - %d Gold" % reroll_cost
	reroll_button.disabled = reroll_cost > gold
	_refresh_current()
	_rebuild_choices()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _apply_skin() -> void:
	backdrop.color = Color(0.015, 0.018, 0.026, 0.76)
	panel.add_theme_stylebox_override("panel", UISkin.choice_panel_style())
	current_row.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	var icon_slot := $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentRow/CurrentMargin/CurrentContent/IconSlot as PanelContainer
	icon_slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	UISkin.label(title_label, 28, Color(0.98, 0.90, 0.67))
	UISkin.label(subtitle_label, 15, Color(0.76, 0.80, 0.88))
	UISkin.label(current_name_label, 18, Color.WHITE)
	UISkin.label(current_summary_label, 14, Color(0.76, 0.82, 0.90))
	UISkin.button_styles(keep_button, "thin")
	UISkin.button_styles(reroll_button, "thin")

func _refresh_current() -> void:
	var current := AccessoryManager.get_equipped_accessory()
	current_icon.texture = load(String(current.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
	current_name_label.text = "Current: %s" % String(current.get("name", "No Accessory"))
	current_summary_label.text = "%s\n%s" % [
		String(current.get("summary", "")),
		AccessoryManager.describe_effects(current)
	]

func _rebuild_choices() -> void:
	for child in choices_row.get_children():
		choices_row.remove_child(child)
		child.queue_free()
	for accessory in active_choices:
		choices_row.add_child(_choice_card(accessory))
	_refresh_layout()

func _choice_card(accessory: Dictionary) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(296, 326)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UISkin.texture_style(UISkin.asset("choice/choice_card_normal.png"), 30, 12))
	button.add_theme_stylebox_override("hover", UISkin.texture_style(UISkin.asset("choice/choice_card_hover.png"), 30, 12))
	button.add_theme_stylebox_override("pressed", UISkin.texture_style(UISkin.asset("choice/choice_card_selected.png"), 30, 12))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 16
	margin.offset_top = 16
	margin.offset_right = -16
	margin.offset_bottom = -16
	button.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(86, 86)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", UISkin.texture_style(UISkin.asset("choice/choice_icon_slot.png"), 22, 4))
	box.add_child(slot)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(String(accessory.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
	slot.add_child(icon)
	var name_label := Label.new()
	name_label.text = String(accessory.get("name", "Accessory"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 42)
	UISkin.label(name_label, 18, Color.WHITE)
	box.add_child(name_label)

	var divider := TextureRect.new()
	divider.custom_minimum_size = Vector2(0, 8)
	divider.texture = UISkin.tex(UISkin.asset("frame/divider_gold_h_long.png"))
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(divider)

	var rarity_label := Label.new()
	rarity_label.text = String(accessory.get("rarity", "Common"))
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UISkin.label(rarity_label, 14, _rarity_color(String(accessory.get("rarity", "Common"))))
	box.add_child(rarity_label)

	var summary_label := Label.new()
	summary_label.text = String(accessory.get("summary", ""))
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size = Vector2(0, 70)
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UISkin.label(summary_label, 13, Color(0.78, 0.84, 0.92))
	box.add_child(summary_label)

	var effects_label := Label.new()
	effects_label.text = AccessoryManager.describe_effects(accessory)
	effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects_label.custom_minimum_size = Vector2(0, 48)
	UISkin.label(effects_label, 12, Color(0.72, 0.92, 0.78))
	box.add_child(effects_label)
	UISkin.ignore_mouse_recursive(margin)
	button.pressed.connect(func() -> void:
		var accessory_id := String(accessory.get("id", ""))
		AccessoryManager.equip(accessory_id, active_actor)
		close()
		accessory_choice_made.emit(accessory_id, false)
	)
	return button

func _on_keep_pressed() -> void:
	AccessoryManager.keep_current(active_actor)
	close()
	accessory_choice_made.emit(String(AccessoryManager.get_equipped_accessory().get("id", "none")), true)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Uncommon":
			return Color(0.62, 0.90, 0.62)
		"Rare":
			return Color(0.54, 0.75, 1.0)
		"Epic":
			return Color(0.78, 0.58, 1.0)
		"Legendary":
			return Color(1.0, 0.72, 0.35)
		_:
			return Color(0.78, 0.80, 0.84)

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if panel == null or choices_row == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 980.0 or viewport_size.y < 720.0
	var very_compact: bool = viewport_size.x < 760.0 or viewport_size.y < 620.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (48.0 if very_compact else 80.0), PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - (48.0 if very_compact else 80.0), PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
	panel_margin.add_theme_constant_override("margin_left", 18 if very_compact else (22 if compact else 30))
	panel_margin.add_theme_constant_override("margin_top", 18 if very_compact else (22 if compact else 28))
	panel_margin.add_theme_constant_override("margin_right", 18 if very_compact else (22 if compact else 30))
	panel_margin.add_theme_constant_override("margin_bottom", 18 if very_compact else (22 if compact else 28))
	current_margin.add_theme_constant_override("margin_left", 10 if very_compact else 12)
	current_margin.add_theme_constant_override("margin_top", 8 if very_compact else 10)
	current_margin.add_theme_constant_override("margin_right", 10 if very_compact else 12)
	current_margin.add_theme_constant_override("margin_bottom", 8 if very_compact else 10)
	current_row.custom_minimum_size.y = 88.0 if very_compact else (96.0 if compact else 108.0)
	current_icon_slot.custom_minimum_size = Vector2(70, 70) if very_compact else (Vector2(78, 78) if compact else Vector2(90, 90))
	current_icon.custom_minimum_size = Vector2(58, 58) if very_compact else (Vector2(66, 66) if compact else Vector2(78, 78))
	choices_scroll.custom_minimum_size.y = clampf(panel.custom_minimum_size.y * (0.42 if very_compact else 0.48), 204.0, 348.0)
	UISkin.label(title_label, 22 if very_compact else (25 if compact else 28), Color(0.98, 0.90, 0.67))
	UISkin.label(subtitle_label, 13 if very_compact else (14 if compact else 15), Color(0.76, 0.80, 0.88))
	UISkin.label(current_name_label, 15 if very_compact else (17 if compact else 18), Color.WHITE)
	UISkin.label(current_summary_label, 12 if very_compact else 13, Color(0.76, 0.82, 0.90))
	var card_width := 220.0 if very_compact else (252.0 if compact else 296.0)
	var card_height := 254.0 if very_compact else (288.0 if compact else 326.0)
	var available_width := maxf(choices_scroll.size.x, panel.custom_minimum_size.x - (56.0 if very_compact else 96.0))
	var next_columns := clampi(int(floor((available_width + CARD_GAP) / (card_width + CARD_GAP))), 1, 3)
	choices_row.columns = max(1, min(next_columns, max(active_choices.size(), 1)))
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 8 if compact else 12)
	keep_button.custom_minimum_size = Vector2(0.0, 48.0 if compact else 54.0)
	reroll_button.custom_minimum_size = Vector2(0.0, 48.0 if compact else 54.0)
	keep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep_button.text = "Keep" if very_compact else "Keep Current"
	reroll_button.text = "Reroll" if compact else "Reroll - %d Gold" % active_reroll_cost
	for child in choices_row.get_children():
		if child is Button:
			var card := child as Button
			card.custom_minimum_size = Vector2(card_width, card_height)
