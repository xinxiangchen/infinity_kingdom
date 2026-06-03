extends CanvasLayer

signal event_choice_made(choice_id: String)

const RunEffects := preload("res://systems/run/run_effects.gd")
const UICardFx := preload("res://ui/ui_card_fx.gd")
const UISkin := preload("res://ui/ui_skin.gd")

const PANEL_MIN_SIZE := Vector2(340.0, 400.0)
const PANEL_MAX_SIZE := Vector2(1080.0, 640.0)
const CARD_GAP := 12.0
const SERVICE_BACKGROUND_PATHS := {
	"church": "res://assets/ui/background/church_bg.png",
	"armory": "res://assets/maps/stitched_demo/room_10_palace_hall.png",
	"shop": "res://assets/ui/shop/shop_panel.png"
}

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
	backdrop.color = Color(0.015, 0.018, 0.026, 0.74)
	panel.add_theme_stylebox_override("panel", UISkin.menu_panel_style())
	context_panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	_apply_heading(kind)
	active_default_detail = _default_detail_for_kind(kind)
	for choice in _choices_for_kind(kind, gold):
		choice_row.add_child(_choice_card_from_data(choice, gold))
	detail_label.text = active_default_detail
	footer_label.text = _footer_text_for_kind(kind)
	_refresh_layout()
	call_deferred("_focus_first_choice")

func _apply_heading(kind: String) -> void:
	match kind:
		"services":
			title_label.text = _locale_text("Town Crossroads", "城镇岔路", "城鎮岔路")
			subtitle_label.text = _locale_text(
				"One stop before the palace route. Pick church, armory, or shop.",
				"进入皇宫路线前的最后补给点。教堂、军需库、商店三选一。",
				"進入皇宮路線前的最後補給點。教堂、軍需庫、商店三選一。"
			)
		"shop":
			title_label.text = _locale_text("Black Market", "商店", "商店")
			subtitle_label.text = _locale_text(
				"Spend gold only where it sharpens the next fight.",
				"只在能明显改善下一战的地方花钱。",
				"只在能明顯改善下一戰的地方花錢。"
			)
		"bounty":
			title_label.text = _locale_text("Bounty Board", "悬赏栏", "懸賞欄")
			subtitle_label.text = _locale_text(
				"Take coin now, or stack stronger payouts for later.",
				"现在拿钱，或把后续战斗的收益做高。",
				"現在拿錢，或把後續戰鬥的收益做高。"
			)
		"rest":
			title_label.text = _locale_text("Church Refuge", "教堂休整", "教堂休整")
			subtitle_label.text = _locale_text(
				"Recover before the next encounter.",
				"在下一场遭遇前整理状态。",
				"在下一場遭遇前整理狀態。"
			)
		"training":
			title_label.text = _locale_text("Training Drill", "训练场", "訓練場")
			subtitle_label.text = _locale_text(
				"Choose one clean long-term stat lane.",
				"选择一条长期稳定收益路线。",
				"選擇一條長期穩定收益路線。"
			)
		"forge":
			title_label.text = _locale_text("Ember Forge", "锻造台", "鍛造台")
			subtitle_label.text = _locale_text(
				"Take one hybrid upgrade shaped around the current build.",
				"根据当前构筑拿一项更完整的复合强化。",
				"根據當前構築拿一項更完整的複合強化。"
			)
		"pact":
			title_label.text = _locale_text("Forbidden Pact", "禁忌契约", "禁忌契約")
			subtitle_label.text = _locale_text(
				"Sharp power now, permanent tradeoff after.",
				"现在拿锋利收益，之后承担永久代价。",
				"現在拿鋒利收益，之後承擔永久代價。"
			)
		"attunement":
			title_label.text = _locale_text("Relic Resonance", "饰品共鸣", "飾品共鳴")
			subtitle_label.text = _locale_text(
				"Deepen the line your current relic already points toward.",
				"继续加深当前饰品已经指向的路线。",
				"繼續加深當前飾品已經指向的路線。"
			)
		"scout":
			title_label.text = _locale_text("Scout Report", "侦查情报", "偵查情報")
			subtitle_label.text = _locale_text(
				"Take one opener tuned for the very next arena.",
				"只为下一张战场拿一项开局方案。",
				"只為下一張戰場拿一項開局方案。"
			)
		_:
			title_label.text = _locale_text("Travel", "旅途", "旅途")
			subtitle_label.text = _locale_text(
				"Move on when you are ready.",
				"准备好后继续前进。",
				"準備好後繼續前進。"
			)

