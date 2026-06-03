extends CanvasLayer

const UICardFx := preload("res://ui/ui_card_fx.gd")
const UISkin := preload("res://ui/ui_skin.gd")

var active_actor: Node = null
var collected_resources := {
	"gold": 0.0,
	"heal": 0.0,
	"repair": 0.0,
	"inspiration": 0.0
}
var recent_pickups: Array[Dictionary] = []
var relic_history: Array[Dictionary] = []

var backdrop: ColorRect
var panel: PanelContainer
var panel_margin: MarginContainer
var title_label: Label
var subtitle_label: Label
var current_icon: TextureRect
var current_name_label: Label
var current_summary_label: Label
var run_label: Label
var stat_label: Label
var bag_label: Label
var pickup_log_label: Label
var route_log_label: Label
var relic_history_label: Label
var catalog_grid: GridContainer
var catalog_scroll: ScrollContainer
var detail_label: Label
var footer_label: Label
var body_row: HBoxContainer
var left_column_box: VBoxContainer
var right_column_box: VBoxContainer
var layout_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	if AccessoryManager != null and not AccessoryManager.accessory_equipped.is_connected(_on_accessory_changed):
		AccessoryManager.accessory_equipped.connect(_on_accessory_changed)
	if RunDirector != null and not RunDirector.state_changed.is_connected(_on_run_state_changed):
		RunDirector.state_changed.connect(_on_run_state_changed)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func reset_run() -> void:
	collected_resources = {
		"gold": 0.0,
		"heal": 0.0,
		"repair": 0.0,
		"inspiration": 0.0
	}
	recent_pickups.clear()
	relic_history.clear()
	if visible:
		refresh()

func record_pickup(kind: String, amount: float) -> void:
	if not collected_resources.has(kind):
		collected_resources[kind] = 0.0
	collected_resources[kind] = float(collected_resources.get(kind, 0.0)) + maxf(amount, 0.0)
	recent_pickups.push_front({
		"kind": kind,
		"amount": amount
	})
	while recent_pickups.size() > 6:
		recent_pickups.pop_back()
	if visible:
		_refresh_bag_text()

func record_relic_equipped(accessory: Dictionary) -> void:
	var relic_id := String(accessory.get("id", ""))
	if relic_id.is_empty() or relic_id == "none":
		return
	if not relic_history.is_empty() and String(relic_history[0].get("id", "")) == relic_id:
		return
	relic_history.push_front({
		"id": relic_id,
		"name": String(accessory.get("name", "Relic")),
		"summary": String(accessory.get("summary", ""))
	})
	while relic_history.size() > 6:
		relic_history.pop_back()
	if visible:
		_refresh_relic_history_text()

func open(actor: Node) -> void:
	active_actor = actor
	refresh()
	visible = true
	get_tree().paused = true
	_focus_first_card()

func toggle(actor: Node) -> void:
	if visible:
		close()
	else:
		open(actor)

func close() -> void:
	visible = false
	get_tree().paused = false

