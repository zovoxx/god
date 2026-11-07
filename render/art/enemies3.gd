class_name ArtEnemies3
extends RefCounted
## Depth 3 — The Clockwork Foundry.

const IRON := Color("#5a6070")
const BRASS := Color("#b08a4a")
const HOT := Color("#ff9a3d")

static func register(A) -> void:
	A.reg("rivethound", Vector2(48, 40), _hound)
	A.reg("coilsentry", Vector2(46, 56), _sentry)
	A.reg("pylon", Vector2(28, 44), _pylon)
	A.reg("ironclad", Vector2(74, 74), _ironclad)
	A.reg("forgemortar", Vector2(58, 58), _mortar)
	A.reg("bellwether", Vector2(52, 58), _bell)
	A.reg("gyrosaw", Vector2(52, 52), _saw)
	A.reg("slagcrawler", Vector2(54, 44), _slag)
	A.reg("sparkmite", Vector2(26, 26), _mite)

static func _hound(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-20, 4, -14, -8, 8, -10, 20, -4, 22, 6, 10, 10, -14, 10]), IRON)
	for x in [-14, -4, 8, 16]:
		Paint.line(ci, Vector2(x, 10), Vector2(x - 2, 18), Color("#3a3e48"), 3.0)
	Paint.poly(ci, Paint.pts([16, -10, 26, -6, 28, 2, 18, 2]), Color("#6a7080"), 2.0)
	for p in [Vector2(-10, -2), Vector2(0, -3), Vector2(10, -2)]:
		ci.draw_circle(p, 2.0, BRASS)
	Paint.eye(ci, Vector2(22, -4), 2.2, HOT)

static func _sentry(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -24, 10, -18, 14, 8, 12, 26, 0, 24]), Color("#4a4e58"))
	for i in 3:
		ci.draw_arc(Vector2(0, -2 + i * 8), 11.0, 0, PI, 10, BRASS, 2.0)
	Paint.glow(ci, Vector2(0, -24), 8.0, Color("#ffe24a"), true)
	Paint.eye(ci, Vector2(0, -10), 2.6, HOT)

static func _pylon(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-8, 18, -5, -12, 5, -12, 8, 18]), Color("#4a4e58"), 2.0)
	ci.draw_line(Vector2(0, -10), Vector2(0, 14), BRASS, 2.0)
	Paint.glow(ci, Vector2(0, -16), 7.0, Color("#ffe24a"), true)

static func _ironclad(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -32, 20, -26, 30, -4, 28, 26, 14, 34, 0, 32]), Color("#6a7282"))
	Paint.poly(ci, Paint.mirror([0, -22, 14, -16, 18, 10, 0, 18]), Color("#8a92a2"), 2.0)
	for p in [Vector2(-18, -18), Vector2(18, -18), Vector2(-20, 14), Vector2(20, 14)]:
		ci.draw_circle(p, 3.0, BRASS)
	ci.draw_rect(Rect2(-10, -14, 20, 5), Color("#100c10"))
	Paint.eye(ci, Vector2(-4, -12), 1.8, HOT)
	Paint.eye(ci, Vector2(4, -12), 1.8, HOT)

static func _mortar(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.ell(Vector2(0, 12), 24, 12, 18), Color("#3a3e48"))
	Paint.poly(ci, Paint.pts([-12, 8, -10, -18, 10, -18, 12, 8]), IRON)
	ci.draw_circle(Vector2(0, -18), 9.0, Paint.OUT)
	Paint.glow(ci, Vector2(0, -18), 7.0, HOT, true)
	for x in [-16, 0, 16]:
		ci.draw_circle(Vector2(x, 14), 3.0, BRASS)

static func _bell(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-18, 18, -12, -12, -4, -22, 4, -22, 12, -12, 18, 18]), BRASS)
	ci.draw_line(Vector2(-18, 14), Vector2(18, 14), Color("#8a6a30"), 3.0)
	Paint.circ(ci, Vector2(0, 22), 5.0, Color("#d8b060"), 2.0)
	Paint.eye(ci, Vector2(-5, -4), 2.0, HOT)
	Paint.eye(ci, Vector2(5, -4), 2.0, HOT)

static func _saw(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.star(Vector2.ZERO, 24.0, 18.0, 12), Color("#c8d0dc"), 2.0)
	ci.draw_circle(Vector2.ZERO, 12.0, IRON)
	ci.draw_circle(Vector2.ZERO, 5.0, Paint.OUT)
	Paint.eye(ci, Vector2.ZERO, 2.5, HOT)

static func _slag(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.ell(Vector2(0, 2), 24, 14, 18), Color("#3a2a24"))
	ci.draw_polyline(Paint.pts([-16, 0, -6, 6, 4, -2, 14, 4]), HOT, 3.0)
	for i in 4:
		Paint.line(ci, Vector2(-14 + i * 9, 12), Vector2(-18 + i * 9, 20), Color("#2a1c18"), 3.0)
	Paint.eye(ci, Vector2(18, -4), 2.4, Color("#ffd27a"))

static func _mite(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2.ZERO, 10.0, Color("#ffe24a"), false)
	Paint.circ(ci, Vector2.ZERO, 7.0, Color("#5a5040"), 2.0)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		ci.draw_line(Geom.dir(a) * 6.0, Geom.dir(a) * 11.0, Paint.OUT, 2.0)
	ci.draw_circle(Vector2.ZERO, 3.0, Color("#ffe24a"))
