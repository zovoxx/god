extends Control
## In-run HUD and screen-space clarity effects: HP bar (chip damage, heals, barrier,
## Death Defiance lanterns), dash pips, Special/Sigil cooldown rings, Overdrive meter, gold
## and Embers, streak tier, boon strip, depth/room, boss bar and callout banners; red edge
## flash + directional damage arc on hurt, low-HP vignette, off-screen threat arrows.

var sim: Sim
var world
var font: Font
var chip: HpChip
var time := 0.0
var hurt_flash := 0.0
var arcs: Array = []          # {ang, t}
var banners: Array = []       # {text, sub, col, t, life, big}
var lantern_break := 0.0
var low_hp := false
var low_hp_k := 0.0
var heal_glow := 0.0
var streak_glow := 0.0
var _defiance_shown := -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	Bus.event.connect(_on_event)

func bind(s: Sim, wv) -> void:
	sim = s
	world = wv
	var H: Dictionary = Cfg.F.hpbar
	chip = HpChip.new(s.player.hp, H.chip_delay, H.chip_drain_speed, H.heal_fill_speed)
	_defiance_shown = s.run.defiance if s.run != null else 0

func _on_event(name: StringName, d: Dictionary) -> void:
	if sim == null:
		return
	match name:
		&"player_hurt":
			hurt_flash = 1.0
			arcs.append({"ang": (d.src - sim.player.pos).angle(), "t": 0.0})
		&"player_healed":
			heal_glow = 1.0
		&"player_defied":
			lantern_break = 1.0
			banners.append({"text": "DEFIED", "sub": "a lantern shatters", "col": Cfg.col("player_gold"), "t": 0.0, "life": 1.8, "big": true})
		&"boss_callout":
			banners.append({"text": String(d.text), "sub": "", "col": Cfg.col("boss"), "t": 0.0, "life": 1.1, "big": false, "top": true})
		&"boss_phase":
			banners.append({"text": String(d.get("text", "PHASE %d" % (int(d.phase) + 1))), "sub": String(d.get("sub", "")), "col": Cfg.col("boss"), "t": 0.0, "life": 2.2, "big": true})
		&"streak_tier":
			streak_glow = 1.0
			banners.append({"text": String(d.name), "sub": "%d kills" % d.kills, "col": Color.html(Cfg.F.streak.colors[d.tier]), "t": 0.0, "life": 1.0, "big": false, "side": true})
		&"room_cleared":
			banners.append({"text": String(d.get("text", "CLEARED")), "sub": "", "col": Cfg.col("pickup"), "t": 0.0, "life": 1.4, "big": false})
		&"banner":
			banners.append({"text": String(d.text), "sub": String(d.get("sub", "")), "col": d.get("col", Color.WHITE), "t": 0.0, "life": float(d.get("life", 2.0)), "big": bool(d.get("big", true))})

func _process(delta: float) -> void:
	if sim == null:
		return
	time += delta
	size = get_viewport_rect().size
	var p := sim.player
	chip.update(delta, p.hp, p.max_hp)
	hurt_flash = maxf(0.0, hurt_flash - delta / float(Cfg.F.hurt.edge_flash_time))
	heal_glow = maxf(0.0, heal_glow - delta * 1.5)
	lantern_break = maxf(0.0, lantern_break - delta * 0.7)
	streak_glow = maxf(0.0, streak_glow - delta * 2.0)
	var arc_t: float = Cfg.F.hurt.arc_time
	arcs = arcs.filter(func(a): a.t += delta; return a.t < arc_t)
	banners = banners.filter(func(b): b.t += delta; return b.t < b.life)
	var was := low_hp
	low_hp = p.hp > 0.0 and p.hp / p.max_hp < float(Cfg.F.low_hp.threshold)
	if low_hp != was:
		Bus.fire(&"low_hp_changed", {"on": low_hp})
		Audio.set_low_hp(low_hp)
		if not low_hp and p.hp > 0.0:
			Audio.play("warm_chime")
	low_hp_k = move_toward(low_hp_k, 1.0 if low_hp else 0.0, delta * 3.0)
	queue_redraw()

# ───────────────────────── drawing ─────────────────────────

