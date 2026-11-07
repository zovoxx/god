class_name ArtFx
extends RefCounted
## Training dummy, hazard icon and small FX sprites.

static func register(A) -> void:
	A.reg("dummy", Vector2(48, 64), _dummy)
	A.reg("hazard", Vector2(32, 32), _hazard)

static func _dummy(ci: CanvasItem) -> void:
	Paint.line(ci, Vector2(0, 30), Vector2(0, -6), Color("#6a4a34"), 5.0)
	Paint.line(ci, Vector2(-20, -4), Vector2(20, -4), Color("#6a4a34"), 4.0)
	Paint.poly(ci, Paint.ell(Vector2(0, 4), 15, 18, 16), Color("#d8c08a"))
	Paint.circ(ci, Vector2(0, -18), 11.0, Color("#e8d4a0"))
	ci.draw_line(Vector2(-5, -21), Vector2(-1, -17), Paint.OUT, 2.0)
	ci.draw_line(Vector2(-1, -21), Vector2(-5, -17), Paint.OUT, 2.0)
	ci.draw_line(Vector2(1, -21), Vector2(5, -17), Paint.OUT, 2.0)
	ci.draw_line(Vector2(5, -21), Vector2(1, -17), Paint.OUT, 2.0)
	for i in 3:
		ci.draw_line(Vector2(-12, -2 + i * 7), Vector2(12, 1 + i * 7), Color("#a88a5a"), 2.0)

static func _hazard(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([0, -13, 13, 11, -13, 11]), Color("#ff6a2a"))
	ci.draw_line(Vector2(0, -5), Vector2(0, 3), Paint.OUT, 3.0)
	ci.draw_circle(Vector2(0, 7), 1.8, Paint.OUT)
