extends CanvasLayer

signal debug_requested

const RunEffects := preload("res://systems/run/run_effects.gd")
const UISkin := preload("res://ui/ui_skin.gd")

var root_margin: MarginContainer
var panel_margin: MarginContainer
var title_label: Label
var subtitle_label: Label
var detail_label: Label
var run_header_label: Label
var info_grid: GridContainer
var objective_value_label: Label
var threat_value_label: Label
var hero_value_label: Label
var relic_value_label: Label
var objective_panel_root: PanelContainer
var threat_panel_root: PanelContainer
var hero_panel_root: PanelContainer
var relic_panel_root: PanelContainer
var context_panel_map: Dictionary = {}
var context_value_map: Dictionary = {}
var context_accent_map: Dictionary = {}
var run_label: Label
var run_route_label: Label
var run_bonus_label: Label
var metric_grid: GridContainer
var metric_value_labels: Dictionary = {}
var metric_panel_map: Dictionary = {}
var metric_accent_map: Dictionary = {}
var context_caption_labels: Array[Label] = []
var metric_caption_labels: Array[Label] = []
var layout_size_override: Vector2 = Vector2.ZERO
var context_state: Dictionary = {}
var run_panel_root: PanelContainer
var debug_button: Button

func _ready() -> void:
	context_state = _default_context_state()
	_build_ui()
	if RunDirector != null and not RunDirector.state_changed.is_connected(_on_run_state_changed):
		RunDirector.state_changed.connect(_on_run_state_changed)
	if UISettings != null and UISettings.has_signal("locale_changed") and not UISettings.locale_changed.is_connected(_refresh_copy):
		UISettings.locale_changed.connect(_refresh_copy)
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

func set_context(context: Dictionary) -> void:
	if context.is_empty():
		return
	for key in ["objective", "threat", "hero", "relic"]:
		if context.has(key):
			context_state[key] = String(context.get(key, context_state[key]))
	_refresh_context()