func _txt(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 6) -> void:
	draw_string_outline(font, pos, s, align, width, size, outline, Color(0, 0, 0, col.a * 0.9))
	draw_string(font, pos, s, align, width, size, col)

func _draw() -> void:
	if sim == null:
		return
	var vs := size
	_draw_screen_fx(vs)
	_draw_offscreen(vs)
	_draw_hp(vs)
	_draw_abilities(vs)
	_draw_top(vs)
	_draw_boss(vs)
	_draw_boons(vs)
	_draw_banners(vs)

func _draw_screen_fx(vs: Vector2) -> void:
	var danger := Cfg.col("danger")
	# streak edge glow
	if sim.streak_tier > 0:
		var c := Color.html(Cfg.F.streak.colors[sim.streak_tier])
		var a := 0.08 + 0.05 * sim.streak_tier + 0.15 * streak_glow
		_edge(vs, Color(c, a), 26.0 + 8.0 * sim.streak_tier)
	# low HP: pulsing red vignette
	if low_hp_k > 0.01:
		var bpm: float = Cfg.F.low_hp.heartbeat_bpm
		var beat := pow(0.5 + 0.5 * sin(time * TAU * bpm / 60.0), 3.0)
		_edge(vs, Color(danger, float(Cfg.F.low_hp.vignette_alpha) * low_hp_k * (0.55 + 0.45 * beat)), 140.0)
	if hurt_flash > 0.0:
		_edge(vs, Color(danger, 0.55 * hurt_flash * Cfg.flash_mul), 90.0)
	if heal_glow > 0.0:
		_edge(vs, Color(Cfg.col("heal"), 0.25 * heal_glow), 60.0)
	# directional damage arcs around Wren, pointing at the source
	if not arcs.is_empty():
		var c2: Vector2 = world.get_global_transform_with_canvas() * world.ipos(sim.player)
		var arc_t: float = Cfg.F.hurt.arc_time
		var half := deg_to_rad(float(Cfg.F.hurt.arc_width_deg)) * 0.5
		for a in arcs:
			var k: float = 1.0 - a.t / arc_t
			draw_arc(c2, 96.0, a.ang - half, a.ang + half, 20, Color(Cfg.col("danger_outline"), 0.8 * k), 16.0, true)
			draw_arc(c2, 96.0, a.ang - half, a.ang + half, 20, Color(danger, 0.95 * k), 10.0, true)
			var tip := c2 + Geom.dir(a.ang) * 116.0
			draw_colored_polygon(PackedVector2Array([tip, c2 + Geom.dir(a.ang - 0.12) * 100.0, c2 + Geom.dir(a.ang + 0.12) * 100.0]), Color(danger, k))
	for f in world.fx.flashes:
		var k2: float = 1.0 - f.t / f.life
		draw_rect(Rect2(Vector2.ZERO, vs), Color(f.col, f.col.a * k2 * Cfg.flash_mul))

func _edge(vs: Vector2, col: Color, w: float) -> void:
	var steps := 8
	for i in steps:
		var k := 1.0 - float(i) / steps
		var c := Color(col, col.a * k * k / steps * 3.0)
		var t := w * float(i + 1) / steps
		draw_rect(Rect2(0, 0, vs.x, t), c)
		draw_rect(Rect2(0, vs.y - t, vs.x, t), c)
		draw_rect(Rect2(0, 0, t, vs.y), c)
		draw_rect(Rect2(vs.x - t, 0, t, vs.y), c)

