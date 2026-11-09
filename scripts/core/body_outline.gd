class_name BodyOutline
extends RefCounted
## Ground outline of a body as a stadium (task-094): every point within `radius` of the segment a..b, on the XZ plane
## (Vector2(x, z)). The grown entity collides as one lying capsule of this outline; interact reach, diamond pickup and
## the dig-ahead of dirt measure against it. Pure geometry, no state.

var a: Vector2 = Vector2.ZERO
var b: Vector2 = Vector2.ZERO
var radius: float = 0.0


func _init(from: Vector2 = Vector2.ZERO, to: Vector2 = Vector2.ZERO, r: float = 0.0) -> void:
	a = from
	b = to
	radius = r


## Outline of a body with ground half-size `extents` (x across, y deep) centred on `centre`, its long axis along the
## screen's right turned by `yaw` radians about UP (Vector3.RIGHT.rotated(UP, yaw)).
static func for_body(centre: Vector2, extents: Vector2, yaw: float) -> BodyOutline:
	var r: float = minf(extents.x, extents.y)
	var half: float = maxf(extents.x - r, 0.0)
	var axis3: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, yaw)
	var axis := Vector2(axis3.x, axis3.z)
	return BodyOutline.new(centre - axis * half, centre + axis * half, r)


## The lying capsule of a body with ground half-size `extents` (its axis is local Y; lying_basis lays it down).
static func capsule_for(extents: Vector2) -> CapsuleShape3D:
	var capsule := CapsuleShape3D.new()
	capsule.radius = minf(extents.x, extents.y)
	capsule.height = maxf(extents.x, extents.y) * 2.0
	return capsule


## Basis that lays a capsule (axis local Y) along the screen's right turned by `yaw` radians about UP.
static func lying_basis(yaw: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -PI * 0.5)


## Distance from the outline to a ground rectangle (0 when they touch or overlap).
func distance_to_rect(rect: Rect2) -> float:
	return maxf(segment_rect_distance(a, b, rect) - radius, 0.0)


## Distance from the outline to a ground point (0 inside).
func distance_to_point(p: Vector2) -> float:
	return maxf(point_segment_distance(p, a, b) - radius, 0.0)


static func point_segment_distance(p: Vector2, s0: Vector2, s1: Vector2) -> float:
	var d: Vector2 = s1 - s0
	var len_sq: float = d.length_squared()
	if len_sq <= 0.0:
		return p.distance_to(s0)
	var t: float = clampf((p - s0).dot(d) / len_sq, 0.0, 1.0)
	return p.distance_to(s0 + d * t)


static func point_rect_distance(p: Vector2, rect: Rect2) -> float:
	var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	return p.distance_to(q)


## Exact distance between a segment and an axis-aligned rectangle in 2D (0 when the segment crosses it).
static func segment_rect_distance(s0: Vector2, s1: Vector2, rect: Rect2) -> float:
	if _segment_hits_rect(s0, s1, rect):
		return 0.0
	var best: float = minf(point_rect_distance(s0, rect), point_rect_distance(s1, rect))
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		best = minf(best, point_segment_distance(corner, s0, s1))
	return best


## Slab test: true when the segment touches the rectangle.
static func _segment_hits_rect(s0: Vector2, s1: Vector2, rect: Rect2) -> bool:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector2 = s1 - s0
	for axis in 2:
		var lo: float = rect.position[axis]
		var hi: float = rect.end[axis]
		if absf(d[axis]) < 0.000001:
			if s0[axis] < lo or s0[axis] > hi:
				return false
			continue
		var ta: float = (lo - s0[axis]) / d[axis]
		var tb: float = (hi - s0[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return false
	return true
