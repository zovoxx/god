class_name ArtChars
extends RefCounted
## Wren, weapons and hub characters.

const GOLD := Color("#ffc94a")
const CREAM := Color("#fff4d6")

static func register(A) -> void:
	A.reg("wren", Vector2(52, 60), _wren)
	A.reg("w_fangs", Vector2(56, 40), _fangs)
	A.reg("w_pike", Vector2(110, 30), _pike)
	A.reg("w_anvil", Vector2(70, 46), _anvil)
	A.reg("w_bow", Vector2(40, 72), _bow)
	A.reg("w_halo", Vector2(52, 52), _halo)
	A.reg("knife", Vector2(30, 12), _knife)
	A.reg("arrow", Vector2(40, 12), _arrow)
	A.reg("ossa", Vector2(70, 90), _ossa)
	A.reg("quill", Vector2(70, 80), _quill)

static func _wren(ci: CanvasItem) -> void:
	# cloak
	var cloak := Paint.mirror([0, -18, 10, -14, 15, 2, 19, 22, 10, 26, 0, 24])
	Paint.poly(ci, cloak, Color("#2c4a6e"))
	ci.draw_colored_polygon(Paint.mirror([0, -6, 8, -2, 12, 20, 0, 21]), Color("#3b6390"))
	# scarf
	Paint.poly(ci, Paint.pts([-11, -6, 11, -6, 9, 0, -9, 0]), Color("#ff9a3d"), 2.0)
	# hood
	Paint.circ(ci, Vector2(0, -16), 12.0, Color("#3b6390"))
	ci.draw_circle(Vector2(0, -13), 8.0, Color("#0e0a18"))
	Paint.eye(ci, Vector2(-3.5, -13), 1.8, CREAM)
	Paint.eye(ci, Vector2(3.5, -13), 1.8, CREAM)
	# lantern at the hip
	Paint.line(ci, Vector2(12, 2), Vector2(16, 9), Color("#8a6a4a"), 2.0)
	Paint.glow(ci, Vector2(17, 15), 11.0, GOLD, false)
	Paint.poly(ci, Paint.pts([12, 9, 22, 9, 21, 21, 13, 21]), Color("#5a3a24"), 2.0)
	ci.draw_circle(Vector2(17, 15), 4.0, GOLD)
	ci.draw_circle(Vector2(17, 15), 2.0, Color.WHITE)

static func _fangs(ci: CanvasItem) -> void:
	for s in [-1.0, 1.0]:
		var o := Vector2(0, 9 * s)
		Paint.poly(ci, Paint.pts([-6 + o.x, -3 + o.y, 18 + o.x, -4 + o.y, 26 + o.x, o.y, 18 + o.x, 4 + o.y, -6 + o.x, 3 + o.y]), Color("#e8eef8"), 1.5)
		ci.draw_line(Vector2(-4, o.y), Vector2(20, o.y), GOLD, 1.5)
		Paint.poly(ci, Paint.pts([-14, -3 + o.y, -6, -3 + o.y, -6, 3 + o.y, -14, 3 + o.y]), Color("#5a3a24"), 1.5)

static func _pike(ci: CanvasItem) -> void:
	Paint.line(ci, Vector2(-50, 0), Vector2(28, 0), Color("#6a4a34"), 4.0)
	var c := Paint.pts([24, -12, 40, -6, 54, 0, 40, 6, 24, 12, 32, 0])
	Paint.poly(ci, c, Color("#e8f0ff"), 2.0)
	Paint.glow(ci, Vector2(36, 0), 7.0, Color("#bfe6ff"), false)
	ci.draw_circle(Vector2(30, 0), 3.0, GOLD)

static func _anvil(ci: CanvasItem) -> void:
	Paint.line(ci, Vector2(-34, 0), Vector2(6, 0), Color("#5a3a24"), 6.0)
	Paint.poly(ci, Paint.pts([4, -20, 30, -20, 34, -12, 34, 12, 30, 20, 4, 20, 0, 12, 0, -12]), Color("#3d3440"), 2.5)
	Paint.glow(ci, Vector2(18, 0), 12.0, Color("#ff8a2a"), false)
	ci.draw_colored_polygon(Paint.pts([8, -12, 26, -12, 26, 12, 8, 12]), Color("#ff7a2a"))
	ci.draw_colored_polygon(Paint.pts([12, -6, 22, -6, 22, 6, 12, 6]), Color("#ffd27a"))

static func _bow(ci: CanvasItem) -> void:
	var arc := PackedVector2Array()
	for i in 17:
		var a := lerpf(-1.2, 1.2, float(i) / 16.0)
		arc.append(Vector2(cos(a) * 14.0 - 6.0, sin(a) * 32.0))
	Paint.polyline(ci, arc, Color("#7a4a8a"), 4.0)
	ci.draw_line(arc[0], arc[16], Color("#e8e0ff"), 1.5)
	Paint.glow(ci, Vector2(8, 0), 6.0, Color("#d8c8ff"), true)

static func _halo(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2.ZERO, 22.0, GOLD, false)
	Paint.poly(ci, Paint.star(Vector2.ZERO, 24.0, 17.0, 10), Color("#ffd27a"), 2.0)
	ci.draw_circle(Vector2.ZERO, 11.0, Paint.OUT)
	ci.draw_circle(Vector2.ZERO, 8.0, Color("#fff4d6"))
	ci.draw_circle(Vector2.ZERO, 5.0, Paint.OUT)

static func _knife(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-12, -3, 8, -3, 14, 0, 8, 3, -12, 3]), Color("#f4f8ff"), 1.5)
	ci.draw_line(Vector2(-10, 0), Vector2(10, 0), GOLD, 1.5)

static func _arrow(ci: CanvasItem) -> void:
	Paint.line(ci, Vector2(-16, 0), Vector2(12, 0), Color("#e8e0ff"), 2.0)
	Paint.poly(ci, Paint.pts([10, -5, 19, 0, 10, 5]), Color("#ffffff"), 1.5)
	Paint.poly(ci, Paint.pts([-18, -5, -12, 0, -18, 5, -14, 0]), Color("#ffc94a"), 1.0)

static func _ossa(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -30, 14, -22, 20, 10, 24, 40, 0, 42]), Color("#5a4a3a"))
	Paint.circ(ci, Vector2(0, -28), 13.0, Color("#c8b898"))
	ci.draw_circle(Vector2(-4, -29), 2.0, Paint.OUT)
	ci.draw_circle(Vector2(4, -29), 2.0, Paint.OUT)
	Paint.line(ci, Vector2(22, -40), Vector2(22, 40), Color("#6a4a34"), 3.0)
	Paint.glow(ci, Vector2(22, -42), 10.0, GOLD, true)

static func _quill(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -20, 30, -34, 34, -6, 12, 8]), Color("#c8b8e8"))
	Paint.poly(ci, Paint.mirror([0, -10, 8, -6, 10, 26, 0, 32]), Color("#6a5a7a"))
	Paint.circ(ci, Vector2(0, -16), 9.0, Color("#8a7aa0"))
	Paint.eye(ci, Vector2(-4, -17), 2.2, Color("#ffd27a"))
	Paint.eye(ci, Vector2(4, -17), 2.2, Color("#ffd27a"))
