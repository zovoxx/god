extends Node
## All transient visual feedback: particles, floor decals, weapon trails, dash ghosts,
## lightning, damage numbers (merging), callouts, plus drawing of projectiles, hazards,
## pickups and telegraphs. Driven by Bus events; FX time runs at 12 % during hit-stop.

const DrawTele := preload("res://render/tele_draw.gd")

var sim: Sim
var cam
var world
var font: Font
var time := 0.0
var gfx_mul := 1.0

# particles (packed for speed)
var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_size := PackedFloat32Array()
var p_drag := PackedFloat32Array()
var p_col := PackedColorArray()
var p_kind := PackedInt32Array()
var p_rot := PackedFloat32Array()

enum P { SPARK, DOT, SHARD, EMBER, RING, SMOKE, STREAK }

var decals: Array = []      # {pos, r, col, t, rot, kind}
var slashes: Array = []     # {pos, ang, range, arc, len, width, shape, t, life, fin, col}
var numbers: Array = []     # {pos, val, crit, col, t, life, id, size, vx, kind}
var callouts: Array = []    # {pos, text, col, t, life, size, world}
var ghosts: Array = []      # {pos, t, life, flip}
var bolts: Array = []       # {pts, t, life, col}
var rings: Array = []       # {pos, r0, r1, t, life, col, w}
var flashes: Array = []     # screen-space flashes for the HUD to read

func _ready() -> void:
	font = ThemeDB.fallback_font
	Bus.event.connect(_on_event)
	_apply_gfx()
	Bus.settings_changed.connect(func(_s): _apply_gfx())

func _apply_gfx() -> void:
	match String(App.settings.get("graphics", "medium")):
		"low": gfx_mul = 0.45
		"high": gfx_mul = 1.3
		_: gfx_mul = 1.0

func bind(s: Sim) -> void:
	sim = s
	decals.clear()
	slashes.clear()
	numbers.clear()
	callouts.clear()
	ghosts.clear()
	bolts.clear()
	rings.clear()
	_clear_particles()

func _clear_particles() -> void:
	p_pos.clear(); p_vel.clear(); p_life.clear(); p_max.clear(); p_size.clear(); p_drag.clear(); p_col.clear(); p_kind.clear(); p_rot.clear()

func emit(kind: int, pos: Vector2, vel: Vector2, life: float, size: float, col: Color, drag: float = 4.0) -> void:
	var mx: int = int(float(Cfg.F.particles.max) * gfx_mul)
	if p_pos.size() >= mx:
		# recycle the oldest
		_remove_particle(0)
	p_pos.append(pos); p_vel.append(vel); p_life.append(life); p_max.append(life); p_size.append(size)
	p_drag.append(drag); p_col.append(col); p_kind.append(kind); p_rot.append(randf() * TAU)

func _remove_particle(i: int) -> void:
	var last := p_pos.size() - 1
	if i != last:
		p_pos[i] = p_pos[last]; p_vel[i] = p_vel[last]; p_life[i] = p_life[last]; p_max[i] = p_max[last]
		p_size[i] = p_size[last]; p_drag[i] = p_drag[last]; p_col[i] = p_col[last]; p_kind[i] = p_kind[last]; p_rot[i] = p_rot[last]
	p_pos.resize(last); p_vel.resize(last); p_life.resize(last); p_max.resize(last); p_size.resize(last)
	p_drag.resize(last); p_col.resize(last); p_kind.resize(last); p_rot.resize(last)

func burst(kind: int, pos: Vector2, n: int, dir: Vector2, cone: float, smin: float, smax: float, life: float, size: float, col: Color, drag: float = 5.0) -> void:
	n = int(round(n * gfx_mul))
	var base := dir.angle() if dir != Vector2.ZERO else 0.0
	for i in n:
		var a := base + randf_range(-cone, cone) if dir != Vector2.ZERO else randf() * TAU
		emit(kind, pos, Geom.dir(a) * randf_range(smin, smax), life * randf_range(0.7, 1.2), size * randf_range(0.7, 1.3), col, drag)

# ───────────────────────── events ─────────────────────────