func _draw_offscreen(vs: Vector2) -> void:
	var A: Dictionary = Cfg.F.arrows
	var xf: Transform2D = world.get_global_transform_with_canvas()
	var margin: float = A.margin
	var center := vs * 0.5
	var ppos: Vector2 = world.ipos(sim.player)
	var threats: Array = []
	for e in sim.enemies:
		if e.alive:
			threats.append([e.pos, Cfg.col("boss") if (e.is_boss or e.is_guardian) else Cfg.col("danger"), 1.0, e.spawn_t > 0.0])
	for pr in sim.projectiles:
		if pr.team == 1 and pr.alive and pr.vel.length() > 10.0:
			var ahead: Vector2 = pr.pos + pr.vel * float(A.projectile_lookahead)
			if (ppos - pr.pos).dot(pr.vel) > 0.0 and Geom.seg_dist(ppos, pr.pos, ahead) < 140.0:
				threats.append([pr.pos, Cfg.col("danger_hot"), 0.7, false])
	var rect := Rect2(Vector2.ZERO, vs).grow(-margin)
	# lit doors off-screen get gold arrows (yours, not a threat)
	if sim.flow != null:
		for i in sim.flow.doors.size():
			if i < sim.flow.doors_lit:
				threats.append([sim.flow.doors[i].pos, Cfg.col("player_gold"), 1.1, false])
	for t in threats:
		var sp: Vector2 = xf * t[0]
		if Rect2(Vector2.ZERO, vs).grow(-10).has_point(sp):
			continue
		var d := sp - center
		var k := minf(absf((rect.size.x * 0.5) / maxf(0.001, absf(d.x))), absf((rect.size.y * 0.5) / maxf(0.001, absf(d.y))))
		var at := center + d * k
		var dist: float = ppos.distance_to(t[0])
		var closeness := clampf(1.0 - (dist - float(A.near_dist)) / (float(A.far_dist) - float(A.near_dist)), 0.0, 1.0)
		var hz := lerpf(A.min_pulse, A.max_pulse, closeness)
		var pulse := 0.55 + 0.45 * sin(time * TAU * hz)
		var s: float = (16.0 + 10.0 * closeness) * float(t[2])
		var ang := d.angle()
		var col: Color = t[1]
		if t[3]:
			col = Color(col, 0.5)
		var tri := PackedVector2Array([at + Geom.dir(ang) * s, at + Geom.dir(ang + 2.5) * s * 0.8, at + Geom.dir(ang - 2.5) * s * 0.8])
		draw_colored_polygon(tri, Color(Cfg.col("danger_outline"), 0.9))
		var tri2 := PackedVector2Array([at + Geom.dir(ang) * (s - 4), at + Geom.dir(ang + 2.5) * (s * 0.8 - 4), at + Geom.dir(ang - 2.5) * (s * 0.8 - 4)])
		draw_colored_polygon(tri2, Color(col, col.a * pulse))

func _draw_hp(vs: Vector2) -> void:
	var H: Dictionary = Cfg.F.hpbar
	var p := sim.player
	var w: float = H.width
	var h: float = H.height
	var origin := Vector2(40, vs.y - 92)
	var mx := maxf(1.0, p.max_hp)
	draw_rect(Rect2(origin - Vector2(4, 4), Vector2(w + 8, h + 8)), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(origin, Vector2(w, h)), Color("#2a1418"))
	# chip (white, drains after a delay)
	draw_rect(Rect2(origin, Vector2(w * chip.chip / mx, h)), Color(1, 1, 1, 0.92))
	# heal (green, fills up)
	if chip.heal_to > chip.shown:
		draw_rect(Rect2(origin, Vector2(w * chip.heal_to / mx, h)), Cfg.col("heal"))
	var hp_col := Color("#e8304a") if not low_hp else Color("#ff3048").lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(time * 9.0)))
	draw_rect(Rect2(origin, Vector2(w * clampf(chip.shown / mx, 0.0, 1.0), h)), hp_col)
	draw_rect(Rect2(origin, Vector2(w * clampf(chip.shown / mx, 0.0, 1.0), h * 0.35)), Color(1, 1, 1, 0.18))
	# barrier: blue segment on top
	if p.barrier > 0.0:
		var bw := w * clampf(p.barrier / mx, 0.0, 1.0)
		draw_rect(Rect2(origin + Vector2(0, -10), Vector2(bw, 10)), Cfg.col("barrier"))
	_txt(origin + Vector2(10, h - 5), "%d / %d" % [ceil(p.hp), mx], 22, Color.WHITE)
	# Death Defiance lanterns
	var left: int = sim.run.defiance if sim.run != null else 0
	var lt := Assets.tex("i_lantern")
	for i in maxi(left, 0):
		var lp := origin + Vector2(w + 18 + i * 34, -8)
		draw_texture_rect(lt, Rect2(lp, Vector2(30, 40)), false)
	if lantern_break > 0.0:
		var lp2 := origin + Vector2(w + 18 + left * 34, -8)
		var k := 1.0 - lantern_break
		for j in 6:
			var a := TAU * j / 6.0
			draw_circle(lp2 + Vector2(15, 20) + Geom.dir(a) * k * 50.0, 5.0 * lantern_break, Color(Cfg.col("player_gold"), lantern_break))

