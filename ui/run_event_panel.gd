extends CanvasLayer

signal event_choice_made(choice_id: String)

const RunEffects := preload("res://systems/run/run_effects.gd")
const UISkin := preload("res://ui/ui_skin.gd")
const PANEL_MIN_SIZE := Vector2(340, 400)
const PANEL_MAX_SIZE := Vector2(1080, 640)
const CARD_MIN_WIDTH := 236.0
const CARD_GAP := 12.0

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer
@onready var panel_margin: MarginContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer
@onready var title_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var context_panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContextPanel
@onready var build_summary_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContextPanel/MarginContainer/VBoxContainer/BuildSummary
@onready var rule_summary_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContextPanel/MarginContainer/VBoxContainer/RuleSummary
@onready var choice_scroll: ScrollContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChoiceScroll
@onready var choice_row: GridContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ChoiceScroll/ChoiceRow
@onready var detail_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Detail
@onready var footer_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Footer

var active_kind: String = ""
var active_gold: int = 0
var active_default_detail: String = ""
var choice_buttons: Array[Button] = []
var layout_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 18
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.color = Color(0.015, 0.018, 0.026, 0.72)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	context_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_label, 28, Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 15, Color(0.78, 0.84, 0.92))
	UISkin.label(build_summary_label, 12, Color(0.90, 0.92, 0.98))
	UISkin.label(rule_summary_label, 12, Color(0.78, 0.84, 0.92))
	UISkin.label(detail_label, 12, Color(0.92, 0.86, 0.72))
	UISkin.label(footer_label, 13, Color(0.74, 0.80, 0.88))
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func open(kind: String, gold: int) -> void:
	active_kind = kind
	active_gold = gold
	_rebuild(kind, gold)
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _rebuild(kind: String, gold: int) -> void:
	choice_buttons.clear()
	for child in choice_row.get_children():
		choice_row.remove_child(child)
		child.queue_free()
	_refresh_context(kind, gold)
	active_default_detail = _default_detail_for_kind(kind)
	match kind:
		"shop":
			title_label.text = "Black Market"
			subtitle_label.text = "Spend gold for a focused advantage before the next fight."
			choice_row.add_child(_choice_card("shop_attack", "Sharpening Oil", "Gain +10% attack damage this run.", "res://assets/ui/consumable/sharpening_oil.png", 45, gold))
			choice_row.add_child(_choice_card("shop_defense", "Light Armor Pack", "Restore defense and gain +12 max defense.", "res://assets/ui/consumable/light_armor_pack.png", 40, gold))
			choice_row.add_child(_choice_card("shop_relic", "Relic Map", "Buy an extra relic choice before the next fight.", "res://assets/ui/icon/ui_shop.png", 55, gold))
			choice_row.add_child(_choice_card("skip", "Save Gold", "Keep your gold for a later event.", "res://assets/ui/icon/currency_gold_pixel.png", 0, gold))
		"rest":
			title_label.text = "Church Refuge"
			subtitle_label.text = "Recover before the next encounter."
			choice_row.add_child(_choice_card("rest_heal", "Medkit", "Restore 45% health.", "res://assets/ui/consumable/medkit.png", 0, gold))
			choice_row.add_child(_choice_card("rest_focus", "Protective Candle", "Restore inspiration and defense.", "res://assets/ui/consumable/protective_candle.png", 0, gold))
			choice_row.add_child(_choice_card("rest_repair", "Field Repair", "Restore defense and gain +8 max hp.", "res://assets/ui/icon/ui_shield.png", 0, gold))
			choice_row.add_child(_choice_card("skip", "Push Forward", "Skip recovery and continue.", "res://assets/ui/icon/ui_check.png", 0, gold))
		"training":
			title_label.text = "Training Drill"
			subtitle_label.text = "Choose one stat technique for the rest of this run."
			choice_row.add_child(_choice_card("train_crit", "Precision", "+5% critical chance.", "res://assets/ui/trait/trait_crit.png", 0, gold))
			choice_row.add_child(_choice_card("train_speed", "Footwork", "+8% move speed.", "res://assets/ui/icon/stat_speed_pixel.png", 0, gold))
			choice_row.add_child(_choice_card("train_cooldown", "Rhythm", "-6% skill cooldowns.", "res://assets/ui/icon/stat_cooldown_pixel.png", 0, gold))
			choice_row.add_child(_choice_card("train_resource", "Focus Drill", "+12 max inspiration.", "res://assets/ui/icon/stat_mana_pixel.png", 0, gold))
		"pact":
			title_label.text = "Forbidden Pact"
			subtitle_label.text = "Take a sharp edge now, and live with the tradeoff for the rest of the run."
			choice_row.add_child(_choice_card("pact_power", "Blood Price", "+18% attack, +10% skill damage, but skills cost more inspiration.", "res://assets/ui/trait/trait_damage.png", 0, gold))
			choice_row.add_child(_choice_card("pact_guard", "Iron Oath", "Gain heavy defense and restore armor, but move slower.", "res://assets/ui/icon/ui_shield.png", 0, gold))
			choice_row.add_child(_choice_card("pact_focus", "Astral Debt", "Gain inspiration and cooldown efficiency, but lose max hp.", "res://assets/ui/icon/ui_mana_flame.png", 0, gold))
			choice_row.add_child(_choice_card("skip", "Refuse", "Walk away without changing the build.", "res://assets/ui/icon/ui_back.png", 0, gold))
		"attunement":
			var tags_text := AccessoryManager.describe_tags()
			title_label.text = "Relic Resonance"
			subtitle_label.text = "Your relic leans toward %s. Draw out one matching response for the rest of this run." % (tags_text if not tags_text.is_empty() else "an unknown path")
			for choice in RunEffects.attunement_choices():
				choice_row.add_child(_choice_card_from_data(choice, gold))
			choice_row.add_child(_choice_card("skip", "Leave It Still", "Keep the relic unchanged and move on.", "res://assets/ui/icon/ui_back.png", 0, gold))
		_:
			title_label.text = "Travel"
			subtitle_label.text = "No event is available."
			choice_row.add_child(_choice_card("skip", "Continue", "Move to the next encounter.", "res://assets/ui/icon/ui_check.png", 0, gold))
	detail_label.text = active_default_detail
	footer_label.text = _footer_text_for_kind(kind)
	_refresh_layout()
	call_deferred("_focus_first_choice")