func _on_event(name: StringName, d: Dictionary) -> void:
	if sim == null:
		return
	var F: GameFeel = Cfg.F
	match name:
		&"enemy_hit":
			_on_enemy_hit(d)
		&"enemy_killed":
			_on_enemy_killed(d)
		&"wall_slam":
			burst(P.SPARK, d.pos, 14, d.normal, 1.1, 200, 520, 0.3, 3.0, Color("#e8f0ff"))
			burst(P.SMOKE, d.pos, 6, d.normal, 1.2, 40, 120, 0.6, 14.0, Color(0.6, 0.6, 0.65, 0.35), 3.0)
			_decal(d.pos, 22.0, 1)
			_callout(d.pos + Vector2(0, -30), "SLAM", Color("#bfe6ff"), 26)
			cam.add_trauma(0.3)
			cam.add_kick(d.normal, 6.0)
			Audio.play("slam")
		&"player_attack":
			_on_player_attack(d)
		&"player_dash":
			ghosts.append({"pos": sim.player.pos, "t": 0.0, "life": float(F.trails.ghost_life), "flip": sim.player.aim_dir.x < 0})
			burst(P.SMOKE, sim.player.pos + Vector2(0, 12), 5, -d.dir, 0.8, 40, 140, 0.35, 10.0, Color(0.8, 0.85, 1.0, 0.25), 4.0)
			Audio.play("dash")
		&"perfect_dash":
			_callout(sim.player.pos + Vector2(0, -50), "PERFECT", Color("#7fd4ff"), 40)
			rings.append({"pos": sim.player.pos, "r0": 10.0, "r1": 140.0, "t": 0.0, "life": 0.4, "col": Color("#7fd4ff"), "w": 6.0})
			flashes.append({"col": Color(0.5, 0.8, 1.0, 0.35), "t": 0.0, "life": 0.25})
			Audio.play("perfect")
		&"enemy_countered":
			_callout(d.pos + Vector2(0, -40), "COUNTER", Color("#ffffff"), 34)
			burst(P.SPARK, d.pos, 22, Vector2.ZERO, PI, 260, 700, 0.3, 3.5, Color.WHITE)
			rings.append({"pos": d.pos, "r0": 10.0, "r1": 90.0, "t": 0.0, "life": 0.25, "col": Color.WHITE, "w": 5.0})
			cam.add_trauma(0.35)
			Audio.play("clang")
		&"finisher":
			_callout(d.pos + Vector2(0, -50), "EXECUTE", Cfg.col("player_gold"), 40)
			burst(P.EMBER, d.pos, 40, Vector2.ZERO, PI, 200, 600, 0.7, 6.0, Cfg.col("player_gold"), 3.0)
			rings.append({"pos": d.pos, "r0": 20.0, "r1": 180.0, "t": 0.0, "life": 0.4, "col": Cfg.col("player_gold"), "w": 8.0})
			cam.add_trauma(0.55)
			cam.zoom_punch(0.05)
			Audio.play("finisher")
		&"enemy_blocked":
			_callout(d.pos + Vector2(0, -26), "BLOCKED", Color("#c8d0e0"), 22)
			burst(P.SPARK, d.pos, 8, Vector2.ZERO, PI, 120, 300, 0.2, 2.5, Color("#c8d0e0"))
			Audio.play("block")
		&"enemy_immune":
			if randf() < 0.3:
				_callout(d.pos + Vector2(0, -30), "IMMUNE", Color("#c8c0d8"), 20)
		&"shield_broken":
			_callout(d.pos + Vector2(0, -40), "SHIELD BROKEN", Color("#7fe3ff"), 26)
			burst(P.SHARD, d.pos, 14, Vector2.ZERO, PI, 120, 360, 0.6, 6.0, Color("#7fe3ff"))
			Audio.play("shatter")
		&"armor_broken":
			_callout(d.pos + Vector2(0, -44), "ARMOR BROKEN", Cfg.col("player_gold"), 30)
			burst(P.SHARD, d.pos, 18, Vector2.ZERO, PI, 140, 420, 0.8, 7.0, Color("#b8c0cc"))
			cam.add_trauma(0.4)
			Audio.play("armor_break")
		&"lightning":
			var pts: Array = d.points
			if pts.size() >= 2:
				bolts.append({"pts": pts, "t": 0.0, "life": 0.16, "col": Color("#ffe24a")})
		&"hazard_burst":
			_on_hazard_burst(d)
		&"player_cast":
			Audio.play("sigil_cast")
		&"player_special":
			Audio.play("special_" + String(d.weapon))
		&"player_fissure":
			cam.add_trauma(0.25 + 0.3 * float(d.power))
			cam.add_kick(Geom.dir(d.angle), 8.0)
		&"perfect_release":
			_callout(d.pos + Vector2(0, -46), "PERFECT", Cfg.col("player_gold"), 32)
			Audio.play("perfect_release")
		&"halo_caught":
			Audio.play("catch")
		&"synergy":
			var c: Color = _patron_col(String(d.get("color", "")))
			_callout(d.pos + Vector2(randf_range(-20, 20), -60), String(d.text) if d.has("text") else "+COMBO", c, 24)
			Audio.play("combo")
		&"status_applied":
			if d.status == "freeze":
				burst(P.SHARD, d.pos, 8, Vector2.ZERO, PI, 60, 160, 0.4, 5.0, Color("#bff0ff"))
				Audio.play("freeze")
		&"pickup_collected":
			if d.kind == "gold":
				Audio.play("coin", 1.0 + randf() * 0.1)
			elif d.kind == "orb":
				Audio.play("heal")
		&"player_hurt":
			_on_player_hurt(d)
		&"player_healed":
			_number(d.pos + Vector2(0, -36), float(d.amount), false, Cfg.col("heal"), -1, "heal")
		&"player_dodged":
			_callout(d.pos + Vector2(0, -40), "DODGE", Color("#bfffe0"), 26)
		&"player_defied":
			_callout(d.pos + Vector2(0, -70), "DEFIED", Cfg.col("player_gold"), 64)
			rings.append({"pos": d.pos, "r0": 20.0, "r1": 260.0, "t": 0.0, "life": 0.9, "col": Cfg.col("player_gold"), "w": 10.0})
			burst(P.EMBER, d.pos, 60, Vector2.ZERO, PI, 100, 500, 1.2, 6.0, Cfg.col("player_gold"), 2.0)
			Audio.play("defied")
		&"enemy_spawning":
			Audio.play("portal", 1.0 + randf() * 0.1, -8.0)
		&"telegraph_started":
			Audio.play("tele_boss" if d.boss else "tele", 1.0, -6.0 if not d.boss else -2.0)
		&"telegraph_impact":
			if d.hit or d.boss:
				cam.add_trauma(0.2 if not d.boss else 0.35)
			Audio.play("impact", 1.0, -10.0)
		&"projectile_wall":
			if d.team == 0:
				burst(P.SPARK, d.pos, 4, Vector2.ZERO, PI, 60, 160, 0.15, 2.0, Color("#fff4d6"))