func _draw_abilities(vs: Vector2) -> void:
	var p := sim.player
	var origin := Vector2(40, vs.y - 52)
	# dash pips
	for i in p.dash_max:
		var c := Vector2(origin.x + 12 + i * 30, origin.y + 18)
		draw_circle(c, 11.0, Color(0, 0, 0, 0.7))
		if i < p.dash_charges:
			draw_circle(c, 8.0, Color("#bfe6ff"))
		elif i == p.dash_charges:
			var k := 1.0 - p.dash_cd / maxf(0.01, sim.dash_cooldown())
			draw_arc(c, 8.0, -PI / 2, -PI / 2 + TAU * k, 16, Color("#bfe6ff"), 3.0)
	_txt(origin + Vector2(0, 4), "DASH", 13, Color(1, 1, 1, 0.6))
	# special ring
	var sx := origin.x + 30 * p.dash_max + 40
	_ring(Vector2(sx, origin.y + 18), 18.0, 1.0 - clampf(p.special_cd / 0.9, 0.0, 1.0), Cfg.col("player_gold") if p.overdrive_ready else Color("#fff4d6"), "SP")
	# sigil charges
	for i in p.cast_max:
		var k2 := 1.0 if i < p.cast_charges else (1.0 - p.cast_recharge / maxf(0.01, sim.cast_recharge_time()) if i == p.cast_charges else 0.0)
		_ring(Vector2(sx + 50 + i * 44, origin.y + 18), 16.0, k2, Color("#ffd27a"), "SG")
	# overdrive meter
	var ox := sx + 50 + p.cast_max * 44 + 20
	var ow := 220.0
	draw_rect(Rect2(Vector2(ox, origin.y + 8), Vector2(ow, 18)), Color(0, 0, 0, 0.7))
	var of := p.overdrive / float(sim.T.overdrive.max)
	var oc := Cfg.col("player_gold") if p.overdrive_ready else Color("#ffe6a0")
	draw_rect(Rect2(Vector2(ox + 2, origin.y + 10), Vector2((ow - 4) * of, 14)), oc)
	if p.overdrive_ready:
		draw_rect(Rect2(Vector2(ox, origin.y + 8), Vector2(ow, 18)), Color(1, 1, 1, 0.3 + 0.3 * sin(time * 8.0)), false, 2.0)
		_txt(Vector2(ox, origin.y + 2), "OVERDRIVE · SPECIAL EMPOWERED", 15, Cfg.col("player_gold"))
	else:
		_txt(Vector2(ox, origin.y + 2), "OVERDRIVE", 15, Color(1, 1, 1, 0.75))

func _ring(c: Vector2, r: float, k: float, col: Color, label: String) -> void:
	draw_circle(c, r + 3.0, Color(0, 0, 0, 0.75))
	draw_arc(c, r - 2.0, -PI / 2, -PI / 2 + TAU * clampf(k, 0.0, 1.0), 24, col if k >= 1.0 else Color(col, 0.6), 5.0, true)
	if k >= 1.0:
		draw_circle(c, r - 7.0, Color(col, 0.35))
	_txt(c + Vector2(-r, 6), label, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 4)