func refresh() -> void:
	if current_name_label == null:
		return
	var equipped := AccessoryManager.get_equipped_accessory() if AccessoryManager != null else {}
	current_icon.texture = load(String(equipped.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
	current_name_label.text = String(equipped.get("name", _locale_text("No Relic", "无饰品", "無飾品")))
	var summary := String(equipped.get("summary", _locale_text("Choose relics between fights to shape this run.", "在战斗间隙选择饰品来决定本局构筑。", "在戰鬥間隙選擇飾品來決定本局構築。")))
	var tags := AccessoryManager.describe_tags(equipped.get("tags", [])) if AccessoryManager != null else ""
	current_summary_label.text = "%s%s" % [summary, ("\n%s" % tags) if not tags.is_empty() else ""]
	_refresh_run_text()
	_refresh_actor_text()
	_refresh_bag_text()
	_refresh_route_text()
	_refresh_relic_history_text()
	_rebuild_catalog()
	_refresh_layout()

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.018, 0.026, 0.76)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100.0, 690.0)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 28)
	panel_margin.add_theme_constant_override("margin_top", 24)
	panel_margin.add_theme_constant_override("margin_right", 28)
	panel_margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(panel_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel_margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 4)
	header.add_child(title_stack)

	title_label = Label.new()
	title_label.text = _locale_text("Backpack", "背包", "背包")
	UISkin.label(title_label, 28, Color(0.98, 0.90, 0.66))
	title_stack.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = _locale_text(
		"Track the run, current relic, and what the arena has paid out so far.",
		"查看当前构筑、战利品流水和本局路线记录。",
		"查看當前構築、戰利品流水和本局路線記錄。"
	)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(subtitle_label, 13, Color(0.78, 0.84, 0.92))
	title_stack.add_child(subtitle_label)

	var close_button := Button.new()
	close_button.text = _locale_text("Close", "关闭", "關閉")
	UISkin.button_styles(close_button, "thin")
	close_button.pressed.connect(close)
	header.add_child(close_button)

	body_row = HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 14)
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body_row)

	left_column_box = VBoxContainer.new()
	left_column_box.custom_minimum_size = Vector2(340.0, 0.0)
	left_column_box.add_theme_constant_override("separation", 12)
	body_row.add_child(left_column_box)

	var current_panel := _section_panel(left_column_box, _locale_text("Equipped Relic", "当前饰品", "當前飾品"))
	var current_stack := _section_stack(current_panel)

	var icon_slot := PanelContainer.new()
	icon_slot.custom_minimum_size = Vector2(108.0, 108.0)
	icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	current_stack.add_child(icon_slot)

	current_icon = TextureRect.new()
	current_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	current_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	current_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_slot.add_child(current_icon)

	current_name_label = Label.new()
	current_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(current_name_label, 20, Color.WHITE)
	current_stack.add_child(current_name_label)

	current_summary_label = Label.new()
	current_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(current_summary_label, 12, Color(0.78, 0.84, 0.92))
	current_stack.add_child(current_summary_label)

	run_label = Label.new()
	run_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(run_label, 13, Color(0.96, 0.86, 0.62))
	current_stack.add_child(run_label)

	stat_label = Label.new()
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(stat_label, 12, Color(0.82, 0.90, 0.98))
	current_stack.add_child(stat_label)

	var bag_panel := _section_panel(left_column_box, _locale_text("Run Satchel", "战利品袋", "戰利品袋"))
	var bag_stack := _section_stack(bag_panel)

	bag_label = Label.new()
	bag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(bag_label, 12, Color(0.90, 0.92, 0.98))
	bag_stack.add_child(bag_label)

	pickup_log_label = Label.new()
	pickup_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(pickup_log_label, 11, Color(0.76, 0.82, 0.90))
	bag_stack.add_child(pickup_log_label)

	var route_panel := _section_panel(left_column_box, _locale_text("Route Notes", "路线记录", "路線記錄"))
	var route_stack := _section_stack(route_panel)

	route_log_label = Label.new()
	route_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(route_log_label, 12, Color(0.90, 0.92, 0.98))
	route_stack.add_child(route_log_label)

	relic_history_label = Label.new()
	relic_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(relic_history_label, 11, Color(0.76, 0.82, 0.90))
	route_stack.add_child(relic_history_label)

	right_column_box = VBoxContainer.new()
	right_column_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column_box.add_theme_constant_override("separation", 12)
	body_row.add_child(right_column_box)

	var catalog_panel := PanelContainer.new()
	catalog_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	right_column_box.add_child(catalog_panel)

	var catalog_margin := MarginContainer.new()
	catalog_margin.add_theme_constant_override("margin_left", 16)
	catalog_margin.add_theme_constant_override("margin_top", 16)
	catalog_margin.add_theme_constant_override("margin_right", 16)
	catalog_margin.add_theme_constant_override("margin_bottom", 16)
	catalog_panel.add_child(catalog_margin)

	var catalog_stack := VBoxContainer.new()
	catalog_stack.add_theme_constant_override("separation", 10)
	catalog_margin.add_child(catalog_stack)

	var catalog_title := Label.new()
	catalog_title.text = _locale_text("Relic Codex", "饰品图鉴", "飾品圖鑑")
	UISkin.label(catalog_title, 14, UISkin.COLOR_ACCENT)
	catalog_stack.add_child(catalog_title)

	catalog_scroll = ScrollContainer.new()
	catalog_scroll.custom_minimum_size = Vector2(0.0, 420.0)
	catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_stack.add_child(catalog_scroll)

	catalog_grid = GridContainer.new()
	catalog_grid.columns = 3
	catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_grid.add_theme_constant_override("h_separation", 10)
	catalog_grid.add_theme_constant_override("v_separation", 10)
	catalog_scroll.add_child(catalog_grid)

	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.text = _locale_text(
		"Focus a relic card to preview its role.",
		"聚焦任意饰品卡片即可查看定位。",
		"聚焦任意飾品卡片即可查看定位。"
	)
	UISkin.label(detail_label, 12, Color(0.90, 0.86, 0.72))
	catalog_stack.add_child(detail_label)

	footer_label = Label.new()
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.text = _locale_text("B / Tab close  |  Esc close", "B / Tab 关闭  |  Esc 关闭", "B / Tab 關閉  |  Esc 關閉")
	UISkin.label(footer_label, 12, Color(0.72, 0.78, 0.86))
	root.add_child(footer_label)