func _choices_for_kind(kind: String, gold: int) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	match kind:
		"services":
			var church_id := _recommended_church_choice()
			var armory_id := _recommended_armory_choice()
			var shop_id := _recommended_shop_choice(gold)
			choices.append(_service_choice(
				church_id,
				_locale_text("Church", "教堂", "教堂"),
				RunEffects.card_summary(church_id),
				"res://assets/ui/consumable/protective_candle.png",
				Color(0.78, 0.96, 0.82),
				_locale_text("Recovery", "恢复", "恢復"),
				String(SERVICE_BACKGROUND_PATHS["church"])
			))
			choices.append(_service_choice(
				armory_id,
				_locale_text("Armory", "军需库", "軍需庫"),
				RunEffects.card_summary(armory_id),
				"res://assets/ui/icon/ui_shield.png",
				Color(0.76, 0.86, 1.0),
				_locale_text("Permanent", "长期强化", "長期強化"),
				String(SERVICE_BACKGROUND_PATHS["armory"])
			))
			choices.append(_service_choice(
				shop_id,
				_locale_text("Shop", "商店", "商店"),
				RunEffects.card_summary(shop_id),
				"res://assets/ui/icon/ui_shop.png",
				Color(1.0, 0.86, 0.56),
				_locale_text("Purchase", "购买", "購買"),
				String(SERVICE_BACKGROUND_PATHS["shop"])
			))
		"shop":
			choices = [
				_simple_choice("shop_attack", "res://assets/ui/consumable/sharpening_oil.png", gold),
				_simple_choice("shop_defense", "res://assets/ui/consumable/light_armor_pack.png", gold),
				_simple_choice("shop_relic", "res://assets/ui/icon/ui_shop.png", gold),
				_skip_choice(
					_locale_text("Save Gold", "保留金币", "保留金幣"),
					_locale_text("Keep your gold for a later stop.", "把金币留给后面的节点。", "把金幣留給後面的節點。"),
					"res://assets/ui/icon/currency_gold_pixel.png"
				)
			]
		"bounty":
			choices = [
				_simple_choice("bounty_cache", "res://assets/ui/icon/currency_gold_pixel.png", gold),
				_simple_choice("bounty_contract", "res://assets/ui/icon/ui_shop.png", gold),
				_simple_choice("bounty_tithe", "res://assets/ui/trait/trait_execute.png", gold),
				_skip_choice(
					_locale_text("Walk Past", "直接离开", "直接離開"),
					_locale_text("Keep the build unchanged and move on.", "不改构筑，直接继续。", "不改構築，直接繼續。"),
					"res://assets/ui/icon/ui_back.png"
				)
			]
		"rest":
			choices = [
				_simple_choice("rest_heal", "res://assets/ui/consumable/medkit.png", gold),
				_simple_choice("rest_focus", "res://assets/ui/consumable/protective_candle.png", gold),
				_simple_choice("rest_repair", "res://assets/ui/icon/ui_shield.png", gold),
				_skip_choice(
					_locale_text("Push Forward", "继续前进", "繼續前進"),
					_locale_text("Skip recovery and keep the tempo.", "跳过恢复，保留节奏。", "跳過恢復，保留節奏。"),
					"res://assets/ui/icon/ui_check.png"
				)
			]
		"training":
			choices = [
				_simple_choice("train_crit", "res://assets/ui/trait/trait_crit.png", gold),
				_simple_choice("train_speed", "res://assets/ui/icon/stat_speed_pixel.png", gold),
				_simple_choice("train_cooldown", "res://assets/ui/icon/stat_cooldown_pixel.png", gold),
				_simple_choice("train_resource", "res://assets/ui/icon/stat_mana_pixel.png", gold),
				_skip_choice(
					_locale_text("Leave the Yard", "离开训练场", "離開訓練場"),
					_locale_text("Keep the current build unchanged.", "保持当前构筑不变。", "保持當前構築不變。"),
					"res://assets/ui/icon/ui_back.png"
				)
			]
		"forge":
			for choice in RunEffects.forge_choices(_current_actor()):
				choices.append(_choice_from_catalog(choice))
			choices.append(_skip_choice(
				_locale_text("Leave the Forge", "离开锻造台", "離開鍛造台"),
				_locale_text("Lock the current build and move on.", "保持当前构筑继续前进。", "保持當前構築繼續前進。"),
				"res://assets/ui/icon/ui_back.png"
			))
		"pact":
			choices = [
				_simple_choice("pact_power", "res://assets/ui/trait/trait_damage.png", gold),
				_simple_choice("pact_guard", "res://assets/ui/icon/ui_shield.png", gold),
				_simple_choice("pact_focus", "res://assets/ui/icon/ui_mana_flame.png", gold),
				_skip_choice(
					_locale_text("Refuse", "拒绝", "拒絕"),
					_locale_text("Leave without changing the build.", "不改变构筑直接离开。", "不改變構築直接離開。"),
					"res://assets/ui/icon/ui_back.png"
				)
			]
		"attunement":
			for choice in RunEffects.attunement_choices():
				choices.append(_choice_from_catalog(choice))
			choices.append(_skip_choice(
				_locale_text("Leave It Still", "维持原样", "維持原樣"),
				_locale_text("Keep the current relic identity unchanged.", "保持当前饰品路线不变。", "保持當前飾品路線不變。"),
				"res://assets/ui/icon/ui_back.png"
			))
		"scout":
			for choice in RunEffects.scout_choices():
				choices.append(_choice_from_catalog(choice))
			choices.append(_skip_choice(
				_locale_text("Ignore the Report", "忽略报告", "忽略報告"),
				_locale_text("Fight the next arena without extra preparation.", "下一战不做额外准备。", "下一戰不做額外準備。"),
				"res://assets/ui/icon/ui_back.png"
			))
		_:
			choices = [
				_skip_choice(
					_locale_text("Continue", "继续", "繼續"),
					_locale_text("Move to the next encounter.", "前往下一场遭遇。", "前往下一場遭遇。"),
					"res://assets/ui/icon/ui_check.png"
				)
			]
	return choices

