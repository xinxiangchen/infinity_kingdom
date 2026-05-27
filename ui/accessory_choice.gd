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
@onready var preview_panel: PanelContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewPanel
@onready var preview_title_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewPanel/MarginContainer/VBoxContainer/PreviewTitle
@onready var preview_detail_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewPanel/MarginContainer/VBoxContainer/PreviewDetail
@onready var button_row: HBoxContainer = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow
@onready var keep_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/KeepButton
@onready var reroll_button: Button = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonRow/RerollButton
@onready var footer_label: Label = $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Footer

var active_choices: Array[Dictionary] = []
var active_actor: Node = null
var active_reroll_cost: int = 0
var active_gold: int = 0
var choice_buttons: Array[Button] = []
var choice_data: Array[Dictionary] = []
var selected_choice_index: int = -1
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
	active_gold = gold
	title_label.text = reason
	subtitle_label.text = UIText.text("accessory_subtitle")
	reroll_button.text = UIText.text("accessory_reroll", {"gold": reroll_cost})
	reroll_button.disabled = reroll_cost > gold
	_refresh_current()
	_rebuild_choices()
	visible = true
	get_tree().paused = true
	call_deferred("_focus_first_choice")

func close() -> void:
	visible = false
	get_tree().paused = false

func _apply_skin() -> void:
	backdrop.color = Color(0.015, 0.018, 0.026, 0.76)
	panel.add_theme_stylebox_override("panel", UISkin.choice_panel_style())
	current_row.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	preview_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	var icon_slot := $Backdrop/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CurrentRow/CurrentMargin/CurrentContent/IconSlot as PanelContainer
	icon_slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	UISkin.label(title_label, 28, Color(0.98, 0.90, 0.67))
	UISkin.label(subtitle_label, 15, Color(0.76, 0.80, 0.88))
	UISkin.label(current_name_label, 18, Color.WHITE)
	UISkin.label(current_summary_label, 14, Color(0.76, 0.82, 0.90))
	UISkin.label(preview_title_label, 15, Color(0.98, 0.90, 0.67))
	UISkin.label(preview_detail_label, 12, Color(0.84, 0.88, 0.96))
	UISkin.label(footer_label, 12, Color(0.74, 0.80, 0.88))
	preview_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.button_styles(keep_button, "thin")
	UISkin.button_styles(reroll_button, "thin")
	current_icon.visible = false
	_ensure_slot_placeholder(current_icon_slot)

func _refresh_current() -> void:
	var current := AccessoryManager.get_equipped_accessory()
	current_icon.texture = null
	var current_placeholder := _ensure_slot_placeholder(current_icon_slot)
	current_placeholder.text = _accessory_placeholder_text(current, UIText.text("status_relic"))
	current_name_label.text = "%s: %s" % [UIText.text("accessory_current"), String(current.get("name", UIText.text("accessory_none")))]
	var tags_text := AccessoryManager.describe_tags(current.get("tags", []))
	var playstyle_text := AccessoryManager.describe_playstyle(current.get("tags", []))
	var detail_parts: Array[String] = []
	var summary_text := String(current.get("summary", ""))
	if not summary_text.is_empty():
		detail_parts.append(summary_text)
	detail_parts.append(AccessoryManager.describe_effects(current))
	if not tags_text.is_empty():
		detail_parts.append(tags_text)
	if not playstyle_text.is_empty():
		detail_parts.append(playstyle_text)
	current_summary_label.text = "\n".join(detail_parts)

func _rebuild_choices() -> void:
	choice_buttons.clear()
	choice_data.clear()
	selected_choice_index = -1
	for child in choices_row.get_children():
		choices_row.remove_child(child)
		child.queue_free()
	var choice_index := 0
	for accessory in active_choices:
		var button := _choice_card(accessory, choice_index)
		choice_buttons.append(button)
		choice_data.append(accessory.duplicate(true))
		choices_row.add_child(button)
		choice_index += 1
	preview_title_label.text = UIText.text("accessory_preview")
	preview_detail_label.text = UIText.text("accessory_preview_hint")
	footer_label.text = _footer_text(false)
	_refresh_layout()

