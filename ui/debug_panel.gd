extends CanvasLayer

const UISkin := preload("res://ui/ui_skin.gd")

@onready var root_margin: MarginContainer = $MarginContainer
@onready var panel: PanelContainer = $MarginContainer/PanelContainer
@onready var label: Label = $MarginContainer/PanelContainer/MarginContainer/Label

var target_world: Node = null
var layout_size_override: Vector2 = Vector2.ZERO
var content_stack: VBoxContainer = null
var upgrade_title_label: Label = null
var upgrade_action_row: HBoxContainer = null
var clear_upgrades_button: Button = null
var upgrade_scroll: ScrollContainer = null
var upgrade_list: VBoxContainer = null
var active_upgrade_target: Node = null
var upgrade_buttons: Array[Button] = []

func _ready() -> void:
	layer = 40
	visible = false
	panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	_build_upgrade_ui()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_queue_layout_refresh):
		get_viewport().size_changed.connect(_queue_layout_refresh)
	_queue_layout_refresh()

func bind_world(world: Node) -> void:
	target_world = world

func toggle() -> void:
	visible = not visible

func _process(_delta: float) -> void:
	if not visible or target_world == null or not is_instance_valid(target_world):
		return
	var player: Node = target_world.player_character
	if player != active_upgrade_target:
		_rebuild_upgrade_controls(player)
	var encounter: Node = target_world.current_encounter
	var lines := PackedStringArray()
	lines.append("Debug")
	lines.append("Gold: %d | Cleared: %d" % [int(RunDirector.gold), int(RunDirector.cleared_encounters)])
	var next_kind := RunDirector.peek_next_event_kind()
	lines.append("Next Event: %s | Modifiers: %d" % [
		RunDirector.describe_event_kind(next_kind) if not next_kind.is_empty() else "Victory",
		RunDirector.get_run_modifiers().size()
	])
	lines.append("Encounter: %s" % (encounter.name if encounter != null and is_instance_valid(encounter) else "none"))
	if player != null and is_instance_valid(player):
		var effective_move_speed := float(player.move_speed)
		if player.has_method("get_effective_move_speed"):
			effective_move_speed = float(player.get_effective_move_speed())
		lines.append("Hero: %s | State: %s" % [
			player.get_character_name() if player.has_method("get_character_name") else player.name,
			String(player.state_machine.get_state_name()) if player.get("state_machine") != null else "n/a"
		])
		lines.append("HP %.0f/%.0f  DEF %.0f/%.0f  INS %.0f/%.0f" % [
			float(player.hp), float(player.max_hp),
			float(player.defense), float(player.max_defense),
			float(player.inspiration), float(player.max_inspiration)
		])
		lines.append("DMG %.1f  Crit %.0f%%  Move %.0f" % [
			float(player.attack_damage),
			float(player.crit_rate) * 100.0,
			effective_move_speed
		])
		if player.has_method("get_control_status_text"):
			var control_text := String(player.get_control_status_text())
			lines.append("Control: %s" % (control_text if not control_text.is_empty() else "Stable"))
		lines.append("CD A %.1f K %.1f L %.1f I %.1f" % [
			float(player.cooldowns.get("attack", 0.0)),
			float(player.cooldowns.get("skill1", 0.0)),
			float(player.cooldowns.get("skill2", 0.0)),
			float(player.cooldowns.get("skill3", 0.0))
		])
	label.text = "\n".join(lines)
	_sync_upgrade_button_states()

func _build_upgrade_ui() -> void:
	if content_stack != null:
		return
	var content_root := label.get_parent()
	if content_root == null:
		return
	content_stack = VBoxContainer.new()
	content_stack.name = "DebugStack"
	content_stack.add_theme_constant_override("separation", 8)
	content_root.remove_child(label)
	content_stack.add_child(label)
	content_root.add_child(content_stack)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	upgrade_title_label = Label.new()
	upgrade_title_label.text = "Upgrades"
	upgrade_title_label.add_theme_font_size_override("font_size", 14)
	upgrade_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.64))
	content_stack.add_child(upgrade_title_label)

	upgrade_action_row = HBoxContainer.new()
	upgrade_action_row.add_theme_constant_override("separation", 8)
	content_stack.add_child(upgrade_action_row)

	clear_upgrades_button = Button.new()
	clear_upgrades_button.text = "Clear Upgrades"
	clear_upgrades_button.toggle_mode = false
	clear_upgrades_button.custom_minimum_size = Vector2(0.0, 34.0)
	UISkin.button_styles(clear_upgrades_button, "thin")
	clear_upgrades_button.pressed.connect(_on_clear_upgrades_pressed)
	upgrade_action_row.add_child(clear_upgrades_button)

	upgrade_scroll = ScrollContainer.new()
	upgrade_scroll.custom_minimum_size = Vector2(0.0, 168.0)
	upgrade_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.add_child(upgrade_scroll)

	upgrade_list = VBoxContainer.new()
	upgrade_list.add_theme_constant_override("separation", 6)
	upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_scroll.add_child(upgrade_list)

