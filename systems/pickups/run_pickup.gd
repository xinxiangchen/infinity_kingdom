extends Node2D

signal collected(kind: String, amount: float, world_position: Vector2)

const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const GOLD_TEXTURE_PATH := "res://assets/effects/pickups/gold.webp"
const EXPERIENCE_TEXTURE_PATH := "res://assets/effects/pickups/experience.webp"

var kind: String = "gold"
var amount: float = 0.0
var tint: Color = Color(1.0, 0.88, 0.42, 1.0)
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0
var lifetime: float = 8.0
var drift_phase: float = 0.0
var collected_flag: bool = false
var icon_texture: Texture2D = null

func setup(pickup_kind: String, pickup_amount: float, options: Dictionary = {}) -> void:
	name = "RunPickup"
	kind = pickup_kind
	amount = maxf(pickup_amount, 0.0)
	tint = options.get("tint", _default_tint(kind))
	var icon_path := String(options.get("icon", ""))
	icon_texture = TEXTURE_LOADER.load_texture(icon_path) if not icon_path.is_empty() else _default_texture(kind)
	var launch_speed := float(options.get("launch_speed", randf_range(34.0, 62.0)))
	var launch_angle := float(options.get("launch_angle", randf() * TAU))
	velocity = Vector2.RIGHT.rotated(launch_angle) * launch_speed
	drift_phase = randf() * TAU
	z_index = 45
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if collected_flag:
		return
	age += delta
	if age <= 0.16:
		global_position += velocity * delta
		velocity = velocity.lerp(Vector2.ZERO, delta * 5.6)
	else:
		var player := _find_player()
		if player != null and is_instance_valid(player):
			var to_player := player.global_position - global_position
			var distance := to_player.length()
			if distance <= 20.0:
				collected_flag = true
				collected.emit(kind, amount, global_position)
				queue_free()
				return
			if distance <= 240.0 or age >= 0.55:
				var pull_speed := 170.0 if age < 0.9 else 260.0
				var target_velocity := to_player.normalized() * pull_speed if distance > 0.001 else Vector2.ZERO
				velocity = velocity.lerp(target_velocity, delta * 6.2)
		global_position += velocity * delta
		velocity = velocity.move_toward(Vector2.ZERO, delta * 28.0)
	if age >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var bob_offset := sin(Time.get_ticks_msec() * 0.01 + drift_phase) * 1.6
	var scale_pulse := 1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.008 + drift_phase)
	var center := Vector2(0.0, bob_offset)
	var outer_radius := 7.0 * scale_pulse
	var inner_radius := 4.0 * scale_pulse
	draw_circle(center, outer_radius + 2.0, Color(0.02, 0.03, 0.05, 0.52))
	if icon_texture != null:
		var icon_size := Vector2(28.0, 28.0)
		if kind == "gold":
			icon_size = Vector2(20.0, 26.0)
		elif kind == "inspiration":
			icon_size = Vector2(26.0, 26.0)
		elif kind == "accessory":
			icon_size = Vector2(26.0, 26.0)
		elif kind == "consumable":
			icon_size = Vector2(30.0, 30.0)
		draw_texture_rect(icon_texture, Rect2(center - icon_size * 0.5, icon_size), false, Color.WHITE)
		draw_arc(center, maxf(icon_size.x, icon_size.y) * 0.5 + 1.0, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.44), 1.2)
		return
	match kind:
		"gold":
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -outer_radius),
				center + Vector2(outer_radius, 0.0),
				center + Vector2(0.0, outer_radius),
				center + Vector2(-outer_radius, 0.0)
			])
			draw_colored_polygon(diamond, tint)
			draw_circle(center, inner_radius, Color(1.0, 0.98, 0.70, 0.72))
		"inspiration":
			draw_circle(center, outer_radius, tint)
			draw_circle(center, inner_radius, Color(0.90, 0.98, 1.0, 0.72))
		"repair":
			var shield := PackedVector2Array([
				center + Vector2(-outer_radius * 0.86, -outer_radius * 0.42),
				center + Vector2(0.0, -outer_radius),
				center + Vector2(outer_radius * 0.86, -outer_radius * 0.42),
				center + Vector2(outer_radius * 0.66, outer_radius * 0.42),
				center + Vector2(0.0, outer_radius),
				center + Vector2(-outer_radius * 0.66, outer_radius * 0.42)
			])
			draw_colored_polygon(shield, tint)
			draw_rect(Rect2(center + Vector2(-1.2, -4.0), Vector2(2.4, 8.0)), Color.WHITE, true)
			draw_rect(Rect2(center + Vector2(-4.0, -1.2), Vector2(8.0, 2.4)), Color.WHITE, true)
		"consumable":
			draw_rect(Rect2(center + Vector2(-outer_radius * 0.55, -outer_radius), Vector2(outer_radius * 1.1, outer_radius * 1.8)), tint, true)
			draw_rect(Rect2(center + Vector2(-outer_radius * 0.32, -outer_radius * 1.24), Vector2(outer_radius * 0.64, outer_radius * 0.34)), Color(0.92, 0.96, 1.0, 1.0), true)
			draw_rect(Rect2(center + Vector2(-1.1, -4.0), Vector2(2.2, 8.0)), Color.WHITE, true)
			draw_rect(Rect2(center + Vector2(-4.0, -1.1), Vector2(8.0, 2.2)), Color.WHITE, true)
		"accessory":
			draw_arc(center, outer_radius * 0.75, 0.0, TAU, 24, tint, 2.8)
			draw_circle(center + Vector2(0.0, -outer_radius * 0.82), inner_radius * 0.62, Color(1.0, 0.96, 0.72, 1.0))
		_:
			draw_circle(center, outer_radius, tint)
			draw_circle(center + Vector2(0.0, -1.0), inner_radius, Color(0.94, 1.0, 0.94, 0.72))
	draw_arc(center, outer_radius + 1.0, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.44), 1.2)

func _find_player() -> Node2D:
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate is Node2D and is_instance_valid(candidate):
			var hp_value: Variant = candidate.get("hp")
			if hp_value != null and float(hp_value) > 0.0:
				return candidate as Node2D
	return null

func _default_tint(pickup_kind: String) -> Color:
	match pickup_kind:
		"inspiration":
			return Color(0.46, 0.72, 1.0, 1.0)
		"repair":
			return Color(0.52, 0.96, 0.92, 1.0)
		"heal":
			return Color(0.58, 1.0, 0.72, 1.0)
		"consumable":
			return Color(0.80, 0.90, 1.0, 1.0)
		"accessory":
			return Color(1.0, 0.88, 0.52, 1.0)
		_:
			return Color(1.0, 0.88, 0.42, 1.0)

func _default_texture(pickup_kind: String) -> Texture2D:
	match pickup_kind:
		"gold":
			return TEXTURE_LOADER.load_texture(GOLD_TEXTURE_PATH)
		"inspiration":
			return TEXTURE_LOADER.load_texture(EXPERIENCE_TEXTURE_PATH)
		_:
			return null