func _build_ui() -> void:
	layer = 4
	root_margin = MarginContainer.new()
	root_margin.offset_left = 18.0
	root_margin.offset_top = 16.0
	root_margin.offset_right = 620.0
	root_margin.offset_bottom = 352.0
	root_margin.add_theme_constant_override("margin_left", 10)
	root_margin.add_theme_constant_override("margin_top", 10)
	root_margin.add_theme_constant_override("margin_right", 10)
	root_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(root_margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UISkin.panel_style())
	root_margin.add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(panel_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel_margin.add_child(content)

	title_label = Label.new()
	title_label.text = _locale_text("Town Boss Trial", "城镇王战试炼", "城鎮王戰試煉")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_label, 24, Color(0.98, 0.90, 0.66))
	content.add_child(title_label)

	debug_button = Button.new()
	debug_button.text = "Debug"
	debug_button.tooltip_text = "Open the test panel"
	UISkin.button_styles(debug_button, "thin")
	debug_button.pressed.connect(_on_debug_pressed)
	content.add_child(debug_button)

	subtitle_label = Label.new()
	subtitle_label.text = _locale_text(
		"Pick a champion, then build toward the bosses instead of only surviving the next room.",
		"先选一名角色，再把整条路线朝首领战去构筑，而不只是想着撑过下一场。",
		"先選一名角色，再把整條路線朝首領戰去構築，而不只是想著撐過下一場。"
	)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(subtitle_label, 15, Color(0.86, 0.88, 0.92))
	content.add_child(subtitle_label)

	detail_label = Label.new()
	detail_label.text = _locale_text(
		"Controls: WASD move, J attack, K/L/I skills.",
		"操作：WASD 移动，J 普攻，K/L/I 技能。",
		"操作：WASD 移動，J 普攻，K/L/I 技能。"
	)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(detail_label, 13, Color(0.70, 0.76, 0.84))
	content.add_child(detail_label)

	info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_grid.add_theme_constant_override("h_separation", 8)
	info_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(info_grid)

	var objective_card := _context_card(_locale_text("Objective", "目标", "目標"), Color(0.98, 0.90, 0.66))
	objective_panel_root = objective_card["panel"] as PanelContainer
	objective_value_label = objective_card["value"] as Label
	info_grid.add_child(objective_panel_root)

	var threat_card := _context_card(_locale_text("Threat", "威胁", "威脅"), Color(1.0, 0.78, 0.66))
	threat_panel_root = threat_card["panel"] as PanelContainer
	threat_value_label = threat_card["value"] as Label
	info_grid.add_child(threat_panel_root)

	var hero_card := _context_card(_locale_text("Hero", "角色", "角色"), Color(0.78, 0.88, 1.0))
	hero_panel_root = hero_card["panel"] as PanelContainer
	hero_value_label = hero_card["value"] as Label
	info_grid.add_child(hero_panel_root)

	var relic_card := _context_card(_locale_text("Relic", "饰品", "飾品"), Color(0.82, 0.92, 0.76))
	relic_panel_root = relic_card["panel"] as PanelContainer
	relic_value_label = relic_card["value"] as Label
	info_grid.add_child(relic_panel_root)

	var run_panel := PanelContainer.new()
	run_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(run_panel)
	run_panel_root = run_panel

	var run_margin := MarginContainer.new()
	run_margin.add_theme_constant_override("margin_left", 10)
	run_margin.add_theme_constant_override("margin_top", 10)
	run_margin.add_theme_constant_override("margin_right", 10)
	run_margin.add_theme_constant_override("margin_bottom", 10)
	run_panel.add_child(run_margin)

	var run_column := VBoxContainer.new()
	run_column.add_theme_constant_override("separation", 8)
	run_margin.add_child(run_column)

	run_header_label = Label.new()
	run_header_label.text = _locale_text("Run Snapshot", "路线快照", "路線快照")
	UISkin.label(run_header_label, 12, UISkin.COLOR_ACCENT)
	run_column.add_child(run_header_label)

	metric_grid = GridContainer.new()
	metric_grid.columns = 2
	metric_grid.add_theme_constant_override("h_separation", 8)
	metric_grid.add_theme_constant_override("v_separation", 8)
	run_column.add_child(metric_grid)

	_add_metric_card("gold", _locale_text("Gold", "金币", "金幣"), Color(0.98, 0.86, 0.58))
	_add_metric_card("cleared", _locale_text("Cleared", "已清", "已清"), Color(0.76, 0.90, 1.0))
	_add_metric_card("next", _locale_text("Next", "下一步", "下一步"), Color(0.88, 0.82, 1.0))
	_add_metric_card("effects", _locale_text("Run Effects", "局内加成", "局內加成"), Color(0.74, 0.92, 0.76))

	run_bonus_label = Label.new()
	run_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(run_bonus_label, 11, Color(0.90, 0.84, 0.68))
	run_column.add_child(run_bonus_label)

	run_route_label = Label.new()
	run_route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(run_route_label, 11, Color(0.84, 0.90, 0.98))
	run_column.add_child(run_route_label)

	run_label = Label.new()
	run_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(run_label, 11, Color(0.72, 0.78, 0.88))
	run_column.add_child(run_label)

	_refresh_context()

func _accent_panel_style(accent: Color, emphasized: bool = false) -> StyleBox:
	var border_color := accent if emphasized else accent.lerp(UISkin.COLOR_BORDER_ALT, 0.45)
	var background := UISkin.COLOR_PANEL_ALT.lightened(0.05 if emphasized else 0.02)
	return UISkin.flat_style(
		background,
		border_color,
		2 if emphasized else 1,
		4 if emphasized else 3,
		Vector4(12, 10, 12, 10)
	)

func _context_card(caption: String, accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _accent_panel_style(accent, true))
	panel.set_meta("accent", accent)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var caption_label := Label.new()
	caption_label.text = caption
	UISkin.label(caption_label, 11, accent)
	column.add_child(caption_label)
	context_caption_labels.append(caption_label)

	var value_label := Label.new()
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.custom_minimum_size.y = 32.0
	UISkin.label(value_label, 13, Color.WHITE)
	column.add_child(value_label)
	context_panel_map[caption.to_lower()] = panel
	context_value_map[caption.to_lower()] = value_label
	context_accent_map[caption.to_lower()] = accent

	return {
		"panel": panel,
		"value": value_label
	}