func _patron_col(id: String) -> Color:
	if Cfg.B != null and Cfg.B.patrons.has(id):
		return Color.html(Cfg.B.patrons[id].color)
	return Cfg.col("player_gold")

func _on_enemy_hit(d: Dictionary) -> void:
	var F: GameFeel = Cfg.F
	var P2: Dictionary = F.particles
	var power: float = d.power
	var dir: Vector2 = d.dir
	var pos: Vector2 = d.pos
	if d.dot:
		_number(pos + Vector2(randf_range(-10, 10), -d.radius - 10), d.dmg, false, Cfg.col("status"), d.id, "status")
		return
	var smul: float = float(P2.streak_mul[sim.streak_tier])
	var n := int(lerpf(P2.hit_min, P2.hit_max, power) * smul) + (int(P2.hit_crit_extra) if d.crit else 0)
	var spark_col := Cfg.col("crit") if d.crit else Color("#fff6e0")
	var hit_pos: Vector2 = pos - dir * d.radius * 0.5
	burst(P.SPARK, hit_pos, n, dir, float(P2.hit_cone), P2.hit_speed_min, P2.hit_speed_max, 0.22, 2.6 + power * 2.0, spark_col, 7.0)
	if d.element != "":
		burst(P.DOT, hit_pos, 4, dir, 1.2, 60, 200, 0.35, 3.0, _patron_col(d.element))
	if power >= 0.5:
		_decal(pos + Vector2(randf_range(-8, 8), d.radius * 0.6), 10.0 + power * 12.0, 0)
	if d.tag == "tip" or d.tag == "backstab":
		_callout(pos + Vector2(0, -d.radius - 30), "TIP" if d.tag == "tip" else "BACKSTAB", Cfg.col("crit"), 20)
	_number(pos + Vector2(0, -d.radius - 12), d.dmg, d.crit, Cfg.col("crit") if d.crit else Color.WHITE, d.id, "hit")
	var S: Dictionary = F.shake
	cam.add_trauma(float(S.trauma_per_power) * power * 0.5 + (float(S.trauma_crit) if d.crit else 0.0))
	cam.add_kick(dir, float(S.kick_per_power) * power)
	Audio.play("hit_crit" if d.crit else "hit", 1.0 + float(sim.streak_tier) * 0.02)