func _choice_from_catalog(choice: Dictionary) -> Dictionary:
	return {
		"id": String(choice.get("id", "")),
		"title": String(choice.get("title", "Choice")),
		"summary": String(choice.get("summary", "")),
		"icon": String(choice.get("icon", "res://assets/ui/icon/ui_unknown.png")),
		"cost": int(choice.get("cost", 0))
	}

func _simple_choice(choice_id: String, icon_path: String, gold: int) -> Dictionary:
	return {
		"id": choice_id,
		"title": RunEffects.display_name(choice_id),
		"summary": RunEffects.card_summary(choice_id),
		"icon": icon_path,
		"cost": RunEffects.cost_for(choice_id),
		"disabled": RunEffects.cost_for(choice_id) > gold
	}

func _skip_choice(title: String, summary: String, icon_path: String) -> Dictionary:
	return {
		"id": "skip",
		"title": title,
		"summary": summary,
		"icon": icon_path,
		"cost": 0
	}

func _service_choice(choice_id: String, place_name: String, summary: String, icon_path: String, badge_color: Color, timing_label: String, background_path: String = "") -> Dictionary:
	return {
		"id": choice_id,
		"title": place_name,
		"summary": summary,
		"icon": icon_path,
		"cost": RunEffects.cost_for(choice_id),
		"meta_type": place_name,
		"meta_timing": timing_label,
		"meta_color": badge_color,
		"fit_title": RunEffects.display_name(choice_id),
		"background": background_path
	}

func _choice_card_from_data(choice: Dictionary, gold: int) -> Button:
	var choice_id := String(choice.get("id", ""))
	var title := String(choice.get("title", "Choice"))
	var summary := String(choice.get("summary", ""))
	var icon_path := String(choice.get("icon", "res://assets/ui/icon/ui_unknown.png"))
	var cost := int(choice.get("cost", 0))
	return _choice_card(choice_id, title, summary, icon_path, cost, gold, choice)

