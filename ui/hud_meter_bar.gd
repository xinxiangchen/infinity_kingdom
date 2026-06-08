extends Control

var meter_id: String = "hp"
var fill_color: Color = Color(0.92, 0.24, 0.22, 1.0)
var track_color: Color = Color(0.055, 0.065, 0.085, 0.98)
var border_color: Color = Color(0.72, 0.78, 0.90, 0.95)
var value: float = 1.0
var current_value: float = 0.0
var max_value: float = 0.0
var alert: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220.0, 22.0)

func configure(id: String, color_value: Color) -> void:
	meter_id = id
	fill_color = color_value
	if meter_id == "hp":
		border_color = Color(0.98, 0.60, 0.54, 0.96)
		track_color = Color(0.13, 0.045, 0.048, 0.96)
	elif meter_id == "defense":
		border_color = Color(0.48, 0.82, 1.0, 0.96)
		track_color = Color(0.045, 0.075, 0.12, 0.96)
	elif meter_id == "inspiration":
		border_color = Color(0.58, 0.66, 1.0, 0.96)
		track_color = Color(0.045, 0.055, 0.13, 0.96)
	set_meta("meter_id", meter_id)
	queue_redraw()

func set_meter_value(current: float, maximum: float) -> void:
	current_value = current
	max_value = maximum
	value = 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	queue_redraw()

func set_meter_alert(active: bool) -> void:
	if alert == active:
		if alert:
			queue_redraw()
		return
	alert = active
	queue_redraw()

func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return
	var rect: Rect2 = Rect2(Vector2(3.0, 3.0), Vector2(size.x - 6.0, size.y - 6.0))
	var inner: Rect2 = rect.grow(-2.0)
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
	var frame_color: Color = border_color.lerp(Color.WHITE, 0.24 * pulse) if alert else border_color
	draw_rect(rect.grow(3.0), Color(0.0, 0.0, 0.0, 0.32), true)
	draw_rect(rect.grow(1.0), frame_color.darkened(0.34), true)
	draw_rect(rect, frame_color, true)
	draw_rect(inner, track_color, true)
	var fill_width: float = floorf(inner.size.x * value)
	if fill_width > 0.0:
		var fill_rect: Rect2 = Rect2(inner.position, Vector2(fill_width, inner.size.y))
		var active_fill: Color = fill_color.lerp(Color.WHITE, 0.20 * pulse) if alert else fill_color
		draw_rect(fill_rect, active_fill, true)
		var shine_height: float = maxf(2.0, floorf(fill_rect.size.y * 0.34))
		draw_rect(Rect2(fill_rect.position + Vector2(0.0, 1.0), Vector2(fill_rect.size.x, shine_height)), Color(1.0, 1.0, 1.0, 0.20), true)
		draw_rect(Rect2(fill_rect.position + Vector2(fill_rect.size.x - 2.0, 0.0), Vector2(2.0, fill_rect.size.y)), Color(1.0, 1.0, 1.0, 0.26), true)
	for index in range(1, 10):
		var tick_x: float = inner.position.x + inner.size.x * float(index) / 10.0
		draw_line(Vector2(tick_x, inner.position.y + 2.0), Vector2(tick_x, inner.end.y - 2.0), Color(0.0, 0.0, 0.0, 0.24), 1.0)
	draw_rect(inner, Color(0.0, 0.0, 0.0, 0.34), false, 1.0)