func _add_metric_card(metric_id: String, caption: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _accent_panel_style(accent))
	panel.set_meta("metric_id", metric_id)
	metric_grid.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)

	var caption_label := Label.new()
	caption_label.text = caption
	UISkin.label(caption_label, 10, accent)
	column.add_child(caption_label)
	metric_caption_labels.append(caption_label)

	var value_label := Label.new()
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.custom_minimum_size.y = 24.0
	UISkin.label(value_label, 15, Color.WHITE)
	column.add_child(value_label)

	metric_value_labels[metric_id] = value_label
	metric_panel_map[metric_id] = panel
	metric_accent_map[metric_id] = accent

func _on_run_state_changed(state: Dictionary) -> void:
	if run_label == null:
		return
	var next_event := String(state.get("next_event_kind", ""))
	var next_text := RunDirector.describe_event_kind(next_event) if RunDirector != null and not next_event.is_empty() else _locale_text("Victory", "胜利结算", "勝利結算")
	var modifier_count := (state.get("run_modifiers", {}) as Dictionary).size()
	var reward_flat_bonus := int(state.get("reward_flat_bonus", 0))
	var reward_multiplier := float(state.get("reward_multiplier", 1.0))
	var pending_prep := state.get("pending_encounter_prep", {}) as Dictionary
	var hero_level := int(state.get("hero_level", 1))
	var hero_xp := int(state.get("hero_xp", 0))
	var hero_xp_to_next := int(state.get("hero_xp_to_next", 45))
	var total_kills := int(state.get("total_kills", 0))
	var route_preview := RunDirector.describe_event_route(3) if RunDirector != null else _locale_text("No route data", "暂无路线数据", "暫無路線資料")
	var prep_text := ""
	if not pending_prep.is_empty():
		prep_text = _locale_text(
			"Prep: %s",
			"备战：%s",
			"備戰：%s"
		) % RunEffects.prep_title(pending_prep)
	var bonus_text := _locale_text("No bounty bonus active.", "当前没有额外赏金加成。", "當前沒有額外賞金加成。")
	if reward_flat_bonus > 0 or reward_multiplier > 1.001:
		var bonus_parts: Array[String] = []
		if reward_flat_bonus > 0:
			bonus_parts.append(_locale_text("+%d gold", "+%d 金币", "+%d 金幣") % reward_flat_bonus)
		if reward_multiplier > 1.001:
			bonus_parts.append(_locale_text("x%.2f rewards", "x%.2f 奖励", "x%.2f 獎勵") % reward_multiplier)
		bonus_text = " / ".join(bonus_parts)

	(metric_value_labels.get("gold") as Label).text = str(int(state.get("gold", 0)))
	(metric_value_labels.get("cleared") as Label).text = str(int(state.get("cleared_encounters", 0)))
	(metric_value_labels.get("next") as Label).text = next_text
	(metric_value_labels.get("effects") as Label).text = _locale_text("%d active", "%d 条激活", "%d 條啟動") % modifier_count

	_refresh_metric_card_states(int(state.get("gold", 0)), int(state.get("cleared_encounters", 0)), modifier_count, reward_flat_bonus, reward_multiplier)
	run_bonus_label.text = "%s %d  |  %s %d/%d  |  %s %d  |  %s %s" % [
		_locale_text("Level", "等级", "等級"),
		hero_level,
		_locale_text("XP", "经验", "經驗"),
		hero_xp,
		hero_xp_to_next,
		_locale_text("Kills", "击杀", "擊殺"),
		total_kills,
		_locale_text("Bounty", "赏金", "賞金"),
		bonus_text
	]
	run_route_label.text = "%s %s%s" % [
		_locale_text("Route", "路线", "路線"),
		route_preview,
		("  |  %s" % prep_text) if not prep_text.is_empty() else ""
	]
	run_label.text = "%s +%d  |  %s %d  |  %s %s" % [
		_locale_text("Last reward", "上次奖励", "上次獎勵"),
		int(state.get("last_reward_gold", 0)),
		_locale_text("Run Effects", "局内加成", "局內加成"),
		modifier_count,
		_locale_text("Current focus", "当前重心", "當前重心"),
		_locale_text("Kill cleanly, scoop drops, and turn levels into safer boss checks.", "打干净、捡掉落，把等级优势转成更稳的 Boss 检定。", "打乾淨、撿掉落，把等級優勢轉成更穩的 Boss 檢定。")
	]

