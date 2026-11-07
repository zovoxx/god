class_name ArtEnemies2
extends RefCounted
## Depth 2 — The Drowned Archive.

static func register(A) -> void:
	A.reg("inkshade", Vector2(48, 56), _inkshade)
	A.reg("lanternist", Vector2(48, 60), _lanternist)
	A.reg("scribe", Vector2(48, 46), _scribe)
	A.reg("tidecleric", Vector2(50, 60), _tidecleric)
	A.reg("hookjaw", Vector2(58, 52), _hookjaw)
	A.reg("slurry", Vector2(74, 62), _slurry)
	A.reg("echo", Vector2(44, 54), _echo)
	A.reg("glimmerjelly", Vector2(52, 62), _jelly)

static func _inkshade(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([0, -24, 14, -14, 18, 6, 12, 24, 6, 16, 0, 26, -6, 16, -12, 24, -18, 6, -14, -14]), Color("#1c2238"))
	ci.draw_colored_polygon(Paint.pts([0, -16, 9, -8, 10, 6, -10, 6, -9, -8]), Color("#2a3458"))
	Paint.eye(ci, Vector2(-5, -8), 2.6, Color("#7fd4ff"))
	Paint.eye(ci, Vector2(5, -8), 2.6, Color("#7fd4ff"))

static func _lanternist(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -24, 10, -18, 15, 10, 16, 28, 0, 26]), Color("#3a3050"))
	Paint.circ(ci, Vector2(0, -18), 10.0, Color("#4a4064"))
	ci.draw_circle(Vector2(0, -16), 6.0, Color("#100c18"))
	Paint.eye(ci, Vector2(0, -16), 2.2, Color("#ffb04a"))
	Paint.line(ci, Vector2(10, -6), Vector2(20, -2), Color("#6a5a7a"), 3.0)
	Paint.glow(ci, Vector2(22, 4), 10.0, Color("#ff7a3a"), false)
	Paint.poly(ci, Paint.pts([17, -2, 27, -2, 26, 10, 18, 10]), Color("#5a3a24"), 2.0)
	ci.draw_circle(Vector2(22, 4), 3.5, Color("#ffd0a0"))

static func _scribe(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-20, -12, 0, -6, 20, -12, 20, 14, 0, 18, -20, 14]), Color("#c8c0e8"))
	ci.draw_line(Vector2(0, -6), Vector2(0, 18), Paint.OUT, 2.0)
	for i in 3:
		ci.draw_line(Vector2(-16, -4 + i * 6), Vector2(-4, -1 + i * 6), Color("#8a80a8"), 1.5)
		ci.draw_line(Vector2(4, -1 + i * 6), Vector2(16, -4 + i * 6), Color("#8a80a8"), 1.5)
	Paint.eye(ci, Vector2(0, -16), 4.0, Color("#ff9a6a"))

static func _tidecleric(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -24, 11, -18, 15, 8, 17, 28, 0, 26]), Color("#2a5a6a"))
	Paint.circ(ci, Vector2(0, -18), 10.0, Color("#3a7a8a"))
	ci.draw_circle(Vector2(0, -16), 6.0, Color("#0c1820"))
	Paint.eye(ci, Vector2(-2.5, -16), 1.8, Color("#a0fff0"))
	Paint.eye(ci, Vector2(2.5, -16), 1.8, Color("#a0fff0"))
	Paint.line(ci, Vector2(-16, -26), Vector2(-16, 26), Color("#6a5a4a"), 3.0)
	Paint.glow(ci, Vector2(-16, -28), 8.0, Color("#5ee8c8"), true)

static func _hookjaw(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-24, 0, -10, -16, 12, -14, 24, -4, 26, 6, 12, 14, -10, 14]), Color("#2a5a7a"))
	Paint.poly(ci, Paint.pts([-24, 0, -34, -10, -32, 10]), Color("#2a4a6a"), 2.0)
	Paint.poly(ci, Paint.pts([20, 4, 30, 8, 28, 18, 22, 22, 24, 14]), Color("#d8d0c0"), 2.0)
	ci.draw_line(Vector2(6, 2), Vector2(24, 4), Paint.OUT, 2.0)
	Paint.eye(ci, Vector2(10, -6), 3.0, Color("#ffd27a"))

static func _slurry(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-30, 18, -32, 4, -24, -12, -8, -22, 10, -20, 26, -10, 32, 6, 28, 20, 0, 24]), Color("#4aa080"))
	ci.draw_colored_polygon(Paint.ell(Vector2(-6, -6), 12, 6, 12), Color(1, 1, 1, 0.25))
	for p in [Vector2(-10, 2), Vector2(8, 0)]:
		Paint.eye(ci, p, 3.4, Color("#ffe0a0"))
	ci.draw_circle(Vector2(18, 12), 3.0, Color("#2a6a50"))

static func _echo(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, 0), 18.0, Color("#d8d0ff"), false)
	Paint.poly(ci, Paint.pts([0, -26, 12, -8, 8, 24, 0, 18, -8, 24, -12, -8]), Color("#9a8ad0"))
	ci.draw_colored_polygon(Paint.pts([0, -16, 6, -6, 0, 10, -6, -6]), Color("#e0d8ff"))
	Paint.eye(ci, Vector2(0, -8), 2.4, Color("#ff9a6a"))

static func _jelly(ci: CanvasItem) -> void:
	for i in 5:
		var x := -12 + i * 6
		Paint.polyline(ci, Paint.pts([x, 4, x - 3, 14, x + 2, 22, x - 1, 30]), Color("#ffb8f0"), 2.0)
	Paint.poly(ci, Paint.pts([-20, 6, -18, -10, -8, -20, 8, -20, 18, -10, 20, 6]), Color("#d87ac8"))
	Paint.glow(ci, Vector2(0, -6), 9.0, Color("#ffd8ff"), true)
	Paint.eye(ci, Vector2(-6, -2), 2.0, Color("#ff9a6a"))
	Paint.eye(ci, Vector2(6, -2), 2.0, Color("#ff9a6a"))
