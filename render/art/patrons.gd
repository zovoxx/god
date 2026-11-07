class_name ArtPatrons
extends RefCounted
## Portraits of the eight Lights: dead stars bound to Wren's lantern.

static func register(A) -> void:
	A.reg("p_ember", Vector2(96, 96), _ember)
	A.reg("p_rime", Vector2(96, 96), _rime)
	A.reg("p_storm", Vector2(96, 96), _storm)
	A.reg("p_tide", Vector2(96, 96), _tide)
	A.reg("p_dawn", Vector2(96, 96), _dawn)
	A.reg("p_gale", Vector2(96, 96), _gale)
	A.reg("p_umbra", Vector2(96, 96), _umbra)
	A.reg("p_thorn", Vector2(96, 96), _thorn)

static func _face(ci: CanvasItem, col: Color, eye_col: Color = Color.WHITE) -> void:
	Paint.glow(ci, Vector2.ZERO, 40.0, col, false)
	Paint.circ(ci, Vector2(0, 4), 22.0, col.darkened(0.55))
	ci.draw_circle(Vector2(0, 6), 17.0, col.darkened(0.75))
	Paint.eye(ci, Vector2(-7, 4), 3.0, eye_col)
	Paint.eye(ci, Vector2(7, 4), 3.0, eye_col)

static func _ember(ci: CanvasItem) -> void:
	var c := Color("#ff7a2a")
	Paint.poly(ci, Paint.pts([0, -44, 12, -22, 26, -30, 22, -8, -22, -8, -26, -30, -12, -22]), c, 2.5)
	_face(ci, c, Color("#ffe6a0"))
	ci.draw_arc(Vector2(0, 14), 6.0, 0.3, PI - 0.3, 8, Color("#ffe6a0"), 2.0)

static func _rime(ci: CanvasItem) -> void:
	var c := Color("#8fe8ff")
	Paint.poly(ci, Paint.mirror([0, -42, 18, -30, 30, 4, 26, 40, 0, 34]), c.darkened(0.3), 2.5)
	_face(ci, c)
	for i in 5:
		var a := -PI * 0.5 + (i - 2) * 0.45
		Paint.line(ci, Geom.dir(a) * 26.0, Geom.dir(a) * 44.0, Color("#e0f8ff"), 3.0)

static func _storm(ci: CanvasItem) -> void:
	var c := Color("#ffe24a")
	for s in [-1.0, 1.0]:
		Paint.polyline(ci, Paint.pts([12 * s, -16, 32 * s, -30, 40 * s, -10, 30 * s, 6]), Color("#d8c890"), 6.0)
	_face(ci, c, Color("#fff8c0"))
	Paint.poly(ci, Paint.pts([-4, -40, 6, -24, 0, -24, 8, -10, -6, -28, 0, -28]), Color("#fff8c0"), 1.5)

static func _tide(ci: CanvasItem) -> void:
	var c := Color("#3d9bff")
	var wave := Paint.pts([-40, 10, -30, -20, -10, -36, 12, -34, 30, -18, 40, 10, 28, 0, 14, -16, -4, -20, -20, -10, -30, 4])
	Paint.poly(ci, wave, c, 2.5)
	_face(ci, c, Color("#c8f0ff"))

static func _dawn(ci: CanvasItem) -> void:
	var c := Color("#fff1a6")
	for i in 12:
		var a := TAU * i / 12.0
		Paint.line(ci, Geom.dir(a) * 30.0, Geom.dir(a) * (44.0 if i % 2 == 0 else 38.0), c, 3.0)
	_face(ci, Color("#ffd27a"), Color.WHITE)

static func _gale(ci: CanvasItem) -> void:
	var c := Color("#8dffc8")
	for i in 3:
		var y := -30.0 + i * 12.0
		Paint.polyline(ci, Paint.pts([-40, y, -10, y - 6, 20, y, 42, y - 10]), c, 3.0)
	_face(ci, c)

static func _umbra(ci: CanvasItem) -> void:
	var c := Color("#b45cff")
	Paint.glow(ci, Vector2.ZERO, 40.0, c, false)
	Paint.poly(ci, Paint.ell(Vector2(0, 0), 34, 18, 24), c.darkened(0.5), 3.0)
	ci.draw_colored_polygon(Paint.ell(Vector2(0, 0), 26, 13, 24), Color("#0a0610"))
	Paint.eye(ci, Vector2.ZERO, 9.0, Color("#e0c0ff"))
	ci.draw_circle(Vector2.ZERO, 4.0, Color("#0a0610"))

static func _thorn(ci: CanvasItem) -> void:
	var c := Color("#86e04a")
	for i in 7:
		var a := -PI + PI * (i + 0.5) / 7.0
		Paint.poly(ci, PackedVector2Array([Geom.dir(a - 0.12) * 22.0, Geom.dir(a) * 44.0, Geom.dir(a + 0.12) * 22.0]), c.darkened(0.2), 2.0)
	_face(ci, c, Color("#e0ffc0"))
