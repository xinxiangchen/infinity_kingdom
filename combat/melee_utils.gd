extends RefCounted

static func is_point_in_arc(origin: Vector2, facing: Vector2, point: Vector2, radius: float, arc_degrees: float) -> bool:
	var offset := point - origin
	if offset.length() > radius:
		return false
	var facing_direction := facing.normalized() if facing != Vector2.ZERO else Vector2.RIGHT
	if offset == Vector2.ZERO:
		return true
	var angle_delta := wrapf(offset.angle() - facing_direction.angle(), -PI, PI)
	return absf(angle_delta) <= deg_to_rad(arc_degrees) * 0.5
