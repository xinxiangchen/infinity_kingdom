extends CanvasLayer

signal character_selected(character_id: StringName)
signal audio_requested
signal settings_requested
signal quit_requested

const UICardFx := preload("res://ui/ui_card_fx.gd")
const UISkin := preload("res://ui/ui_skin.gd")

const HEROES := [
	{
		"id": &"knight",
		"portrait": "res://assets/heroes/knight.png",
		"name": {
			"en": "Knight",
			"zh_Hans": "骑士",
			"zh_Hant": "騎士"
		},
		"role": {
			"en": "Frontline",
			"zh_Hans": "前线",
			"zh_Hant": "前線"
		},
		"stats": {
			"en": ["HP", "Armor", "Melee"],
			"zh_Hans": ["生命", "护甲", "近战"],
			"zh_Hant": ["生命", "護甲", "近戰"]
		},
		"summary": {
			"en": "Stable opener, heavy sustain, slower reposition.",
			"zh_Hans": "最稳的开局角色，正面换血强，但转位节奏偏慢。",
			"zh_Hant": "最穩的開局角色，正面換血強，但轉位節奏偏慢。"
		},
		"signature": {
			"en": "Best when you anchor space, absorb pressure, and win long trades.",
			"zh_Hans": "适合顶住前线、吃下压力，再靠长线换血把局势拖稳。",
			"zh_Hant": "適合頂住前線、吃下壓力，再靠長線換血把局勢拖穩。"
		},
		"route": {
			"en": "Pairs cleanly with defense, survival, and heavy skill relic routes.",
			"zh_Hans": "和防御、生存、技能型饰品路线最容易成型。",
			"zh_Hant": "和防禦、生存、技能型飾品路線最容易成型。"
		}
	},
	{
		"id": &"ranger",
		"portrait": "res://assets/heroes/ranger.png",
		"name": {
			"en": "Ranger",
			"zh_Hans": "游侠",
			"zh_Hant": "遊俠"
		},
		"role": {
			"en": "Agile",
			"zh_Hans": "灵巧",
			"zh_Hant": "靈巧"
		},
		"stats": {
			"en": ["Crit", "Speed", "Burst"],
			"zh_Hans": ["暴击", "速度", "爆发"],
			"zh_Hant": ["暴擊", "速度", "爆發"]
		},
		"summary": {
			"en": "Fast picks, high tempo, lower fault tolerance.",
			"zh_Hans": "点杀速度最快，节奏很高，但失误容错最低。",
			"zh_Hant": "點殺速度最快，節奏很高，但失誤容錯最低。"
		},
		"signature": {
			"en": "Excels when you keep moving, create angles, and finish targets early.",
			"zh_Hans": "适合不停走位、切角度、在敌人展开前先完成收割。",
			"zh_Hant": "適合不停走位、切角度、在敵人展開前先完成收割。"
		},
		"route": {
			"en": "Loves crit, speed, tempo, and burst-focused relic packages.",
			"zh_Hans": "最吃暴击、速度、节奏和爆发型饰品路线。",
			"zh_Hant": "最吃暴擊、速度、節奏和爆發型飾品路線。"
		}
	},
	{
		"id": &"mage",
		"portrait": "res://assets/heroes/mage.png",
		"name": {
			"en": "Mage",
			"zh_Hans": "法师",
			"zh_Hant": "法師"
		},
		"role": {
			"en": "Control",
			"zh_Hans": "控场",
			"zh_Hant": "控場"
		},
		"stats": {
			"en": ["Range", "Skill", "Control"],
			"zh_Hans": ["射程", "技能", "控制"],
			"zh_Hant": ["射程", "技能", "控制"]
		},
		"summary": {
			"en": "Safest spacing, strong area control, lightest body.",
			"zh_Hans": "拉扯最安全，范围控制最强，但身板最薄。",
			"zh_Hant": "拉扯最安全，範圍控制最強，但身板最薄。"
		},
		"signature": {
			"en": "Wins by shaping the arena, denying movement, and converting skill windows.",
			"zh_Hans": "擅长先把场地切开，再把技能窗口稳定换成优势。",
			"zh_Hant": "擅長先把場地切開，再把技能窗口穩定換成優勢。"
		},
		"route": {
			"en": "Builds best with skill, resource, control, and route-planning relics.",
			"zh_Hans": "最适合技能、资源、控制和规划型饰品路线。",
			"zh_Hant": "最適合技能、資源、控制和規劃型飾品路線。"
		}
	}
]

const FEATURED_ACCESSORY_IDS := [
	"ember_talisman",
	"wolf_pendant",
	"old_king_crest",
	"throne_remnant"
]

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

const EFFECT_LABELS := {
	"attack_damage_pct": {
		"en": "attack damage",
		"zh_Hans": "攻击伤害",
		"zh_Hant": "攻擊傷害"
	},
	"attack_interval_pct": {
		"en": "attack rhythm",
		"zh_Hans": "攻速节奏",
		"zh_Hant": "攻速節奏"
	},
	"crit_rate": {
		"en": "crit chance",
		"zh_Hans": "暴击率",
		"zh_Hant": "暴擊率"
	},
	"inspiration_gain_on_attack_hit": {
		"en": "inspiration on hit",
		"zh_Hans": "命中回灵感",
		"zh_Hant": "命中回靈感"
	},
	"max_defense": {
		"en": "defense cap",
		"zh_Hans": "护甲上限",
		"zh_Hant": "護甲上限"
	},
	"max_hp": {
		"en": "max hp",
		"zh_Hans": "生命上限",
		"zh_Hant": "生命上限"
	},
	"max_inspiration": {
		"en": "inspiration cap",
		"zh_Hans": "灵感上限",
		"zh_Hant": "靈感上限"
	},
	"move_speed_pct": {
		"en": "move speed",
		"zh_Hans": "移动速度",
		"zh_Hant": "移動速度"
	},
	"skill_cooldown_pct": {
		"en": "skill recovery",
		"zh_Hans": "技能回复",
		"zh_Hant": "技能回復"
	},
	"skill_cost_pct": {
		"en": "skill cost",
		"zh_Hans": "技能消耗",
		"zh_Hant": "技能消耗"
	},
	"skill_damage_pct": {
		"en": "skill damage",
		"zh_Hans": "技能伤害",
		"zh_Hant": "技能傷害"
	}
}

var panel: PanelContainer
var panel_margin: MarginContainer
var menu_left_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var background_rect: TextureRect
var title_banner_frame: PanelContainer
var title_banner_image: TextureRect
var hero_top_row: HBoxContainer
var hero_portrait_frame: PanelContainer
var hero_portrait: TextureRect
var hero_detail_title: Label
var hero_detail_role: Label
var hero_detail_desc: Label
var menu_overview_panel: PanelContainer
var menu_overview_title: Label
var menu_overview_scroll: ScrollContainer
var menu_overview_grid: GridContainer
var menu_overview_buttons: Array[Button] = []
var cards_panel: PanelContainer
var cards_grid: GridContainer
var hero_buttons: Array[Button] = []
var menu_action_buttons: Array[Button] = []
var primary_start_button: Button
var settings_button: Button
var audio_button: Button
var gallery_button: Button
var about_button: Button
var quit_button: Button
var left_hint_label: Label
var left_blurb_label: Label
var layout_size_override: Vector2 = Vector2.ZERO
var selected_hero_index: int = 0
var active_gallery_entry_id: String = "gallery_hero_knight"
var active_about_entry_id: String = "about_overview"
var detail_mode: String = "hero"
var screen_mode: String = "menu"
var menu_preview_key: StringName = &""
var disabled_family_ids: Array[String] = []

