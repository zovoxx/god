extends RefCounted
## Draws telegraphs and enemy floor hazards in the danger colours.
## Shapes fill from the outside in over the windup; the edge turns white in the counter
## window; the whole shape flashes white at impact. Boss attacks get a purple rim.

static func draw_all(ci: CanvasItem, sim: Sim, time: float) -> void:
	var F: GameFeel = Cfg.F
	var TG: Dictionary = F.telegraph
	var flash_w: float = TG.flash_window
	for t in sim.telegraphs:
		if t.cancelled:
			continue
		if t.resolved:
			var a: float = clampf(t.linger / float(TG.impact_flash), 0.0, 1.0) * Cfg.flash_mul
			_shape(ci, t, 1.0, Color(1, 1, 1, 0.75 * a), true)
			continue
		var p: float = t.progress()
		var danger := Cfg.col("danger")
		var hot := Cfg.col("danger_hot")
		if not t.hits_player:
			# aim line for a projectile: thin, brightening
			var c := Color(hot, 0.25 + 0.5 * p)
			var d := Geom.dir(t.angle)
			ci.draw_line(t.pos, t.pos + d * t.length, Color(Cfg.col("danger_outline"), 0.6), t.width * 0.5 + 4.0)
			ci.draw_line(t.pos, t.pos + d * t.length, c, t.width * 0.5)
			if t.in_flash(flash_w):
				ci.draw_line(t.pos, t.pos + d * t.length, Color(1, 1, 1, 0.8 * Cfg.flash_mul), 2.0)
			continue
		var fill := Color(danger, float(TG.fill_alpha) + 0.2 * p)
		_shape(ci, t, 1.0, Color(danger, 0.12), true)       # full area, faint
		_shape(ci, t, p, fill, true)                        # band filling from the outside in
		var edge := Color(hot, float(TG.edge_alpha))
		if t.in_flash(flash_w):
			edge = Color(1, 1, 1, 0.95) if not Cfg.reduce_flashing else Color(1, 0.9, 0.7, 0.95)
		_outline(ci, t, Color(Cfg.col("danger_outline"), 0.85), 6.0)
		_outline(ci, t, edge, 3.0)
		if t.boss:
			_outline(ci, t, Color(Cfg.col("boss"), 0.9), 1.5, 4.0)

## draws the shape filled from its outer edge inward to fraction k (1 = fully filled)
static func _shape(ci: CanvasItem, t, k: float, col: Color, filled: bool) -> void:
	k = clampf(k, 0.0, 1.0)
	if k <= 0.001:
		return
	match t.shape:
		Tele.Shape.CIRCLE:
			var band: float = t.radius * k
			ci.draw_arc(t.pos, t.radius - band * 0.5, 0, TAU, 48, col, band)
		Tele.Shape.RING:
			var w: float = t.radius - t.inner
			var band2: float = w * k
			ci.draw_arc(t.pos, t.radius - band2 * 0.5, 0, TAU, 56, col, band2)
		Tele.Shape.CONE:
			var r_in: float = t.radius * (1.0 - k)
			var pts := PackedVector2Array()
			var n := 20
			for i in n + 1:
				pts.append(t.pos + Geom.dir(t.angle - t.arc * 0.5 + t.arc * i / n) * t.radius)
			for i in range(n, -1, -1):
				pts.append(t.pos + Geom.dir(t.angle - t.arc * 0.5 + t.arc * i / n) * maxf(r_in, 0.5))
			ci.draw_colored_polygon(pts, col)
		Tele.Shape.LINE:
			var d := Geom.dir(t.angle)
			var nrm := d.orthogonal()
			var hw: float = t.width * 0.5
			var band3 := hw * k
			for s in [-1.0, 1.0]:
				var outer: Vector2 = nrm * hw * s
				var inner: Vector2 = nrm * (hw - band3) * s
				var pts2 := PackedVector2Array([t.pos + outer, t.pos + d * t.length + outer, t.pos + d * t.length + inner, t.pos + inner])
				ci.draw_colored_polygon(pts2, col)