func _refresh_metric_card_states(gold_value: int, cleared_value: int, modifier_count: int, reward_flat_bonus: int, reward_multiplier: float) -> void:
	for metric_id in metric_panel_map.keys():
		var panel := metric_panel_map[metric_id] as PanelContainer
		var accent := metric_accent_map.get(metric_id, UISkin.COLOR_ACCENT) as Color
		var emphasized := false
		match String(metric_id):
			"gold":
				emphasized = gold_value > 0
			"cleared":
				emphasized = cleared_value > 0
			"next":
				emphasized = true
			"effects":
				emphasized = modifier_count > 0 or reward_flat_bonus > 0 or reward_multiplier > 1.001
		if panel != null:
			panel.add_theme_stylebox_override("panel", _accent_panel_style(accent, emphasized))

func _refresh_copy(_locale: String = "") -> void:
	title_label.text = _locale_text("Town Boss Trial", "城镇王战试炼", "城鎮王戰試煉")
	subtitle_label.text = _locale_text(
		"Pick a champion, then build toward the bosses instead of only surviving the next room.",
		"先选一名角色，再把整条路线朝首领战去构筑，而不只是想着撑过下一场。",
		"先選一名角色，再把整條路線朝首領戰去構築，而不只是想著撐過下一場。"
	)
	detail_label.text = _locale_text(
		"Controls: WASD move, J attack, K/L/I skills.",
		"操作：WASD 移动，J 普攻，K/L/I 技能。",
		"操作：WASD 移動，J 普攻，K/L/I 技能。"
	)
	if run_header_label != null:
		run_header_label.text = _locale_text("Run Snapshot", "路线快照", "路線快照")
	if context_caption_labels.size() >= 4:
		context_caption_labels[0].text = _locale_text("Objective", "目标", "目標")
		context_caption_labels[1].text = _locale_text("Threat", "威胁", "威脅")
		context_caption_labels[2].text = _locale_text("Hero", "角色", "角色")
		context_caption_labels[3].text = _locale_text("Relic", "饰品", "飾品")
	if metric_caption_labels.size() >= 4:
		metric_caption_labels[0].text = _locale_text("Gold", "金币", "金幣")
		metric_caption_labels[1].text = _locale_text("Cleared", "已清", "已清")
		metric_caption_labels[2].text = _locale_text("Next", "下一步", "下一步")
		metric_caption_labels[3].text = _locale_text("Run Effects", "局内加成", "局內加成")

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

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _default_context_state() -> Dictionary:
	return {
		"objective": _locale_text(
			"Select a champion to begin the run.",
			"先选择一名角色，再开始这轮试炼。",
			"先選擇一名角色，再開始這輪試煉。"
		),
		"threat": _locale_text(
			"Knight is safest, Ranger spikes tempo, Mage controls space.",
			"骑士最稳，游侠最会滚节奏，法师最擅长控场。",
			"騎士最穩，遊俠最會滾節奏，法師最擅長控場。"
		),
		"hero": _locale_text(
			"No champion selected.",
			"当前还没有锁定角色。",
			"當前還沒有鎖定角色。"
		),
		"relic": _locale_text(
			"No Accessory\nChoose a relic to shape this run.",
			"无饰品\n选择一件饰品来决定这一局的构筑方向。",
			"無飾品\n選擇一件飾品來決定這一局的構築方向。"
		)
	}

