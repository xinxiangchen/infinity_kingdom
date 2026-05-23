extends CanvasLayer

const UISkin := preload("res://ui/ui_skin.gd")

@onready var panel: PanelContainer = $MarginContainer/PanelContainer
@onready var label: Label = $MarginContainer/PanelContainer/MarginContainer/Label

var target_world: Node = null

func _ready() -> void:
	layer = 40
	visible = false
	panel.add_theme_stylebox_override("panel", UISkin.content_panel_style())
	UISkin.label(label, 12, Color(0.82, 0.90, 0.98))

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
	lines.append("Encounter: %s" % (encounter.name if encounter != null and is_instance_valid(encounter) else "none"))
	if player != null and is_instance_valid(player):
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
			float(player.move_speed)
		])
		lines.append("CD A %.1f K %.1f L %.1f I %.1f" % [
			float(player.cooldowns.get("attack", 0.0)),
			float(player.cooldowns.get("skill1", 0.0)),
			float(player.cooldowns.get("skill2", 0.0)),
			float(player.cooldowns.get("skill3", 0.0))
		])
	label.text = "\n".join(lines)
