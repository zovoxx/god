class_name Paint
extends RefCounted
## Vector-style drawing helpers for procedural sprites: bold fills, a dark outline and an
## emissive "lantern glow" accent. All coordinates are world units centred on the sprite.

const OUT := Color("#120a16")

static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = 3.0) -> void:
	if pts.size() < 3:
		return
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, OUT, w * 2.0, true)
	ci.draw_colored_polygon(pts, fill)

static func circ(ci: CanvasItem, c: Vector2, r: float, fill: Color, w: float = 3.0) -> void:
	ci.draw_circle(c, r + w, OUT)
	ci.draw_circle(c, r, fill)

static func disc(ci: CanvasItem, c: Vector2, r: float, fill: Color) -> void:
	ci.draw_circle(c, r, fill)

static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, core: bool = true) -> void:
	for i in 6:
		var k := 1.0 - float(i) / 6.0
		ci.draw_circle(c, r * (0.45 + k * 0.9), Color(col.r, col.g, col.b, 0.09 + (1.0 - k) * 0.06))
	if core:
		ci.draw_circle(c, r * 0.45, col)
		ci.draw_circle(c, r * 0.22, col.lerp(Color.WHITE, 0.75))

static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float = 4.0) -> void:
	ci.draw_line(a, b, OUT, w + 5.0, true)
	ci.draw_line(a, b, col, w, true)

static func polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float = 4.0) -> void:
	ci.draw_polyline(pts, OUT, w + 5.0, true)
	ci.draw_polyline(pts, col, w, true)

static func ell(c: Vector2, rx: float, ry: float, n: int = 24, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

static func star(c: Vector2, r1: float, r2: float, n: int, rot: float = -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := rot + PI * float(i) / float(n)
		var r := r1 if i % 2 == 0 else r2
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

static func ngon(c: Vector2, r: float, n: int, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

static func pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, arr.size(), 2):
		out.append(Vector2(arr[i], arr[i + 1]))
	return out

## mirrored polygon: give the right half (x >= 0) from top to bottom, returns the full shape
static func mirror(half: Array) -> PackedVector2Array:
	var right := pts(half)
	var out := right.duplicate()
	for i in range(right.size() - 1, -1, -1):
		var p := right[i]
		if absf(p.x) > 0.01:
			out.append(Vector2(-p.x, p.y))
	return out

static func shade(c: Color, k: float) -> Color:
	return c.darkened(k) if k > 0.0 else c.lightened(-k)

static func eye(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	glow(ci, c, r * 2.2, col, false)
	ci.draw_circle(c, r + 1.5, OUT)
	ci.draw_circle(c, r, col)
	ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.45, Color.WHITE)
