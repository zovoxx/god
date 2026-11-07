extends Node2D
## Draws the room floor, walls and floor pattern for the current depth. Redrawn only when the
## room changes, so the many shapes are cached by the renderer.

var arena := {}
var style := 0
var seed_v := 1

func setup(a: Dictionary, room_seed: int) -> void:
	arena = a
	style = int(a.get("style", 0))
	seed_v = room_seed
	queue_redraw()

func _draw() -> void:
	if arena.is_empty():
		return
	var P := Palettes.get_depth(style)
	var r: Rect2 = arena.rect
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# outer darkness
	draw_rect(r.grow(900), P.bg)
	# wall band
	draw_rect(r.grow(46), P.wall)
	draw_rect(r.grow(46), P.wall_top, false, 6.0)
	# floor
	draw_rect(r, P.floor)
	var tile := 80.0
	match style:
		0: # gardens: irregular flagstones + moss tufts
			for y in range(int(r.position.y), int(r.end.y), int(tile)):
				for x in range(int(r.position.x), int(r.end.x), int(tile)):
					var o := Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
					var rr := Rect2(Vector2(x, y) + Vector2(5, 5) + o, Vector2(tile - 10, tile - 10)).intersection(r)
					if rr.size.x > 4 and rr.size.y > 4:
						draw_rect(rr, P.floor2 if rng.randf() < 0.5 else P.floor)
						draw_rect(rr, P.line, false, 2.0)
			for i in 40:
				var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
				draw_circle(p, rng.randf_range(3, 7), Color(P.accent, 0.22))
		1: # archive: long wooden boards + ink puddles
			for y in range(int(r.position.y), int(r.end.y), 40):
				var off := rng.randf_range(0, 160)
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), P.line, 2.0)
				var x := r.position.x - off
				while x < r.end.x:
					draw_line(Vector2(maxf(x, r.position.x), y), Vector2(maxf(x, r.position.x), minf(y + 40, r.end.y)), P.line, 2.0)
					x += rng.randf_range(140, 260)
			for i in 6:
				var p := Vector2(rng.randf_range(r.position.x + 60, r.end.x - 60), rng.randf_range(r.position.y + 60, r.end.y - 60))
				draw_colored_polygon(Paint.ell(p, rng.randf_range(30, 70), rng.randf_range(16, 30)), Color(P.accent, 0.08))
		2: # foundry: riveted metal plates
			for y in range(int(r.position.y), int(r.end.y), int(tile * 1.5)):
				for x in range(int(r.position.x), int(r.end.x), int(tile * 1.5)):
					var rr := Rect2(Vector2(x, y) + Vector2(3, 3), Vector2(tile * 1.5 - 6, tile * 1.5 - 6)).intersection(r)
					if rr.size.x > 4 and rr.size.y > 4:
						draw_rect(rr, P.floor2 if (x / int(tile * 1.5) + y / int(tile * 1.5)) % 2 == 0 else P.floor)
						draw_rect(rr, P.line, false, 2.0)
						for c in [rr.position + Vector2(8, 8), Vector2(rr.end.x - 8, rr.position.y + 8), rr.end - Vector2(8, 8), Vector2(rr.position.x + 8, rr.end.y - 8)]:
							draw_circle(c, 3.0, P.line.lightened(0.15))
		3: # crown: marble diamonds + star specks
			for y in range(int(r.position.y), int(r.end.y), int(tile)):
				for x in range(int(r.position.x), int(r.end.x), int(tile)):
					var c := Vector2(x + tile * 0.5, y + tile * 0.5)
					var d := Paint.pts([c.x, c.y - tile * 0.5, c.x + tile * 0.5, c.y, c.x, c.y + tile * 0.5, c.x - tile * 0.5, c.y])
					var col: Color = P.floor2 if (int(x / tile) + int(y / tile)) % 2 == 0 else P.floor
					if r.has_point(c):
						draw_colored_polygon(d, col)
			for i in 90:
				var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
				draw_circle(p, rng.randf_range(0.8, 2.2), Color(P.accent, rng.randf_range(0.2, 0.6)))
		_: # wick: warm planks
			for y in range(int(r.position.y), int(r.end.y), 46):
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), P.line, 2.0)
	# inner wall lip so the boundary reads clearly
	draw_rect(r, P.wall_top.lightened(0.1), false, 4.0)
	draw_rect(r.grow(-6), Color(0, 0, 0, 0.25), false, 8.0)
