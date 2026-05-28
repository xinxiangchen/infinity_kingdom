extends CanvasLayer

const RunEffects := preload("res://systems/run/run_effects.gd")
const UISkin := preload("res://ui/ui_skin.gd")

const TAG_LABELS := {
	"attack": {"en": "Attack", "zh_Hans": "普攻", "zh_Hant": "普攻"},
	"crit": {"en": "Crit", "zh_Hans": "暴击", "zh_Hant": "暴擊"},
	"damage": {"en": "Damage", "zh_Hans": "伤害", "zh_Hant": "傷害"},
	"defense": {"en": "Defense", "zh_Hans": "防御", "zh_Hant": "防禦"},
	"power": {"en": "Power", "zh_Hans": "强压", "zh_Hant": "強壓"},
	"resource": {"en": "Resource", "zh_Hans": "资源", "zh_Hant": "資源"},
	"risk": {"en": "Risk", "zh_Hans": "风险", "zh_Hant": "風險"},
	"skill": {"en": "Skill", "zh_Hans": "技能", "zh_Hant": "技能"},
	"speed": {"en": "Speed", "zh_Hans": "速度", "zh_Hant": "速度"},
	"survival": {"en": "Survival", "zh_Hans": "生存", "zh_Hant": "生存"},
	"tempo": {"en": "Tempo", "zh_Hans": "节奏", "zh_Hant": "節奏"}
}

var player_character: Node = null
var root_margin: MarginContainer
var root_panel: PanelContainer
var inner_margin: MarginContainer
var content: VBoxContainer
var title_label: Label
var vitals_header_label: Label
var status_header_label: Label
var skills_header_label: Label
var accessory_header_label: Label
var run_header_label: Label
var hp_bar: TextureProgressBar
var hp_label: Label
var defense_bar: TextureProgressBar
var defense_label: Label
var inspiration_bar: TextureProgressBar
var inspiration_label: Label
var shield_label: Label
var state_label: Label
var level_label: Label
var xp_label: Label
var status_grid: GridContainer
var control_label: Label
var combat_feed_label: Label
var run_state_label: Label
var accessory_icon: TextureRect
var accessory_name_label: Label
var accessory_tags_label: Label
var accessory_summary_label: Label
var accessory_grid: GridContainer
var accessory_panel_root: PanelContainer
var skill_grid: GridContainer
var skill_slots: Dictionary = {}
var meter_bars: Array[TextureProgressBar] = []
var combat_feed_tween: Tween = null
var last_control_summary: String = ""
var layout_size_override: Vector2 = Vector2.ZERO
var run_metric_grid: GridContainer
var run_metric_labels: Dictionary = {}
var run_panel_root: PanelContainer
var skill_icon_paths := {
	"Knight": [
		"res://assets/ui/skill/knight_charge_slash.png",
		"res://assets/ui/skill/knight_counter_shock.png",
		"res://assets/ui/skill/knight_holy_field.png"
	],
	"Ranger": [
		"res://assets/ui/skill/ranger_wind_arrow.png",
		"res://assets/ui/skill/ranger_shadow_step.png",
		"res://assets/ui/skill/ranger_hunt_rush.png"
	],
	"Mage": [
		"res://assets/ui/skill/mage_blade_whirl.png",
		"res://assets/ui/skill/mage_arcane_burst.png",
		"res://assets/ui/skill/mage_silence_decree.png"
	]
}

func _ready() -> void:
	_build_ui()
	if AccessoryManager != null and not AccessoryManager.accessory_equipped.is_connected(_on_accessory_equipped):
		AccessoryManager.accessory_equipped.connect(_on_accessory_equipped)
	if RunDirector != null and not RunDirector.state_changed.is_connected(_on_run_state_changed):
		RunDirector.state_changed.connect(_on_run_state_changed)
	if UISettings != null and UISettings.has_signal("locale_changed") and not UISettings.locale_changed.is_connected(_on_locale_changed):
		UISettings.locale_changed.connect(_on_locale_changed)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	if AccessoryManager != null:
		_on_accessory_equipped(AccessoryManager.get_equipped_accessory())
	if RunDirector != null:
		_on_run_state_changed(RunDirector.get_state())
	_queue_layout_refresh()

func bind_character(target: Node) -> void:
	player_character = target
	if player_character == null:
		return
	last_control_summary = ""
	title_label.text = "%s %s" % [_hero_display_name(String(player_character.get_character_name())), _locale_text("Combat Frame", "战斗面板", "戰鬥面板")]
	_refresh_skill_icons()
	_connect_character_signal("hp_changed", _on_hp_changed)
	_connect_character_signal("defense_changed", _on_defense_changed)
	_connect_character_signal("inspiration_changed", _on_inspiration_changed)
	_connect_character_signal("shield_changed", _on_shield_changed)
	_connect_character_signal("took_damage", _on_took_damage)
	_connect_character_signal("control_status_changed", _on_control_status_changed)
	_connect_character_signal("attack_started", _on_attack_started)
	_connect_character_signal("attack_hit", _on_attack_hit)
	_on_hp_changed(player_character.hp, player_character.max_hp)
	_on_defense_changed(player_character.defense, player_character.max_defense)
	_on_inspiration_changed(player_character.inspiration, player_character.max_inspiration)
	_on_shield_changed(player_character.shield)
	if player_character.has_method("get_control_status_text"):
		_on_control_status_changed(player_character.get_control_status_text())
	if AccessoryManager != null:
		_on_accessory_equipped(AccessoryManager.get_equipped_accessory())
	_queue_layout_refresh()

