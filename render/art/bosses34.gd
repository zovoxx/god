class_name ArtBosses34
extends RefCounted
## Guardians and bosses of depths 3–4.

const IRON := Color("#5a6070")
const BRASS := Color("#b08a4a")
const HOT := Color("#ff9a3d")

static func register(A) -> void:
	A.reg("mini_riveter", Vector2(80, 78), _riveter)
	A.reg("mini_foreman", Vector2(100, 100), _foreman)
	A.reg("mini_eclipse", Vector2(90, 96), _eclipse)
	A.reg("mini_matron", Vector2(96, 96), _matron)
	A.reg("boss_engine", Vector2(170, 150), _engine)
	A.reg("boss_regent", Vector2(116, 136), _regent)

static func _riveter(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -32, 22, -24, 30, 4, 24, 30, 0, 32]), IRON)
	for i in 4:
		ci.draw_circle(Vector2(-16 + i * 10, -18), 3.0, BRASS)
	Paint.poly(ci, Paint.pts([24, -6, 40, -10, 40, 6, 24, 8]), Color("#7a8090"), 2.0)
	Paint.glow(ci, Vector2(0, -4), 10.0, Color("#ffe24a"), true)
	Paint.eye(ci, Vector2(-8, -12), 2.6, HOT)
	Paint.eye(ci, Vector2(8, -12), 2.6, HOT)
	ArtBosses.crown(ci, Vector2(0, -34), 22.0)

static func _foreman(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -40, 28, -32, 40, 0, 36, 40, 0, 44]), Color("#6a7282"))
	Paint.poly(ci, Paint.mirror([0, -30, 18, -24, 22, 10, 0, 20]), Color("#8a92a2"), 2.0)
	ci.draw_rect(Rect2(-14, -22, 28, 7), Color("#100c10"))
	Paint.eye(ci, Vector2(-6, -19), 2.4, HOT)
	Paint.eye(ci, Vector2(6, -19), 2.4, HOT)
	Paint.line(ci, Vector2(30, 10), Vector2(46, -30), Color("#4a3424"), 6.0)
	Paint.poly(ci, Paint.pts([36, -44, 58, -36, 54, -22, 32, -30]), IRON, 2.5)
	ArtBosses.crown(ci, Vector2(0, -44), 26.0)

static func _eclipse(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, -20), 30.0, Color("#e0e8ff"), false)
	Paint.poly(ci, Paint.mirror([0, -36, 16, -28, 22, 8, 20, 42, 0, 38]), Color("#2a2a4a"))
	Paint.circ(ci, Vector2(0, -28), 14.0, Color("#4a4a6a"))
	ci.draw_circle(Vector2(0, -28), 9.0, Color("#e0e8ff"))
	ci.draw_circle(Vector2(3, -28), 8.0, Color("#0a0a18"))
	Paint.line(ci, Vector2(24, 30), Vector2(36, -34), Color("#d8e0ff"), 4.0)
	ArtBosses.crown(ci, Vector2(0, -44), 24.0)

static func _matron(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2.ZERO, 40.0, Color("#d45cff"), false)
	Paint.poly(ci, Paint.mirror([0, -40, 22, -28, 36, 0, 28, 40, 0, 32]), Color("#3a1a5a"))
	ci.draw_colored_polygon(Paint.ell(Vector2(0, 4), 18, 20, 20), Color("#0a0414"))
	for i in 3:
		ci.draw_arc(Vector2(0, 4), 6.0 + i * 5.0, i * 1.2, i * 1.2 + 2.2, 10, Color("#d45cff"), 2.5)
	Paint.eye(ci, Vector2(-8, -22), 3.0, HOT)
	Paint.eye(ci, Vector2(8, -22), 3.0, HOT)
	ArtBosses.crown(ci, Vector2(0, -42), 26.0)

static func _engine(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-74, 50, -78, -10, -50, -50, 50, -50, 78, -10, 74, 50]), Color("#4a4e58"))
	for i in 5:
		ci.draw_rect(Rect2(-60 + i * 26, 30, 16, 14), Color("#2a2e36"))
		Paint.glow(ci, Vector2(-52 + i * 26, 37), 5.0, HOT, false)
	ci.draw_circle(Vector2(0, -4), 34.0, Paint.OUT)
	ci.draw_circle(Vector2(0, -4), 30.0, BRASS)
	for i in 8:
		var a := TAU * i / 8.0
		ci.draw_line(Vector2(0, -4) + Geom.dir(a) * 18.0, Vector2(0, -4) + Geom.dir(a) * 30.0, Color("#6a5028"), 4.0)
	Paint.glow(ci, Vector2(0, -4), 16.0, HOT, true)
	for s in [-1.0, 1.0]:
		Paint.poly(ci, Paint.pts([56 * s, -50, 66 * s, -70, 74 * s, -66, 70 * s, -40]), IRON, 2.0)
	ArtBosses.crown(ci, Vector2(0, -58), 36.0)

static func _regent(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, -10), 50.0, Color("#e0d8ff"), false)
	Paint.poly(ci, Paint.mirror([0, -46, 20, -34, 34, 4, 42, 52, 16, 62, 0, 56]), Color("#d8d0e8"))
	ci.draw_colored_polygon(Paint.mirror([0, -24, 14, -14, 20, 40, 0, 48]), Color("#a8a0c0"))
	Paint.circ(ci, Vector2(0, -38), 15.0, Color("#f0ecff"))
	ci.draw_colored_polygon(Paint.ell(Vector2(0, -36), 9, 11, 16), Color("#0a0614"))
	Paint.eye(ci, Vector2(-3.5, -37), 2.2, HOT)
	Paint.eye(ci, Vector2(3.5, -37), 2.2, HOT)
	Paint.glow(ci, Vector2(0, -60), 14.0, Color("#b05cff"), false)
	ArtBosses.crown(ci, Vector2(0, -56), 34.0)
	for i in 6:
		var a := PI + 0.2 + i * 0.55
		ci.draw_circle(Vector2(0, -10) + Geom.dir(a) * 58.0, 3.0, Color("#fff4d6"))
