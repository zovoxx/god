class_name ArtEnemies4
extends RefCounted
## Depth 4 — The Starless Crown.

const VOID := Color("#2a1a40")
const PALE := Color("#d8d0f0")
const HOT := Color("#ff8a5a")

static func register(A) -> void:
	A.reg("voidcaller", Vector2(50, 60), _caller)
	A.reg("voidportal", Vector2(56, 56), _portal)
	A.reg("voidimp", Vector2(34, 32), _imp)
	A.reg("mirrorknight", Vector2(56, 64), _knight)
	A.reg("gravewell", Vector2(50, 54), _well)
	A.reg("prism", Vector2(44, 58), _prism)
	A.reg("wraithlancer", Vector2(54, 58), _lancer)
	A.reg("aegisherald", Vector2(50, 56), _herald)
	A.reg("hexer", Vector2(44, 56), _hexer)
	A.reg("nullshard", Vector2(42, 48), _shard)

static func _caller(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -26, 12, -18, 16, 8, 18, 28, 0, 24]), VOID)
	Paint.circ(ci, Vector2(0, -18), 10.0, Color("#3a2858"))
	Paint.eye(ci, Vector2(0, -18), 3.0, HOT)
	for s in [-1.0, 1.0]:
		Paint.glow(ci, Vector2(20 * s, -2), 6.0, Color("#d45cff"), true)

static func _portal(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.ell(Vector2.ZERO, 24, 26, 24), Color("#5a2a7a"), 3.0)
	ci.draw_colored_polygon(Paint.ell(Vector2.ZERO, 17, 19, 24), Color("#0a0414"))
	for i in 3:
		ci.draw_arc(Vector2.ZERO, 8.0 + i * 4.0, i * 1.3, i * 1.3 + 2.0, 8, Color("#d45cff"), 2.0)

static func _imp(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-12, 8, -14, -6, -8, -2, 0, -12, 8, -2, 14, -6, 12, 8, 0, 12]), Color("#4a2a6a"))
	Paint.eye(ci, Vector2(-4, 0), 2.0, HOT)
	Paint.eye(ci, Vector2(4, 0), 2.0, HOT)

static func _knight(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -28, 12, -22, 16, 6, 14, 30, 0, 28]), Color("#4a4a6a"))
	Paint.circ(ci, Vector2(0, -20), 10.0, Color("#6a6a8a"))
	ci.draw_rect(Rect2(-7, -22, 14, 4), Color("#0a0a14"))
	Paint.eye(ci, Vector2(0, -20), 1.8, HOT)
	Paint.poly(ci, Paint.pts([14, -20, 28, -14, 28, 12, 14, 18]), PALE, 2.5)
	ci.draw_line(Vector2(18, -12), Vector2(24, 8), Color(1, 1, 1, 0.7), 2.0)

static func _well(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, 4), 18.0, Color("#b48cff"), false)
	Paint.poly(ci, Paint.pts([0, -24, 14, -10, 16, 10, 0, 24, -16, 10, -14, -10]), Color("#3a2a5a"))
	ci.draw_circle(Vector2(0, 2), 8.0, Color("#0a0414"))
	ci.draw_arc(Vector2(0, 2), 11.0, 0, TAU, 16, Color("#b48cff"), 2.0)
	Paint.eye(ci, Vector2(0, -12), 2.4, HOT)

static func _prism(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([0, -26, 14, -4, 8, 24, -8, 24, -14, -4]), Color("#a8c0e8"))
	ci.draw_colored_polygon(Paint.pts([0, -18, 6, -4, 0, 16, -6, -4]), Color("#e8f4ff"))
	Paint.glow(ci, Vector2(0, -4), 8.0, HOT, true)

static func _lancer(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([0, -26, 12, -10, 10, 22, 0, 14, -10, 22, -12, -10]), Color("#3a4a6a"))
	Paint.line(ci, Vector2(-22, 18), Vector2(24, -24), Color("#c8d8ff"), 3.0)
	Paint.poly(ci, Paint.pts([24, -24, 30, -30, 26, -20]), PALE, 1.5)
	Paint.eye(ci, Vector2(-3, -12), 2.0, HOT)
	Paint.eye(ci, Vector2(3, -12), 2.0, HOT)

static func _herald(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -24, 14, -16, 18, 6, 10, 26, 0, 22]), Color("#3a4a6a"))
	ci.draw_arc(Vector2(0, -6), 22.0, PI * 1.1, PI * 1.9, 16, Color("#7fe3ff"), 4.0)
	Paint.circ(ci, Vector2(0, -14), 9.0, Color("#5a6a8a"))
	Paint.eye(ci, Vector2(0, -14), 2.4, HOT)

static func _hexer(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -26, 10, -16, 14, 8, 16, 26, 0, 22]), Color("#2a1a3a"))
	Paint.circ(ci, Vector2(0, -18), 9.0, Color("#3a2a4a"))
	Paint.eye(ci, Vector2(0, -18), 3.0, HOT)
	for i in 3:
		var a := -PI * 0.5 + (i - 1) * 0.8
		ci.draw_circle(Vector2(0, -18) + Geom.dir(a) * 18.0, 3.0, Color("#b45cff"))

static func _shard(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2.ZERO, 16.0, PALE, false)
	Paint.poly(ci, Paint.pts([0, -22, 12, 0, 0, 22, -12, 0]), Color("#8a80b0"))
	ci.draw_colored_polygon(Paint.pts([0, -12, 6, 0, 0, 12, -6, 0]), PALE)
	Paint.eye(ci, Vector2.ZERO, 2.4, HOT)
