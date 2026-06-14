extends CanvasLayer

const UISkin := preload("res://ui/ui_skin.gd")

var row: HBoxContainer
var slot_icons: Array[TextureRect] = []
var slot_labels: Array[Label] = []

func _ready() -> void:
	layer = 9
	_build_ui()
	if ConsumableManager != null:
		if not ConsumableManager.inventory_changed.is_connected(_on_inventory_changed):
			ConsumableManager.inventory_changed.connect(_on_inventory_changed)
		_on_inventory_changed(ConsumableManager.get_slots())

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.offset_left = -608.0
	margin.offset_top = -96.0
	margin.offset_right = -26.0
	margin.offset_bottom = -24.0
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)

	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	for index in range(ConsumableManager.MAX_SLOTS if ConsumableManager != null else 4):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(88, 64)
		panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
		row.add_child(panel)
		var stack := VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 0)
		panel.add_child(stack)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(42, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stack.add_child(icon)
		slot_icons.append(icon)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UISkin.label(label, 12, UISkin.COLOR_TEXT)
		stack.add_child(label)
		slot_labels.append(label)

func _on_inventory_changed(slots: Array) -> void:
	for index in range(slot_labels.size()):
		var slot: Dictionary = slots[index] if index < slots.size() else {}
		var label := slot_labels[index]
		var icon := slot_icons[index]
		var consumable_id := String(slot.get("id", ""))
		if consumable_id.is_empty() or ConsumableManager == null:
			icon.texture = null
			label.text = "%d  -" % [index + 1]
			continue
		var data := ConsumableManager.describe(consumable_id)
		icon.texture = load(String(data.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
		label.text = "%d  %s x%d" % [
			index + 1,
			String(data.get("short_name", consumable_id)),
			int(slot.get("amount", 1))
		]
