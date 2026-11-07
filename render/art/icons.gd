class_name ArtIcons
extends RefCounted
## UI icons: Death Defiance lantern, boon slots, status effects, elite modifiers, currencies.

static func register(A) -> void:
	A.reg("i_lantern", Vector2(30, 40), _lantern)
	A.reg("i_lantern_off", Vector2(30, 40), _lantern_off)
	A.reg("i_gold", Vector2(24, 24), func(ci): Paint.circ(ci, Vector2.ZERO, 9.0, Color("#ffd166")); ci.draw_circle(Vector2(-3, -3), 3.0, Color.WHITE))
	A.reg("i_ember", Vector2(24, 24), func(ci): Paint.glow(ci, Vector2.ZERO, 10.0, Color("#ffe6a0")))
	# boon slots (drawn as glyphs, tinted by the HUD)
	A.reg("i_slot_attack", Vector2(24, 24), func(ci): Paint.poly(ci, Paint.pts([-8, 8, 6, -6, 9, -9, 6, -4, -6, 8]), Color.WHITE, 1.0))
	A.reg("i_slot_special", Vector2(24, 24), func(ci): Paint.poly(ci, Paint.star(Vector2.ZERO, 10.0, 4.0, 4), Color.WHITE, 1.0))
	A.reg("i_slot_dash", Vector2(24, 24), func(ci):
		for i in 3:
			ci.draw_line(Vector2(-9 + i * 3, -6 + i * 6), Vector2(8, -6 + i * 6), Color.WHITE, 3.0))
	A.reg("i_slot_cast", Vector2(24, 24), func(ci):
		ci.draw_arc(Vector2.ZERO, 8.0, 0, TAU, 20, Color.WHITE, 3.0)
		ci.draw_circle(Vector2.ZERO, 3.0, Color.WHITE))
	A.reg("i_slot_revenge", Vector2(24, 24), func(ci): Paint.poly(ci, Paint.pts([0, -10, 9, -4, 7, 7, 0, 10, -7, 7, -9, -4]), Color.WHITE, 1.0))
	A.reg("i_slot_passive", Vector2(24, 24), func(ci): ci.draw_circle(Vector2.ZERO, 8.0, Color.WHITE))
	A.reg("i_slot_legendary", Vector2(24, 24), func(ci): Paint.poly(ci, Paint.pts([-9, 6, -9, -6, -4, 0, 0, -9, 4, 0, 9, -6, 9, 6]), Color.WHITE, 1.0))
	A.reg("i_slot_duo", Vector2(24, 24), func(ci):
		ci.draw_circle(Vector2(-4, 0), 6.0, Color.WHITE)
		ci.draw_circle(Vector2(4, 0), 6.0, Color(1, 1, 1, 0.7)))
	# statuses
	A.reg("i_st_burn", Vector2(16, 16), func(ci): ci.draw_colored_polygon(Paint.pts([0, -7, 5, 1, 3, 6, -3, 6, -5, 1]), Color.WHITE))
	A.reg("i_st_chill", Vector2(16, 16), _flake)
	A.reg("i_st_freeze", Vector2(16, 16), _flake)
	A.reg("i_st_hex", Vector2(16, 16), func(ci):
		ci.draw_colored_polygon(Paint.ell(Vector2.ZERO, 7, 4, 12), Color.WHITE)
		ci.draw_circle(Vector2.ZERO, 2.5, Color.BLACK))
	A.reg("i_st_bleed", Vector2(16, 16), func(ci): ci.draw_colored_polygon(Paint.pts([0, -7, 5, 2, 0, 7, -5, 2]), Color.WHITE))
	A.reg("i_st_mark", Vector2(16, 16), func(ci): ci.draw_colored_polygon(Paint.star(Vector2.ZERO, 7.0, 3.0, 4), Color.WHITE))
	# elite modifiers
	var E := {
		"hasted": ["#8dffc8", _i_haste], "shielded": ["#7fe3ff", _i_shield], "volatile": ["#ff7a2a", _i_bomb], "blazing": ["#ff4a2a", _i_fire],
		"vampiric": ["#ff3d6e", _i_fang], "brood": ["#c9ff6a", _i_brood], "hulking": ["#ffd166", _i_hulk], "blinking": ["#d45cff", _i_blink],
		"orbiting": ["#fff1a6", _i_orbit], "mending": ["#5dff9a", _i_mend],
	}
	for k in E.keys():
		var col := Color(E[k][0])
		var f: Callable = E[k][1]
		A.reg("i_elite_" + k, Vector2(20, 20), func(ci):
			ci.draw_circle(Vector2.ZERO, 9.5, Paint.OUT)
			ci.draw_circle(Vector2.ZERO, 8.0, col)
			f.call(ci))

static func _lantern(ci: CanvasItem) -> void:
	Paint.glow(ci, Vector2(0, 4), 14.0, Color("#ffc94a"), false)
	ci.draw_line(Vector2(0, -18), Vector2(0, -12), Paint.OUT, 3.0)
	Paint.poly(ci, Paint.pts([-9, -12, 9, -12, 11, 14, -11, 14]), Color("#5a3a24"), 2.0)
	ci.draw_colored_polygon(Paint.pts([-6, -8, 6, -8, 7, 10, -7, 10]), Color("#ffc94a"))
	ci.draw_circle(Vector2(0, 2), 4.0, Color.WHITE)

static func _lantern_off(ci: CanvasItem) -> void:
	Paint.poly(ci, Paint.pts([-9, -12, 9, -12, 11, 14, -11, 14]), Color("#3a2a20"), 2.0)
	ci.draw_colored_polygon(Paint.pts([-6, -8, 6, -8, 7, 10, -7, 10]), Color("#241a16"))

static func _flake(ci: CanvasItem) -> void:
	for i in 3:
		var a := PI * i / 3.0
		ci.draw_line(Geom.dir(a) * 7.0, -Geom.dir(a) * 7.0, Color.WHITE, 2.0)

static func _i_haste(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(Paint.pts([-4, -6, 2, -1, -1, 0, 4, 6, -2, 1, 1, 0]), Color.BLACK)
static func _i_shield(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(Paint.pts([0, -6, 5, -3, 4, 3, 0, 6, -4, 3, -5, -3]), Color.BLACK)
static func _i_bomb(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(0, 1), 4.0, Color.BLACK)
	ci.draw_line(Vector2(2, -3), Vector2(4, -6), Color.BLACK, 1.5)
static func _i_fire(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(Paint.pts([0, -6, 4, 1, 2, 5, -2, 5, -4, 1]), Color.BLACK)
static func _i_fang(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(Paint.pts([-4, -4, -1, 5, 0, -4]), Color.BLACK)
	ci.draw_colored_polygon(Paint.pts([4, -4, 1, 5, 0, -4]), Color.BLACK)
static func _i_brood(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(-2.5, 0), 2.5, Color.BLACK)
	ci.draw_circle(Vector2(2.5, 0), 2.5, Color.BLACK)
static func _i_hulk(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-4, -4, 8, 8), Color.BLACK)
static func _i_blink(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2.ZERO, 4.5, 0.5, TAU - 0.5, 10, Color.BLACK, 2.0)
static func _i_orbit(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2.ZERO, 2.0, Color.BLACK)
	ci.draw_arc(Vector2.ZERO, 5.5, 0, TAU, 12, Color.BLACK, 1.2)
static func _i_mend(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-1.5, -5, 3, 10), Color.BLACK)
	ci.draw_rect(Rect2(-5, -1.5, 10, 3), Color.BLACK)