func _draw_top(vs: Vector2) -> void:
	var y := 46.0
	if sim.run != null:
		var depth_name: String = Palettes.get_depth(sim.run.depth - 1).name
		_txt(Vector2(40, y), "%s  ·  ROOM %d" % [depth_name.to_upper(), sim.run.room_index + 1], 24, Color(1, 1, 1, 0.85))
		_txt(Vector2(40, y + 34), "◆ %d gold" % sim.run.gold, 22, Color("#ffd166"))
		_txt(Vector2(220, y + 34), "✦ %d embers" % sim.run.embers, 22, Color("#ffe6a0"))
	else:
		_txt(Vector2(40, y), "TRAINING GROUNDS  ·  1–5 swap weapon", 22, Color(1, 1, 1, 0.7))
	# streak
	if sim.streak_kills > 0:
		var S: Dictionary = Cfg.F.streak
		var tier := sim.streak_tier
		var col := Color.html(S.colors[tier])
		var label: String = S.names[tier] if tier > 0 else "STREAK"
		_txt(Vector2(vs.x - 420, y), "%s  ×%d" % [label, sim.streak_kills], 30 if tier > 0 else 22, col, HORIZONTAL_ALIGNMENT_RIGHT, 380)
		var win := float(S.window) + float(S.window_per_tier) * tier
		var k := clampf(sim.streak_timer / win, 0.0, 1.0)
		draw_rect(Rect2(Vector2(vs.x - 240, y + 12), Vector2(200, 6)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(Vector2(vs.x - 240, y + 12), Vector2(200 * k, 6)), col)

func _draw_boss(vs: Vector2) -> void:
	var boss = null
	for e in sim.enemies:
		if e.alive and (e.is_boss or e.is_guardian) and e.spawn_t <= 0.0:
			boss = e
			break
	if boss == null:
		return
	var w := minf(900.0, vs.x * 0.5)
	var origin := Vector2((vs.x - w) * 0.5, 96)
	var purple := Cfg.col("boss")
	_txt(origin + Vector2(0, -12), boss.name.to_upper(), 26, purple.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, w)
	draw_rect(Rect2(origin - Vector2(3, 3), Vector2(w + 6, 24)), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(origin, Vector2(w * boss.hp_frac(), 18)), purple)
	if boss.shield > 0.0:
		draw_rect(Rect2(origin, Vector2(w * clampf(boss.shield / boss.max_hp, 0.0, 1.0), 6)), Color("#7fe3ff"))
	var phases: Array = boss.def.get("phases", [])
	for ph in phases:
		var x: float = origin.x + w * float(ph)
		draw_line(Vector2(x, origin.y - 2), Vector2(x, origin.y + 20), Color.WHITE, 2.0)

func _draw_boons(vs: Vector2) -> void:
	if sim.run == null:
		return
	var boons: Array = sim.run.boons
	var x := vs.x * 0.5 - boons.size() * 22.0
	for b in boons:
		var col: Color = Boons.color_of(b.id)
		var c := Vector2(x + 22, vs.y - 40)
		draw_circle(c, 18.0, Color(0, 0, 0, 0.75))
		draw_circle(c, 15.0, Color(col, 0.85))
		var ic := Assets.tex("i_slot_" + Boons.slot_of(b.id))
		draw_texture_rect(ic, Rect2(c - Vector2(11, 11), Vector2(22, 22)), false, Color(0, 0, 0, 0.8))
		draw_arc(c, 18.0, 0, TAU, 20, Color.html(Boons.RARITY_COLORS[clampi(int(b.rarity), 0, 3)]), 2.0)
		x += 44

func _draw_banners(vs: Vector2) -> void:
	var top_y := 170.0
	for b in banners:
		var k: float = b.t / b.life
		var a := clampf(minf(b.t / 0.12, (b.life - b.t) / 0.3), 0.0, 1.0)
		var size := 84 if b.big else 46
		var pop := lerpf(1.35, 1.0, clampf(b.t / 0.15, 0.0, 1.0))
		var y := vs.y * 0.36 if b.big else top_y
		if b.get("side", false):
			_txt(Vector2(vs.x - 460, 120), b.text, int(40 * pop), Color(b.col, a), HORIZONTAL_ALIGNMENT_RIGHT, 420)
			continue
		if not b.big:
			top_y += 56
		if b.big:
			draw_rect(Rect2(0, y - size * 0.95, vs.x, size * 1.45), Color(0, 0, 0, 0.35 * a))
		_txt(Vector2(0, y), b.text, int(size * pop), Color(b.col, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 10)
		if b.sub != "":
			_txt(Vector2(0, y + 40), b.sub, 26, Color(1, 1, 1, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
