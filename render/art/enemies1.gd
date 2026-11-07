class_name ArtEnemies1
extends RefCounted
## Depth 1 — The Ashen Gardens.

const EMB := Color("#ff8a2a")

static func register(A) -> void:
	A.reg("cinderling", Vector2(46, 46), _cinderling)
	A.reg("bramblehorn", Vector2(70, 60), _bramblehorn)
	A.reg("spitbloom", Vector2(56, 60), _spitbloom)
	A.reg("ashwisp", Vector2(34, 38), _ashwisp)
	A.reg("burrowmaw", Vector2(60, 60), _burrowmaw)
	A.reg("mound", Vector2(60, 40), _mound)
	A.reg("kindlepod", Vector2(46, 54), _kindlepod)
	A.reg("thornwarden", Vector2(64, 66), _thornwarden)
	A.reg("grubmother", Vector2(70, 60), _grubmother)
	A.reg("grub", Vector2(30, 26), _grub)

static func _cinderling(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, 2), 16.0, EMB, false)
	Paint.poly(ci, Paint.mirror([0, -18, 6, -12, 13, -16, 12, -4, 15, 8, 9, 17, 0, 15]), Color("#3a2a28"))
	ci.draw_polyline(Paint.pts([-6, 4, -2, 9, 3, 5, 7, 11]), EMB, 2.0)
	ci.draw_polyline(Paint.pts([-9, -4, -4, -1]), EMB, 2.0)
	Paint.eye(ci, Vector2(-4, -6), 2.4, Color("#ffd27a"))
	Paint.eye(ci, Vector2(4, -6), 2.4, Color("#ffd27a"))

static func _bramblehorn(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.ell(Vector2(-2, 6), 26, 17, 18), Color("#6a4a34"))
	for i in 4:
		Paint.poly(ci, Paint.pts([-20 + i * 9, -6, -16 + i * 9, -16, -12 + i * 9, -6]), Color("#7aa05a"), 1.5)
	Paint.circ(ci, Vector2(20, 0), 12.0, Color("#7a5a40"))
	Paint.poly(ci, Paint.pts([22, -8, 34, -22, 30, -6]), Color("#d8c8a0"), 2.0)
	Paint.poly(ci, Paint.pts([24, 6, 36, 16, 28, 10]), Color("#d8c8a0"), 2.0)
	Paint.eye(ci, Vector2(24, -2), 2.4, Color("#ffb04a"))
	for x in [-14, -2, 10]:
		Paint.line(ci, Vector2(x, 20), Vector2(x, 27), Color("#4a3424"), 4.0)

static func _spitbloom(ci: CanvasItem) -> void:
	Paint.line(ci, Vector2(0, 28), Vector2(0, 6), Color("#4a7a3a"), 5.0)
	Paint.poly(ci, Paint.pts([-4, 22, -18, 14, -6, 16]), Color("#5a9a4a"), 1.5)
	Paint.poly(ci, Paint.pts([4, 24, 18, 16, 6, 18]), Color("#5a9a4a"), 1.5)
	for i in 6:
		var a := TAU * i / 6.0
		Paint.poly(ci, Paint.ell(Vector2(0, -6) + Geom.dir(a) * 12.0, 9, 6, 10, a), Color("#9ad06a"), 1.5)
	Paint.circ(ci, Vector2(0, -6), 9.0, Color("#3a5a2a"))
	Paint.glow(ci, Vector2(0, -6), 7.0, Color("#ff9a4a"), true)

static func _ashwisp(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, 2), 14.0, Color("#ffd8a0"), false)
	Paint.poly(ci, Paint.pts([0, -16, 7, -4, 10, 8, 0, 14, -10, 8, -7, -4]), Color("#8a8078"))
	ci.draw_colored_polygon(Paint.pts([0, -6, 5, 3, 0, 9, -5, 3]), Color("#ffe6c0"))
	Paint.eye(ci, Vector2(-3, 0), 1.6, Color("#ff9a3d"))
	Paint.eye(ci, Vector2(3, 0), 1.6, Color("#ff9a3d"))

static func _burrowmaw(ci: CanvasItem) -> void:
	Paint.circ(ci, Vector2.ZERO, 24.0, Color("#b08a5a"))
	ci.draw_circle(Vector2.ZERO, 15.0, Color("#3a1810"))
	for i in 10:
		var a := TAU * i / 10.0
		ci.draw_colored_polygon(PackedVector2Array([Geom.dir(a - 0.15) * 15.0, Geom.dir(a + 0.15) * 15.0, Geom.dir(a) * 8.0]), Color("#f0e0c0"))
	Paint.glow(ci, Vector2.ZERO, 5.0, Color("#ff7a3a"), true)

static func _mound(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.ell(Vector2(0, 4), 26, 13, 16), Color("#6a5034"), 2.0)
	for i in 5:
		ci.draw_circle(Vector2(-16 + i * 8, 2 - (i % 2) * 4), 4.0, Color("#8a6a44"))

static func _kindlepod(ci: CanvasItem) -> void:
	Paint.line(ci, Vector2(2, -18), Vector2(8, -26), Color("#4a3424"), 3.0)
	Paint.glow(ci, Vector2(8, -26), 5.0, Color("#ffd27a"), true)
	Paint.poly(ci, Paint.ell(Vector2(0, 4), 16, 20, 18), Color("#6a2a1a"))
	for i in 3:
		ci.draw_polyline(Paint.pts([-10 + i * 8, -8, -8 + i * 8, 4, -11 + i * 8, 14]), EMB, 2.0)
	Paint.eye(ci, Vector2(-5, 0), 2.0, Color("#ffd27a"))
	Paint.eye(ci, Vector2(5, 0), 2.0, Color("#ffd27a"))

static func _thornwarden(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.mirror([0, -26, 12, -20, 16, 6, 14, 26, 0, 28]), Color("#5a4a34"))
	Paint.circ(ci, Vector2(0, -20), 10.0, Color("#6a5a40"))
	Paint.eye(ci, Vector2(-3, -21), 2.0, Color("#b8ff7a"))
	Paint.eye(ci, Vector2(3, -21), 2.0, Color("#b8ff7a"))
	# the big bark shield (front = right)
	Paint.poly(ci, Paint.pts([14, -24, 30, -16, 32, 10, 18, 26, 12, 8]), Color("#7a6a44"), 2.5)
	for i in 4:
		Paint.poly(ci, Paint.pts([28, -14 + i * 9, 36, -11 + i * 9, 28, -8 + i * 9]), Color("#9ac06a"), 1.0)

static func _grubmother(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.ell(Vector2(0, 4), 30, 22, 20), Color("#d8c08a"))
	for i in 4:
		ci.draw_arc(Vector2(-18 + i * 12, 4), 14.0, -1.2, 1.2, 8, Color("#a88a5a"), 2.0)
	for p in [Vector2(-16, -12), Vector2(0, -16), Vector2(16, -12)]:
		Paint.circ(ci, p, 6.0, Color("#f0e0a0"), 2.0)
		Paint.glow(ci, p, 3.0, Color("#ffe0a0"), true)
	Paint.eye(ci, Vector2(20, 2), 2.5, Color("#ff9a3d"))
	Paint.eye(ci, Vector2(26, 2), 2.5, Color("#ff9a3d"))

static func _grub(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.ell(Vector2.ZERO, 12, 8, 14), Color("#e0cc98"), 2.0)
	ci.draw_arc(Vector2(-3, 0), 7.0, -1.0, 1.0, 6, Color("#a88a5a"), 1.5)
	Paint.eye(ci, Vector2(7, -2), 1.6, Color("#ff9a3d"))