func _choice_card(choice_id: String, title: String, summary: String, icon_path: String, cost: int, gold: int, meta_source: Dictionary = {}) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(236.0, 274.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.disabled = bool(meta_source.get("disabled", false)) or cost > gold
	button.add_theme_stylebox_override("normal", UISkin.choice_panel_style())
	button.add_theme_stylebox_override("hover", UISkin.flat_style(Color(0.20, 0.22, 0.26, 0.98), UISkin.COLOR_ACCENT, 2, 4, Vector4(16, 14, 16, 14)))
	button.add_theme_stylebox_override("pressed", UISkin.flat_style(Color(0.12, 0.13, 0.16, 1.0), UISkin.COLOR_ACCENT.darkened(0.18), 2, 4, Vector4(16, 14, 16, 14)))
	button.add_theme_stylebox_override("disabled", UISkin.flat_style(Color(0.12, 0.13, 0.15, 0.72), Color(0.34, 0.36, 0.40, 0.8), 1, 4, Vector4(16, 14, 16, 14)))
	button.set_meta("choice_id", choice_id)
	button.set_meta("choice_title", title)
	button.set_meta("choice_summary", summary)
	button.set_meta("choice_cost", cost)
	choice_buttons.append(button)

	var tilt_root := UICardFx.install(button, {
		"active_scale": 1.024,
		"rotation_max": 2.4,
		"float_offset": Vector2(5.0, 3.0),
		"sheen_alpha": 0.10
	})

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 16
	margin.offset_top = 16
	margin.offset_right = -16
	margin.offset_bottom = -16
	tilt_root.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var meta := _choice_meta(choice_id, cost, meta_source)
	var fit_data := RunEffects.evaluate_choice(choice_id, _current_actor()) if choice_id != "skip" else {}

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 6)
	box.add_child(badge_row)
	badge_row.add_child(_badge(String(meta.get("type", "Choice")), meta.get("color", Color(0.82, 0.86, 0.96))))

	var fit_label := String(meta_source.get("meta_timing", fit_data.get("label", meta.get("timing", "Now"))))
	if _current_locale() != "en":
		fit_label = _localized_fit_label(fit_label)
	badge_row.add_child(_badge(fit_label, meta.get("timing_color", Color(0.92, 0.84, 0.66))))

	var background_path := String(meta_source.get("background", ""))
	var scenic_card := not background_path.is_empty()
	if not scenic_card:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(88.0, 88.0)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
		box.add_child(slot)

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(icon_path) as Texture2D
		slot.add_child(icon)
	else:
		var scene_slot := PanelContainer.new()
		scene_slot.custom_minimum_size = Vector2(0.0, 104.0)
		scene_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scene_slot.clip_contents = true
		scene_slot.add_theme_stylebox_override("panel", UISkin.icon_slot_style())
		box.add_child(scene_slot)

		var background_texture := TextureRect.new()
		background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background_texture.texture = load(background_path) as Texture2D
		background_texture.modulate = Color(1.0, 1.0, 1.0, 0.96)
		scene_slot.add_child(background_texture)

		var top_shade := ColorRect.new()
		top_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		top_shade.color = Color(0.04, 0.05, 0.07, 0.18)
		scene_slot.add_child(top_shade)

		var bottom_shade := ColorRect.new()
		bottom_shade.anchor_top = 0.52
		bottom_shade.anchor_right = 1.0
		bottom_shade.anchor_bottom = 1.0
		bottom_shade.grow_horizontal = Control.GROW_DIRECTION_BOTH
		bottom_shade.grow_vertical = Control.GROW_DIRECTION_BOTH
		bottom_shade.color = Color(0.02, 0.03, 0.05, 0.48)
		scene_slot.add_child(bottom_shade)

		var place_label := Label.new()
		place_label.position = Vector2(12.0, 10.0)
		place_label.text = title
		UISkin.label(place_label, 12, Color(0.98, 0.92, 0.76))
		scene_slot.add_child(place_label)

		var icon_chip := PanelContainer.new()
		icon_chip.position = Vector2(12.0, 62.0)
		icon_chip.custom_minimum_size = Vector2(34.0, 34.0)
		icon_chip.add_theme_stylebox_override("panel", UISkin.flat_style(Color(0.06, 0.08, 0.12, 0.84), Color(0.96, 0.90, 0.66, 0.74), 1, 5))
		scene_slot.add_child(icon_chip)

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(icon_path) as Texture2D
		icon_chip.add_child(icon)

	if not scenic_card:
		var title_text := Label.new()
		title_text.text = title
		title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UISkin.label(title_text, 18, Color.WHITE)
		box.add_child(title_text)

	if not scenic_card:
		var summary_label := Label.new()
		summary_label.text = summary
		summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_label.custom_minimum_size = Vector2(0.0, 72.0)
		summary_label.max_lines_visible = 4
		UISkin.label(summary_label, 13, Color(0.78, 0.84, 0.92))
		box.add_child(summary_label)

	if meta_source.has("fit_title"):
		var fit_title_label := Label.new()
		fit_title_label.text = String(meta_source.get("fit_title", ""))
		fit_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UISkin.label(fit_title_label, 12, Color(0.98, 0.90, 0.66))
		box.add_child(fit_title_label)

	var cost_label := Label.new()
	cost_label.text = _locale_text("Free", "免费", "免費") if cost <= 0 else _locale_text("Cost %d Gold", "花费 %d 金币", "花費 %d 金幣") % cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UISkin.label(cost_label, 13, Color(1.0, 0.86, 0.55) if not button.disabled else Color(0.72, 0.54, 0.48))
	box.add_child(cost_label)

	UISkin.ignore_mouse_recursive(margin)
	UICardFx.bind(button, func() -> void:
		_preview_choice(choice_id, title, summary, cost, button.disabled, meta_source)
	)
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
			KEY_5, KEY_KP_5:
				_activate_choice_index(4)
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
	var equipped_accessory := AccessoryManager.get_equipped_accessory() if AccessoryManager != null else {}
	var accessory_name := String(equipped_accessory.get("name", _locale_text("No Relic", "无饰品", "無飾品")))
	var tags_text := AccessoryManager.describe_tags(equipped_accessory.get("tags", [])) if AccessoryManager != null else ""
	var route_preview := RunDirector.describe_event_route(4) if RunDirector != null else ""
	build_summary_label.text = "%s %d  |  %s %s%s" % [
		_locale_text("Gold", "金币", "金幣"),
		gold,
		_locale_text("Relic", "饰品", "飾品"),
		accessory_name,
		("  |  %s" % tags_text) if not tags_text.is_empty() else ""
	]
	rule_summary_label.text = "%s\n%s %s" % [
		_rule_summary_for_kind(kind),
		_locale_text("Route", "路线", "路線"),
		route_preview
	]