func _on_enemy_killed(d: Dictionary) -> void:
	var F: GameFeel = Cfg.F
	var P2: Dictionary = F.particles
	var blood := Color.html(String(d.blood))
	var r: float = d.radius
	var n := int(lerpf(P2.shards_min, P2.shards_max, clampf(r / 40.0, 0.0, 1.0)) * float(P2.streak_mul[sim.streak_tier]))
	burst(P.SHARD, d.pos, n, d.dir, 1.4, 120, 460, 0.7, 4.0 + r * 0.12, blood, 3.5)
	burst(P.EMBER, d.pos, int(P2.ember_burst) + (12 if d.boss else 0), Vector2.UP, 1.2, 60, 260, 0.9, 4.0, Color("#ffe6a0"), 2.0)
	rings.append({"pos": d.pos, "r0": r * 0.5, "r1": r * 2.6, "t": 0.0, "life": 0.3, "col": Color(1, 1, 1, 0.7), "w": 4.0})
	_decal(d.pos + Vector2(0, r * 0.5), r * 1.2, 2)
	cam.add_trauma(float(F.shake.trauma_kill) + (0.5 if d.boss else 0.0))
	Audio.play("kill", 1.0 + float(d.streak) * float(F.streak.pitch_step))

func _on_player_attack(d: Dictionary) -> void:
	var F: GameFeel = Cfg.F
	if d.phase == "active":
		var col := Cfg.col("player")
		if d.finisher:
			col = Cfg.col("player_gold")
		slashes.append({"pos": d.pos, "ang": d.angle, "range": d.range, "arc": d.arc, "len": d.len, "width": d.width, "shape": d.shape,
			"t": 0.0, "life": float(F.trails.finisher_life if d.finisher else F.trails.slash_life) + float(d.life) * 0.5, "fin": d.finisher, "col": col, "step": d.step})
		var step: int = maxi(0, int(d.step))
		Audio.play("swing_" + String(d.weapon), 1.0 + step * float(F.audio.combo_pitch_step))
	elif d.phase == "shot" or d.phase == "power":
		Audio.play("bow_shot" if d.phase == "shot" else "bow_power", 1.0 + int(d.step) * float(F.audio.combo_pitch_step))
	elif d.phase == "throw":
		Audio.play("halo_throw", 1.0 + int(d.step) * float(F.audio.combo_pitch_step))

func _on_hazard_burst(d: Dictionary) -> void:
	var col := Cfg.col("player_gold")
	match String(d.kind):
		"sigil":
			rings.append({"pos": d.pos, "r0": d.radius * 0.3, "r1": d.radius * 1.2, "t": 0.0, "life": 0.3, "col": col, "w": 8.0})
			burst(P.EMBER, d.pos, 24, Vector2.ZERO, PI, 80, 320, 0.5, 5.0, col, 4.0)
			_decal(d.pos, d.radius * 0.8, 1)
			cam.add_trauma(0.3)
			Audio.play("sigil_blast")
		"fissure":
			var a: float = d.angle
			for i in 10:
				var p: Vector2 = d.pos + Geom.dir(a) * d.length * (float(i) / 9.0)
				burst(P.SPARK, p, 3, Geom.dir(a + PI * 0.5 * (1 if i % 2 == 0 else -1)), 0.6, 120, 320, 0.3, 3.0, Color("#ffb04a"))
				_decal(p, d.width * 0.35, 1)
			Audio.play("fissure")
		"shockwave", "apex":
			rings.append({"pos": d.pos, "r0": 10.0, "r1": d.radius, "t": 0.0, "life": 0.3, "col": col, "w": 6.0})
			Audio.play("sigil_blast", 1.3)
		_:
			pass

func _on_player_hurt(d: Dictionary) -> void:
	var F: GameFeel = Cfg.F
	var p := sim.player
	_number(p.pos + Vector2(0, -40), d.dmg, false, Cfg.col("hurt_number"), -2, "hurt", String(d.art))
	cam.add_trauma(float(F.shake.trauma_hurt))
	cam.add_kick(d.dir, 10.0)
	burst(P.SPARK, p.pos, 12, d.dir, 1.0, 160, 420, 0.25, 3.0, Color("#ffd0c0"))
	Audio.play("hurt")

