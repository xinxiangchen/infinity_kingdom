extends Node2D

const UISkin := preload("res://ui/ui_skin.gd")

var tracked_actor: Node2D = null
var health_component: Node = null
var y_offset: float = -52.0
var bar_width: float = 64.0
var hp_height: float = 8.0
var defense_height: float = 3.0
var always_visible: bool = false
var elite: bool = false
var boss: bool = false
var visibility_timer: float = 0.0
var impact_timer: float = 0.0

func setup(actor: Node, options: Dictionary = {}) -> void:
	name = "WorldHealthBar"
	tracked_actor = actor as Node2D
	health_component = _find_health_component(actor)
	y_offset = float(options.get("y_offset", y_offset))
	bar_width = float(options.get("bar_width", bar_width))
	hp_height = float(options.get("hp_height", hp_height))
	defense_height = float(options.get("defense_height", defense_height))
	always_visible = bool(options.get("always_visible", false))
	elite = bool(options.get("elite", false))
	boss = bool(options.get("boss", false))
	z_index = 60
	if health_component != null:
		if health_component.has_signal("damaged") and not health_component.damaged.is_connected(_on_damaged):
			health_component.damaged.connect(_on_damaged)
		if health_component.has_signal("healed") and not health_component.healed.is_connected(_on_healed):
			health_component.healed.connect(_on_healed)
		if health_component.has_signal("defense_changed") and not health_component.defense_changed.is_connected(_on_defense_changed):
			health_component.defense_changed.connect(_on_defense_changed)
		if health_component.has_signal("shield_changed") and not health_component.shield_changed.is_connected(_on_shield_changed):
			health_component.shield_changed.connect(_on_shield_changed)
	visibility_timer = 2.5 if always_visible else 0.0
	position = Vector2(0.0, y_offset)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if tracked_actor == null or not is_instance_valid(tracked_actor):
		queue_free()
		return
	position = Vector2(0.0, y_offset)
	visibility_timer = maxf(visibility_timer - delta, 0.0)
	impact_timer = maxf(impact_timer - delta, 0.0)
	var hp_ratio := _ratio(_current_hp(), _max_hp())
	visible = always_visible or hp_ratio < 0.995 or visibility_timer > 0.0
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var hp_ratio := _ratio(_current_hp(), _max_hp())
	var defense_ratio := _ratio(_current_defense(), _max_defense())
	var shield_ratio := clampf(_current_shield() / maxf(_max_hp(), 1.0), 0.0, 0.45)
	var alpha := 0.98 if (always_visible or hp_ratio < 0.995) else 0.74
	var origin := Vector2(-bar_width * 0.5, 0.0)
	var hp_rect := Rect2(origin, Vector2(bar_width, hp_height))
	var defense_rect := Rect2(origin + Vector2(0.0, hp_height + 2.0), Vector2(bar_width, defense_height))
	var border_color := Color(1.0, 0.86, 0.52, alpha) if (elite or boss) else Color(0.72, 0.82, 0.96, alpha)
	var background_color := Color(0.04, 0.05, 0.07, 0.88 * alpha)
	draw_rect(hp_rect.grow(1.5), background_color, true)
	draw_rect(defense_rect.grow(1.0), background_color, true)
	draw_rect(hp_rect, Color(0.20, 0.08, 0.08, 0.88 * alpha), true)
	if hp_ratio > 0.0:
		var hp_color := Color(0.96, 0.24, 0.22, alpha)
		if hp_ratio <= 0.25:
			var pulse := 0.84 + 0.16 * sin(Time.get_ticks_msec() * 0.015)
			hp_color = hp_color.lerp(Color(1.0, 0.86, 0.62, alpha), 0.35 * pulse)
		draw_rect(Rect2(hp_rect.position, Vector2(bar_width * hp_ratio, hp_height)), hp_color, true)
	draw_rect(defense_rect, Color(0.08, 0.12, 0.18, 0.92 * alpha), true)
	if defense_ratio > 0.0:
		draw_rect(Rect2(defense_rect.position, Vector2(bar_width * defense_ratio, defense_height)), Color(0.36, 0.76, 0.98, alpha), true)
	if shield_ratio > 0.0:
		draw_rect(Rect2(hp_rect.position + Vector2(0.0, -2.0), Vector2(bar_width * shield_ratio, 1.5)), Color(1.0, 0.88, 0.44, alpha), true)
	draw_rect(hp_rect.grow(1.0), border_color, false, 1.2)
	draw_rect(defense_rect.grow(1.0), Color(0.48, 0.66, 0.86, alpha), false, 1.0)
	if impact_timer > 0.0:
		draw_rect(hp_rect.grow(3.0), Color(1.0, 1.0, 1.0, 0.18 + impact_timer * 1.8), false, 1.8)

func _find_health_component(actor: Object) -> Node:
	if actor == null:
		return null
	if actor is Node and (actor as Node).has_node("HealthComponent"):
		return (actor as Node).get_node("HealthComponent")
	for property in actor.get_property_list():
		if String(property.get("name", "")) == "health_component":
			return actor.get("health_component") as Node
	return null

func _current_hp() -> float:
	if health_component != null and _has_property(health_component, "hp"):
		return float(health_component.get("hp"))
	if tracked_actor != null and _has_property(tracked_actor, "hp"):
		return float(tracked_actor.get("hp"))
	return 0.0

func _max_hp() -> float:
	if health_component != null and _has_property(health_component, "max_hp"):
		return float(health_component.get("max_hp"))
	if tracked_actor != null and _has_property(tracked_actor, "max_hp"):
		return float(tracked_actor.get("max_hp"))
	return 1.0

func _current_defense() -> float:
	if health_component != null and _has_property(health_component, "defense"):
		return float(health_component.get("defense"))
	if tracked_actor != null and _has_property(tracked_actor, "defense"):
		return float(tracked_actor.get("defense"))
	if tracked_actor != null and _has_property(tracked_actor, "defense_value"):
		return float(tracked_actor.get("defense_value"))
	return 0.0

func _max_defense() -> float:
	if health_component != null and _has_property(health_component, "max_defense"):
		return float(health_component.get("max_defense"))
	if tracked_actor != null and _has_property(tracked_actor, "max_defense"):
		return float(tracked_actor.get("max_defense"))
	if tracked_actor != null and _has_property(tracked_actor, "defense_value"):
		return float(tracked_actor.get("defense_value"))
	return 0.0

func _current_shield() -> float:
	if health_component != null and _has_property(health_component, "shield"):
		return float(health_component.get("shield"))
	return 0.0

func _ratio(current_value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clampf(current_value / max_value, 0.0, 1.0)

func _has_property(target: Object, field: String) -> bool:
	if target == null:
		return false
	for property in target.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false

func _mark_visible(duration: float = 1.6) -> void:
	visibility_timer = maxf(visibility_timer, duration)

func _on_damaged(_amount: float, _remaining_hp: float, _source: Node) -> void:
	impact_timer = 0.18
	_mark_visible(2.1)

func _on_healed(_amount: float, _current_hp: float) -> void:
	_mark_visible(1.0)

func _on_defense_changed(_current_defense: float, _max_defense: float) -> void:
	_mark_visible(1.2)

func _on_shield_changed(_current_shield: float) -> void:
	_mark_visible(1.0)