func _rule_summary_for_kind(kind: String) -> String:
	match kind:
		"services":
			return _locale_text(
				"This stop appears only after the town stretch. Choose one service before entering the palace route.",
				"这个补给点只会出现在城镇段之后。进入皇宫路线前，只能拿一项服务。",
				"這個補給點只會出現在城鎮段之後。進入皇宮路線前，只能拿一項服務。"
			)
		"shop":
			return _locale_text(
				"Buy one focused upgrade now. Gold spent here is gone immediately.",
				"现在买一项明确强化，这里花掉的金币会立刻结算。",
				"現在買一項明確強化，這裡花掉的金幣會立刻結算。"
			)
		"bounty":
			return _locale_text(
				"Bounties shape your economy. Some pay now, some pay through later fights.",
				"悬赏会改你的经济曲线，有的给现钱，有的给后续收益。",
				"懸賞會改你的經濟曲線，有的給現錢，有的給後續收益。"
			)
		"rest":
			return _locale_text(
				"Recovery resolves immediately and does not change your long-term route.",
				"恢复会立刻生效，不会改变长期路线。",
				"恢復會立刻生效，不會改變長期路線。"
			)
		"training":
			return _locale_text(
				"Training is a permanent lane for the rest of the run.",
				"训练是本局剩余流程的永久路线。",
				"訓練是本局剩餘流程的永久路線。"
			)
		"forge":
			return _locale_text(
				"The forge offers mixed permanent upgrades tuned to the current build.",
				"锻造给的是更贴着当前构筑的复合永久强化。",
				"鍛造給的是更貼著當前構築的複合永久強化。"
			)
		"pact":
			return _locale_text(
				"Pacts are permanent. They raise power now and reshape future fights.",
				"契约是永久性的，现在变强，之后一直承担代价。",
				"契約是永久性的，現在變強，之後一直承擔代價。"
			)
		"attunement":
			return _locale_text(
				"Attunement follows your current relic identity and lasts the whole run.",
				"共鸣会顺着当前饰品路线继续放大，持续到本局结束。",
				"共鳴會順著當前飾品路線繼續放大，持續到本局結束。"
			)
		"scout":
			return _locale_text(
				"Scout routes are short spikes aimed at the very next arena.",
				"侦查路线只强化下一张战场。",
				"偵查路線只強化下一張戰場。"
			)
		_:
			return _locale_text("Move on when you are ready.", "准备好后继续前进。", "準備好後繼續前進。")