func _decal(pos: Vector2, r: float, kind: int) -> void:
	var mx := int(float(Cfg.F.decals.max) * gfx_mul)
	if decals.size() >= mx:
		decals.pop_front()
	decals.append({"pos": pos, "r": r, "t": 0.0, "rot": randf() * TAU, "kind": kind})

func _callout(pos: Vector2, text: String, col: Color, size: int) -> void:
	callouts.append({"pos": pos, "text": text, "col": col, "t": 0.0, "life": 0.8, "size": size})

## damage numbers merge into one rising total for repeated hits on the same target
func _number(pos: Vector2, val: float, crit: bool, col: Color, target_id: int, kind: String, icon: String = "") -> void:
	if not Cfg.numbers_on:
		return
	var DN: Dictionary = Cfg.F.damage_numbers
	if target_id >= 0:
		for n in numbers:
			if n.id == target_id and n.kind == kind and n.t < float(DN.merge_window):
				n.val += val
				n.t = 0.0
				n.crit = n.crit or crit
				if crit:
					n.col = col
				n.pos = pos
				return
	var size: float = float(DN.crit_size if crit else DN.size)
	if kind == "hurt":
		size = float(DN.player_hurt_size)
	numbers.append({"pos": pos, "val": val, "crit": crit, "col": col, "t": 0.0, "life": float(DN.life) + (0.3 if kind == "hurt" else 0.0), "id": target_id, "size": size * Cfg.numbers_mul, "vx": randf_range(-20, 20), "kind": kind, "icon": icon})

# ───────────────────────── update ─────────────────────────

func _process(delta: float) -> void:
	if sim == null:
		return
	var dt := delta * sim.fx_scale()
	time += dt
	var i := 0
	while i < p_pos.size():
		p_life[i] -= dt
		if p_life[i] <= 0.0:
			_remove_particle(i)
			continue
		var v := p_vel[i]
		v *= exp(-p_drag[i] * dt)
		if p_kind[i] == P.EMBER:
			v.y -= 60.0 * dt
		elif p_kind[i] == P.SHARD:
			v.y += 300.0 * dt
			p_rot[i] += dt * 10.0
		p_vel[i] = v
		p_pos[i] += v * dt
		i += 1
	var DC: Dictionary = Cfg.F.decals
	decals = decals.filter(func(dd): dd.t += dt; return dd.t < float(DC.hold) + float(DC.fade))
	slashes = slashes.filter(func(s): s.t += dt; return s.t < s.life)
	numbers = numbers.filter(func(n): n.t += delta; return n.t < n.life)
	callouts = callouts.filter(func(c): c.t += delta; return c.t < c.life)
	ghosts = ghosts.filter(func(g): g.t += dt; return g.t < g.life)
	bolts = bolts.filter(func(b): b.t += dt; return b.t < b.life)
	rings = rings.filter(func(r): r.t += dt; return r.t < r.life)
	flashes = flashes.filter(func(f): f.t += delta; return f.t < f.life)
	# dash afterimages
	var p := sim.player
	if p.state == SimPlayer.St.DASH and int(time * 60.0) % 2 == 0:
		ghosts.append({"pos": p.pos, "t": 0.0, "life": float(Cfg.F.trails.ghost_life), "flip": p.aim_dir.x < 0})

# ───────────────────────── drawing ─────────────────────────

func draw_under(ci: CanvasItem, wv) -> void:
	var DC: Dictionary = Cfg.F.decals
	for dd in decals:
		var a := 1.0
		if dd.t > float(DC.hold):
			a = 1.0 - (dd.t - float(DC.hold)) / float(DC.fade)
		var col := Color(0.0, 0.0, 0.0, 0.28 * a)
		if dd.kind == 1:
			col = Color(0.05, 0.03, 0.02, 0.4 * a)
		ci.draw_colored_polygon(Paint.ell(dd.pos, dd.r, dd.r * 0.55, 12, dd.rot * 0.2), col)
		if dd.kind == 2:
			for k in 5:
				var ang: float = dd.rot + k * TAU / 5.0
				ci.draw_line(dd.pos, dd.pos + Geom.dir(ang) * dd.r * 1.3, Color(0, 0, 0, 0.2 * a), 3.0)
	_draw_hazards(ci, wv, true)
	DrawTele.draw_all(ci, sim, time)
	_draw_pickups(ci, wv)

