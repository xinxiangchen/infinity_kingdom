extends Control

var texture: Texture2D = null:
	set(value):
		texture = value
		queue_redraw()

var accent: Color = Color(0.92, 0.88, 0.64, 1.0):
	set(value):
		accent = value
		queue_redraw()

var hotkey: String = "":
	set(value):
		hotkey = value
		queue_redraw()

var cooldown_remaining: float = 0.0:
	set(value):
		cooldown_remaining = maxf(value, 0.0)
		queue_redraw()

var cooldown_total: float = 1.0:
	set(value):
		cooldown_total = maxf(value, 0.001)
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(48.0, 48.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_icon_texture(value: Texture2D) -> void:
	texture = value

func set_cooldown_state(remaining: float, total: float) -> void:
	cooldown_total = maxf(total, 0.001)
	cooldown_remaining = maxf(remaining, 0.0)

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 2.0:
		return
	var center := size * 0.5
	var radius := side * 0.45
	var ready := cooldown_remaining <= 0.05
	var fill_alpha := 1.0 if ready else 0.56
	draw_circle(center + Vector2(0.0, 3.0), radius + 5.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_circle(center, radius + 3.0, Color(0.035, 0.04, 0.055, 0.98))
	draw_circle(center, radius, Color(0.10, 0.11, 0.14, 0.96))
	if texture != null:
		var icon_side := side * 0.66
		var icon_rect := Rect2(center - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
		draw_texture_rect(texture, icon_rect, false, Color(1.0, 1.0, 1.0, fill_alpha))
	if not ready:
		_draw_cooldown_wedge(center, radius, clampf(cooldown_remaining / cooldown_total, 0.0, 1.0))
	var ring_color := accent if ready else accent.lerp(Color(0.26, 0.30, 0.36, 1.0), 0.48)
	draw_arc(center, radius + 1.0, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.44), 5.0, true)
	draw_arc(center, radius + 1.0, -PI * 0.5, TAU - PI * 0.5, 64, ring_color, 2.6 if ready else 2.0, true)
	if not ready:
		var cooldown_text := "%.1f" % cooldown_remaining if cooldown_remaining < 10.0 else str(int(ceil(cooldown_remaining)))
		var font := get_theme_default_font()
		var font_size := maxi(13, int(round(side * 0.26)))
		var text_size := font.get_string_size(cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var text_pos := center + Vector2(-text_size.x * 0.5, text_size.y * 0.32)
		draw_circle(center, radius * 0.42, Color(0.0, 0.0, 0.0, 0.42))
		draw_string(font, text_pos + Vector2(1.0, 1.0), cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.86))
		draw_string(font, text_pos, cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.92, 0.72, 1.0))
	if not hotkey.is_empty():
		var font := get_theme_default_font()
		var font_size := maxi(9, int(round(side * 0.20)))
		var hotkey_pos := Vector2(5.0, size.y - 5.0)
		draw_string(font, hotkey_pos + Vector2(1.0, 1.0), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.72))
		draw_string(font, hotkey_pos, hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.98, 0.92, 0.72, 1.0))

func _draw_cooldown_wedge(center: Vector2, radius: float, ratio: float) -> void:
	if ratio <= 0.0:
		return
	var points: PackedVector2Array = PackedVector2Array()
	points.append(center)
	var segments := clampi(int(ceil(64.0 * ratio)), 6, 64)
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * ratio
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * (radius + 0.5))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.66))
	draw_arc(center, radius - 1.0, start_angle, end_angle, segments, Color(0.02, 0.03, 0.04, 0.78), radius * 0.18, true)