func _default_detail_for_kind(kind: String) -> String:
	match kind:
		"services":
			return _locale_text(
				"Church is the cleanest recovery, armory is the best long-term polish, and shop converts gold into a sharper route.",
				"教堂最适合补状态，军需库最适合补长期强度，商店则把金币换成更锋利的路线。",
				"教堂最適合補狀態，軍需庫最適合補長期強度，商店則把金幣換成更鋒利的路線。"
			)
		"shop":
			return _locale_text(
				"Buy only if it clearly sharpens the next checkpoint. Saving gold keeps later options open.",
				"只有在它能明显改善下一个检定时才值得买；不买就保留后手。",
				"只有在它能明顯改善下一個檢定時才值得買；不買就保留後手。"
			)
		"bounty":
			return _locale_text(
				"Take cash now if rerolls or purchases are coming. Contracts get better when more fights remain.",
				"如果后面准备重抽或购物，就先拿现钱；剩余战斗越多，长期契约越值。",
				"如果後面準備重抽或購物，就先拿現錢；剩餘戰鬥越多，長期契約越值。"
			)
		"rest":
			return _locale_text(
				"Heal if survival is shaky, or refill defense and inspiration if the build is already stable.",
				"生存吃紧就补血，构筑稳定时就补护甲和灵感。",
				"生存吃緊就補血，構築穩定時就補護甲和靈感。"
			)
		"training":
			return _locale_text(
				"Pick the lane your hero and relic already reward.",
				"优先强化角色与饰品已经在奖励的方向。",
				"優先強化角色與飾品已經在獎勵的方向。"
			)
		"forge":
			return _locale_text(
				"Use forge options to cover a weakness or lock in a winning lane.",
				"锻造适合补短板，或者把已经成型的路线彻底定住。",
				"鍛造適合補短板，或者把已經成型的路線徹底定住。"
			)
		"pact":
			return _locale_text(
				"Look for the drawback your current hero can absorb best.",
				"优先选当前角色扛得住代价的那一项。",
				"優先選當前角色扛得住代價的那一項。"
			)
		"attunement":
			return _locale_text(
				"Resonance is the cleanest way to reinforce your current relic identity.",
				"共鸣最适合继续放大当前饰品路线。",
				"共鳴最適合繼續放大當前飾品路線。"
			)
		"scout":
			return _locale_text(
				"Choose aggression, stability, or skill tempo for the next arena only.",
				"只为下一战选择进攻、稳健或技能节奏。",
				"只為下一戰選擇進攻、穩健或技能節奏。"
			)
		_:
			return _locale_text("Choose a path and continue.", "选好路线后继续。", "選好路線後繼續。")

func _footer_text_for_kind(kind: String) -> String:
	var count := mini(maxi(choice_row.get_child_count(), 1), 5)
	var lead := _locale_text("1-%d choose", "1-%d 选择", "1-%d 選擇") % count
	if _has_skip_choice():
		lead += _locale_text("  |  Esc skip", "  |  Esc 跳过", "  |  Esc 跳過")
	match kind:
		"services":
			return lead + _locale_text(
				"  |  This stop happens once before the palace route.",
				"  |  这是进入皇宫路线前唯一一次三选一服务点。",
				"  |  這是進入皇宮路線前唯一一次三選一服務點。"
			)
		"scout":
			return lead + _locale_text(
				"  |  Scout prep expires after the next encounter.",
				"  |  侦查预备会在下一战结束后消失。",
				"  |  偵查預備會在下一戰結束後消失。"
			)
		"shop":
			return lead + _locale_text("  |  Gold is spent immediately.", "  |  金币会立刻扣除。", "  |  金幣會立刻扣除。")
		_:
			return lead + _locale_text("  |  Effects apply immediately.", "  |  选中后会立刻生效。", "  |  選中後會立刻生效。")

func _preview_choice(choice_id: String, title: String, summary: String, cost: int, disabled: bool, meta_source: Dictionary = {}) -> void:
	var fit_data := RunEffects.evaluate_choice(choice_id, _current_actor()) if choice_id != "skip" else {}
	var fit_label := String(meta_source.get("fit_title", ""))
	if fit_label.is_empty():
		fit_label = String(fit_data.get("label", _locale_text("Flexible", "可用", "可用")))
		if _current_locale() != "en":
			fit_label = _localized_fit_label(fit_label)
	var cost_text := _locale_text("Free", "免费", "免費") if cost <= 0 else _locale_text("Cost %d Gold", "花费 %d 金币", "花費 %d 金幣") % cost
	if disabled:
		cost_text = _locale_text("Not enough gold yet.", "当前金币不足。", "當前金幣不足。")
	detail_label.text = "%s\n%s: %s\n%s\n%s" % [
		title,
		_locale_text("Fit", "契合度", "契合度"),
		fit_label,
		summary,
		cost_text
	]

func _focus_first_choice() -> void:
	for child in choice_row.get_children():
		if child is Button and not (child as Button).disabled:
			var button := child as Button
			button.grab_focus()
			_preview_choice(
				String(button.get_meta("choice_id", "")),
				String(button.get_meta("choice_title", "")),
				String(button.get_meta("choice_summary", "")),
				int(button.get_meta("choice_cost", 0)),
				button.disabled
			)
			return
	for child in choice_row.get_children():
		if child is Button:
			var button := child as Button
			button.grab_focus()
			_preview_choice(
				String(button.get_meta("choice_id", "")),
				String(button.get_meta("choice_title", "")),
				String(button.get_meta("choice_summary", "")),
				int(button.get_meta("choice_cost", 0)),
				button.disabled
			)
			return