func bind_knight(target: Node) -> void:
	bind_character(target)

func _process(_delta: float) -> void:
	if player_character == null or not is_instance_valid(player_character):
		return
	var state_name := ""
	if player_character.get("state_machine") != null:
		state_name = String(player_character.state_machine.get_state_name())
	state_label.text = "%s %s" % [_locale_text("State", "状态", "狀態"), state_name]
	_update_skill_slots()
	_update_danger_visuals()
	if RunDirector != null:
		_refresh_run_state_label(RunDirector.get_state())

func _build_ui() -> void:
	layer = 5
	root_margin = MarginContainer.new()
	root_margin.anchor_top = 1.0
	root_margin.anchor_bottom = 1.0
	root_margin.offset_left = 18.0
	root_margin.offset_top = -454.0
	root_margin.offset_right = 500.0
	root_margin.offset_bottom = -18.0
	root_margin.add_theme_constant_override("margin_left", 10)
	root_margin.add_theme_constant_override("margin_top", 10)
	root_margin.add_theme_constant_override("margin_right", 10)
	root_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(root_margin)

	root_panel = PanelContainer.new()
	root_panel.add_theme_stylebox_override("panel", UISkin.panel_style())
	root_margin.add_child(root_panel)

	inner_margin = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 12)
	inner_margin.add_theme_constant_override("margin_top", 12)
	inner_margin.add_theme_constant_override("margin_right", 12)
	inner_margin.add_theme_constant_override("margin_bottom", 12)
	root_panel.add_child(inner_margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	inner_margin.add_child(content)

	title_label = Label.new()
	title_label.text = _locale_text("Character Combat Frame", "角色战斗面板", "角色戰鬥面板")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_label, 20, Color(0.98, 0.90, 0.66))
	content.add_child(title_label)

	var vitals_panel := PanelContainer.new()
	vitals_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(vitals_panel)

	var vitals_margin := MarginContainer.new()
	vitals_margin.add_theme_constant_override("margin_left", 10)
	vitals_margin.add_theme_constant_override("margin_top", 10)
	vitals_margin.add_theme_constant_override("margin_right", 10)
	vitals_margin.add_theme_constant_override("margin_bottom", 10)
	vitals_panel.add_child(vitals_margin)

	var vitals_column := VBoxContainer.new()
	vitals_column.add_theme_constant_override("separation", 6)
	vitals_margin.add_child(vitals_column)

	vitals_header_label = _section_label(_locale_text("Vitals", "生命面板", "生命面板"))
	vitals_column.add_child(vitals_header_label)
	vitals_column.add_child(_meter("hp", _locale_text("HP", "生命", "生命"), Color(0.82, 0.22, 0.20)))
	vitals_column.add_child(_meter("defense", _locale_text("Defense", "护甲", "護甲"), Color(0.34, 0.68, 0.82)))
	vitals_column.add_child(_meter("inspiration", _locale_text("Inspiration", "灵感", "靈感"), Color(0.30, 0.52, 0.95)))

	status_grid = GridContainer.new()
	status_grid.columns = 2
	status_grid.add_theme_constant_override("h_separation", 10)
	status_grid.add_theme_constant_override("v_separation", 4)
	vitals_column.add_child(status_grid)

	shield_label = _make_label(_locale_text("Shield 0", "护盾 0", "護盾 0"), 13, Color(0.82, 0.90, 0.98))
	state_label = _make_label(_locale_text("State Idle", "状态 Idle", "狀態 Idle"), 13, Color(0.82, 0.90, 0.98))
	level_label = _make_label(_locale_text("Level 1", "等级 1", "等級 1"), 13, Color(0.94, 0.88, 0.68))
	xp_label = _make_label(_locale_text("XP 0 / 45", "经验 0 / 45", "經驗 0 / 45"), 13, Color(0.74, 0.88, 1.0))
	shield_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_grid.add_child(shield_label)
	status_grid.add_child(state_label)
	status_grid.add_child(level_label)
	status_grid.add_child(xp_label)

	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(status_panel)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 10)
	status_margin.add_theme_constant_override("margin_top", 10)
	status_margin.add_theme_constant_override("margin_right", 10)
	status_margin.add_theme_constant_override("margin_bottom", 10)
	status_panel.add_child(status_margin)

	var status_column := VBoxContainer.new()
	status_column.add_theme_constant_override("separation", 6)
	status_margin.add_child(status_column)

	status_header_label = _section_label(_locale_text("Combat Readout", "战斗读数", "戰鬥讀數"))
	status_column.add_child(status_header_label)

	control_label = _make_label(_locale_text("Status Stable", "状态 稳定", "狀態 穩定"), 12, Color(0.72, 0.88, 1.0))
	control_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_column.add_child(control_label)

	combat_feed_label = _make_label(_locale_text("Combat feed ready.", "战斗播报已就绪。", "戰鬥播報已就緒。"), 12, Color(0.90, 0.94, 1.0))
	combat_feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_feed_label.custom_minimum_size.y = 28.0
	status_column.add_child(combat_feed_label)

	var skills_panel := PanelContainer.new()
	skills_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(skills_panel)

	var skills_margin := MarginContainer.new()
	skills_margin.add_theme_constant_override("margin_left", 10)
	skills_margin.add_theme_constant_override("margin_top", 10)
	skills_margin.add_theme_constant_override("margin_right", 10)
	skills_margin.add_theme_constant_override("margin_bottom", 10)
	skills_panel.add_child(skills_margin)

	var skills_column := VBoxContainer.new()
	skills_column.add_theme_constant_override("separation", 8)
	skills_margin.add_child(skills_column)

	skills_header_label = _section_label(_locale_text("Skill Deck", "技能列", "技能列"))
	skills_column.add_child(skills_header_label)

	skill_grid = GridContainer.new()
	skill_grid.columns = 4
	skill_grid.add_theme_constant_override("h_separation", 8)
	skill_grid.add_theme_constant_override("v_separation", 8)
	skills_column.add_child(skill_grid)
	for key in ["attack", "skill1", "skill2", "skill3"]:
		var label_text := "J" if key == "attack" else ("K" if key == "skill1" else ("L" if key == "skill2" else "I"))
		var icon_path := "res://assets/ui/icon/stat_attack_pixel.png"
		if key != "attack":
			icon_path = "res://assets/ui/icon/ui_unknown.png"
		var slot_data := _skill_slot(key, label_text, icon_path)
		skill_slots[key] = slot_data
		skill_grid.add_child(slot_data["root"])

	accessory_panel_root = PanelContainer.new()
	accessory_panel_root.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(accessory_panel_root)

	var accessory_margin := MarginContainer.new()
	accessory_margin.add_theme_constant_override("margin_left", 10)
	accessory_margin.add_theme_constant_override("margin_top", 10)
	accessory_margin.add_theme_constant_override("margin_right", 10)
	accessory_margin.add_theme_constant_override("margin_bottom", 10)
	accessory_panel_root.add_child(accessory_margin)

	var accessory_column := VBoxContainer.new()
	accessory_column.add_theme_constant_override("separation", 8)
	accessory_margin.add_child(accessory_column)

	accessory_header_label = _section_label(_locale_text("Equipped Relic", "当前饰品", "當前飾品"))
	accessory_column.add_child(accessory_header_label)

	accessory_grid = GridContainer.new()
	accessory_grid.columns = 2
	accessory_grid.add_theme_constant_override("h_separation", 10)
	accessory_grid.add_theme_constant_override("v_separation", 8)
	accessory_column.add_child(accessory_grid)

	var slot := PanelContainer.new()
	slot.name = "AccessorySlot"
	slot.custom_minimum_size = Vector2(64, 64)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	accessory_grid.add_child(slot)

	accessory_icon = TextureRect.new()
	accessory_icon.custom_minimum_size = Vector2(52, 52)
	accessory_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	accessory_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(accessory_icon)

	var accessory_text := VBoxContainer.new()
	accessory_text.name = "AccessoryText"
	accessory_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accessory_text.add_theme_constant_override("separation", 4)
	accessory_grid.add_child(accessory_text)

	accessory_name_label = _make_label(_locale_text("No Accessory", "无饰品", "無飾品"), 15, Color.WHITE)
	accessory_tags_label = _make_label(_locale_text("Route tags: None", "路线标签：无", "路線標籤：無"), 11, Color(0.88, 0.84, 0.66))
	accessory_summary_label = _make_label(_locale_text("Win encounters to claim relics.", "通过战斗获得饰品。", "通過戰鬥獲得飾品。"), 12, Color(0.72, 0.78, 0.86))
	accessory_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accessory_text.add_child(accessory_name_label)
	accessory_text.add_child(accessory_tags_label)
	accessory_text.add_child(accessory_summary_label)

	run_panel_root = PanelContainer.new()
	run_panel_root.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	content.add_child(run_panel_root)

	var run_margin := MarginContainer.new()
	run_margin.add_theme_constant_override("margin_left", 10)
	run_margin.add_theme_constant_override("margin_top", 10)
	run_margin.add_theme_constant_override("margin_right", 10)
	run_margin.add_theme_constant_override("margin_bottom", 10)
	run_panel_root.add_child(run_margin)

	var run_column := VBoxContainer.new()
	run_column.add_theme_constant_override("separation", 8)
	run_margin.add_child(run_column)

	run_header_label = _section_label(_locale_text("Route Snapshot", "路线快照", "路線快照"))
	run_column.add_child(run_header_label)

	run_metric_grid = GridContainer.new()
	run_metric_grid.columns = 2
	run_metric_grid.add_theme_constant_override("h_separation", 8)
	run_metric_grid.add_theme_constant_override("v_separation", 8)
	run_column.add_child(run_metric_grid)

	_add_run_metric("gold", _locale_text("Gold", "金币", "金幣"))
	_add_run_metric("next", _locale_text("Next", "下一步", "下一步"))
	_add_run_metric("bounty", _locale_text("Bounty", "赏金", "賞金"))
	_add_run_metric("prep", _locale_text("Prep", "备战", "備戰"))

	run_state_label = _make_label(_locale_text("Gold 0 | Next Black Market", "金币 0 | 下一步 黑市", "金幣 0 | 下一步 黑市"), 12, Color(0.84, 0.90, 0.98))
	run_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	run_column.add_child(run_state_label)