func _section_panel(parent: Node, title_text: String) -> PanelContainer:
	var panel_value := PanelContainer.new()
	panel_value.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	parent.add_child(panel_value)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel_value.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title_value := Label.new()
	title_value.text = title_text
	UISkin.label(title_value, 14, UISkin.COLOR_ACCENT)
	stack.add_child(title_value)
	return panel_value

func _section_stack(section_panel: PanelContainer) -> VBoxContainer:
	if section_panel == null or section_panel.get_child_count() <= 0:
		return null
	var margin := section_panel.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() <= 0:
		return null
	return margin.get_child(0) as VBoxContainer

func _refresh_run_text() -> void:
	if RunDirector == null:
		run_label.text = ""
		return
	var state := RunDirector.get_state()
	run_label.text = "%s %d  |  %s %d  |  %s %d/%d  |  %s %d" % [
		_locale_text("Gold", "金币", "金幣"),
		int(state.get("gold", 0)),
		_locale_text("Level", "等级", "等級"),
		int(state.get("hero_level", 1)),
		_locale_text("XP", "经验", "經驗"),
		int(state.get("hero_xp", 0)),
		int(state.get("hero_xp_to_next", 45)),
		_locale_text("Kills", "击杀", "擊殺"),
		int(state.get("total_kills", 0))
	]

func _refresh_actor_text() -> void:
	if active_actor == null or not is_instance_valid(active_actor):
		stat_label.text = _locale_text("No hero selected.", "当前没有角色。", "當前沒有角色。")
		return
	var hp := _actor_value("hp")
	var max_hp := _actor_value("max_hp")
	var defense := _actor_value("defense")
	var max_defense := _actor_value("max_defense")
	var attack := _actor_value("attack_damage")
	var speed := _actor_value("move_speed")
	stat_label.text = "%s %.0f/%.0f\n%s %.0f/%.0f\n%s %.0f  |  %s %.0f" % [
		_locale_text("HP", "生命", "生命"),
		hp,
		max_hp,
		_locale_text("Armor", "护甲", "護甲"),
		defense,
		max_defense,
		_locale_text("Attack", "攻击", "攻擊"),
		attack,
		_locale_text("Move", "移动", "移動"),
		speed
	]

func _refresh_bag_text() -> void:
	bag_label.text = "%s %d  |  %s %d  |  %s %d  |  %s %d" % [
		_locale_text("Gold Looted", "已拾金币", "已拾金幣"),
		int(round(float(collected_resources.get("gold", 0.0)))),
		_locale_text("Healing", "治疗值", "治療值"),
		int(round(float(collected_resources.get("heal", 0.0)))),
		_locale_text("Repair", "修复值", "修復值"),
		int(round(float(collected_resources.get("repair", 0.0)))),
		_locale_text("Inspiration", "灵感值", "靈感值"),
		int(round(float(collected_resources.get("inspiration", 0.0))))
	]
	if recent_pickups.is_empty():
		pickup_log_label.text = _locale_text("No pickups collected yet.", "暂时还没有拾取记录。", "暫時還沒有拾取記錄。")
		return
	var parts: Array[String] = []
	for entry in recent_pickups:
		parts.append("%s +%d" % [_pickup_label(String(entry.get("kind", ""))), int(round(float(entry.get("amount", 0.0))))])
	pickup_log_label.text = _locale_text("Recent", "最近拾取", "最近拾取") + "\n" + "  |  ".join(parts)