func _choice_meta(choice_id: String, cost: int, meta_source: Dictionary = {}) -> Dictionary:
	var meta := {
		"type": _locale_text("Choice", "选择", "選擇"),
		"timing": _locale_text("Now", "当前", "當前"),
		"detail": _locale_text("Updates the current run path.", "会影响当前本局路线。", "會影響當前本局路線。"),
		"color": Color(0.76, 0.84, 0.96),
		"timing_color": Color(0.92, 0.84, 0.66)
	}
	if meta_source.has("meta_type"):
		meta["type"] = String(meta_source.get("meta_type", meta["type"]))
	if meta_source.has("meta_color"):
		meta["color"] = meta_source.get("meta_color", meta["color"])
	if choice_id == "skip":
		meta["type"] = _locale_text("Skip", "跳过", "跳過")
		meta["timing"] = _locale_text("No Cost", "无消耗", "無消耗")
		meta["detail"] = _locale_text(
			"Keeps the current build unchanged and moves the run forward.",
			"保持当前构筑不变，继续推进流程。",
			"保持當前構築不變，繼續推進流程。"
		)
		meta["color"] = Color(0.72, 0.78, 0.88)
		meta["timing_color"] = Color(0.76, 0.82, 0.90)
	elif choice_id.begins_with("shop_"):
		meta["type"] = _locale_text("Purchase", "购买", "購買")
		meta["timing"] = _locale_text("Run Bonus", "本局增益", "本局增益") if choice_id != "shop_relic" else _locale_text("Next Relic", "下一件饰品", "下一件飾品")
		meta["detail"] = _locale_text(
			"Spends gold now for a lasting upgrade.",
			"现在花金币，换取持续到本局结束的强化。",
			"現在花金幣，換取持續到本局結束的強化。"
		)
		meta["color"] = Color(1.0, 0.86, 0.56)
	elif choice_id.begins_with("bounty_"):
		meta["type"] = _locale_text("Bounty", "悬赏", "懸賞")
		meta["timing"] = _locale_text("Economy", "经济", "經濟")
		meta["color"] = Color(1.0, 0.82, 0.50)
	elif choice_id.begins_with("rest_"):
		meta["type"] = _locale_text("Recovery", "恢复", "恢復")
		meta["timing"] = _locale_text("Instant", "即时", "即時")
		meta["color"] = Color(0.78, 0.96, 0.82)
	elif choice_id.begins_with("train_"):
		meta["type"] = _locale_text("Training", "训练", "訓練")
		meta["timing"] = _locale_text("Permanent", "永久", "永久")
		meta["color"] = Color(0.78, 0.90, 1.0)
	elif choice_id.begins_with("forge_"):
		meta["type"] = _locale_text("Forge", "锻造", "鍛造")
		meta["timing"] = _locale_text("Permanent", "永久", "永久")
		meta["color"] = Color(1.0, 0.78, 0.58)
	elif choice_id.begins_with("pact_"):
		meta["type"] = _locale_text("Pact", "契约", "契約")
		meta["timing"] = _locale_text("Tradeoff", "代价", "代價")
		meta["color"] = Color(1.0, 0.74, 0.66)
	elif choice_id.begins_with("scout_"):
		meta["type"] = _locale_text("Scout", "侦查", "偵查")
		meta["timing"] = _locale_text("Next Fight", "下一战", "下一戰")
		meta["color"] = Color(0.80, 0.96, 0.90)
	elif choice_id.begins_with("attune_"):
		meta["type"] = _locale_text("Attunement", "共鸣", "共鳴")
		meta["timing"] = _locale_text("Permanent", "永久", "永久")
		meta["color"] = Color(0.88, 0.76, 1.0)
	if cost > 0:
		meta["timing"] = _locale_text("Cost %d", "花费 %d", "花費 %d") % cost
	return meta

func _recommended_church_choice() -> String:
	var actor := _current_actor()
	if actor == null:
		return "rest_focus"
	var hp_ratio := _actor_ratio(actor, "hp", "max_hp")
	if hp_ratio <= 0.58:
		return "rest_heal"
	var defense_ratio := _actor_ratio(actor, "defense", "max_defense")
	var inspiration_ratio := _actor_ratio(actor, "inspiration", "max_inspiration")
	if defense_ratio <= 0.42 or inspiration_ratio <= 0.45:
		return "rest_focus"
	return "rest_repair"

func _recommended_armory_choice() -> String:
	var actor := _current_actor()
	var candidates := ["forge_guard", "forge_edge", "forge_focus", "forge_flow", "forge_seal"]
	var best_choice := "forge_guard"
	var best_score := -9999.0
	for choice_id in candidates:
		var fit_data := RunEffects.evaluate_choice(choice_id, actor)
		var score := _fit_score(String(fit_data.get("label", "Flexible")))
		if score > best_score:
			best_score = score
			best_choice = choice_id
	return best_choice

