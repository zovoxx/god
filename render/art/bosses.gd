class_name ArtBosses
extends RefCounted
## Guardians and bosses. Bosses carry a purple accent (purple = boss in the colour language).

const PURPLE := Color("#b05cff")
const EMB := Color("#ff8a2a")

static func register(A) -> void:
	A.reg("mini_thornback", Vector2(100, 88), _thornback)
	A.reg("mini_bloom", Vector2(104, 104), _bloom)
	A.reg("mini_librarian", Vector2(84, 100), _librarian)
	A.reg("mini_deepmaw", Vector2(100, 94), _deepmaw)
	A.reg("boss_stag", Vector2(150, 150), _stag)
	A.reg("boss_archivist", Vector2(124, 136), _archivist)
	ArtBosses34.register(A)

static func crown(ci: CanvasItem, c: Vector2, w: float) -> void:
	Paint.glow(ci, c, w * 0.6, PURPLE, false)
	Paint.poly(ci, Paint.pts([c.x - w * 0.5, c.y + 4, c.x - w * 0.5, c.y - 6, c.x - w * 0.25, c.y, c.x, c.y - 10, c.x + w * 0.25, c.y, c.x + w * 0.5, c.y - 6, c.x + w * 0.5, c.y + 4]), PURPLE, 2.0)

static func _thornback(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.ell(Vector2(-4, 8), 40, 26, 22), Color("#6a4a30"))
	for i in 7:
		var x := -34 + i * 10
		Paint.poly(ci, Paint.pts([x, -6, x + 5, -30 + (i % 2) * 6, x + 10, -6]), Color("#8ab05a"), 2.0)
	Paint.circ(ci, Vector2(34, 6), 16.0, Color("#7a5638"))
	Paint.poly(ci, Paint.pts([40, 14, 54, 4, 46, 18]), Color("#e8d8b0"), 2.0)
	Paint.eye(ci, Vector2(38, 0), 3.4, Color("#ffb04a"))
	for x in [-26, -8, 10, 24]:
		Paint.line(ci, Vector2(x, 30), Vector2(x, 40), Color("#4a3420"), 6.0)

static func _bloom(ci: CanvasItem) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		Paint.poly(ci, Paint.ell(Geom.dir(a) * 30.0, 20, 12, 12, a), Color("#c86a9a") if i % 2 == 0 else Color("#e08ab0"), 2.0)
	Paint.circ(ci, Vector2.ZERO, 22.0, Color("#3a5a2a"))
	Paint.glow(ci, Vector2.ZERO, 14.0, Color("#ff9a5a"), true)
	for i in 4:
		var a2 := TAU * i / 4.0 + 0.4
		Paint.eye(ci, Geom.dir(a2) * 12.0, 2.6, Color("#ffd27a"))

static func _librarian(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -40, 16, -30, 22, 10, 28, 46, 0, 44]), Color("#4a3a2a"))
	Paint.circ(ci, Vector2(0, -32), 13.0, Color("#6a5238"))
	ci.draw_circle(Vector2(0, -30), 8.0, Color("#100c08"))
	Paint.eye(ci, Vector2(-3, -30), 2.2, Color("#ffd27a"))
	Paint.eye(ci, Vector2(3, -30), 2.2, Color("#ffd27a"))
	for i in 3:
		var a := -PI * 0.5 + (i - 1) * 0.9
		var p := Vector2(0, -6) + Geom.dir(a) * 36.0
		Paint.poly(ci, Paint.pts([p.x - 9, p.y - 7, p.x + 9, p.y - 7, p.x + 9, p.y + 7, p.x - 9, p.y + 7]), Color("#e8dcc0"), 2.0)

static func _deepmaw(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-44, 20, -30, -20, 0, -36, 30, -24, 46, 0, 36, 30, 0, 40, -30, 36]), Color("#1a3a6a"))
	ci.draw_colored_polygon(Paint.ell(Vector2(14, 8), 22, 16, 18), Color("#080c18"))
	for i in 9:
		var a := TAU * i / 9.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(14, 8) + Geom.dir(a - 0.2) * 20.0, Vector2(14, 8) + Geom.dir(a + 0.2) * 20.0, Vector2(14, 8) + Geom.dir(a) * 10.0]), Color("#e0e8ff"))
	Paint.eye(ci, Vector2(-14, -12), 4.0, Color("#7fd4ff"))
	Paint.eye(ci, Vector2(0, -20), 3.2, Color("#7fd4ff"))

static func _stag(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, -40), 40.0, EMB, false)
	# body
	Paint.poly(ci, Paint.ell(Vector2(-8, 20), 50, 30, 24), Color("#3a2a24"))
	for x in [-42, -20, 8, 30]:
		Paint.line(ci, Vector2(x, 44), Vector2(x - 2, 66), Color("#2a1c18"), 7.0)
	ci.draw_polyline(Paint.pts([-40, 14, -20, 24, 0, 16, 20, 26]), EMB, 3.0)
	# neck + head
	Paint.poly(ci, Paint.pts([22, 10, 36, -20, 50, -18, 44, 16]), Color("#4a362c"))
	Paint.circ(ci, Vector2(46, -24), 14.0, Color("#5a4234"))
	Paint.eye(ci, Vector2(50, -28), 3.6, Color("#ffd27a"))
	# burning antlers
	for s in [-1.0, 1.0]:
		var b := Vector2(42 + 6 * s, -36)
		Paint.polyline(ci, PackedVector2Array([b, b + Vector2(-8 * s - 6, -22), b + Vector2(-2 * s - 10, -44)]), Color("#e8d0a0"), 5.0)
		Paint.polyline(ci, PackedVector2Array([b + Vector2(-8 * s - 6, -22), b + Vector2(10 * s, -34)]), Color("#e8d0a0"), 4.0)
		Paint.glow(ci, b + Vector2(-2 * s - 10, -46), 9.0, EMB, true)
		Paint.glow(ci, b + Vector2(10 * s, -36), 7.0, EMB, true)
	crown(ci, Vector2(-8, -4), 30.0)

static func _archivist(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, -10), 46.0, Color("#5ec8e0"), false)
	Paint.poly(ci, Paint.mirror([0, -50, 18, -38, 30, 0, 38, 50, 14, 60, 0, 52]), Color("#1c3a4a"))
	ci.draw_colored_polygon(Paint.mirror([0, -30, 12, -20, 18, 30, 0, 40]), Color("#2a5466"))
	Paint.circ(ci, Vector2(0, -42), 16.0, Color("#3a6a7a"))
	ci.draw_circle(Vector2(0, -40), 10.0, Color("#06121a"))
	Paint.eye(ci, Vector2(-4, -40), 2.8, Color("#a0f8ff"))
	Paint.eye(ci, Vector2(4, -40), 2.8, Color("#a0f8ff"))
	for i in 5:
		var a := PI + 0.3 + i * 0.6
		var p := Vector2(0, -10) + Geom.dir(a) * 52.0
		Paint.poly(ci, Paint.pts([p.x - 3, p.y + 10, p.x, p.y - 12, p.x + 3, p.y + 10]), Color("#e8f4ff"), 1.5)
	Paint.poly(ci, Paint.pts([-22, 10, 0, 16, 22, 10, 22, 30, 0, 36, -22, 30]), Color("#e8dcc0"), 2.0)
	crown(ci, Vector2(0, -60), 28.0)