func _refresh_route_text() -> void:
	if RunDirector == null:
		route_log_label.text = ""
		return
	var route_text := RunDirector.describe_event_route(4)
	var history_text := RunDirector.describe_event_history(4)
	route_log_label.text = "%s\n%s" % [
		_locale_text("Upcoming", "后续路线", "後續路線"),
		route_text
	]
	relic_history_label.text = "%s\n%s" % [
		_locale_text("Recent Choices", "最近事件", "最近事件"),
		history_text
	]

func _refresh_relic_history_text() -> void:
	if relic_history.is_empty():
		return
	var names: Array[String] = []
	for entry in relic_history:
		names.append(String(entry.get("name", "Relic")))
	relic_history_label.text += "\n\n%s\n%s" % [
		_locale_text("Relic Path", "饰品路线", "飾品路線"),
		"  ->  ".join(names)
	]

func _rebuild_catalog() -> void:
	for child in catalog_grid.get_children():
		catalog_grid.remove_child(child)
		child.queue_free()
	if AccessoryManager == null:
		return
	for accessory in AccessoryManager.get_catalog():
		catalog_grid.add_child(_catalog_card(accessory))

func _catalog_card(accessory: Dictionary) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(176.0, 164.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UISkin.choice_panel_style())
	button.add_theme_stylebox_override("hover", UISkin.flat_style(Color(0.20, 0.22, 0.26, 0.98), UISkin.COLOR_ACCENT, 2, 4, Vector4(12, 10, 12, 10)))

	var tilt_root := UICardFx.install(button, {
		"active_scale": 1.018,
		"rotation_max": 2.0,
		"float_offset": Vector2(4.0, 3.0),
		"sheen_alpha": 0.08
	})
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 10
	margin.offset_top = 10
	margin.offset_right = -10
	margin.offset_bottom = -10
	tilt_root.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(50.0, 50.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(String(accessory.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
	stack.add_child(icon)

	var name_label := Label.new()
	name_label.text = String(accessory.get("name", "Relic"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(name_label, 13, Color.WHITE)
	stack.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = String(accessory.get("rarity", "Common"))
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UISkin.label(rarity_label, 11, Color(0.98, 0.86, 0.58))
	stack.add_child(rarity_label)

	var tags := AccessoryManager.describe_tags(accessory.get("tags", [])) if AccessoryManager != null else ""
	var tag_label := Label.new()
	tag_label.text = tags
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_label.max_lines_visible = 2
	UISkin.label(tag_label, 10, Color(0.76, 0.84, 0.92))
	stack.add_child(tag_label)

	UISkin.ignore_mouse_recursive(margin)
	button.focus_entered.connect(func() -> void:
		_preview_accessory(accessory)
	)
	button.mouse_entered.connect(func() -> void:
		_preview_accessory(accessory)
	)
	return button

func _preview_accessory(accessory: Dictionary) -> void:
	var effect_text := AccessoryManager.describe_effects(accessory) if AccessoryManager != null else ""
	var playstyle := AccessoryManager.describe_playstyle(accessory.get("tags", [])) if AccessoryManager != null else ""
	detail_label.text = "%s\n%s\n%s" % [
		String(accessory.get("summary", "")),
		effect_text,
		playstyle
	]

func _focus_first_card() -> void:
	if catalog_grid == null:
		return
	for child in catalog_grid.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if panel == null or panel_margin == null or left_column_box == null or catalog_grid == null:
		return
	var viewport_size := layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact := viewport_size.x < 1180.0 or viewport_size.y < 760.0
	var very_compact := viewport_size.x < 860.0 or viewport_size.y < 620.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (44.0 if very_compact else 96.0), 380.0, 1100.0),
		clampf(viewport_size.y - (36.0 if very_compact else 84.0), 440.0, 690.0)
	)
	panel_margin.add_theme_constant_override("margin_left", 18 if very_compact else (22 if compact else 28))
	panel_margin.add_theme_constant_override("margin_top", 16 if very_compact else (20 if compact else 24))
	panel_margin.add_theme_constant_override("margin_right", 18 if very_compact else (22 if compact else 28))
	panel_margin.add_theme_constant_override("margin_bottom", 16 if very_compact else (20 if compact else 24))
	left_column_box.custom_minimum_size.x = 220.0 if very_compact else (272.0 if compact else 340.0)
	body_row.add_theme_constant_override("separation", 10 if very_compact else (12 if compact else 14))
	if catalog_scroll != null:
		catalog_scroll.custom_minimum_size.y = clampf(panel.custom_minimum_size.y * (0.28 if very_compact else (0.36 if compact else 0.42)), 170.0, 420.0)
	catalog_grid.columns = 1 if very_compact else (2 if compact else 3)
	var catalog_card_size := Vector2(142.0, 148.0) if very_compact else (Vector2(156.0, 154.0) if compact else Vector2(176.0, 164.0))
	for child in catalog_grid.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = catalog_card_size
	UISkin.label(title_label, 22 if very_compact else (25 if compact else 28), Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 12 if very_compact else 13, Color(0.78, 0.84, 0.92))
	UISkin.label(current_name_label, 17 if compact else 20, Color.WHITE)
	UISkin.label(current_summary_label, 11 if compact else 12, Color(0.78, 0.84, 0.92))
	UISkin.label(run_label, 12 if compact else 13, Color(0.96, 0.86, 0.62))
	UISkin.label(stat_label, 11 if compact else 12, Color(0.82, 0.90, 0.98))
	UISkin.label(bag_label, 11 if compact else 12, Color(0.90, 0.92, 0.98))
	UISkin.label(pickup_log_label, 10 if compact else 11, Color(0.76, 0.82, 0.90))
	UISkin.label(route_log_label, 11 if compact else 12, Color(0.90, 0.92, 0.98))
	UISkin.label(relic_history_label, 10 if compact else 11, Color(0.76, 0.82, 0.90))
	UISkin.label(detail_label, 11 if compact else 12, Color(0.90, 0.86, 0.72))
	UISkin.label(footer_label, 10 if compact else 12, Color(0.72, 0.78, 0.86))
	footer_label.text = _locale_text("B / Tab  |  Esc", "B / Tab  |  Esc", "B / Tab  |  Esc") if very_compact else _locale_text("B / Tab close  |  Esc close", "B / Tab 关闭  |  Esc 关闭", "B / Tab 關閉  |  Esc 關閉")

func _on_accessory_changed(accessory: Dictionary) -> void:
	record_relic_equipped(accessory)
	if visible:
		refresh()

func _on_run_state_changed(_state: Dictionary) -> void:
	if visible:
		_refresh_run_text()
		_refresh_route_text()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B or event.keycode == KEY_TAB:
			close()
			get_viewport().set_input_as_handled()

func _pickup_label(kind: String) -> String:
	match kind:
		"gold":
			return _locale_text("Gold", "金币", "金幣")
		"heal":
			return _locale_text("Heal", "治疗", "治療")
		"repair":
			return _locale_text("Repair", "修复", "修復")
		"inspiration":
			return _locale_text("Inspiration", "灵感", "靈感")
		_:
			return kind.capitalize()

func _actor_value(field: String) -> float:
	if active_actor == null or not is_instance_valid(active_actor):
		return 0.0
	for property in active_actor.get_property_list():
		if String(property.get("name", "")) == field:
			return float(active_actor.get(field))
	return 0.0

func _current_locale() -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		return String(UISettings.get_locale())
	return "zh_Hans"

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	match _current_locale():
		"zh_Hant":
			return zh_hant_text
		"zh_Hans":
			return zh_hans_text
		_:
			return en_text