func _rebuild_upgrade_controls(player: Node) -> void:
	active_upgrade_target = player
	_clear_upgrade_entries()
	if clear_upgrades_button != null:
		clear_upgrades_button.disabled = player == null or not is_instance_valid(player) or not player.has_method("clear_all_upgrades")
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("get_upgrade_sections") or not player.has_method("is_upgrade_enabled") or not player.has_method("set_upgrade_enabled"):
		return
	var sections: Array = player.get_upgrade_sections()
	for section_variant in sections:
		var section: Dictionary = section_variant
		var section_title := Label.new()
		section_title.text = String(section.get("title", "Upgrades"))
		section_title.add_theme_font_size_override("font_size", 12)
		section_title.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98))
		upgrade_list.add_child(section_title)
		for upgrade_variant in section.get("upgrades", []):
			var upgrade: Dictionary = upgrade_variant
			var upgrade_id := String(upgrade.get("id", ""))
			var upgrade_label := String(upgrade.get("label", upgrade_id))
			var upgrade_description := String(upgrade.get("description", ""))
			var button := Button.new()
			button.toggle_mode = true
			button.text = upgrade_label
			button.tooltip_text = upgrade_description
			button.custom_minimum_size = Vector2(0.0, 34.0)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UISkin.button_styles(button, "thin")
			button.set_meta("upgrade_id", upgrade_id)
			button.button_pressed = bool(player.is_upgrade_enabled(upgrade_id))
			button.toggled.connect(func(pressed: bool) -> void:
				if active_upgrade_target == null or not is_instance_valid(active_upgrade_target):
					return
				if not active_upgrade_target.has_method("set_upgrade_enabled"):
					return
				active_upgrade_target.set_upgrade_enabled(upgrade_id, pressed)
			)
			upgrade_list.add_child(button)
			upgrade_buttons.append(button)
	_sync_upgrade_button_states()

func _sync_upgrade_button_states() -> void:
	if active_upgrade_target == null or not is_instance_valid(active_upgrade_target):
		return
	if not active_upgrade_target.has_method("is_upgrade_enabled"):
		return
	for button in upgrade_buttons:
		if button == null or not is_instance_valid(button):
			continue
		if not button.has_meta("upgrade_id"):
			continue
		var upgrade_id := String(button.get_meta("upgrade_id"))
		var should_be_pressed := bool(active_upgrade_target.is_upgrade_enabled(upgrade_id))
		if button.button_pressed != should_be_pressed:
			button.button_pressed = should_be_pressed

func _clear_upgrade_entries() -> void:
	upgrade_buttons.clear()
	if upgrade_list == null:
		return
	for child in upgrade_list.get_children():
		child.queue_free()

func _on_clear_upgrades_pressed() -> void:
	if active_upgrade_target == null or not is_instance_valid(active_upgrade_target):
		return
	if not active_upgrade_target.has_method("clear_all_upgrades"):
		return
	active_upgrade_target.clear_all_upgrades()
	_sync_upgrade_button_states()
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
	var compact: bool = viewport_size.x < 880.0
	root_margin.offset_left = -clampf(viewport_size.x * (0.42 if compact else 0.34), 260.0, 396.0)
	root_margin.offset_top = 12.0 if compact else 18.0
	root_margin.offset_right = -12.0 if compact else -18.0
	root_margin.offset_bottom = clampf(viewport_size.y * 0.34, 176.0, 260.0)
	UISkin.label(label, 11 if compact else 12, Color(0.82, 0.90, 0.98))
