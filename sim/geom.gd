class_name Geom
extends RefCounted
## Pure geometry helpers shared by simulation, telegraphs and tests.

static func wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)

static func angle_diff(a: float, b: float) -> float:
	return wrapf(b - a, -PI, PI)

static func dir(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))

## circle (p, r) overlaps a circle sector at origin facing `ang` with `range` and full arc `arc_deg`
static func in_arc(p: Vector2, r: float, origin: Vector2, ang: float, rng: float, arc_deg: float) -> bool:
	var d := p - origin
	var dist := d.length()
	if dist > rng + r:
		return false
	if arc_deg >= 359.0 or dist < r:
		return true
	var half := deg_to_rad(arc_deg) * 0.5
	var da := absf(angle_diff(ang, d.angle()))
	if da <= half:
		return true
	# allow the target's radius to graze the edge of the arc
	return dist * sin(minf(da - half, PI * 0.5)) <= r and da - half < PI * 0.5

## circle (p, r) overlaps a rectangle that starts at origin and extends `len` along `ang` with full `width`
static func in_line(p: Vector2, r: float, origin: Vector2, ang: float, length: float, width: float) -> bool:
	var d := (p - origin).rotated(-ang)
	if d.x < -r or d.x > length + r:
		return false
	return absf(d.y) <= width * 0.5 + r

## fraction (0..1) along a line where the point projects (used for pike tip crits)
static func line_frac(p: Vector2, origin: Vector2, ang: float, length: float) -> float:
	var d := (p - origin).rotated(-ang)
	return clampf(d.x / maxf(1.0, length), 0.0, 1.0)

static func in_circle(p: Vector2, r: float, c: Vector2, radius: float) -> bool:
	return p.distance_squared_to(c) <= (radius + r) * (radius + r)

static func in_ring(p: Vector2, r: float, c: Vector2, inner: float, outer: float) -> bool:
	var d := p.distance_to(c)
	return d + r >= inner and d - r <= outer

## closest distance between point p and segment ab
static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func approach(v: float, target: float, delta: float) -> float:
	if v < target:
		return minf(v + delta, target)
	return maxf(v - delta, target)