func _on_debug_pressed() -> void:
	debug_requested.emit()

func _refresh_context() -> void:
	if objective_value_label == null:
		return
	objective_value_label.text = String(context_state.get("objective", ""))
	threat_value_label.text = String(context_state.get("threat", ""))
	hero_value_label.text = String(context_state.get("hero", ""))
	relic_value_label.text = String(context_state.get("relic", ""))

func _has_selected_hero() -> bool:
	var hero_text := String(context_state.get("hero", ""))
	if hero_text.is_empty():
		return false
	return hero_text != _locale_text(
		"No champion selected.",
		"当前还没有锁定角色。",
		"當前還沒有鎖定角色。"
	)

func _refresh_layout() -> void:
	if root_margin == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 980.0 or viewport_size.y < 680.0
	var very_compact: bool = viewport_size.x < 760.0 or viewport_size.y < 560.0
	var hero_selected := _has_selected_hero()
	var show_run_panel := not hero_selected and not very_compact
	var show_secondary_context := not hero_selected
	root_margin.offset_right = clampf(
		viewport_size.x * ((0.31 if compact else 0.27) if hero_selected else (0.42 if very_compact else (0.35 if compact else 0.38))),
		244.0 if hero_selected else (320.0 if very_compact else 360.0),
		420.0 if hero_selected else 620.0
	)
	root_margin.offset_bottom = clampf(
		viewport_size.y * ((0.25 if very_compact else (0.22 if compact else 0.20)) if hero_selected else (0.46 if very_compact else (0.41 if compact else 0.44))),
		140.0 if hero_selected else 256.0,
		216.0 if hero_selected else 420.0
	)
	panel_margin.add_theme_constant_override("margin_left", 10 if very_compact else (12 if compact else 14))
	panel_margin.add_theme_constant_override("margin_top", 10 if very_compact else (12 if compact else 14))
	panel_margin.add_theme_constant_override("margin_right", 10 if very_compact else (12 if compact else 14))
	panel_margin.add_theme_constant_override("margin_bottom", 10 if very_compact else (12 if compact else 14))
	info_grid.columns = 1 if (very_compact or hero_selected) else 2
	metric_grid.columns = 1 if very_compact else 2
	if objective_panel_root != null:
		objective_panel_root.visible = true
	if threat_panel_root != null:
		threat_panel_root.visible = true
	if hero_panel_root != null:
		hero_panel_root.visible = show_secondary_context
	if relic_panel_root != null:
		relic_panel_root.visible = show_secondary_context
	if run_panel_root != null:
		run_panel_root.visible = show_run_panel
	UISkin.label(title_label, 18 if very_compact else (21 if compact else 24), Color(0.98, 0.90, 0.66))
	UISkin.label(subtitle_label, 12 if very_compact else (13 if compact else 15), Color(0.86, 0.88, 0.92))
	UISkin.label(detail_label, 10 if very_compact else (11 if compact else 13), Color(0.70, 0.76, 0.84))
	subtitle_label.visible = not hero_selected
	detail_label.visible = not hero_selected
	detail_label.max_lines_visible = 1 if very_compact else 2
	for value_label in [objective_value_label, threat_value_label, hero_value_label, relic_value_label]:
		if value_label != null:
			UISkin.label(value_label, 11 if very_compact else (12 if compact else 13), Color.WHITE)
	for key in metric_value_labels.keys():
		var metric_label := metric_value_labels[key] as Label
		if metric_label != null:
			UISkin.label(metric_label, 11 if very_compact else (13 if compact else 15), Color.WHITE)
	UISkin.label(run_bonus_label, 10 if very_compact else 11, Color(0.90, 0.84, 0.68))
	UISkin.label(run_route_label, 10 if very_compact else 11, Color(0.84, 0.90, 0.98))
	UISkin.label(run_label, 10 if very_compact else 11, Color(0.72, 0.78, 0.88))
	run_bonus_label.max_lines_visible = 2 if compact else 3
	run_route_label.max_lines_visible = 2 if compact else 3
	run_label.max_lines_visible = 2 if compact else 3