func _recommended_shop_choice(gold: int) -> String:
	var actor := _current_actor()
	var candidates := ["shop_relic", "shop_attack", "shop_defense"]
	var best_choice := "shop_relic"
	var best_score := -9999.0
	for choice_id in candidates:
		if RunEffects.cost_for(choice_id) > gold and gold > 0:
			continue
		var fit_data := RunEffects.evaluate_choice(choice_id, actor)
		var score := _fit_score(String(fit_data.get("label", "Flexible")))
		if choice_id == "shop_relic":
			score += 0.2
		if score > best_score:
			best_score = score
			best_choice = choice_id
	return best_choice

func _fit_score(label_text: String) -> float:
	match label_text:
		"Best Now":
			return 3.0
		"Strong Fit":
			return 2.0
		"Flexible":
			return 1.0
		"Hold":
			return 0.5
		"Risky":
			return -1.0
		_:
			return 0.0

func _current_actor() -> Node:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get("player_character") if scene_root.has_method("get") else null

func _actor_ratio(actor: Node, current_field: String, max_field: String) -> float:
	if actor == null or not is_instance_valid(actor):
		return 1.0
	var has_current := false
	var has_max := false
	for property in actor.get_property_list():
		var name := String(property.get("name", ""))
		if name == current_field:
			has_current = true
		elif name == max_field:
			has_max = true
	if not has_current or not has_max:
		return 1.0
	var max_value := float(actor.get(max_field))
	if max_value <= 0.0:
		return 1.0
	return clampf(float(actor.get(current_field)) / max_value, 0.0, 1.0)

func _has_skip_choice() -> bool:
	for button in choice_buttons:
		if button != null and String(button.get_meta("choice_id", "")) == "skip":
			return true
	return false

func _badge(text_value: String, color_value: Color) -> PanelContainer:
	var panel_value := PanelContainer.new()
	panel_value.add_theme_stylebox_override("panel", UISkin.flat_style(color_value.darkened(0.76), color_value, 1, 5))
	var label_value := Label.new()
	label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_value.text = text_value
	UISkin.label(label_value, 10, color_value.lightened(0.12))
	panel_value.add_child(label_value)
	return panel_value

func _refresh_layout() -> void:
	if panel == null or choice_row == null:
		return
	var viewport_size := layout_size_override
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO and get_window() != null:
		viewport_size = Vector2(get_window().size)
	var compact := viewport_size.x < 980.0 or viewport_size.y < 700.0
	var very_compact := viewport_size.x < 760.0 or viewport_size.y < 600.0
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
		footer_label.text = _locale_text("1-%d choose", "1-%d 选择", "1-%d 選擇") % mini(maxi(choice_row.get_child_count(), 1), 5)
		if _has_skip_choice():
			footer_label.text += _locale_text("  |  Esc skip", "  |  Esc 跳过", "  |  Esc 跳過")
	var card_width := 196.0 if very_compact else (224.0 if compact else 236.0)
	var card_height := 204.0 if very_compact else (252.0 if compact else 274.0)
	if active_kind == "services":
		card_height = 214.0 if very_compact else (264.0 if compact else 300.0)
	var available_width := maxf(choice_scroll.size.x, panel.custom_minimum_size.x - (56.0 if very_compact else 96.0))
	var max_columns := 3 if active_kind == "services" else (3 if compact else 4)
	if active_kind == "services":
		max_columns = 3
	var next_columns := clampi(int(floor((available_width + CARD_GAP) / (card_width + CARD_GAP))), 1, max_columns)
	choice_row.columns = max(1, min(next_columns, max(choice_row.get_child_count(), 1)))
	for child in choice_row.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(card_width, card_height)

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

func _localized_fit_label(label_text: String) -> String:
	match label_text:
		"Best Now":
			return _locale_text("Best Now", "当前最优", "當前最優")
		"Strong Fit":
			return _locale_text("Strong Fit", "高度契合", "高度契合")
		"Flexible":
			return _locale_text("Flexible", "灵活可拿", "靈活可拿")
		"Risky":
			return _locale_text("Risky", "风险较高", "風險較高")
		"Hold":
			return _locale_text("Hold", "先保留", "先保留")
		"Recovery":
			return _locale_text("Recovery", "恢复", "恢復")
		"Permanent":
			return _locale_text("Permanent", "长期强化", "長期強化")
		"Purchase":
			return _locale_text("Purchase", "购买", "購買")
		_:
			return label_text