func _choice_card_from_data(choice: Dictionary, gold: int) -> Button:
	return _choice_card(
		String(choice.get("id", "")),
		String(choice.get("title", "Choice")),
		String(choice.get("summary", "")),
		String(choice.get("icon", "res://assets/ui/icon/ui_unknown.png")),
		int(choice.get("cost", 0)),
		gold
	)

func _choice_card(choice_id: String, title: String, summary: String, icon_path: String, cost: int, gold: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(236, 274)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.disabled = cost > gold
	button.add_theme_stylebox_override("normal", UISkin.texture_style(UISkin.asset("choice/choice_card_normal.png"), 30, 12))
	button.add_theme_stylebox_override("hover", UISkin.texture_style(UISkin.asset("choice/choice_card_hover.png"), 30, 12))
	button.add_theme_stylebox_override("pressed", UISkin.texture_style(UISkin.asset("choice/choice_card_selected.png"), 30, 12))
	button.add_theme_stylebox_override("disabled", UISkin.texture_style(UISkin.asset("choice/choice_card_disabled.png"), 30, 12))
	button.set_meta("choice_id", choice_id)
	choice_buttons.append(button)

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

	var meta := _choice_meta(choice_id, cost)
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 6)
	box.add_child(badge_row)
	badge_row.add_child(_badge(String(meta.get("type", "Choice")), meta.get("color", Color(0.82, 0.86, 0.96))))
	badge_row.add_child(_badge(String(meta.get("timing", "Now")), meta.get("timing_color", Color(0.92, 0.84, 0.66))))

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
	button.focus_entered.connect(func() -> void: _preview_choice(choice_id, title, summary, cost, button.disabled))
	button.mouse_entered.connect(func() -> void: _preview_choice(choice_id, title, summary, cost, button.disabled))
	button.pressed.connect(func() -> void:
		close()
		event_choice_made.emit(choice_id)
	)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_activate_choice_index(0)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				_activate_choice_index(1)
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				_activate_choice_index(2)
				get_viewport().set_input_as_handled()
			KEY_4, KEY_KP_4:
				_activate_choice_index(3)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_activate_skip_choice()
				get_viewport().set_input_as_handled()