func draw_over(ci: CanvasItem, wv) -> void:
	_draw_hazards(ci, wv, false)
	# dash ghosts
	var wt := Assets.tex("wren")
	var ws := Assets.draw_scale("wren")
	for g in ghosts:
		var a: float = 0.35 * (1.0 - g.t / g.life)
		var sz := Vector2(wt.get_width(), wt.get_height()) * ws
		ci.draw_texture_rect(wt, Rect2(g.pos - sz * 0.5 + Vector2(0, -8), sz * (Vector2(-1, 1) if g.flip else Vector2.ONE)), false, Color(0.6, 0.85, 1.0, a))
	_draw_slashes(ci)
	_draw_projectiles(ci, wv)
	for b in bolts:
		var pts: Array = b.pts
		var a2: float = 1.0 - b.t / b.life
		for k in range(pts.size() - 1):
			var seg := _jag(pts[k], pts[k + 1])
			ci.draw_polyline(seg, Color(1, 1, 1, a2 * 0.5), 7.0)
			ci.draw_polyline(seg, Color(b.col, a2), 3.0)
	for r in rings:
		var k: float = r.t / r.life
		var rr: float = lerpf(r.r0, r.r1, 1.0 - (1.0 - k) * (1.0 - k))
		ci.draw_arc(r.pos, rr, 0, TAU, 48, Color(r.col, (1.0 - k) * r.col.a), r.w * (1.0 - k * 0.6), true)
	# particles
	for i in p_pos.size():
		var k2 := p_life[i] / p_max[i]
		var c := p_col[i]
		c.a *= minf(1.0, k2 * 1.6)
		var s := p_size[i]
		match p_kind[i]:
			P.SPARK:
				var v := p_vel[i]
				ci.draw_line(p_pos[i], p_pos[i] - v * 0.03, c, s)
			P.DOT:
				ci.draw_circle(p_pos[i], s * k2, c)
			P.SHARD:
				var rot := p_rot[i]
				var pts2 := PackedVector2Array([p_pos[i] + Geom.dir(rot) * s, p_pos[i] + Geom.dir(rot + 2.3) * s * 0.7, p_pos[i] + Geom.dir(rot + 4.0) * s * 0.8])
				ci.draw_colored_polygon(pts2, c)
			P.EMBER:
				ci.draw_circle(p_pos[i], s * 1.8 * k2, Color(c, c.a * 0.25))
				ci.draw_circle(p_pos[i], s * 0.7 * k2, c)
			P.SMOKE:
				ci.draw_circle(p_pos[i], s * (1.6 - k2 * 0.6), Color(c, c.a * k2))
	_draw_numbers(ci)

