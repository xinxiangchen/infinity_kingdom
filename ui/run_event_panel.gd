extends CanvasLayer

signal event_choice_made(choice_id: String)

const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(720, 480)
const PANEL_MAX_SIZE := Vector2(1080, 640)
const CARD_MIN_WIDTH := 236.0
const CARD_GAP := 12.0

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer
@onready var title_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var choice_scroll: ScrollContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChoiceScroll
@onready var choice_row: GridContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChoiceScroll/ChoiceRow
@onready var footer_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Footer

var active_kind: String = ""

func _ready() -> void:
	layer = 18
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.color = Color(0.015, 0.018, 0.026, 0.72)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	UISkin.label(title_label, 28, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 15, Color(0.78, 0.84, 0.92))
	UISkin.label(footer_label, 13, Color(0.74, 0.80, 0.88))
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func open(kind: String, gold: int) -> void:
	active_kind = kind
	_rebuild(kind, gold)
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _rebuild(kind: String, gold: int) -> void:
	for child in choice_row.get_children():
		choice_row.remove_child(child)
		child.queue_free()
	match kind:
		"shop":
			title_label.text = "Black Market"
			subtitle_label.text = "Spend gold for a focused advantage before the next fight."
			footer_label.text = "Gold: %d" % gold
			choice_row.add_child(_choice_card("shop_attack", "Sharpening Oil", "Gain +10% attack damage this run.", "res://assets/ui/consumable/sharpening_oil.png", 45, gold))
			choice_row.add_child(_choice_card("shop_defense", "Light Armor Pack", "Restore defense and gain +12 max defense.", "res://assets/ui/consumable/light_armor_pack.png", 40, gold))
			choice_row.add_child(_choice_card("shop_relic", "Relic Map", "Buy an extra relic choice before the next fight.", "res://assets/ui/icon/ui_shop.png", 55, gold))
			choice_row.add_child(_choice_card("skip", "Save Gold", "Keep your gold for a later event.", "res://assets/ui/icon/currency_gold_pixel.png", 0, gold))
		"rest":
			title_label.text = "Church Refuge"
			subtitle_label.text = "Recover before the next encounter."
			footer_label.text = "A quiet room, a candle, and just enough time."
			choice_row.add_child(_choice_card("rest_heal", "Medkit", "Restore 45% health.", "res://assets/ui/consumable/medkit.png", 0, gold))
			choice_row.add_child(_choice_card("rest_focus", "Protective Candle", "Restore inspiration and defense.", "res://assets/ui/consumable/protective_candle.png", 0, gold))
			choice_row.add_child(_choice_card("rest_repair", "Field Repair", "Restore defense and gain +8 max hp.", "res://assets/ui/icon/ui_shield.png", 0, gold))
			choice_row.add_child(_choice_card("skip", "Push Forward", "Skip recovery and continue.", "res://assets/ui/icon/ui_check.png", 0, gold))
		"training":
			title_label.text = "Training Drill"
			subtitle_label.text = "Choose one stat technique for the rest of this run."
			footer_label.text = "Training stacks with relics."
			choice_row.add_child(_choice_card("train_crit", "Precision", "+5% critical chance.", "res://assets/ui/trait/trait_crit.png", 0, gold))
			choice_row.add_child(_choice_card("train_speed", "Footwork", "+8% move speed.", "res://assets/ui/icon/stat_speed_pixel.png", 0, gold))
			choice_row.add_child(_choice_card("train_cooldown", "Rhythm", "-6% skill cooldowns.", "res://assets/ui/icon/stat_cooldown_pixel.png", 0, gold))
			choice_row.add_child(_choice_card("train_resource", "Focus Drill", "+12 max inspiration.", "res://assets/ui/icon/stat_mana_pixel.png", 0, gold))
		"pact":
			title_label.text = "Forbidden Pact"
			subtitle_label.text = "Take a sharp edge now, and live with the tradeoff for the rest of the run."
			footer_label.text = "These bargains do not cost gold."
			choice_row.add_child(_choice_card("pact_power", "Blood Price", "+18% attack, +10% skill damage, but skills cost more inspiration.", "res://assets/ui/trait/trait_damage.png", 0, gold))
			choice_row.add_child(_choice_card("pact_guard", "Iron Oath", "Gain heavy defense and restore armor, but move slower.", "res://assets/ui/icon/ui_shield.png", 0, gold))
			choice_row.add_child(_choice_card("pact_focus", "Astral Debt", "Gain inspiration and cooldown efficiency, but lose max hp.", "res://assets/ui/icon/ui_mana_flame.png", 0, gold))
			choice_row.add_child(_choice_card("skip", "Refuse", "Walk away without changing the build.", "res://assets/ui/icon/ui_back.png", 0, gold))
		_:
			title_label.text = "Travel"
			subtitle_label.text = "No event is available."
			footer_label.text = ""
			choice_row.add_child(_choice_card("skip", "Continue", "Move to the next encounter.", "res://assets/ui/icon/ui_check.png", 0, gold))
	_refresh_layout()

func _choice_card(choice_id: String, title: String, summary: String, icon_path: String, cost: int, gold: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(236, 274)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.disabled = cost > gold
	button.add_theme_stylebox_override("normal", UISkin.texture_style(UISkin.asset("choice/choice_card_normal.png"), 30, 12))
	button.add_theme_stylebox_override("hover", UISkin.texture_style(UISkin.asset("choice/choice_card_hover.png"), 30, 12))
	button.add_theme_stylebox_override("pressed", UISkin.texture_style(UISkin.asset("choice/choice_card_selected.png"), 30, 12))
	button.add_theme_stylebox_override("disabled", UISkin.texture_style(UISkin.asset("choice/choice_card_disabled.png"), 30, 12))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 16
	margin.offset_top = 16
	margin.offset_right = -16
	margin.offset_bottom = -16
	button.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(88, 88)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	box.add_child(slot)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(70, 70)
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)

	var title_text := Label.new()
	title_text.text = title
	title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_text, 18, Color.WHITE)
	box.add_child(title_text)

	var summary_label := Label.new()
	summary_label.text = summary
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size = Vector2(0, 70)
	UISkin.label(summary_label, 13, Color(0.78, 0.84, 0.92))
	box.add_child(summary_label)

	var cost_label := Label.new()
	cost_label.text = "Cost %d gold" % cost if cost > 0 else "Free"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UISkin.label(cost_label, 13, Color(1.0, 0.86, 0.55) if not button.disabled else Color(0.72, 0.54, 0.48))
	box.add_child(cost_label)

	UISkin.ignore_mouse_recursive(margin)
	button.pressed.connect(func() -> void:
		close()
		event_choice_made.emit(choice_id)
	)
	return button

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if panel == null or choice_row == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - 88.0, PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - 88.0, PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
	var available_width := maxf(choice_scroll.size.x, panel.custom_minimum_size.x - 96.0)
	var next_columns := clampi(int(floor((available_width + CARD_GAP) / (CARD_MIN_WIDTH + CARD_GAP))), 1, 4)
	choice_row.columns = max(1, min(next_columns, max(choice_row.get_child_count(), 1)))