func _activate_choice_index(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= choice_buttons.size():
		return
	var button := choice_buttons[choice_index]
	if button == null or button.disabled:
		return
	button.grab_focus()
	button.emit_signal("pressed")

func _activate_skip_choice() -> void:
	for button in choice_buttons:
		if button != null and String(button.get_meta("choice_id", "")) == "skip" and not button.disabled:
			button.grab_focus()
			button.emit_signal("pressed")
			return

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_context(kind: String, gold: int) -> void:
	var equipped_accessory := AccessoryManager.get_equipped_accessory()
	var accessory_name := String(equipped_accessory.get("name", "No Accessory"))
	var tags_text := AccessoryManager.describe_tags(equipped_accessory.get("tags", []))
	var next_event := RunDirector.describe_event_kind(RunDirector.peek_next_event_kind())
	build_summary_label.text = "Gold %d  |  Relic %s%s" % [
		gold,
		accessory_name,
		("  |  %s" % tags_text) if not tags_text.is_empty() else ""
	]
	rule_summary_label.text = _rule_summary_for_kind(kind, next_event)

func _rule_summary_for_kind(kind: String, next_event: String) -> String:
	match kind:
		"shop":
			return "Buy one focused upgrade now. Next event after this: %s." % next_event
		"rest":
			return "Recovery is immediate and does not change your long-term route."
		"training":
			return "Training permanently boosts one lane for the rest of the run."
		"pact":
			return "Pacts are permanent. They raise power now and reshape future fights."
		"attunement":
			return "Attunement follows your relic tags and lasts for the rest of this run."
		_:
			return "Move on when you are ready."

func _default_detail_for_kind(kind: String) -> String:
	match kind:
		"shop":
			return "Choose a purchase if it sharpens the next boss check. Saving gold keeps later options open."
		"rest":
			return "Take health if survival is shaky, or recover defense and inspiration if your build is already stable."
		"training":
			return "Training is permanent. Pick the lane your current relic and hero already reward."
		"pact":
			return "Every pact is a commitment. Look for the tradeoff your current hero can absorb best."
		"attunement":
			return "Resonance is the cleanest way to reinforce your current relic identity."
		_:
			return "Choose a path and continue."

func _footer_text_for_kind(kind: String) -> String:
	var lead := "1-4 choose  |  Esc skip"
	match kind:
		"shop":
			return "%s  |  Gold is spent immediately." % lead
		"rest":
			return "%s  |  Recovery resolves instantly." % lead
		"training":
			return "%s  |  Training stacks for the rest of the run." % lead
		"pact":
			return "%s  |  Pact tradeoffs are permanent." % lead
		"attunement":
			return "%s  |  Resonance lasts for the rest of the run." % lead
		_:
			return "%s  |  Continue when ready." % lead

func _preview_choice(choice_id: String, title: String, summary: String, cost: int, disabled: bool) -> void:
	var meta := _choice_meta(choice_id, cost)
	var cost_text := "Cost %d gold." % cost if cost > 0 else "No gold cost."
	if disabled:
		cost_text = "Not enough gold yet."
	detail_label.text = "%s: %s %s %s" % [
		title,
		String(meta.get("detail", "")),
		summary,
		cost_text
	]

func _focus_first_choice() -> void:
	for child in choice_row.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
	for child in choice_row.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return

func _choice_meta(choice_id: String, cost: int) -> Dictionary:
	var meta := {
		"type": "Choice",
		"timing": "Now",
		"detail": "Updates the current run path.",
		"color": Color(0.76, 0.84, 0.96),
		"timing_color": Color(0.92, 0.84, 0.66)
	}
	if choice_id == "skip":
		meta["type"] = "Skip"
		meta["timing"] = "No Cost"
		meta["detail"] = "Keeps the current build unchanged and moves the run forward."
		meta["color"] = Color(0.72, 0.78, 0.88)
		meta["timing_color"] = Color(0.76, 0.82, 0.90)
	elif choice_id.begins_with("shop_"):
		meta["type"] = "Purchase"
		meta["timing"] = "Run Bonus" if choice_id != "shop_relic" else "Next Relic"
		meta["detail"] = "Spends gold now for a lasting upgrade."
		meta["color"] = Color(1.0, 0.86, 0.56)
	elif choice_id.begins_with("rest_"):
		meta["type"] = "Recovery"
		meta["timing"] = "Instant"
		meta["detail"] = "Resolves immediately before the next encounter."
		meta["color"] = Color(0.78, 0.96, 0.82)
	elif choice_id.begins_with("train_"):
		meta["type"] = "Training"
		meta["timing"] = "Permanent"
		meta["detail"] = "Adds a clean stat bonus for the rest of the run."
		meta["color"] = Color(0.78, 0.90, 1.0)
	elif choice_id.begins_with("pact_"):
		meta["type"] = "Pact"
		meta["timing"] = "Tradeoff"
		meta["detail"] = "Permanent power with a permanent drawback."
		meta["color"] = Color(1.0, 0.74, 0.66)
	elif choice_id.begins_with("attune_"):
		meta["type"] = "Attunement"
		meta["timing"] = "Permanent"
		meta["detail"] = "Deepens the current relic identity instead of changing direction."
		meta["color"] = Color(0.88, 0.76, 1.0)
	if cost > 0:
		meta["timing"] = "Cost %d" % cost
	return meta

func _badge(text_value: String, color_value: Color) -> PanelContainer:
	var panel_value := PanelContainer.new()
	panel_value.add_theme_stylebox_override(
		"panel",
		UISkin.flat_style(color_value.darkened(0.76), color_value, 1, 5)
	)
	var label_value := Label.new()
	label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_value.text = text_value
	UISkin.label(label_value, 10, color_value.lightened(0.12))
	panel_value.add_child(label_value)
	return panel_value

func _refresh_layout() -> void:
	if panel == null or choice_row == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 980.0 or viewport_size.y < 700.0
	var very_compact: bool = viewport_size.x < 760.0 or viewport_size.y < 600.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (48.0 if very_compact else 88.0), PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x),
		clampf(viewport_size.y - (48.0 if very_compact else 88.0), PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)
	)
	panel_margin.add_theme_constant_override("margin_left", 18 if very_compact else (24 if compact else 34))
	panel_margin.add_theme_constant_override("margin_top", 18 if very_compact else (22 if compact else 30))
	panel_margin.add_theme_constant_override("margin_right", 18 if very_compact else (24 if compact else 34))
	panel_margin.add_theme_constant_override("margin_bottom", 18 if very_compact else (22 if compact else 30))
	choice_scroll.custom_minimum_size.y = clampf(panel.custom_minimum_size.y * (0.34 if very_compact else (0.40 if compact else 0.46)), 164.0, 330.0)
	UISkin.label(title_label, 22 if very_compact else (25 if compact else 28), Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 13 if very_compact else (14 if compact else 15), Color(0.78, 0.84, 0.92))
	UISkin.label(build_summary_label, 11 if compact else 12, Color(0.90, 0.92, 0.98))
	UISkin.label(rule_summary_label, 11 if compact else 12, Color(0.78, 0.84, 0.92))
	UISkin.label(detail_label, 11 if compact else 12, Color(0.92, 0.86, 0.72))
	UISkin.label(footer_label, 11 if compact else 12, Color(0.74, 0.80, 0.88))
	if very_compact:
		footer_label.text = "1-4 choose  |  Esc skip"
	var card_width := 212.0 if very_compact else (224.0 if compact else 236.0)
	var card_height := 238.0 if very_compact else (252.0 if compact else 274.0)
	var available_width := maxf(choice_scroll.size.x, panel.custom_minimum_size.x - (56.0 if very_compact else 96.0))
	var next_columns := clampi(int(floor((available_width + CARD_GAP) / (card_width + CARD_GAP))), 1, 4)
	choice_row.columns = max(1, min(next_columns, max(choice_row.get_child_count(), 1)))
	for child in choice_row.get_children():
		if child is Button:
			var card := child as Button
			card.custom_minimum_size = Vector2(card_width, card_height)