func _ready() -> void:
	_build_ui()
	if UISettings != null and UISettings.has_signal("locale_changed") and not UISettings.locale_changed.is_connected(_refresh_copy):
		UISettings.locale_changed.connect(_refresh_copy)
	_set_selected_hero(0)
	_show_menu()
	_refresh_copy()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func _build_ui() -> void:
	layer = 10

	background_rect = TextureRect.new()
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_rect.texture = load("res://assets/ui/background/title_screen_bg.png") as Texture2D
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_rect.modulate = Color(1.0, 1.0, 1.0, 0.96)
	add_child(background_rect)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.03, 0.04, 0.05, 0.46)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	panel.name = "CharacterSelectPanel"
	panel.custom_minimum_size = Vector2(1180, 690)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	center.add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 28)
	panel_margin.add_theme_constant_override("margin_top", 24)
	panel_margin.add_theme_constant_override("margin_right", 28)
	panel_margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(panel_margin)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 18)
	panel_margin.add_child(root_column)

	title_banner_frame = PanelContainer.new()
	title_banner_frame.name = "TitleBannerFrame"
	title_banner_frame.custom_minimum_size = Vector2(0, 164)
	title_banner_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_banner_frame.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	root_column.add_child(title_banner_frame)

	title_banner_image = TextureRect.new()
	title_banner_image.name = "TitleBannerImage"
	title_banner_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_banner_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_banner_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_banner_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title_banner_image.texture = load("res://assets/ui/background/title_screen_bg.png") as Texture2D
	title_banner_frame.add_child(title_banner_image)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(title_label, 34, UISkin.COLOR_ACCENT)
	root_column.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(subtitle_label, 14, UISkin.COLOR_MUTED)
	root_column.add_child(subtitle_label)

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 18)
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_column.add_child(main_row)

	menu_left_panel = PanelContainer.new()
	menu_left_panel.custom_minimum_size = Vector2(286, 0)
	menu_left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_left_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	main_row.add_child(menu_left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 16)
	left_margin.add_theme_constant_override("margin_top", 16)
	left_margin.add_theme_constant_override("margin_right", 16)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	menu_left_panel.add_child(left_margin)

	var left_column := VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 12)
	left_margin.add_child(left_column)

	left_blurb_label = Label.new()
	left_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(left_blurb_label, 13, Color(0.90, 0.92, 0.98))
	left_column.add_child(left_blurb_label)

	primary_start_button = _menu_button(&"start", "", _on_primary_pressed, true)
	settings_button = _menu_button(&"settings", "", func() -> void: settings_requested.emit())
	audio_button = _menu_button(&"audio", "", func() -> void: audio_requested.emit())
	gallery_button = _menu_button(&"gallery", "", _show_gallery)
	about_button = _menu_button(&"about", "", _show_about)
	quit_button = _menu_button(&"quit", "", func() -> void: quit_requested.emit())
	audio_button.visible = false
	gallery_button.visible = false
	menu_action_buttons = [primary_start_button, about_button, settings_button, quit_button]
	for button in menu_action_buttons:
		left_column.add_child(button)

	left_hint_label = Label.new()
	left_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(left_hint_label, 11, UISkin.COLOR_MUTED)
	left_column.add_child(left_hint_label)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	main_row.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 18)
	right_margin.add_theme_constant_override("margin_top", 18)
	right_margin.add_theme_constant_override("margin_right", 18)
	right_margin.add_theme_constant_override("margin_bottom", 18)
	right_panel.add_child(right_margin)

	var right_column := VBoxContainer.new()
	right_column.add_theme_constant_override("separation", 16)
	right_margin.add_child(right_column)

	hero_top_row = HBoxContainer.new()
	hero_top_row.add_theme_constant_override("separation", 16)
	right_column.add_child(hero_top_row)

	hero_portrait_frame = PanelContainer.new()
	hero_portrait_frame.custom_minimum_size = Vector2(220, 260)
	hero_portrait_frame.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	hero_top_row.add_child(hero_portrait_frame)

	hero_portrait = TextureRect.new()
	hero_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero_portrait_frame.add_child(hero_portrait)

	var hero_info_panel := PanelContainer.new()
	hero_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_info_panel.add_theme_stylebox_override("panel", UISkin.choice_panel_style())
	hero_top_row.add_child(hero_info_panel)

	var hero_info_margin := MarginContainer.new()
	hero_info_margin.add_theme_constant_override("margin_left", 14)
	hero_info_margin.add_theme_constant_override("margin_top", 14)
	hero_info_margin.add_theme_constant_override("margin_right", 14)
	hero_info_margin.add_theme_constant_override("margin_bottom", 14)
	hero_info_panel.add_child(hero_info_margin)

	var hero_info_column := VBoxContainer.new()
	hero_info_column.add_theme_constant_override("separation", 8)
	hero_info_margin.add_child(hero_info_column)

	hero_detail_title = Label.new()
	hero_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hero_detail_title, 24, Color.WHITE)
	hero_info_column.add_child(hero_detail_title)

	hero_detail_role = Label.new()
	hero_detail_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UISkin.label(hero_detail_role, 14, UISkin.COLOR_ACCENT)
	hero_info_column.add_child(hero_detail_role)

	hero_detail_desc = Label.new()
	hero_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UISkin.label(hero_detail_desc, 12, UISkin.COLOR_MUTED)
	hero_info_column.add_child(hero_detail_desc)

	menu_overview_panel = PanelContainer.new()
	menu_overview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_overview_panel.add_theme_stylebox_override("panel", UISkin.choice_panel_style())
	right_column.add_child(menu_overview_panel)

	var overview_margin := MarginContainer.new()
	overview_margin.add_theme_constant_override("margin_left", 12)
	overview_margin.add_theme_constant_override("margin_top", 12)
	overview_margin.add_theme_constant_override("margin_right", 12)
	overview_margin.add_theme_constant_override("margin_bottom", 12)
	menu_overview_panel.add_child(overview_margin)

	var overview_column := VBoxContainer.new()
	overview_column.add_theme_constant_override("separation", 10)
	overview_margin.add_child(overview_column)

	menu_overview_title = Label.new()
	UISkin.label(menu_overview_title, 13, UISkin.COLOR_ACCENT)
	overview_column.add_child(menu_overview_title)

	menu_overview_scroll = ScrollContainer.new()
	menu_overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_overview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_column.add_child(menu_overview_scroll)

	menu_overview_grid = GridContainer.new()
	menu_overview_grid.columns = 3
	menu_overview_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_overview_grid.add_theme_constant_override("h_separation", 10)
	menu_overview_grid.add_theme_constant_override("v_separation", 10)
	menu_overview_scroll.add_child(menu_overview_grid)

	cards_panel = PanelContainer.new()
	cards_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_panel.add_theme_stylebox_override("panel", UISkin.choice_panel_style())
	right_column.add_child(cards_panel)

	var cards_margin := MarginContainer.new()
	cards_margin.add_theme_constant_override("margin_left", 12)
	cards_margin.add_theme_constant_override("margin_top", 12)
	cards_margin.add_theme_constant_override("margin_right", 12)
	cards_margin.add_theme_constant_override("margin_bottom", 12)
	cards_panel.add_child(cards_margin)

	cards_grid = GridContainer.new()
	cards_grid.columns = 3
	cards_grid.add_theme_constant_override("h_separation", 12)
	cards_grid.add_theme_constant_override("v_separation", 12)
	cards_margin.add_child(cards_grid)

	for hero_index in range(HEROES.size()):
		var hero_button := _hero_card(HEROES[hero_index], hero_index)
		hero_buttons.append(hero_button)
		cards_grid.add_child(hero_button)

func _hero_card(hero: Dictionary, hero_index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 200)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UISkin.choice_panel_style())
	button.add_theme_stylebox_override("hover", UISkin.flat_style(Color(0.22, 0.23, 0.27), UISkin.COLOR_ACCENT, 2, 3))
	button.add_theme_stylebox_override("pressed", UISkin.flat_style(Color(0.14, 0.15, 0.18), UISkin.COLOR_ACCENT.darkened(0.2), 2, 3))
	var tilt_root := UICardFx.install(button, {
		"active_scale": 1.026,
		"rotation_max": 2.6,
		"float_offset": Vector2(5.0, 4.0)
	})
	UICardFx.bind(button, func() -> void: _set_selected_hero(hero_index))
	button.pressed.connect(func() -> void: _activate_hero(hero_index))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 12
	margin.offset_top = 12
	margin.offset_right = -12
	margin.offset_bottom = -12
	tilt_root.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "CardColumn"
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.custom_minimum_size = Vector2(0, 96)
	portrait_frame.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	column.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = load(String(hero.get("portrait", ""))) as Texture2D
	portrait_frame.add_child(portrait)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "%s  [%d]" % [_hero_name(hero), hero_index + 1]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size.y = 18.0
	UISkin.label(name_label, 16, Color.WHITE)
	column.add_child(name_label)

	var role_label := Label.new()
	role_label.name = "RoleLabel"
	role_label.text = _hero_role(hero)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.custom_minimum_size.y = 16.0
	UISkin.label(role_label, 12, UISkin.COLOR_ACCENT)
	column.add_child(role_label)

	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = " / ".join(_hero_stats(hero))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.custom_minimum_size.y = 30.0
	UISkin.label(stats_label, 11, UISkin.COLOR_MUTED)
	column.add_child(stats_label)

	UISkin.ignore_mouse_recursive(margin)
	return button