static func _outline(ci: CanvasItem, t, col: Color, w: float, grow: float = 0.0) -> void:
	match t.shape:
		Tele.Shape.CIRCLE:
			ci.draw_arc(t.pos, t.radius + grow, 0, TAU, 48, col, w, true)
		Tele.Shape.RING:
			ci.draw_arc(t.pos, t.radius + grow, 0, TAU, 56, col, w, true)
			ci.draw_arc(t.pos, maxf(1.0, t.inner - grow), 0, TAU, 48, col, w, true)
		Tele.Shape.CONE:
			var pts := PackedVector2Array([t.pos])
			var n := 20
			for i in n + 1:
				pts.append(t.pos + Geom.dir(t.angle - t.arc * 0.5 + t.arc * i / n) * (t.radius + grow))
			pts.append(t.pos)
			ci.draw_polyline(pts, col, w, true)
		Tele.Shape.LINE:
			var d := Geom.dir(t.angle)
			var nrm = d.orthogonal() * (t.width * 0.5 + grow)
			var pts2 := PackedVector2Array([t.pos + nrm, t.pos + d * t.length + nrm, t.pos + d * t.length - nrm, t.pos - nrm, t.pos + nrm])
			ci.draw_polyline(pts2, col, w, true)

## enemy floor hazards: two warning pulses, then a solid danger fill while active
static func draw_enemy_hazard(ci: CanvasItem, h: SimHazard, time: float) -> void:
	var danger := Cfg.col("danger")
	var hot := Cfg.col("danger_hot")
	var outline := Cfg.col("danger_outline")
	if not h.active():
		var k := clampf(h.t / maxf(0.001, h.warn), 0.0, 1.0)
		var pulses := float(Cfg.F.telegraph.hazard_pulses)
		var pulse := 0.5 - 0.5 * cos(k * pulses * TAU)
		_hshape(ci, h, Color(danger, 0.08 + 0.3 * pulse), true)
		_hshape(ci, h, Color(hot, 0.4 + 0.5 * pulse), false)
		return
	var fade := clampf((h.life - h.t) / 0.25, 0.0, 1.0)
	_hshape(ci, h, Color(danger, 0.42 * fade), true)
	_hshape(ci, h, Color(outline, 0.8 * fade), false, 5.0)
	_hshape(ci, h, Color(hot, 0.9 * fade), false, 2.5)
	if h.kind in ["fire", "slag", "field"]:
		for i in 2:
			var a := time * 3.0 + i * PI + h.id
			ci.draw_circle(h.pos + Geom.dir(a) * h.radius * 0.5, h.radius * 0.18, Color(Cfg.col("danger_core"), 0.35 * fade))

static func _hshape(ci: CanvasItem, h: SimHazard, col: Color, filled: bool, w: float = 3.0) -> void:
	match h.shape:
		SimHazard.Shape.LINE:
			var d := Geom.dir(h.angle)
			if filled:
				ci.draw_line(h.pos, h.pos + d * h.length, col, h.width)
			else:
				var nrm := d.orthogonal() * h.width * 0.5
				ci.draw_polyline(PackedVector2Array([h.pos + nrm, h.pos + d * h.length + nrm, h.pos + d * h.length - nrm, h.pos - nrm, h.pos + nrm]), col, w)
		SimHazard.Shape.RING:
			if filled:
				ci.draw_arc(h.pos, (h.radius + h.inner) * 0.5, 0, TAU, 48, col, h.radius - h.inner)
			else:
				ci.draw_arc(h.pos, h.radius, 0, TAU, 48, col, w)
				ci.draw_arc(h.pos, h.inner, 0, TAU, 40, col, w)
		_:
			if filled:
				ci.draw_circle(h.pos, h.radius, col)
			else:
				ci.draw_arc(h.pos, h.radius, 0, TAU, 40, col, w, true)
