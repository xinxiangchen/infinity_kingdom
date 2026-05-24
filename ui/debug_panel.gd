extends CanvasLayer

const UISkin := preload("res://ui/ui_skin.gd")

@onready var root_margin: MarginContainer = $MarginContainer
@onready var panel: PanelContainer = $MarginContainer/PanelContainer
@onready var label: Label = $MarginContainer/PanelContainer/MarginContainer/Label

var target_world: Node = null
var layout_size_override: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 40
	visible = false
	panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	UISkin.label(label, 12, Color(0.82, 0.90, 0.98))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