func _overview_entry_card(entry: Dictionary, pressed_callback: Callable, preview_callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 94)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", UISkin.choice_panel_style())
	button.add_theme_stylebox_override("hover", UISkin.flat_style(Color(0.22, 0.23, 0.27), UISkin.COLOR_ACCENT, 2, 3))
	button.add_theme_stylebox_override("pressed", UISkin.flat_style(Color(0.14, 0.15, 0.18), UISkin.COLOR_ACCENT.darkened(0.2), 2, 3))
	button.set_meta("entry_id", String(entry.get("id", "")))
	var tilt_root := UICardFx.install(button, {
		"active_scale": 1.022,
		"rotation_max": 2.0,
		"float_offset": Vector2(4.0, 3.0),
		"sheen_alpha": 0.09
	})
	UICardFx.bind(button, preview_callback)
	button.pressed.connect(pressed_callback)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 10
	margin.offset_top = 10
	margin.offset_right = -10
	margin.offset_bottom = -10
	tilt_root.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(54, 54)
	portrait_frame.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
	row.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = load(String(entry.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
	portrait_frame.add_child(portrait)

	var text_column := VBoxContainer.new()
	text_column.name = "TextColumn"
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = _localized_entry_field(entry, "title")
	UISkin.label(name_label, 13, Color.WHITE)
	text_column.add_child(name_label)

	var role_label := Label.new()
	role_label.name = "RoleLabel"
	role_label.text = _localized_entry_field(entry, "subtitle")
	UISkin.label(role_label, 11, UISkin.COLOR_ACCENT)
	text_column.add_child(role_label)

	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.text = _localized_entry_field(entry, "meta")
	UISkin.label(stats_label, 10, UISkin.COLOR_MUTED)
	text_column.add_child(stats_label)

	UISkin.ignore_mouse_recursive(margin)
	return button

func _menu_button(menu_key: StringName, text_value: String, callback: Callable, highlighted: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.set_meta("menu_key", String(menu_key))
	button.custom_minimum_size = Vector2(0, 46)
	UISkin.button_styles(button, "large" if highlighted else "medium")
	UICardFx.install_text_button(button, {
		"font_size": 15 if highlighted else 14,
		"active_scale": 1.022 if highlighted else 1.018,
		"rotation_max": 1.7 if highlighted else 1.3,
		"float_offset": Vector2(4.0, 2.4) if highlighted else Vector2(3.0, 1.8),
		"sheen_alpha": 0.07 if highlighted else 0.05
	})
	UICardFx.bind(button, func() -> void: _set_menu_preview(menu_key))
	button.focus_exited.connect(func() -> void:
		if not button.is_hovered():
			call_deferred("_sync_menu_preview")
	)
	button.mouse_exited.connect(func() -> void:
		if not button.has_focus():
			call_deferred("_sync_menu_preview")
	)
	button.pressed.connect(callback)
	return button

func _on_primary_pressed() -> void:
	if screen_mode == "select":
		_activate_selected_hero()
		return
	_show_hero_select()

func _show_menu() -> void:
	screen_mode = "menu"
	detail_mode = "menu"
	menu_preview_key = &""
	_sync_title_banner_visibility()
	menu_overview_panel.visible = false
	cards_panel.visible = false
	_refresh_menu_overview_copy()
	_apply_title_preview()
	_refresh_copy()
	_queue_layout_refresh()
	call_deferred("_focus_primary_button")

func _show_hero_select() -> void:
	screen_mode = "select"
	detail_mode = "hero"
	menu_preview_key = &""
	_sync_title_banner_visibility()
	menu_overview_panel.visible = false
	cards_panel.visible = true
	_set_selected_hero(selected_hero_index)
	_refresh_copy()
	_queue_layout_refresh()
	call_deferred("_focus_selected_card")

func _show_gallery() -> void:
	screen_mode = "gallery"
	detail_mode = "gallery"
	menu_preview_key = &""
	_sync_title_banner_visibility()
	menu_overview_panel.visible = true
	cards_panel.visible = false
	_refresh_menu_overview_copy()
	_set_gallery_entry(active_gallery_entry_id)
	_refresh_copy()
	_queue_layout_refresh()
	call_deferred("_focus_current_overview_entry")

func _show_about() -> void:
	screen_mode = "about"
	detail_mode = "about"
	menu_preview_key = &""
	_sync_title_banner_visibility()
	menu_overview_panel.visible = true
	cards_panel.visible = false
	_refresh_menu_overview_copy()
	_set_about_entry(active_about_entry_id)
	_refresh_copy()
	_queue_layout_refresh()
	call_deferred("_focus_current_overview_entry")

func _focus_selected_card() -> void:
	if selected_hero_index >= 0 and selected_hero_index < hero_buttons.size():
		hero_buttons[selected_hero_index].grab_focus()

func set_disabled_family_ids(next_disabled_family_ids: Array) -> void:
	disabled_family_ids.clear()
	for raw_id in next_disabled_family_ids:
		var family_id := String(raw_id)
		if not disabled_family_ids.has(family_id):
			disabled_family_ids.append(family_id)
	if _is_selected_hero_disabled():
		selected_hero_index = _first_enabled_hero_index()
	_refresh_hero_button_enabled_states()
	_set_selected_hero(selected_hero_index)

func _sync_title_banner_visibility() -> void:
	if title_banner_frame != null:
		title_banner_frame.visible = screen_mode == "menu"

func _focus_primary_button() -> void:
	if primary_start_button != null:
		primary_start_button.grab_focus()

func _focus_current_overview_entry() -> void:
	var target_id := ""
	match screen_mode:
		"gallery":
			target_id = active_gallery_entry_id
		"about":
			target_id = active_about_entry_id
		_:
			target_id = "menu_hero_%s" % String(HEROES[selected_hero_index].get("id", ""))
	for button in menu_overview_buttons:
		if String(button.get_meta("entry_id", "")) == target_id:
			button.grab_focus()
			return
	if not menu_overview_buttons.is_empty():
		menu_overview_buttons[0].grab_focus()

func _refresh_card_focus_states() -> void:
	for hero_index in range(hero_buttons.size()):
		UICardFx.pin(hero_buttons[hero_index], hero_index == selected_hero_index)
	_refresh_menu_button_fx_states()
	var active_entry_id := ""
	match screen_mode:
		"gallery":
			active_entry_id = active_gallery_entry_id
		"about":
			active_entry_id = active_about_entry_id
		_:
			active_entry_id = "menu_hero_%s" % String(HEROES[selected_hero_index].get("id", ""))
	for button in menu_overview_buttons:
		UICardFx.pin(button, String(button.get_meta("entry_id", "")) == active_entry_id)

func _refresh_menu_button_fx_states() -> void:
	if menu_action_buttons.is_empty():
		return
	for button in menu_action_buttons:
		var menu_key := StringName(String(button.get_meta("menu_key", "")))
		var active := false
		match menu_key:
			&"start":
				active = screen_mode == "menu" or screen_mode == "select"
			&"gallery":
				active = screen_mode == "gallery"
			&"about":
				active = screen_mode == "about"
		UICardFx.pin(button, active)
		UICardFx.sync_text_button_state(button)

func _set_menu_preview(menu_key: StringName) -> void:
	menu_preview_key = menu_key
	_sync_menu_preview()

func _sync_menu_preview() -> void:
	if menu_action_buttons.is_empty():
		return
	var active_preview_key: StringName = &""
	for button in menu_action_buttons:
		if button == null:
			continue
		if button.has_focus() or button.is_hovered():
			active_preview_key = StringName(String(button.get_meta("menu_key", "")))
			break
	if active_preview_key == &"":
		menu_preview_key = &""
		left_blurb_label.text = _blurb_for_mode()
		left_hint_label.text = _hint_text()
		return
	menu_preview_key = active_preview_key
	left_blurb_label.text = _blurb_for_menu_key(active_preview_key)
	left_hint_label.text = _hint_for_menu_key(active_preview_key)

func _blurb_for_menu_key(menu_key: StringName) -> String:
	match menu_key:
		&"start":
			return _locale_text(
				"Jump into hero select, then commit to the champion whose rhythm and risk profile fit your route plan.",
				"先进入选角，再锁定最适合你节奏和路线规划的角色。",
				"先進入選角，再鎖定最適合你節奏和路線規劃的角色。"
			)
		&"settings":
			return _locale_text(
				"Switch display mode, VSync, and language before the run so the interface feels right end to end.",
				"在开局前调整显示模式、垂直同步和语言，让整套界面都顺手。",
				"在開局前調整顯示模式、垂直同步和語言，讓整套介面都順手。"
			)
		&"audio":
			return _locale_text(
				"Shape the mix before you enter: chapter score, room tone, combat impacts, and UI calls all have their own lane.",
				"开局前先调音：章节音乐、环境氛围、战斗反馈和界面提示都能单独处理。",
				"開局前先調音：章節音樂、環境氛圍、戰鬥回饋和介面提示都能單獨處理。"
			)
		&"gallery":
			return _locale_text(
				"Review heroes, bosses, relic families, and route notes before you lock into a run plan.",
				"先看角色、首领、饰品家族和路线说明，再决定这一局怎么构筑。",
				"先看角色、首領、飾品家族和路線說明，再決定這一局怎麼構築。"
			)
		&"about":
			return _locale_text(
				"Use the primer to refresh controls, encounter pacing, and how relic, prep, and drops fit together.",
				"用玩法导览快速回顾操作、遭遇节奏，以及饰品、准备和掉落之间的关系。",
				"用玩法導覽快速回顧操作、遭遇節奏，以及飾品、準備和掉落之間的關係。"
			)
		&"quit":
			return _locale_text(
				"Leave from here when you are done. The title menu keeps your settings and mix adjustments.",
				"结束时可以从这里退出，菜单里的设置和音频调整都会保留。",
				"結束時可以從這裡退出，選單裡的設定和音訊調整都會保留。"
			)
		_:
			return _blurb_for_mode()

func _hint_for_menu_key(menu_key: StringName) -> String:
	match menu_key:
		&"start":
			return _locale_text(
				"Enter hero select  |  1 / 2 / 3 quick pick  |  Enter confirm",
				"Enter 进入选角  |  1 / 2 / 3 快速选角  |  Enter 确认",
				"Enter 進入選角  |  1 / 2 / 3 快速選角  |  Enter 確認"
			)
		&"settings":
			return _locale_text(
				"S settings  |  F fullscreen  |  W windowed  |  V vsync",
				"S 设置  |  F 全屏  |  W 窗口  |  V 垂直同步",
				"S 設定  |  F 全螢幕  |  W 視窗  |  V 垂直同步"
			)
		&"audio":
			return _locale_text(
				"F10 audio mix  |  Drag sliders  |  Preview each lane",
				"F10 音频混音  |  拖动滑杆  |  逐条试听",
				"F10 音訊混音  |  拖動滑桿  |  逐條試聽"
			)
		&"gallery":
			return _locale_text(
				"G gallery  |  Compare routes  |  Review featured relics",
				"G 图鉴  |  对比路线  |  查看重点饰品",
				"G 圖鑑  |  對比路線  |  查看重點飾品"
			)
		&"about":
			return _locale_text(
				"A primer  |  Controls  |  Encounter flow  |  Run systems",
				"A 玩法导览  |  操作  |  遭遇流程  |  局内系统",
				"A 玩法導覽  |  操作  |  遭遇流程  |  局內系統"
			)
		&"quit":
			return _locale_text(
				"Q quit game  |  Esc stay here",
				"Q 退出游戏  |  Esc 留在这里",
				"Q 退出遊戲  |  Esc 留在這裡"
			)
		_:
			return _hint_text()

func _set_selected_hero(hero_index: int) -> void:
	detail_mode = "hero"
	selected_hero_index = clampi(hero_index, 0, HEROES.size() - 1)
	var hero: Dictionary = HEROES[selected_hero_index]
	var disabled := _is_hero_disabled(hero)
	hero_portrait.texture = load(String(hero.get("portrait", ""))) as Texture2D
	hero_detail_title.text = _hero_name(hero)
	hero_detail_role.text = "%s  |  %s" % [
		_locale_text("Hero Profile", "角色档案", "角色檔案"),
		_hero_role(hero)
	]
	var action_text := _locale_text(
		"Press Enter to begin with this champion." if screen_mode == "select" else "Open hero select, then lock this champion.",
		"若已进入选角，按 Enter 直接开始；否则先打开选角再锁定这名角色。",
		"若已進入選角，按 Enter 直接開始；否則先打開選角再鎖定這名角色。"
	)
	if disabled:
		action_text = _disabled_hero_text()
	hero_detail_desc.text = "%s\n%s\n%s\n%s" % [
		_hero_summary(hero),
		" / ".join(_hero_stats(hero)),
		_localized_hero_field(hero, "signature"),
		action_text if screen_mode == "select" else _localized_hero_field(hero, "route")
	]
	_refresh_card_focus_states()

func _activate_selected_hero() -> void:
	_activate_hero(selected_hero_index)

func _activate_hero(hero_index: int) -> void:
	var safe_index := clampi(hero_index, 0, HEROES.size() - 1)
	if _is_hero_disabled(HEROES[safe_index]):
		_set_selected_hero(_first_enabled_hero_index())
		return
	visible = false
	character_selected.emit(HEROES[safe_index]["id"])

func _refresh_hero_button_enabled_states() -> void:
	for hero_index in range(hero_buttons.size()):
		var button := hero_buttons[hero_index]
		if button == null:
			continue
		var disabled := _is_hero_disabled(HEROES[hero_index])
		button.disabled = disabled
		button.modulate = Color(0.55, 0.55, 0.58, 0.72) if disabled else Color.WHITE

func _is_selected_hero_disabled() -> bool:
	if selected_hero_index < 0 or selected_hero_index >= HEROES.size():
		return false
	return _is_hero_disabled(HEROES[selected_hero_index])

func _is_hero_disabled(hero: Dictionary) -> bool:
	return disabled_family_ids.has(String(hero.get("id", "")))

func _first_enabled_hero_index() -> int:
	for hero_index in range(HEROES.size()):
		if not _is_hero_disabled(HEROES[hero_index]):
			return hero_index
	return 0

func _disabled_hero_text() -> String:
	return _locale_text(
		"This family has already worn the crown in this archive. Choose one of the remaining bloodlines.",
		"这个家族已经在本档案里戴过王冠。请选择剩余血脉。",
		"這個家族已經在本檔案裡戴過王冠。請選擇剩餘血脈。"
	)

func _set_gallery_entry(entry_id: String) -> void:
	detail_mode = "gallery"
	var entries := _gallery_entries()
	var entry := _find_entry(entries, entry_id)
	if entry.is_empty() and not entries.is_empty():
		entry = entries[0]
	entry_id = String(entry.get("id", "gallery_hero_knight"))
	active_gallery_entry_id = entry_id
	_apply_detail_entry(entry)
	_refresh_card_focus_states()

func _set_about_entry(entry_id: String) -> void:
	detail_mode = "about"
	var entries := _about_entries()
	var entry := _find_entry(entries, entry_id)
	if entry.is_empty() and not entries.is_empty():
		entry = entries[0]
	entry_id = String(entry.get("id", "about_overview"))
	active_about_entry_id = entry_id
	_apply_detail_entry(entry)
	_refresh_card_focus_states()

func _apply_detail_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	hero_portrait.texture = load(String(entry.get("icon", "res://assets/ui/icon/ui_unknown.png"))) as Texture2D
	hero_detail_title.text = _localized_entry_field(entry, "detail_title" if entry.has("detail_title") else "title")
	hero_detail_role.text = _localized_entry_field(entry, "detail_role" if entry.has("detail_role") else "subtitle")
	hero_detail_desc.text = _localized_entry_field(entry, "detail_desc")

func _refresh_copy(_locale: String = "") -> void:
	title_label.text = UIText.text("menu_title")
	subtitle_label.text = _subtitle_for_mode()
	UICardFx.set_button_text(primary_start_button, _locale_text("Start", "开始", "開始") if screen_mode != "select" else _locale_text("Enter Trial", "进入试炼", "進入試煉"))
	UICardFx.set_button_text(settings_button, UIText.text("menu_settings"))
	UICardFx.set_button_text(audio_button, UIText.text("audio_mix"))
	UICardFx.set_button_text(gallery_button, UIText.text("menu_gallery"))
	UICardFx.set_button_text(about_button, UIText.text("menu_about"))
	UICardFx.set_button_text(quit_button, UIText.text("menu_quit"))
	UICardFx.set_button_text(primary_start_button, "Start" if screen_mode == "select" else "New Game")
	UICardFx.set_button_text(about_button, "About")
	UICardFx.set_button_text(settings_button, "Setting")
	UICardFx.set_button_text(quit_button, "Quit")
	_refresh_menu_button_fx_states()
	_sync_menu_preview()
	_refresh_menu_overview_copy()
	if detail_mode == "menu":
		_apply_title_preview()
		return
	match detail_mode:
		"gallery":
			_set_gallery_entry(active_gallery_entry_id)
		"about":
			_set_about_entry(active_about_entry_id)
		_:
			_set_selected_hero(selected_hero_index)

func _apply_title_preview() -> void:
	detail_mode = "menu"
	hero_portrait.texture = load("res://assets/ui/background/title_screen_bg.png") as Texture2D
	hero_detail_title.text = "Town Trial"
	hero_detail_role.text = "New Game / About / Setting / Quit"
	hero_detail_desc.text = "Use New Game to choose one champion and enter the run. About stays here for credits and the primer; Setting handles display and language before play."
	_refresh_card_focus_states()

func _subtitle_for_mode() -> String:
	match screen_mode:
		"gallery":
			return _locale_text(
				"Compendium entries, route systems, and featured relic notes live here.",
				"这里会集中展示图鉴条目、路线系统和重点饰品说明。",
				"這裡會集中展示圖鑑條目、路線系統和重點飾品說明。"
			)
		"about":
			return _locale_text(
				"A quick primer for the town trial, controls, and run-building logic.",
				"这里整理了城镇试炼的玩法脉络、操作方式和构筑逻辑。",
				"這裡整理了城鎮試煉的玩法脈絡、操作方式和構築邏輯。"
			)
		"select":
			return _locale_text(
				"Pick the champion whose rhythm you want to carry through the trial.",
				"选定最适合你节奏的角色，然后带着这套打法走完整轮试炼。",
				"選定最適合你節奏的角色，然後帶著這套打法走完整輪試煉。"
			)
		_:
			return _locale_text(
				"Choose a menu entry first, then lock in a hero for the town trial.",
				"先选一个菜单入口，再决定要带哪名角色进入城镇试炼。",
				"先選一個選單入口，再決定要帶哪名角色進入城鎮試煉。"
			)

func _blurb_for_mode() -> String:
	match screen_mode:
		"gallery":
			return _locale_text(
				"Use the compendium to compare heroes, late bosses, and key relic families before committing to a route.",
				"图鉴更适合在开局前快速对比角色、终局首领和核心饰品路线，先把思路想清楚再开跑。",
				"圖鑑更適合在開局前快速對比角色、終局首領和核心飾品路線，先把思路想清楚再開跑。"
			)
		"about":
			return _locale_text(
				"This panel focuses on the structure of a run: what you do, why the relic system matters, and how encounters escalate.",
				"介绍页更偏向说明整局结构：你在做什么、饰品系统为什么重要，以及战斗是怎么逐步加压的。",
				"介紹頁更偏向說明整局結構：你在做什麼、飾品系統為什麼重要，以及戰鬥是怎麼逐步加壓的。"
			)
		"select":
			return _locale_text(
				"Each hero has a different failure pattern. Pick the one whose risks you naturally read well.",
				"每个角色都不是单纯的强弱区别，而是失误代价完全不同。选你最容易稳定发挥的那一个。",
				"每個角色都不是單純的強弱區別，而是失誤代價完全不同。選你最容易穩定發揮的那一個。"
			)
		_:
			return _locale_text(
				"Start here, tweak settings if needed, then lock a champion and shape the run with relics, route picks, and boss prep.",
				"从这里开始，先调好设置，再锁定角色，靠饰品、路线选择和首领准备把整局打成你想要的样子。",
				"從這裡開始，先調好設定，再鎖定角色，靠飾品、路線選擇和首領準備把整局打成你想要的樣子。"
			)

func _hint_text() -> String:
	match screen_mode:
		"select":
			return _locale_text(
				"1 / 2 / 3 hero  |  Enter begin  |  Esc menu  |  S settings  |  F10 audio  |  Q quit",
				"1 / 2 / 3 选角色  |  Enter 开始  |  Esc 返回菜单  |  S 设置  |  F10 音频  |  Q 退出",
				"1 / 2 / 3 選角色  |  Enter 開始  |  Esc 返回選單  |  S 設定  |  F10 音訊  |  Q 退出"
			)
		"gallery":
			return _locale_text(
				"G gallery  |  Enter start menu  |  Esc menu  |  S settings  |  F10 audio  |  Q quit",
				"G 图鉴  |  Enter 打开选角  |  Esc 返回菜单  |  S 设置  |  F10 音频  |  Q 退出",
				"G 圖鑑  |  Enter 打開選角  |  Esc 返回選單  |  S 設定  |  F10 音訊  |  Q 退出"
			)
		"about":
			return _locale_text(
				"A about  |  Enter start menu  |  Esc menu  |  S settings  |  F10 audio  |  Q quit",
				"A 介绍  |  Enter 打开选角  |  Esc 返回菜单  |  S 设置  |  F10 音频  |  Q 退出",
				"A 介紹  |  Enter 打開選角  |  Esc 返回選單  |  S 設定  |  F10 音訊  |  Q 退出"
			)
		_:
			return _locale_text(
				"Enter New Game  |  A About  |  S Setting  |  Q Quit",
				"Enter New Game  |  A About  |  S Setting  |  Q Quit",
				"Enter New Game  |  A About  |  S Setting  |  Q Quit"
			)

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	if panel == null or cards_grid == null or menu_overview_grid == null:
		return
	var viewport_size: Vector2 = layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact := viewport_size.x < 1100.0 or viewport_size.y < 760.0
	var very_compact := viewport_size.x < 860.0 or viewport_size.y < 640.0
	panel.custom_minimum_size = Vector2(
		clampf(viewport_size.x - (48.0 if compact else 96.0), 720.0, 1360.0),
		clampf(viewport_size.y - (48.0 if compact else 96.0), 540.0, 820.0)
	)
	panel_margin.add_theme_constant_override("margin_left", 18 if compact else 28)
	panel_margin.add_theme_constant_override("margin_top", 16 if compact else 24)
	panel_margin.add_theme_constant_override("margin_right", 18 if compact else 28)
	panel_margin.add_theme_constant_override("margin_bottom", 16 if compact else 24)
	if menu_left_panel != null:
		menu_left_panel.custom_minimum_size.x = 192.0 if very_compact else (224.0 if compact else 286.0)
	if title_banner_frame != null:
		title_banner_frame.visible = screen_mode == "menu"
		title_banner_frame.custom_minimum_size.y = 96.0 if very_compact else (124.0 if compact else 164.0)
	if hero_top_row != null:
		hero_top_row.add_theme_constant_override("separation", 10 if very_compact else (12 if compact else 16))
	if hero_portrait_frame != null:
		hero_portrait_frame.custom_minimum_size = Vector2(124.0 if very_compact else (170.0 if compact else 220.0), 174.0 if very_compact else (214.0 if compact else 260.0))
	UISkin.label(title_label, 28 if compact else 34, UISkin.COLOR_ACCENT)
	UISkin.label(subtitle_label, 13 if compact else 14, UISkin.COLOR_MUTED)
	UISkin.label(left_blurb_label, 12 if compact else 13, Color(0.90, 0.92, 0.98))
	UISkin.label(hero_detail_title, 21 if compact else 24, Color.WHITE)
	UISkin.label(hero_detail_role, 13 if compact else 14, UISkin.COLOR_ACCENT)
	UISkin.label(hero_detail_desc, 11 if very_compact else (12 if compact else 13), UISkin.COLOR_MUTED)
	UISkin.label(left_hint_label, 10 if very_compact else (11 if compact else 12), UISkin.COLOR_MUTED)
	UISkin.label(menu_overview_title, 12 if compact else 13, UISkin.COLOR_ACCENT)
	left_blurb_label.max_lines_visible = 4 if very_compact else (5 if compact else -1)
	left_hint_label.max_lines_visible = 3 if very_compact else -1
	menu_overview_panel.custom_minimum_size.y = 182.0 if very_compact else (214.0 if compact else 232.0)
	menu_overview_grid.columns = _overview_columns(compact, very_compact)
	cards_grid.columns = 1 if very_compact else (2 if compact else 3)
	hero_portrait.custom_minimum_size = Vector2(112.0 if very_compact else (150.0 if compact else 200.0), 162.0 if very_compact else (194.0 if compact else 240.0))
	for button in [primary_start_button, settings_button, audio_button, gallery_button, about_button, quit_button]:
		if button != null:
			var full_height := 54.0 if button == primary_start_button else 42.0
			button.custom_minimum_size.y = 34.0 if very_compact else (40.0 if compact else full_height)
			UICardFx.sync_text_button_state(button)
	for hero_button in hero_buttons:
		hero_button.custom_minimum_size.y = 164.0 if very_compact else (190.0 if compact else 208.0)
		var portrait_frame := hero_button.get_node_or_null("TiltRoot/Margin/CardColumn/PortraitFrame") as PanelContainer
		var name_label := hero_button.get_node_or_null("TiltRoot/Margin/CardColumn/NameLabel") as Label
		var role_label := hero_button.get_node_or_null("TiltRoot/Margin/CardColumn/RoleLabel") as Label
		var stats_label := hero_button.get_node_or_null("TiltRoot/Margin/CardColumn/StatsLabel") as Label
		if portrait_frame != null:
			portrait_frame.custom_minimum_size.y = 74.0 if very_compact else (86.0 if compact else 96.0)
		if name_label != null:
			UISkin.label(name_label, 13 if compact else 16, Color.WHITE)
		if role_label != null:
			UISkin.label(role_label, 10 if compact else 12, UISkin.COLOR_ACCENT)
		if stats_label != null:
			stats_label.max_lines_visible = 1 if very_compact else 2
			UISkin.label(stats_label, 9 if compact else 11, UISkin.COLOR_MUTED)
	for overview_button in menu_overview_buttons:
		overview_button.custom_minimum_size.y = 84.0 if very_compact else (90.0 if compact else 94.0)
		var name_label := overview_button.get_node_or_null("Margin/Row/TextColumn/NameLabel") as Label
		var role_label := overview_button.get_node_or_null("Margin/Row/TextColumn/RoleLabel") as Label
		var stats_label := overview_button.get_node_or_null("Margin/Row/TextColumn/StatsLabel") as Label
		if name_label != null:
			UISkin.label(name_label, 11 if compact else 13, Color.WHITE)
		if role_label != null:
			UISkin.label(role_label, 10 if compact else 11, UISkin.COLOR_ACCENT)
		if stats_label != null:
			UISkin.label(stats_label, 9 if compact else 10, UISkin.COLOR_MUTED)

func _overview_columns(compact: bool, very_compact: bool) -> int:
	match screen_mode:
		"gallery":
			return 1 if very_compact else 2
		"about":
			return 1
		_:
			return 2 if compact else 3

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_show_hero_select()
				_set_selected_hero(0)
			KEY_2, KEY_KP_2:
				_show_hero_select()
				_set_selected_hero(1)
			KEY_3, KEY_KP_3:
				_show_hero_select()
				_set_selected_hero(2)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if screen_mode == "select":
					_activate_selected_hero()
				else:
					_show_hero_select()
			KEY_ESCAPE:
				if screen_mode != "menu":
					_show_menu()
				else:
					return
			KEY_S:
				settings_requested.emit()
			KEY_G:
				if screen_mode != "menu":
					_show_gallery()
				else:
					return
			KEY_A:
				_show_about()
			KEY_Q:
				quit_requested.emit()
			_:
				return
		get_viewport().set_input_as_handled()

func _hero_name(hero: Dictionary) -> String:
	return _localized_hero_field(hero, "name")

func _hero_role(hero: Dictionary) -> String:
	return _localized_hero_field(hero, "role")

func _hero_summary(hero: Dictionary) -> String:
	return _localized_hero_field(hero, "summary")

func _hero_stats(hero: Dictionary) -> Array[String]:
	var locale := _current_locale()
	var localized := hero.get("stats", {}) as Dictionary
	var raw: Variant = localized.get(locale, localized.get("en", []))
	var output: Array[String] = []
	if raw is Array:
		for entry in raw:
			output.append(String(entry))
	return output

func _localized_hero_field(hero: Dictionary, field: String) -> String:
	var locale := _current_locale()
	var localized := hero.get(field, {}) as Dictionary
	return String(localized.get(locale, localized.get("en", "")))

func _localized_entry_field(entry: Dictionary, field: String) -> String:
	var raw: Variant = entry.get(field, "")
	if raw is Dictionary:
		var localized := raw as Dictionary
		var locale := _current_locale()
		return String(localized.get(locale, localized.get("en", "")))
	return String(raw)

func _refresh_menu_overview_copy() -> void:
	for child in menu_overview_grid.get_children():
		menu_overview_grid.remove_child(child)
		child.queue_free()
	menu_overview_buttons.clear()
	match screen_mode:
		"gallery":
			menu_overview_title.text = _locale_text("Compendium", "图鉴目录", "圖鑑目錄")
			for entry in _gallery_entries():
				var entry_id := String(entry.get("id", ""))
				var button := _overview_entry_card(
					entry,
					func() -> void: _set_gallery_entry(entry_id),
					func() -> void: _set_gallery_entry(entry_id)
				)
				menu_overview_buttons.append(button)
				menu_overview_grid.add_child(button)
		"about":
			menu_overview_title.text = _locale_text("Run Primer", "玩法介绍", "玩法介紹")
			for entry in _about_entries():
				var entry_id := String(entry.get("id", ""))
				var button := _overview_entry_card(
					entry,
					func() -> void: _set_about_entry(entry_id),
					func() -> void: _set_about_entry(entry_id)
				)
				menu_overview_buttons.append(button)
				menu_overview_grid.add_child(button)
		_:
			menu_overview_title.text = _locale_text("Hero Roster", "角色预览", "角色預覽")
			for hero_index in range(HEROES.size()):
				var hero_entry := _menu_hero_entry(HEROES[hero_index])
				var button := _overview_entry_card(
					hero_entry,
					func() -> void:
						_show_hero_select()
						_set_selected_hero(hero_index),
					func() -> void: _set_selected_hero(hero_index)
				)
				menu_overview_buttons.append(button)
				menu_overview_grid.add_child(button)
	_refresh_card_focus_states()

func _menu_hero_entry(hero: Dictionary) -> Dictionary:
	return {
		"id": "menu_hero_%s" % String(hero.get("id", "")),
		"icon": String(hero.get("portrait", "")),
		"title": hero.get("name", {}),
		"subtitle": hero.get("role", {}),
		"meta": {
			"en": " / ".join(_hero_stats(hero)),
			"zh_Hans": " / ".join(_hero_stats(hero)),
			"zh_Hant": " / ".join(_hero_stats(hero))
		}
	}

func _gallery_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for hero in HEROES:
		entries.append(_gallery_hero_entry(hero))
	for relic_entry in _gallery_relic_entries():
		entries.append(relic_entry)
	entries.append_array([
		{
			"id": "gallery_boss_judicator",
			"icon": "res://assets/ui/icon/ui_shield.png",
			"title": {
				"en": "Judicator",
				"zh_Hans": "裁决者",
				"zh_Hant": "裁決者"
			},
			"subtitle": {
				"en": "Boss Intel",
				"zh_Hans": "首领情报",
				"zh_Hant": "首領情報"
			},
			"meta": {
				"en": "Leap slam, line charge, enrage finish.",
				"zh_Hans": "跳斩、直线冲锋、残血狂暴。",
				"zh_Hant": "跳斬、直線衝鋒、殘血狂暴。"
			},
			"detail_title": {
				"en": "Judicator",
				"zh_Hans": "裁决者",
				"zh_Hant": "裁決者"
			},
			"detail_role": {
				"en": "Boss Intel | Arena pressure",
				"zh_Hans": "首领情报 | 正面压场",
				"zh_Hant": "首領情報 | 正面壓場"
			},
			"detail_desc": {
				"en": "This boss wins by forcing you to panic in short windows. Watch the landing ring, leave enough room for the charge lane, and respect the low-health enrage spike.",
				"zh_Hans": "这个首领最强的地方不是数值，而是逼你在很短的窗口里慌张处理。看到落点圈就提前让位，给直线冲锋预留空间，残血阶段一定要防它的狂暴追击。",
				"zh_Hant": "這個首領最強的地方不是數值，而是逼你在很短的窗口裡慌張處理。看到落點圈就提前讓位，給直線衝鋒預留空間，殘血階段一定要防它的狂暴追擊。"
			}
		},
		{
			"id": "gallery_boss_guards",
			"icon": "res://assets/ui/icon/ui_church.png",
			"title": {
				"en": "Royal Guard Formation",
				"zh_Hans": "王庭卫阵",
				"zh_Hant": "王庭衛陣"
			},
			"subtitle": {
				"en": "Boss Intel",
				"zh_Hans": "首领情报",
				"zh_Hant": "首領情報"
			},
			"meta": {
				"en": "Immune shell, lane pressure, collapse condition.",
				"zh_Hans": "免疫外壳、边线压迫、拆阵条件。",
				"zh_Hant": "免疫外殼、邊線壓迫、拆陣條件。"
			},
			"detail_title": {
				"en": "Royal Guard Formation",
				"zh_Hans": "王庭卫阵",
				"zh_Hant": "王庭衛陣"
			},
			"detail_role": {
				"en": "Boss Intel | Formation encounter",
				"zh_Hans": "首领情报 | 阵型关卡",
				"zh_Hant": "首領情報 | 陣型關卡"
			},
			"detail_desc": {
				"en": "The formation starts immune, then opens once coverage fully unfolds. The fight asks you to read the whole board, not only the nearest guard. Clear pressure without losing the center.",
				"zh_Hans": "这场战斗的重点是读整体阵型，不是只盯最近的小兵。护阵阶段先处理边线压力，等覆盖完全展开以后再抓住中场空档，一口气把阵型拆穿。",
				"zh_Hant": "這場戰鬥的重點是讀整體陣型，不是只盯最近的小兵。護陣階段先處理邊線壓力，等覆蓋完全展開以後再抓住中場空檔，一口氣把陣型拆穿。"
			}
		},
		{
			"id": "gallery_boss_princes",
			"icon": "res://assets/ui/icon/ui_ember_seed.png",
			"title": {
				"en": "Twin Princes",
				"zh_Hans": "双王子",
				"zh_Hant": "雙王子"
			},
			"subtitle": {
				"en": "Boss Intel",
				"zh_Hans": "首领情报",
				"zh_Hant": "首領情報"
			},
			"meta": {
				"en": "Teleport marks, phase shift, desperation push.",
				"zh_Hans": "传送标记、转阶段、绝境追击。",
				"zh_Hant": "傳送標記、轉階段、絕境追擊。"
			},
			"detail_title": {
				"en": "Twin Princes",
				"zh_Hans": "双王子",
				"zh_Hant": "雙王子"
			},
			"detail_role": {
				"en": "Boss Intel | Burst execution",
				"zh_Hans": "首领情报 | 爆发执行",
				"zh_Hant": "首領情報 | 爆發執行"
			},
			"detail_desc": {
				"en": "A late fight built around phase shifts and execution checks. If your build cannot cash out damage quickly, the teleport slash and barrage overlap will start taxing every mistake.",
				"zh_Hans": "这是一场要求你真正兑现构筑强度的终局战。若伤害和走位都不够果断，传送斩和弹幕一旦叠在一起，整场就会被失误税慢慢吃死。",
				"zh_Hant": "這是一場要求你真正兌現構築強度的終局戰。若傷害和走位都不夠果斷，傳送斬和彈幕一旦疊在一起，整場就會被失誤稅慢慢吃死。"
			}
		},
		{
			"id": "gallery_system_route",
			"icon": "res://assets/ui/icon/ui_shop.png",
			"title": {
				"en": "Route Events",
				"zh_Hans": "路线事件",
				"zh_Hant": "路線事件"
			},
			"subtitle": {
				"en": "System Guide",
				"zh_Hans": "系统导览",
				"zh_Hant": "系統導覽"
			},
			"meta": {
				"en": "Market, scout, training, forge, bounty.",
				"zh_Hans": "黑市、侦察、训练、熔炉、悬赏。",
				"zh_Hant": "黑市、偵察、訓練、熔爐、懸賞。"
			},
			"detail_title": {
				"en": "Route Events",
				"zh_Hans": "路线事件",
				"zh_Hant": "路線事件"
			},
			"detail_role": {
				"en": "System Guide | Mid-run decisions",
				"zh_Hans": "系统导览 | 中途决策",
				"zh_Hant": "系統導覽 | 中途決策"
			},
			"detail_desc": {
				"en": "Runs are shaped between fights as much as during them. Markets sharpen builds, scouts bias upcoming rewards, training offers raw stats, and the forge pushes high-risk pivots.",
				"zh_Hans": "一整局的方向往往不是在战斗里决定，而是在战斗之间慢慢被拧出来。黑市负责尖锐补强，侦察负责提前偏向路线，训练给稳定面板，熔炉则更像高风险转向工具。",
				"zh_Hant": "一整局的方向往往不是在戰鬥裡決定，而是在戰鬥之間慢慢被擰出來。黑市負責尖銳補強，偵察負責提前偏向路線，訓練給穩定面板，熔爐則更像高風險轉向工具。"
			}
		}
	])
	return entries

func _gallery_hero_entry(hero: Dictionary) -> Dictionary:
	return {
		"id": "gallery_hero_%s" % String(hero.get("id", "")),
		"icon": String(hero.get("portrait", "")),
		"title": hero.get("name", {}),
		"subtitle": {
			"en": "Hero Dossier",
			"zh_Hans": "角色图鉴",
			"zh_Hant": "角色圖鑑"
		},
		"meta": hero.get("summary", {}),
		"detail_title": hero.get("name", {}),
		"detail_role": {
			"en": "Hero Dossier | %s" % _hero_role(hero),
			"zh_Hans": "角色图鉴 | %s" % _hero_role(hero),
			"zh_Hant": "角色圖鑑 | %s" % _hero_role(hero)
		},
		"detail_desc": {
			"en": "%s\n%s\n%s\n%s" % [
				_hero_summary(hero),
				" / ".join(_hero_stats(hero)),
				_localized_hero_field(hero, "signature"),
				_localized_hero_field(hero, "route")
			],
			"zh_Hans": "%s\n%s\n%s\n%s" % [
				_hero_summary(hero),
				" / ".join(_hero_stats(hero)),
				_localized_hero_field(hero, "signature"),
				_localized_hero_field(hero, "route")
			],
			"zh_Hant": "%s\n%s\n%s\n%s" % [
				_hero_summary(hero),
				" / ".join(_hero_stats(hero)),
				_localized_hero_field(hero, "signature"),
				_localized_hero_field(hero, "route")
			]
		}
	}

func _gallery_relic_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if AccessoryManager == null:
		return entries
	for accessory_id in FEATURED_ACCESSORY_IDS:
		var accessory := AccessoryManager.get_accessory(accessory_id)
		if accessory.is_empty():
			continue
		var tags_text := _localized_tag_list(accessory.get("tags", []))
		var effect_text := _format_accessory_effects(accessory.get("effects", {}) as Dictionary, 2)
		var detail_lines: Array[String] = []
		detail_lines.append(String(accessory.get("summary", "")))
		if not effect_text.is_empty():
			detail_lines.append(effect_text)
		if not tags_text.is_empty():
			detail_lines.append(_locale_text("Route tags: %s", "路线标签：%s", "路線標籤：%s") % tags_text)
		detail_lines.append(_accessory_compendium_line(accessory))
		entries.append({
			"id": "gallery_relic_%s" % accessory_id,
			"icon": String(accessory.get("icon", "res://assets/ui/icon/ui_unknown.png")),
			"title": {
				"en": String(accessory.get("name", "Relic")),
				"zh_Hans": String(accessory.get("name", "饰品")),
				"zh_Hant": String(accessory.get("name", "飾品"))
			},
			"subtitle": {
				"en": "%s Relic" % String(accessory.get("rarity", "Common")),
				"zh_Hans": "%s 饰品" % String(accessory.get("rarity", "普通")),
				"zh_Hant": "%s 飾品" % String(accessory.get("rarity", "普通"))
			},
			"meta": {
				"en": effect_text if not effect_text.is_empty() else tags_text,
				"zh_Hans": effect_text if not effect_text.is_empty() else tags_text,
				"zh_Hant": effect_text if not effect_text.is_empty() else tags_text
			},
			"detail_title": {
				"en": String(accessory.get("name", "Relic")),
				"zh_Hans": String(accessory.get("name", "饰品")),
				"zh_Hant": String(accessory.get("name", "飾品"))
			},
			"detail_role": {
				"en": "Relic Archive | %s" % String(accessory.get("rarity", "Common")),
				"zh_Hans": "饰品档案 | %s" % String(accessory.get("rarity", "普通")),
				"zh_Hant": "飾品檔案 | %s" % String(accessory.get("rarity", "普通"))
			},
			"detail_desc": {
				"en": "\n".join(detail_lines),
				"zh_Hans": "\n".join(detail_lines),
				"zh_Hant": "\n".join(detail_lines)
			}
		})
	return entries

func _accessory_compendium_line(accessory: Dictionary) -> String:
	var tags: Array = accessory.get("tags", [])
	if tags.has("survival") or tags.has("defense"):
		return _locale_text(
			"Good for stabilizing greedy routes before a boss spike.",
			"适合在首领压力到来前，把偏贪的路线先稳住。",
			"適合在首領壓力到來前，把偏貪的路線先穩住。"
		)
	if tags.has("crit") or tags.has("damage"):
		return _locale_text(
			"Best when you already know you want sharper burst windows.",
			"更适合你已经决定走高爆发窗口的时候拿来做尖锐补强。",
			"更適合你已經決定走高爆發窗口的時候拿來做尖銳補強。"
		)
	if tags.has("skill") or tags.has("resource"):
		return _locale_text(
			"Helps builds that want to cycle skills constantly instead of trading basics.",
			"更适合频繁转技能循环、而不是只靠普攻磨血的构筑。",
			"更適合頻繁轉技能循環、而不是只靠普攻磨血的構築。"
		)
	return _locale_text(
		"Flexible enough to slot into many mid-run pivots.",
		"属于中途转向时也很容易接得住的通用型饰品。",
		"屬於中途轉向時也很容易接得住的通用型飾品。"
	)

func _about_entries() -> Array[Dictionary]:
	return [
		{
			"id": "about_overview",
			"icon": "res://assets/ui/background/title_screen_bg.png",
			"title": {
				"en": "Trial Overview",
				"zh_Hans": "试炼概览",
				"zh_Hant": "試煉概覽"
			},
			"subtitle": {
				"en": "Start Here",
				"zh_Hans": "先看这里",
				"zh_Hant": "先看這裡"
			},
			"meta": {
				"en": "Pick a hero, build a route, survive the town bosses.",
				"zh_Hans": "选角色、做路线、打穿城镇首领。",
				"zh_Hant": "選角色、做路線、打穿城鎮首領。"
			},
			"detail_title": {
				"en": "Trial Overview",
				"zh_Hans": "试炼概览",
				"zh_Hant": "試煉概覽"
			},
			"detail_role": {
				"en": "Run Primer | Core loop",
				"zh_Hans": "玩法介绍 | 核心循环",
				"zh_Hant": "玩法介紹 | 核心循環"
			},
			"detail_desc": {
				"en": "A run begins with champion choice, then keeps asking the same question in tougher forms: do you want stability, sharper burst, or a route pivot? Fights, relic picks, and mid-run events all feed that answer.",
				"zh_Hans": "一局的开头是选角色，但真正决定这局样子的，是后面每一次都在反复追问你的那个问题：你要更稳、更爆，还是中途转向？战斗、饰品和路线事件，都会把这个答案越拧越清楚。",
				"zh_Hant": "一局的開頭是選角色，但真正決定這局樣子的，是後面每一次都在反覆追問你的那個問題：你要更穩、更爆，還是中途轉向？戰鬥、飾品和路線事件，都會把這個答案越擰越清楚。"
			}
		},
		{
			"id": "about_combat",
			"icon": "res://assets/ui/icon/stat_attack_pixel.png",
			"title": {
				"en": "Combat Rhythm",
				"zh_Hans": "战斗节奏",
				"zh_Hant": "戰鬥節奏"
			},
			"subtitle": {
				"en": "Read Windows",
				"zh_Hans": "读窗口",
				"zh_Hant": "讀窗口"
			},
			"meta": {
				"en": "Movement, control, and skill timing matter more than raw stats.",
				"zh_Hans": "走位、控制和技能时机，比单纯面板更重要。",
				"zh_Hant": "走位、控制和技能時機，比單純面板更重要。"
			},
			"detail_title": {
				"en": "Combat Rhythm",
				"zh_Hans": "战斗节奏",
				"zh_Hant": "戰鬥節奏"
			},
			"detail_role": {
				"en": "Run Primer | Fighting well",
				"zh_Hans": "玩法介绍 | 怎么打得顺",
				"zh_Hant": "玩法介紹 | 怎麼打得順"
			},
			"detail_desc": {
				"en": "The combat layer is built around short advantage windows. Normal attacks stabilize, skills cash out tempo, and spacing decides whether pressure turns into free damage or panic.",
				"zh_Hans": "这套战斗不是靠站桩硬换，而是围绕一个个很短的优势窗口展开。普攻负责稳定，技能负责兑现，走位决定你是在吃压力，还是把压力反过来换成白赚输出。",
				"zh_Hant": "這套戰鬥不是靠站樁硬換，而是圍繞一個個很短的優勢窗口展開。普攻負責穩定，技能負責兌現，走位決定你是在吃壓力，還是把壓力反過來換成白賺輸出。"
			}
		},
		{
			"id": "about_relics",
			"icon": "res://assets/ui/accessory/old_king_crest.png",
			"title": {
				"en": "Relic Routes",
				"zh_Hans": "饰品路线",
				"zh_Hant": "飾品路線"
			},
			"subtitle": {
				"en": "Build Identity",
				"zh_Hans": "构筑身份",
				"zh_Hant": "構築身份"
			},
			"meta": {
				"en": "Relics are not only stats; they decide how your run cashes out.",
				"zh_Hans": "饰品不只是数值，而是决定你这局怎么兑现优势。",
				"zh_Hant": "飾品不只是數值，而是決定你這局怎麼兌現優勢。"
			},
			"detail_title": {
				"en": "Relic Routes",
				"zh_Hans": "饰品路线",
				"zh_Hant": "飾品路線"
			},
			"detail_role": {
				"en": "Run Primer | Build identity",
				"zh_Hans": "玩法介绍 | 构筑身份",
				"zh_Hant": "玩法介紹 | 構築身份"
			},
			"detail_desc": {
				"en": "Every offering is quietly asking whether you want to reinforce your current lane or pivot. Strong runs usually choose one identity early, then only deviate when the event route or boss prep justifies it.",
				"zh_Hans": "每一次饰品掉落，其实都在问你同一个问题：继续加深当前路线，还是借机转向？好打的局通常会尽早形成一个清晰身份，只有在路线事件或首领准备真的值得时才突然改道。",
				"zh_Hant": "每一次飾品掉落，其實都在問你同一個問題：繼續加深當前路線，還是藉機轉向？好打的局通常會盡早形成一個清晰身份，只有在路線事件或首領準備真的值得時才突然改道。"
			}
		},
		{
			"id": "about_progression",
			"icon": "res://assets/ui/icon/ui_shop.png",
			"title": {
				"en": "Route Progression",
				"zh_Hans": "路线推进",
				"zh_Hant": "路線推進"
			},
			"subtitle": {
				"en": "Between Fights",
				"zh_Hans": "战斗之间",
				"zh_Hant": "戰鬥之間"
			},
			"meta": {
				"en": "Shops, scouts, training, and forge choices shape the next check.",
				"zh_Hans": "黑市、侦察、训练和熔炉会把下一关变成完全不同的问题。",
				"zh_Hant": "黑市、偵察、訓練和熔爐會把下一關變成完全不同的問題。"
			},
			"detail_title": {
				"en": "Route Progression",
				"zh_Hans": "路线推进",
				"zh_Hant": "路線推進"
			},
			"detail_role": {
				"en": "Run Primer | Mid-run structure",
				"zh_Hans": "玩法介绍 | 中局结构",
				"zh_Hant": "玩法介紹 | 中局結構"
			},
			"detail_desc": {
				"en": "The run layer exists so choices outside combat matter. Gold lets you sharpen a plan, scouting lets you bias future drops, and forge-style events tempt you into higher-risk, higher-payoff pivots.",
				"zh_Hans": "路线系统的意义，是让局外决策真的会反过来影响战斗。金币让你补强计划，侦察让你提前偏向未来掉落，熔炉这类事件则会不断诱惑你去赌高风险高回报的转向。",
				"zh_Hant": "路線系統的意義，是讓局外決策真的會反過來影響戰鬥。金幣讓你補強計畫，偵察讓你提前偏向未來掉落，熔爐這類事件則會不斷誘惑你去賭高風險高回報的轉向。"
			}
		},
		{
			"id": "about_controls",
			"icon": "res://assets/ui/icon/ui_settings.png",
			"title": {
				"en": "Controls",
				"zh_Hans": "操作键位",
				"zh_Hant": "操作鍵位"
			},
			"subtitle": {
				"en": "Keep It Simple",
				"zh_Hans": "快速上手",
				"zh_Hant": "快速上手"
			},
			"meta": {
				"en": "WASD move, J attack, K/L/I skills, Esc menus.",
				"zh_Hans": "WASD 移动，J 普攻，K/L/I 技能，Esc 菜单。",
				"zh_Hant": "WASD 移動，J 普攻，K/L/I 技能，Esc 選單。"
			},
			"detail_title": {
				"en": "Controls",
				"zh_Hans": "操作键位",
				"zh_Hant": "操作鍵位"
			},
			"detail_role": {
				"en": "Run Primer | Input map",
				"zh_Hans": "玩法介绍 | 输入映射",
				"zh_Hant": "玩法介紹 | 輸入映射"
			},
			"detail_desc": {
				"en": "WASD handles movement. J is your stable basic attack. K, L, and I are your three combat skills. Esc always backs out to a menu layer, while the title screen keeps G and A as quick links for compendium and intro.",
				"zh_Hans": "WASD 负责移动。J 是最稳定的普攻，K、L、I 是三枚战斗技能。Esc 始终负责返回菜单层，而标题界面额外保留了 G 和 A 作为图鉴与介绍的快捷入口。",
				"zh_Hant": "WASD 負責移動。J 是最穩定的普攻，K、L、I 是三枚戰鬥技能。Esc 始終負責返回選單層，而標題介面額外保留了 G 和 A 作為圖鑑與介紹的快捷入口。"
			}
		},
		{
			"id": "about_credits",
			"icon": "res://assets/ui/icon/ui_check.png",
			"title": {
				"en": "Authors",
				"zh_Hans": "作者",
				"zh_Hant": "作者"
			},
			"subtitle": {
				"en": "Credits",
				"zh_Hans": "制作署名",
				"zh_Hant": "製作署名"
			},
			"meta": {
				"en": "Team roles and contributors for art, UI, and gameplay design.",
				"zh_Hans": "美术、UI、游玩调节与关卡角色设计署名。",
				"zh_Hant": "美術、UI、遊玩調節與關卡角色設計署名。"
			},
			"detail_title": {
				"en": "Authors",
				"zh_Hans": "作者",
				"zh_Hant": "作者"
			},
			"detail_role": {
				"en": "Credits | Team",
				"zh_Hans": "制作署名 | 团队成员",
				"zh_Hant": "製作署名 | 團隊成員"
			},
			"detail_desc": {
				"en": "Meishu ziyuan yu ditu sheji: Wang Baishu, Zhang Shurui\nUI yu youwan xiaoguo tiaojie: Li Chenghang, Yuan Yirui\nGuanka yu juese sheji: Li Jiachang, Li Kangqi",
				"zh_Hans": "美术资源与地图设计：王百树，张书睿\nUI与游玩效果调节：李承航，袁苡瑞\n关卡与角色设计：李嘉昌，李康齐",
				"zh_Hant": "美術資源與地圖設計：王百樹，張書睿\nUI與遊玩效果調節：李承航，袁苡瑞\n關卡與角色設計：李嘉昌，李康齊"
			}
		}
	]

func _find_entry(entries: Array[Dictionary], entry_id: String) -> Dictionary:
	for entry in entries:
		if String(entry.get("id", "")) == entry_id:
			return entry
	return {}

func _localized_tag_list(tags_raw: Array) -> String:
	var parts: Array[String] = []
	for raw_tag in tags_raw:
		var tag := String(raw_tag)
		var localized: Dictionary = TAG_LABELS.get(tag, {}) as Dictionary
		if not localized.is_empty():
			parts.append(String(localized.get(_current_locale(), localized.get("en", tag.capitalize()))))
		else:
			parts.append(tag.capitalize())
	return ", ".join(parts)

func _format_accessory_effects(effects: Dictionary, limit: int = 2) -> String:
	var keys := effects.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return absf(float(effects.get(String(a), 0.0))) > absf(float(effects.get(String(b), 0.0)))
	)
	var parts: Array[String] = []
	for index in range(mini(limit, keys.size())):
		var effect_key := String(keys[index])
		parts.append(_format_accessory_effect(effect_key, float(effects.get(effect_key, 0.0))))
	return "  |  ".join(parts)

func _format_accessory_effect(effect_key: String, value: float) -> String:
	var label_map: Dictionary = EFFECT_LABELS.get(effect_key, {}) as Dictionary
	var label := effect_key
	if not label_map.is_empty():
		label = String(label_map.get(_current_locale(), label_map.get("en", effect_key)))
	if effect_key == "attack_interval_pct" or effect_key == "skill_cooldown_pct":
		var percent := int(round(absf(value) * 100.0))
		if value < 0.0:
			return _locale_text("%d%% faster %s", "%d%% 更快的%s", "%d%% 更快的%s") % [percent, label]
		return _locale_text("%d%% slower %s", "%d%% 更慢的%s", "%d%% 更慢的%s") % [percent, label]
	if effect_key == "skill_cost_pct":
		var percent_value := int(round(absf(value) * 100.0))
		if value < 0.0:
			return _locale_text("%d%% lower %s", "%d%% 更低的%s", "%d%% 更低的%s") % [percent_value, label]
		return _locale_text("%d%% higher %s", "%d%% 更高的%s", "%d%% 更高的%s") % [percent_value, label]
	if effect_key.ends_with("_pct") or effect_key == "crit_rate":
		var pct := int(round(value * 100.0))
		return "%+d%% %s" % [pct, label]
	return "%+d %s" % [int(round(value)), label]

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