func _jag(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	var n := 5
	var perp := (b - a).orthogonal().normalized()
	for i in range(1, n):
		out.append(a.lerp(b, float(i) / n) + perp * randf_range(-12, 12))
	out.append(b)
	return out

func _draw_slashes(ci: CanvasItem) -> void:
	for s in slashes:
		var k: float = s.t / s.life
		var a := 1.0 - k
		var col: Color = s.col
		var pos: Vector2 = sim.player.pos if s.t < 0.12 else s.pos
		if s.shape == "arc":
			var arc := deg_to_rad(float(s.arc))
			var r: float = s.range
			var side := 1.0 if int(s.step) % 2 == 0 else -1.0
			var n := 18
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			var sweep := clampf(k * 2.5, 0.0, 1.0)
			for i in n + 1:
				var f := float(i) / n * sweep
				var ang: float = s.ang + (-arc * 0.5 + arc * f) * side
				var thick := sin(f / maxf(0.01, sweep) * PI) * (16.0 if not s.fin else 26.0)
				outer.append(pos + Geom.dir(ang) * r)
				inner.append(pos + Geom.dir(ang) * (r - thick - 2.0))
			inner.reverse()
			var poly := outer + inner
			if poly.size() >= 3:
				ci.draw_colored_polygon(poly, Color(col, 0.85 * a))
				ci.draw_polyline(outer, Color(1, 1, 1, a), 2.0)
		else:
			var dirv := Geom.dir(s.ang)
			var length: float = s.len
			var w: float = s.width * 0.5 * (1.0 - k * 0.5)
			var base: Vector2 = pos + dirv * 10.0
			var tip: Vector2 = pos + dirv * length
			var poly2 := PackedVector2Array([base + dirv.orthogonal() * w, tip, base - dirv.orthogonal() * w])
			ci.draw_colored_polygon(poly2, Color(col, 0.7 * a))
			ci.draw_line(base, tip, Color(1, 1, 1, a), 2.0)

func _draw_projectiles(ci: CanvasItem, wv) -> void:
	var danger := Cfg.col("danger")
	var core := Cfg.col("danger_core")
	var outline := Cfg.col("danger_outline")
	for pr in sim.projectiles:
		if not pr.alive:
			continue
		var pos: Vector2 = pr.prev.lerp(pr.pos, wv.alpha)
		if pr.team == 1:
			var r: float = pr.radius
			ci.draw_circle(pos, r * 2.0, Color(danger, 0.18))
			var v: Vector2 = pr.vel
			if v.length() > 40.0:
				ci.draw_line(pos, pos - v.normalized() * r * 2.6, Color(Cfg.col("danger_hot"), 0.55), r * 1.1)
			ci.draw_circle(pos, r + 2.5, outline)
			ci.draw_circle(pos, r, danger)
			ci.draw_circle(pos, r * 0.5, core)
		else:
			var art: String = pr.art
			if art == "wave":
				ci.draw_arc(pos, pr.radius, pr.rot - 1.0, pr.rot + 1.0, 16, Color(Cfg.col("player"), 0.9), 6.0, true)
				continue
			var tex := Assets.tex(art if art != "arrow_power" else "arrow")
			var sc := Assets.draw_scale(art if art != "arrow_power" else "arrow") * (1.5 if art == "arrow_power" else 1.0)
			if pr.kind == SimProj.Kind.HALO or pr.kind == SimProj.Kind.ORBIT:
				ci.draw_circle(pos, pr.radius * 1.2, Color(Cfg.col("player_gold"), 0.15))
			else:
				ci.draw_line(pos, pos - pr.vel.normalized() * 26.0, Color(Cfg.col("player"), 0.45), 4.0)
			ci.draw_set_transform(pos, pr.rot, Vector2.ONE * sc)
			ci.draw_texture(tex, -Vector2(tex.get_width(), tex.get_height()) * 0.5)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hazards(ci: CanvasItem, wv, floor_pass: bool) -> void:
	for h in sim.hazards:
		if not h.alive:
			continue
		if h.team == 0:
			if not floor_pass:
				continue
			_draw_player_hazard(ci, h)
		else:
			if floor_pass:
				DrawTele.draw_enemy_hazard(ci, h, time)

func _draw_player_hazard(ci: CanvasItem, h: SimHazard) -> void:
	var gold := Cfg.col("player_gold")
	var white := Cfg.col("player")
	var pre := h.warn + h.delay
	var k := clampf(h.t / maxf(0.001, pre), 0.0, 1.0)
	if h.shape == SimHazard.Shape.LINE:
		var d := Geom.dir(h.angle)
		var end := h.pos + d * h.length
		if not h.active():
			ci.draw_line(h.pos, end, Color(gold, 0.35), h.width * k)
		else:
			var a := 1.0 - clampf((h.t - pre) / 0.25, 0.0, 1.0)
			ci.draw_line(h.pos, end, Color(1.0, 0.75, 0.3, a), h.width * 0.6)
			ci.draw_line(h.pos, end, Color(1, 1, 1, a), 4.0)
		return
	if h.kind == "starfall":
		ci.draw_arc(h.pos, h.radius, 0, TAU, 40, Color(white, 0.6), 2.0, true)
		ci.draw_circle(h.pos, h.radius, Color(gold, 0.08))
		if h.active():
			for i in 3:
				var p := h.pos + Vector2(randf_range(-h.radius, h.radius), randf_range(-h.radius, h.radius)) * 0.7
				ci.draw_line(p + Vector2(-20, -70), p, Color(white, 0.8), 3.0)
		return
	if not h.active():
		# Sigil and blasts: a gold ring whose inside fills from the outside in
		ci.draw_circle(h.pos, h.radius, Color(gold, 0.08))
		ci.draw_arc(h.pos, h.radius, 0, TAU, 48, Color(gold, 0.9), 3.0, true)
		ci.draw_arc(h.pos, h.radius * (1.0 - k) + 2.0, 0, TAU, 40, Color(white, 0.55), 2.0, true)
		var rot := time * 2.0
		for i in 6:
			var a2 := rot + TAU * i / 6.0
			ci.draw_line(h.pos + Geom.dir(a2) * h.radius * 0.55, h.pos + Geom.dir(a2) * h.radius * 0.85, Color(gold, 0.7), 2.0)

func _draw_pickups(ci: CanvasItem, wv) -> void:
	var cyan := Cfg.col("pickup")
	for pk in sim.pickups:
		var pos: Vector2 = pk.prev.lerp(pk.pos, wv.alpha)
		var bob := sin(time * 6.0 + pk.id) * 2.0
		ci.draw_circle(pos + Vector2(0, bob), 12.0, Color(cyan, 0.16))
		match pk.kind:
			"gold":
				ci.draw_circle(pos + Vector2(0, bob), 6.5, Paint.OUT)
				ci.draw_circle(pos + Vector2(0, bob), 5.0, Color("#ffd166"))
				ci.draw_arc(pos + Vector2(0, bob), 8.5, 0, TAU, 16, Color(cyan, 0.8), 1.5)
			"ember":
				ci.draw_circle(pos + Vector2(0, bob), 7.0, Paint.OUT)
				ci.draw_circle(pos + Vector2(0, bob), 5.5, Color("#ffe6a0"))
				ci.draw_arc(pos + Vector2(0, bob), 9.0, 0, TAU, 16, cyan, 2.0)
			"orb":
				ci.draw_circle(pos + Vector2(0, bob), 9.0, Paint.OUT)
				ci.draw_circle(pos + Vector2(0, bob), 7.5, Cfg.col("heal"))
				ci.draw_circle(pos + Vector2(-2, bob - 2), 3.0, Color.WHITE)
			"reward":
				var r := 18.0 + sin(time * 4.0) * 2.0
				ci.draw_circle(pos, r * 2.2, Color(cyan, 0.12))
				ci.draw_circle(pos, r + 3.0, Paint.OUT)
				ci.draw_circle(pos, r, Color(cyan, 0.9))
				ci.draw_circle(pos, r * 0.5, Color.WHITE)

func _draw_numbers(ci: CanvasItem) -> void:
	var DN: Dictionary = Cfg.F.damage_numbers
	for n in numbers:
		var k: float = n.t / n.life
		var pop := 1.0
		if n.t < float(DN.pop_time):
			pop = lerpf(float(DN.pop_scale), 1.0, n.t / float(DN.pop_time))
		var rise: float = float(DN.rise) * (1.0 - (1.0 - k) * (1.0 - k))
		var pos: Vector2 = n.pos + Vector2(n.vx * k, -rise)
		if n.crit:
			pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(DN.critShake) * (1.0 - k)
		var size := int(n.size * pop)
		var txt := str(int(round(n.val)))
		if n.kind == "heal":
			txt = "+" + txt
		elif n.kind == "hurt":
			txt = "-" + txt
		var a := 1.0 if k < 0.7 else (1.0 - (k - 0.7) / 0.3)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := pos - Vector2(w * 0.5, 0)
		if n.kind == "hurt" and n.icon != "":
			var it := Assets.tex(n.icon)
			var isz := Vector2(26, 26)
			ci.draw_texture_rect(it, Rect2(at - Vector2(isz.x + 4, isz.y * 0.8), isz), false, Color(1, 1, 1, a))
		ci.draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 5), Color(0, 0, 0, a))
		ci.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(n.col, a))
	for c in callouts:
		var k2: float = c.t / c.life
		var pop2 := lerpf(1.6, 1.0, clampf(c.t / 0.1, 0.0, 1.0))
		var size2 := int(c.size * pop2)
		var a2 := 1.0 if k2 < 0.65 else 1.0 - (k2 - 0.65) / 0.35
		var p2: Vector2 = c.pos + Vector2(0, -26.0 * k2)
		var w2 := font.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size2).x
		ci.draw_string_outline(font, p2 - Vector2(w2 * 0.5, 0), c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size2, maxi(4, size2 / 5), Color(0, 0, 0, a2))
		ci.draw_string(font, p2 - Vector2(w2 * 0.5, 0), c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size2, Color(c.col, a2))