func _choice_card(accessory: Dictionary, choice_index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(296, 326)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UISkin.choice_panel_style())
	button.add_theme_stylebox_override("hover", UISkin.flat_style(Color(0.20, 0.22, 0.26, 0.98), UISkin.COLOR_ACCENT, 2, 4, Vector4(16, 14, 16, 14)))
	button.add_theme_stylebox_override("pressed", UISkin.flat_style(Color(0.12, 0.13, 0.16, 1.0), UISkin.COLOR_ACCENT.darkened(0.18), 2, 4, Vector4(16, 14, 16, 14)))
	button.set_meta("accessory_id", String(accessory.get("id", "")))

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
	slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	box.add_child(slot)
	var slot_label := _ensure_slot_placeholder(slot)
	slot_label.text = _accessory_placeholder_text(accessory, str(choice_index + 1))
	var name_label := Label.new()
	name_label.text = String(accessory.get("name", "Accessory"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 42)
	UISkin.label(name_label, 18, Color.WHITE)
	box.add_child(name_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.40, 0.44, 0.52, 0.92)
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

	var plan_label := Label.new()
	plan_label.text = AccessoryManager.describe_playstyle(accessory.get("tags", []))
	plan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_label.custom_minimum_size = Vector2(0, 40)
	UISkin.label(plan_label, 11, Color(0.92, 0.84, 0.66))
	box.add_child(plan_label)
	UISkin.ignore_mouse_recursive(margin)
	button.focus_entered.connect(func() -> void: _preview_accessory(choice_index))
	button.mouse_entered.connect(func() -> void: _preview_accessory(choice_index))
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
			KEY_K:
				_on_keep_pressed()
				get_viewport().set_input_as_handled()
			KEY_R:
				if not reroll_button.disabled:
					reroll_requested.emit()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_on_keep_pressed()
				get_viewport().set_input_as_handled()

func _activate_choice_index(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= choice_buttons.size():
		return
	var button := choice_buttons[choice_index]
	if button == null or button.disabled:
		return
	button.grab_focus()
	button.emit_signal("pressed")

func _preview_accessory(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= choice_data.size():
		return
	selected_choice_index = choice_index
	var accessory := choice_data[choice_index]
	var accessory_name := String(accessory.get("name", "Accessory"))
	var tags_text := AccessoryManager.describe_tags(accessory.get("tags", []))
	var summary_text := String(accessory.get("summary", ""))
	var effect_text := AccessoryManager.describe_effects(accessory)
	var playstyle_text := AccessoryManager.describe_playstyle(accessory.get("tags", []))
	preview_title_label.text = "%s %d: %s%s" % [
		UIText.text("accessory_preview"),
		choice_index + 1,
		accessory_name,
		("  |  %s" % tags_text) if not tags_text.is_empty() else ""
	]
	var detail_parts: Array[String] = []
	if not summary_text.is_empty():
		detail_parts.append(summary_text)
	if not effect_text.is_empty():
		detail_parts.append(effect_text)
	if not playstyle_text.is_empty():
		detail_parts.append(playstyle_text)
	preview_detail_label.text = " ".join(detail_parts)

func _focus_first_choice() -> void:
	if choice_buttons.is_empty():
		return
	choice_buttons[0].grab_focus()
	_preview_accessory(0)

func _footer_text(compact: bool) -> String:
	if compact:
		return UIText.text("accessory_footer_short")
	return UIText.text("accessory_footer", {
		"gold": active_reroll_cost,
		"current_gold": active_gold
	})

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

func _ensure_slot_placeholder(slot: PanelContainer) -> Label:
	var placeholder := slot.get_node_or_null("PlaceholderLabel") as Label
	if placeholder == null:
		placeholder = Label.new()
		placeholder.name = "PlaceholderLabel"
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(placeholder)
	UISkin.label(placeholder, 12, Color(0.90, 0.92, 0.98))
	return placeholder

func _accessory_placeholder_text(accessory: Dictionary, fallback: String) -> String:
	var tags := accessory.get("tags", []) as Array
	if not tags.is_empty():
		var primary_tag := str(tags[0]).replace("_", " ").to_upper()
		return primary_tag.substr(0, mini(primary_tag.length(), 6))
	var name := String(accessory.get("name", ""))
	var initials := ""
	for word in name.split(" ", false):
		if initials.length() >= 3:
			break
		initials += word.substr(0, 1).to_upper()
	if not initials.is_empty():
		return initials
	return fallback

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
	preview_panel.custom_minimum_size.y = 82.0 if very_compact else (88.0 if compact else 96.0)
	choices_scroll.custom_minimum_size.y = clampf(panel.custom_minimum_size.y * (0.34 if very_compact else 0.41), 188.0, 330.0)
	UISkin.label(title_label, 22 if very_compact else (25 if compact else 28), Color(0.98, 0.90, 0.67))
	UISkin.label(subtitle_label, 13 if very_compact else (14 if compact else 15), Color(0.76, 0.80, 0.88))
	UISkin.label(current_name_label, 15 if very_compact else (17 if compact else 18), Color.WHITE)
	UISkin.label(current_summary_label, 12 if very_compact else 13, Color(0.76, 0.82, 0.90))
	UISkin.label(preview_title_label, 13 if very_compact else (14 if compact else 15), Color(0.98, 0.90, 0.67))
	UISkin.label(preview_detail_label, 11 if compact else 12, Color(0.84, 0.88, 0.96))
	UISkin.label(footer_label, 10 if very_compact else 11, Color(0.74, 0.80, 0.88))
	var card_width := 220.0 if very_compact else (252.0 if compact else 296.0)
	var card_height := 286.0 if very_compact else (314.0 if compact else 350.0)
	var available_width := maxf(choices_scroll.size.x, panel.custom_minimum_size.x - (56.0 if very_compact else 96.0))
	var next_columns := clampi(int(floor((available_width + CARD_GAP) / (card_width + CARD_GAP))), 1, 3)
	choices_row.columns = max(1, min(next_columns, max(active_choices.size(), 1)))
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 8 if compact else 12)
	keep_button.custom_minimum_size = Vector2(0.0, 48.0 if compact else 54.0)
	reroll_button.custom_minimum_size = Vector2(0.0, 48.0 if compact else 54.0)
	keep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep_button.text = UIText.text("accessory_keep_short") if very_compact else UIText.text("accessory_keep")
	reroll_button.text = UIText.text("accessory_reroll_short") if compact else UIText.text("accessory_reroll", {"gold": active_reroll_cost})
	footer_label.text = _footer_text(very_compact)
	for child in choices_row.get_children():
		if child is Button:
			var card := child as Button
			card.custom_minimum_size = Vector2(card_width, card_height)