func _section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	UISkin.label(label, 12, UISkin.COLOR_ACCENT)
	return label

func _add_run_metric(metric_id: String, caption: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UISkin.choice_panel_style())
	run_metric_grid.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)

	var caption_label := Label.new()
	caption_label.text = caption
	UISkin.label(caption_label, 10, Color(0.82, 0.88, 0.96))
	column.add_child(caption_label)

	var value_label := Label.new()
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(value_label, 12, Color.WHITE)
	column.add_child(value_label)

	run_metric_labels[metric_id] = {
		"caption": caption_label,
		"value": value_label
	}

func _meter(meter_id: String, label_text: String, _fill_color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var label := _make_label("%s 0 / 0" % label_text, 13, Color(0.86, 0.88, 0.92))
	box.add_child(label)
	var bar := TextureProgressBar.new()
	var bar_height := 20.0
	if meter_id == "hp":
		bar_height = 28.0
	elif meter_id == "defense":
		bar_height = 22.0
	bar.custom_minimum_size = Vector2(386, bar_height)
	UISkin.texture_bar(bar, meter_id)
	meter_bars.append(bar)
	box.add_child(bar)
	match meter_id:
		"hp":
			hp_bar = bar
			hp_label = label
		"defense":
			defense_bar = bar
			defense_label = label
		"inspiration":
			inspiration_bar = bar
			inspiration_label = label
	return box

func _skill_slot(key: String, hotkey: String, icon_path: String) -> Dictionary:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(84, 78)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_stylebox_override("panel", UISkin.choice_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(icon)

	var label := Label.new()
	label.text = _skill_ready_text(hotkey)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(label, 11, Color(0.86, 0.88, 0.92))
	stack.add_child(label)

	return {"root": root, "icon": icon, "label": label, "hotkey": hotkey, "key": key}

func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	UISkin.label(label, size, color)
	return label

func _connect_character_signal(signal_name: String, callable: Callable) -> void:
	if not player_character.has_signal(signal_name):
		return
	if not player_character.is_connected(StringName(signal_name), callable):
		player_character.connect(StringName(signal_name), callable)

func _on_hp_changed(current_hp: float, max_hp_value: float) -> void:
	hp_bar.value = 0.0 if max_hp_value <= 0.0 else clampf(current_hp / max_hp_value, 0.0, 1.0)
	var hp_percent := 0 if max_hp_value <= 0.0 else int(round(clampf(current_hp / max_hp_value, 0.0, 1.0) * 100.0))
	hp_label.text = "%s %d / %d  |  %d%%" % [_locale_text("HP", "生命", "生命"), int(round(current_hp)), int(round(max_hp_value)), hp_percent]

func _on_inspiration_changed(current_inspiration: float, max_inspiration_value: float) -> void:
	inspiration_bar.value = 0.0 if max_inspiration_value <= 0.0 else clampf(current_inspiration / max_inspiration_value, 0.0, 1.0)
	var inspiration_percent := 0 if max_inspiration_value <= 0.0 else int(round(clampf(current_inspiration / max_inspiration_value, 0.0, 1.0) * 100.0))
	inspiration_label.text = "%s %d / %d  |  %d%%" % [_locale_text("Inspiration", "灵感", "靈感"), int(round(current_inspiration)), int(round(max_inspiration_value)), inspiration_percent]

func _on_defense_changed(current_defense: float, max_defense_value: float) -> void:
	defense_bar.value = 0.0 if max_defense_value <= 0.0 else clampf(current_defense / max_defense_value, 0.0, 1.0)
	var defense_percent := 0 if max_defense_value <= 0.0 else int(round(clampf(current_defense / max_defense_value, 0.0, 1.0) * 100.0))
	defense_label.text = "%s %d / %d  |  %d%%" % [_locale_text("Defense", "护甲", "護甲"), int(round(current_defense)), int(round(max_defense_value)), defense_percent]

func _on_shield_changed(current_shield: float) -> void:
	shield_label.text = "%s %d" % [_locale_text("Shield", "护盾", "護盾"), int(round(current_shield))]

func _on_took_damage(amount: float, remaining_hp: float) -> void:
	if player_character != null and is_instance_valid(player_character):
		_on_shield_changed(player_character.shield)
	var max_hp_value := float(player_character.max_hp) if player_character != null and is_instance_valid(player_character) else 0.0
	var hp_ratio := 0.0 if max_hp_value <= 0.0 else clampf(remaining_hp / max_hp_value, 0.0, 1.0)
	if amount > 0.0:
		if hp_ratio <= 0.25:
			_set_combat_feed(_locale_text("Danger %.0f HP", "危险血线 %.0f", "危險血線 %.0f") % remaining_hp, Color(1.0, 0.72, 0.68), 1.06)
		else:
			_set_combat_feed(_locale_text("Took %.0f damage", "受到 %.0f 伤害", "受到 %.0f 傷害") % amount, Color(1.0, 0.84, 0.76), 1.04)

func _on_control_status_changed(summary: String) -> void:
	if control_label == null:
		return
	if summary.is_empty():
		control_label.text = "%s %s" % [_locale_text("Status", "状态", "狀態"), _locale_text("Stable", "稳定", "穩定")]
		control_label.modulate = Color(0.72, 0.88, 1.0)
		if not last_control_summary.is_empty():
			_set_combat_feed(_locale_text("Steady again", "状态重新稳定", "狀態重新穩定"), Color(0.98, 0.90, 0.68), 1.05)
		last_control_summary = ""
		return
	control_label.text = "%s %s" % [_locale_text("Status", "状态", "狀態"), summary]
	control_label.modulate = Color(1.0, 0.84, 0.64)
	if summary != last_control_summary:
		_set_combat_feed(summary, Color(0.90, 0.82, 1.0), 1.04)
	last_control_summary = summary

func _on_attack_started(attack_name: StringName) -> void:
	if attack_name == &"attack":
		return
	_set_combat_feed(_locale_text("%s ready", "%s 就绪", "%s 就緒") % _attack_display_name(attack_name), Color(0.84, 0.90, 1.0), 1.04)

func _on_attack_hit(attack_name: StringName, target: Node) -> void:
	var action_label := _attack_display_name(attack_name)
	var target_defeated := _is_target_defeated(target)
	if target_defeated:
		_set_combat_feed(_locale_text("%s finished the target", "%s 完成收割", "%s 完成收割") % action_label, Color(1.0, 0.86, 0.66), 1.08)
	elif attack_name == &"attack":
		_set_combat_feed(_locale_text("Hit confirmed", "命中确认", "命中確認"), Color(0.86, 0.96, 1.0), 1.03)
	else:
		_set_combat_feed(_locale_text("%s landed", "%s 命中", "%s 命中") % action_label, Color(0.88, 1.0, 0.82), 1.05)

func _on_accessory_equipped(accessory: Dictionary) -> void:
	if accessory_icon == null:
		return
	accessory_icon.texture = load(String(accessory.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
	accessory_name_label.text = String(accessory.get("name", _locale_text("No Accessory", "无饰品", "無飾品")))
	var tags_text := _localized_tag_list(accessory.get("tags", []))
	accessory_tags_label.text = "%s %s" % [
		_locale_text("Route tags:", "路线标签：", "路線標籤："),
		tags_text if not tags_text.is_empty() else _locale_text("None", "无", "無")
	]
	var summary_parts: Array[String] = []
	var summary_text := String(accessory.get("summary", ""))
	if not summary_text.is_empty():
		summary_parts.append(summary_text)
	var route_hint := _accessory_route_hint(accessory.get("tags", []))
	if not route_hint.is_empty():
		summary_parts.append(route_hint)
	if summary_parts.is_empty():
		summary_parts.append(_locale_text("Win encounters to claim relics.", "通过战斗获得饰品。", "通過戰鬥獲得飾品。"))
	accessory_summary_label.text = "\n".join(summary_parts)

func _on_run_state_changed(state: Dictionary) -> void:
	if run_state_label == null:
		return
	_refresh_run_state_label(state)

func _refresh_run_state_label(state: Dictionary) -> void:
	if run_state_label == null:
		return
	var next_kind := String(state.get("next_event_kind", ""))
	var next_label := RunDirector.describe_event_kind(next_kind) if RunDirector != null and not next_kind.is_empty() else _locale_text("Victory", "胜利结算", "勝利結算")
	var reward_flat_bonus := int(state.get("reward_flat_bonus", 0))
	var reward_multiplier := float(state.get("reward_multiplier", 1.0))
	var pending_prep := state.get("pending_encounter_prep", {}) as Dictionary
	var hero_level := int(state.get("hero_level", 1))
	var hero_xp := int(state.get("hero_xp", 0))
	var hero_xp_to_next := int(state.get("hero_xp_to_next", 45))
	var total_kills := int(state.get("total_kills", 0))
	var bounty_text := _locale_text("None", "无", "無")
	if reward_flat_bonus > 0 or reward_multiplier > 1.001:
		var parts: Array[String] = []
		if reward_flat_bonus > 0:
			parts.append(_locale_text("+%d gold", "+%d 金币", "+%d 金幣") % reward_flat_bonus)
		if reward_multiplier > 1.001:
			parts.append(_locale_text("x%.2f reward", "x%.2f 奖励", "x%.2f 獎勵") % reward_multiplier)
		bounty_text = " / ".join(parts)
	var current_scene := get_tree().current_scene
	var prep_text := _prep_run_text(current_scene, pending_prep)
	var prep_display := _locale_text("Ready", "待定", "待定") if prep_text.is_empty() else prep_text.replace("  |  ", "")
	_set_run_metric_value("gold", str(int(state.get("gold", 0))))
	_set_run_metric_value("next", next_label)
	_set_run_metric_value("bounty", bounty_text)
	_set_run_metric_value("prep", prep_display)
	var route_preview := RunDirector.describe_event_route(3) if RunDirector != null else _locale_text("No route data", "暂无路线数据", "暫無路線資料")
	run_state_label.text = "%s %d  |  %s %d/%d  |  %s %d  |  %s %s%s" % [
		_locale_text("Level", "等级", "等級"),
		hero_level,
		_locale_text("XP", "经验", "經驗"),
		hero_xp,
		hero_xp_to_next,
		_locale_text("Kills", "击杀", "擊殺"),
		total_kills,
		_locale_text("Route", "路线", "路線"),
		route_preview,
		prep_text
	]
	if level_label != null:
		level_label.text = "%s %d  |  %s %d" % [_locale_text("Level", "等级", "等級"), hero_level, _locale_text("Kills", "击杀", "擊殺"), total_kills]
	if xp_label != null:
		xp_label.text = "%s %d / %d" % [_locale_text("XP", "经验", "經驗"), hero_xp, hero_xp_to_next]

func _set_run_metric_value(metric_id: String, value: String) -> void:
	if not run_metric_labels.has(metric_id):
		return
	var slot := run_metric_labels[metric_id] as Dictionary
	var label := slot.get("value") as Label
	if label != null:
		label.text = value

func _on_locale_changed(_locale: String) -> void:
	vitals_header_label.text = _locale_text("Vitals", "生命面板", "生命面板")
	status_header_label.text = _locale_text("Combat Readout", "战斗读数", "戰鬥讀數")
	skills_header_label.text = _locale_text("Skill Deck", "技能列", "技能列")
	accessory_header_label.text = _locale_text("Equipped Relic", "当前饰品", "當前飾品")
	run_header_label.text = _locale_text("Route Snapshot", "路线快照", "路線快照")
	if run_metric_labels.has("gold"):
		((run_metric_labels["gold"] as Dictionary).get("caption") as Label).text = _locale_text("Gold", "金币", "金幣")
	if run_metric_labels.has("next"):
		((run_metric_labels["next"] as Dictionary).get("caption") as Label).text = _locale_text("Next", "下一步", "下一步")
	if run_metric_labels.has("bounty"):
		((run_metric_labels["bounty"] as Dictionary).get("caption") as Label).text = _locale_text("Bounty", "赏金", "賞金")
	if run_metric_labels.has("prep"):
		((run_metric_labels["prep"] as Dictionary).get("caption") as Label).text = _locale_text("Prep", "备战", "備戰")
	if player_character != null and is_instance_valid(player_character):
		title_label.text = "%s %s" % [_hero_display_name(String(player_character.get_character_name())), _locale_text("Combat Frame", "战斗面板", "戰鬥面板")]
		_on_hp_changed(player_character.hp, player_character.max_hp)
		_on_defense_changed(player_character.defense, player_character.max_defense)
		_on_inspiration_changed(player_character.inspiration, player_character.max_inspiration)
		_on_shield_changed(player_character.shield)
	if AccessoryManager != null:
		_on_accessory_equipped(AccessoryManager.get_equipped_accessory())
	if RunDirector != null:
		_refresh_run_state_label(RunDirector.get_state())

func _refresh_skill_icons() -> void:
	if player_character == null or not is_instance_valid(player_character):
		return
	var character_name := String(player_character.get_character_name())
	var icons: Array = skill_icon_paths.get(character_name, [])
	for index in range(icons.size()):
		var slot_key := "skill%d" % (index + 1)
		if not skill_slots.has(slot_key):
			continue
		var slot: Dictionary = skill_slots[slot_key] as Dictionary
		var icon: TextureRect = slot.get("icon") as TextureRect
		if icon != null:
			icon.texture = load(String(icons[index])) as Texture2D

func _update_skill_slots() -> void:
	if player_character == null or not is_instance_valid(player_character):
		return
	for key in skill_slots.keys():
		var slot: Dictionary = skill_slots[key] as Dictionary
		var label: Label = slot.get("label") as Label
		var cooldown := float(player_character.cooldowns.get(key, 0.0))
		if cooldown <= 0.05:
			label.text = _skill_ready_text(String(slot.get("hotkey", "")))
			label.modulate = Color(0.78, 1.0, 0.78)
		else:
			label.text = "%s %.1f" % [String(slot.get("hotkey", "")), cooldown]
			label.modulate = Color(1.0, 0.80, 0.62)

func _prep_run_text(current_scene: Node, pending_prep: Dictionary) -> String:
	var active_prep: Dictionary = {}
	if current_scene != null:
		active_prep = current_scene.get("active_encounter_prep") as Dictionary
	if not active_prep.is_empty():
		return _locale_text("  |  Prep %s", "  |  备战 %s", "  |  備戰 %s") % RunEffects.prep_title(active_prep)
	if not pending_prep.is_empty():
		return _locale_text("  |  Prep %s", "  |  备战 %s", "  |  備戰 %s") % RunEffects.prep_title(pending_prep)
	return ""

func _update_danger_visuals() -> void:
	if player_character == null or not is_instance_valid(player_character):
		return
	var max_hp_value := float(player_character.max_hp)
	var max_defense_value := float(player_character.max_defense)
	var max_inspiration_value := float(player_character.max_inspiration)
	var hp_ratio := 0.0 if max_hp_value <= 0.0 else clampf(float(player_character.hp) / max_hp_value, 0.0, 1.0)
	var defense_ratio := 0.0 if max_defense_value <= 0.0 else clampf(float(player_character.defense) / max_defense_value, 0.0, 1.0)
	var inspiration_ratio := 0.0 if max_inspiration_value <= 0.0 else clampf(float(player_character.inspiration) / max_inspiration_value, 0.0, 1.0)
	if hp_ratio <= 0.30:
		var pulse := 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.01)
		hp_label.modulate = Color(1.0, 0.70 + 0.12 * pulse, 0.70 + 0.10 * pulse, 1.0)
		hp_bar.modulate = Color(1.0, 0.92, 0.92, 0.92 + 0.08 * pulse)
	else:
		hp_label.modulate = Color.WHITE
		hp_bar.modulate = Color.WHITE
	if defense_ratio <= 0.22:
		var defense_pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.012 + 0.7)
		defense_label.modulate = Color(0.74 + 0.18 * defense_pulse, 0.92, 1.0, 1.0)
		defense_bar.modulate = Color(0.90, 0.98, 1.0, 0.90 + 0.10 * defense_pulse)
	else:
		defense_label.modulate = Color.WHITE
		defense_bar.modulate = Color.WHITE
	if inspiration_ratio >= 0.95:
		var inspiration_pulse := 0.86 + 0.14 * sin(Time.get_ticks_msec() * 0.011 + 1.5)
		inspiration_label.modulate = Color(0.90, 0.96, 1.0, 1.0)
		inspiration_bar.modulate = Color(1.0, 1.0, 1.0, 0.92 + 0.08 * inspiration_pulse)
	else:
		inspiration_label.modulate = Color.WHITE
		inspiration_bar.modulate = Color.WHITE

func _set_combat_feed(text: String, color_value: Color, scale_value: float = 1.0) -> void:
	if combat_feed_label == null:
		return
	combat_feed_label.text = text
	combat_feed_label.modulate = color_value
	combat_feed_label.scale = Vector2.ONE * scale_value
	if combat_feed_tween != null:
		combat_feed_tween.kill()
	combat_feed_tween = create_tween()
	combat_feed_tween.tween_property(combat_feed_label, "scale", Vector2.ONE, 0.16)

func push_feed_message(text: String, color_value: Color = Color.WHITE, scale_value: float = 1.0) -> void:
	_set_combat_feed(text, color_value, scale_value)

func _attack_display_name(attack_name: StringName) -> String:
	var character_name := String(player_character.get_character_name()) if player_character != null and is_instance_valid(player_character) and player_character.has_method("get_character_name") else ""
	match character_name:
		"Knight":
			match attack_name:
				&"skill1":
					return _locale_text("Charge Slash", "冲锋斩", "衝鋒斬")
				&"skill2":
					return _locale_text("Counter Shock", "反震斩", "反震斬")
				&"skill3":
					return _locale_text("Holy Field", "圣域", "聖域")
		"Ranger":
			match attack_name:
				&"skill1":
					return _locale_text("Piercing Arrow", "穿刺箭", "穿刺箭")
				&"skill2":
					return _locale_text("Shadow Step", "影步", "影步")
				&"skill3":
					return _locale_text("Hunt Rush", "猎袭", "獵襲")
		"Mage":
			match attack_name:
				&"skill1":
					return _locale_text("Arcane Blades", "奥术刃群", "奧術刃群")
				&"skill2":
					return _locale_text("Arcane Burst", "奥术爆发", "奧術爆發")
				&"skill3":
					return _locale_text("Silence Decree", "沉默敕令", "沉默敕令")
	match attack_name:
		&"attack":
			return _locale_text("Attack", "普攻", "普攻")
		&"skill1_bonus":
			return _locale_text("Blade Echo", "刃响回声", "刃響回聲")
		_:
			return String(attack_name).capitalize()

func _skill_ready_text(hotkey: String) -> String:
	return _locale_text("%s Ready", "%s 就绪", "%s 就緒") % hotkey

func _is_target_defeated(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	for property in target.get_property_list():
		if String(property.get("name", "")) == "hp":
			return float(target.get("hp")) <= 0.0
	return false

func _localized_tag_list(tags_raw: Array) -> String:
	var parts: Array[String] = []
	for raw_tag in tags_raw:
		var tag := String(raw_tag)
		var localized: Dictionary = TAG_LABELS.get(tag, {}) as Dictionary
		if localized.is_empty():
			continue
		parts.append(String(localized.get(_current_locale(), localized.get("en", tag.capitalize()))))
	return ", ".join(parts)

func _accessory_route_hint(tags_raw: Array) -> String:
	if tags_raw.has("survival") or tags_raw.has("defense"):
		return _locale_text(
			"Better when you need a steadier route before the next boss check.",
			"更适合在下一次首领检定前，把路线先稳住。",
			"更適合在下一次首領檢定前，把路線先穩住。"
		)
	if tags_raw.has("crit") or tags_raw.has("damage"):
		return _locale_text(
			"Pushes the run toward sharper burst windows and cleaner finishes.",
			"会把整局往更尖锐的爆发窗口和收割节奏上推。",
			"會把整局往更尖銳的爆發窗口和收割節奏上推。"
		)
	if tags_raw.has("skill") or tags_raw.has("resource"):
		return _locale_text(
			"Supports builds that want to cycle skills constantly and keep tempo rolling.",
			"适合想把技能循环一直转起来、靠节奏压制的构筑。",
			"適合想把技能循環一直轉起來、靠節奏壓制的構築。"
		)
	return _locale_text(
		"Flexible enough to support pivots without fully breaking your route.",
		"属于不太会打断路线，也适合中途转向的通用型补强。",
		"屬於不太會打斷路線，也適合中途轉向的通用型補強。"
	)

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

func _hero_display_name(hero_name: String) -> String:
	match hero_name:
		"Knight":
			return _locale_text("Knight", "骑士", "騎士")
		"Ranger":
			return _locale_text("Ranger", "游侠", "遊俠")
		"Mage":
			return _locale_text("Mage", "法师", "法師")
		_:
			return hero_name

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if root_margin == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact: bool = viewport_size.x < 980.0 or viewport_size.y < 720.0
	var very_compact: bool = viewport_size.x < 780.0 or viewport_size.y < 620.0
	var panel_width := clampf(viewport_size.x * (0.36 if very_compact else 0.30), 304.0, 500.0)
	root_margin.offset_right = panel_width
	root_margin.offset_top = -clampf(viewport_size.y * (1.0 if very_compact else 0.97), 540.0 if very_compact else 540.0, 760.0)
	root_margin.offset_left = 10.0 if very_compact else 18.0
	root_margin.offset_bottom = -10.0 if very_compact else -18.0
	root_margin.add_theme_constant_override("margin_left", 8 if very_compact else 10)
	root_margin.add_theme_constant_override("margin_top", 8 if very_compact else 10)
	root_margin.add_theme_constant_override("margin_right", 8 if very_compact else 10)
	root_margin.add_theme_constant_override("margin_bottom", 8 if very_compact else 10)
	inner_margin.add_theme_constant_override("margin_left", 10 if very_compact else 12)
	inner_margin.add_theme_constant_override("margin_top", 10 if very_compact else 12)
	inner_margin.add_theme_constant_override("margin_right", 10 if very_compact else 12)
	inner_margin.add_theme_constant_override("margin_bottom", 10 if very_compact else 12)
	content.add_theme_constant_override("separation", 4 if very_compact else (6 if compact else 8))
	status_grid.columns = 2
	skill_grid.columns = 4 if panel_width >= 300.0 else (2 if very_compact else 4)
	skill_grid.add_theme_constant_override("h_separation", 6 if compact else 8)
	skill_grid.add_theme_constant_override("v_separation", 6 if compact else 8)
	accessory_grid.columns = 2 if panel_width >= 300.0 else 1
	accessory_grid.add_theme_constant_override("h_separation", 8 if compact else 10)
	accessory_grid.add_theme_constant_override("v_separation", 6 if compact else 8)
	run_metric_grid.columns = 2
	run_metric_grid.visible = not very_compact
	if run_panel_root != null:
		run_panel_root.visible = not very_compact
	if accessory_panel_root != null:
		accessory_panel_root.visible = not very_compact
	accessory_summary_label.max_lines_visible = 1 if very_compact else 3
	combat_feed_label.max_lines_visible = 2 if very_compact else 3
	run_state_label.max_lines_visible = 2 if very_compact else 3
	UISkin.label(title_label, 16 if very_compact else (18 if compact else 20), Color(0.98, 0.90, 0.66))
	for header in [vitals_header_label, status_header_label, skills_header_label, accessory_header_label, run_header_label]:
		UISkin.label(header, 11 if compact else 12, UISkin.COLOR_ACCENT)
	UISkin.label(hp_label, 11 if compact else 13, Color(0.86, 0.88, 0.92))
	UISkin.label(defense_label, 11 if compact else 13, Color(0.86, 0.88, 0.92))
	UISkin.label(inspiration_label, 11 if compact else 13, Color(0.86, 0.88, 0.92))
	UISkin.label(shield_label, 11 if compact else 13, Color(0.82, 0.90, 0.98))
	UISkin.label(state_label, 11 if compact else 13, Color(0.82, 0.90, 0.98))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if very_compact else HORIZONTAL_ALIGNMENT_RIGHT
	UISkin.label(control_label, 10 if compact else 12, Color(0.72, 0.88, 1.0))
	UISkin.label(combat_feed_label, 10 if compact else 12, Color(0.90, 0.94, 1.0))
	UISkin.label(accessory_name_label, 13 if compact else 15, Color.WHITE)
	UISkin.label(accessory_tags_label, 10 if compact else 11, Color(0.88, 0.84, 0.66))
	UISkin.label(accessory_summary_label, 10 if compact else 12, Color(0.72, 0.78, 0.86))
	UISkin.label(run_state_label, 10 if compact else 12, Color(0.84, 0.90, 0.98))
	for bar in meter_bars:
		bar.custom_minimum_size = Vector2(panel_width - (56.0 if very_compact else 78.0), 18.0 if compact else 22.0)
	var slot_width := 60.0 if very_compact else (72.0 if compact else 84.0)
	var slot_height := 64.0 if very_compact else (72.0 if compact else 78.0)
	for slot_data in skill_slots.values():
		var slot_dict: Dictionary = slot_data as Dictionary
		var root := slot_dict.get("root") as PanelContainer
		var icon := slot_dict.get("icon") as TextureRect
		var label := slot_dict.get("label") as Label
		if root != null:
			root.custom_minimum_size = Vector2(slot_width, slot_height)
		if icon != null:
			icon.custom_minimum_size = Vector2(34.0 if very_compact else 40.0, 34.0 if very_compact else 40.0)
		if label != null:
			UISkin.label(label, 9 if very_compact else 11, Color(0.86, 0.88, 0.92))
	for metric_id in run_metric_labels.keys():
		var metric_slot: Dictionary = run_metric_labels[metric_id] as Dictionary
		var caption_label := metric_slot.get("caption") as Label
		var value_label := metric_slot.get("value") as Label
		if caption_label != null:
			UISkin.label(caption_label, 9 if very_compact else 10, Color(0.82, 0.88, 0.96))
		if value_label != null:
			UISkin.label(value_label, 10 if very_compact else 12, Color.WHITE)
	var accessory_slot := accessory_grid.get_node("AccessorySlot") as PanelContainer
	if accessory_slot != null:
		accessory_slot.custom_minimum_size = Vector2(56.0 if compact else 64.0, 56.0 if compact else 64.0)
	accessory_icon.custom_minimum_size = Vector2(44.0 if compact else 52.0, 44.0 if compact else 52.0)
