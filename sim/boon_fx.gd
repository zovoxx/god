class_name BoonFx
extends RefCounted
## Unique boon mechanics hooked into the combat pipeline. Effects that combine two sources
## (Freeze + lightning, Bleed bursts, Hex spreading, steam, slam combos...) announce
## themselves with a coloured "+COMBO" callout and an extra layered sound.

static func synergy(sim, pos: Vector2, text: String, patron: String) -> void:
	if sim.run != null:
		sim.run.synergies += 1
	sim.fire(&"synergy", {"pos": pos, "text": text, "color": patron})

static func _hit(sim, e: SimEnemy, dmg: float, slot: String, power: float, src: Vector2, tag: String, element: String = "") -> void:
	if not e.alive or dmg <= 0.0:
		return
	var h := HitInfo.make(dmg, slot, power, e.pos - src, src)
	h.tag = tag
	h.no_infuse = true
	h.no_hitstop = true
	h.element = element
	Combat.deal(sim, e, h)

static func _near(sim, pos: Vector2, r: float, exclude = null) -> Array:
	var out: Array = []
	for e in sim.enemies:
		if e != exclude and e.targetable() and e.pos.distance_to(pos) <= r + e.radius:
			out.append(e)
	return out

static func _nearest(sim, pos: Vector2, n: int, r: float, exclude: Array = []) -> Array:
	var c: Array = _near(sim, pos, r).filter(func(e): return not exclude.has(e))
	c.sort_custom(func(a, b): return a.pos.distance_to(pos) < b.pos.distance_to(pos))
	return c.slice(0, n)

static func wind_blade(sim, pos: Vector2, ang: float, dmg: float) -> void:
	var pr := Projectiles.player_shot(sim, pos, ang, 760.0, dmg, "special", 0.25, 12.0, "knife", 0.55)
	pr.pierce = 3
	pr.data["wind"] = true
	pr.data["on_hit"] = func(e):
		if sim.stats.has("cuts"):
			Status.add_bleed(sim, e, sim.stats.val("cuts"), null)

# ───────── hooks ─────────

static func on_hit(sim, e: SimEnemy, h: HitInfo, dealt: float, crit: bool, first_hit: bool) -> void:
	var st: Stats = sim.stats
	if e.frozen() and h.tag == "jolt":
		synergy(sim, e.pos, "+COMBO SHOCK", "storm")
	if h.tag in ["morning", "jolt", "bleed_burst", "hex_burst", "shatter", "steam"]:
		return
	if crit:
		if st.has("morning_star"):
			for o in _near(sim, e.pos, 70.0, e):
				_hit(sim, o, st.val("morning_star"), "other", 0.2, e.pos, "morning", "dawn")
		if st.has("solar_flare"):
			Status.add_burn(sim, e, st.val("solar_flare"))
		if e.mark_t > 0.0 and st.has("glare"):
			for o in _nearest(sim, e.pos, int(st.val("glare")), 220.0, [e]):
				Status.mark(sim, o)
		if e.hex_t > 0.0 and st.has("eclipse"):
			for o in _nearest(sim, e.pos, 1, 220.0, [e]):
				Status.hex(sim, o)
			synergy(sim, e.pos, "+ECLIPSE", "umbra")
	if h.slot == "special" and st.has("dawn_special_crit"):
		pass  # applied through crit_bonus below (see Combat)
	if st.has("cuts") and h.slot == "dash" and e.alive:
		Status.add_bleed(sim, e, st.val("cuts"), null)

static func on_kill(sim, e: SimEnemy, h: HitInfo) -> void:
	var st: Stats = sim.stats
	# Hex: hexed deaths burst and spread the curse
	if e.hex_t > 0.0:
		for o in _near(sim, e.pos, 90.0, e):
			_hit(sim, o, st.hex_burst, "other", 0.3, e.pos, "hex_burst", "umbra")
		var spread := _nearest(sim, e.pos, int(st.hex_spread), float(sim.T.status.hex_spread_radius), [e])
		for o in spread:
			Status.hex(sim, o)
		sim.fire(&"hex_burst", {"pos": e.pos, "to": spread.map(func(o): return o.pos)})
		if not spread.is_empty():
			synergy(sim, e.pos, "+HEX SPREAD", "umbra")
		if st.has("siphon"):
			Combat.heal_player(sim, st.val("siphon"), "siphon")
		if st.has("black_sun") and sim.rng.randf() < st.val("black_sun"):
			var p: SimPlayer = sim.player
			if p.cast_charges < p.cast_max:
				p.cast_charges += 1
		if st.has("drowned"):
			var hz := Hazards.player_field(sim, e.pos, 140.0, 0.0, 1.5, 0.25, 4.0, "other", 0.1, "whirlpool")
			hz.data["pull"] = 260.0
	# Frozen: shatter
	if e.frozen() and st.shatter_dmg > 0.0:
		for o in _near(sim, e.pos, 100.0, e):
			_hit(sim, o, st.shatter_dmg, "other", 0.5, e.pos, "shatter", "rime")
		sim.fire(&"shatter", {"pos": e.pos})
		synergy(sim, e.pos, "+SHATTER", "rime")
	# Burning: wildfire
	if e.burn > 0.0 and st.has("wildfire"):
		for o in _near(sim, e.pos, 110.0, e):
			_hit(sim, o, st.val("wildfire"), "other", 0.4, e.pos, "wildfire", "ember")
			Status.add_burn(sim, o, maxf(2.0, e.burn * 0.5))
		sim.fire(&"explosion", {"pos": e.pos, "radius": 110.0, "friendly": true})
		synergy(sim, e.pos, "+WILDFIRE", "ember")

static func on_freeze(sim, e: SimEnemy) -> void:
	var st: Stats = sim.stats
	if st.has("steam") and e.burn > 0.0:
		var dmg := e.burn * st.val("steam")
		for o in _near(sim, e.pos, 110.0):
			_hit(sim, o, dmg, "other", 0.6, e.pos, "steam", "ember")
		e.burn = 0.0
		sim.fire(&"explosion", {"pos": e.pos, "radius": 110.0, "friendly": true})
		synergy(sim, e.pos, "+STEAM BURST", "rime")
	if st.has("abs_zero"):
		for o in _near(sim, e.pos, st.val("abs_zero"), e):
			if o.chill > 0.0 and not o.frozen():
				Status.freeze(sim, o)
		synergy(sim, e.pos, "+ABSOLUTE ZERO", "rime")

static func on_bleed_burst(sim, e: SimEnemy, stacks: float) -> void:
	var st: Stats = sim.stats
	if st.has("bloodletting"):
		Combat.heal_player(sim, st.val("bloodletting"), "bleed")
	if st.has("wildthorn"):
		Status.add_burn(sim, e, stacks)
		synergy(sim, e.pos, "+WILDTHORN", "ember")
	if st.has("blood_moon"):
		Status.hex(sim, e)
		Combat.heal_player(sim, st.val("blood_moon"), "blood moon")
	if st.has("thousand_thorns"):
		for o in _nearest(sim, e.pos, int(st.val("thousand_thorns")), 200.0, [e]):
			o.bleed = minf(st.bleed_max, o.bleed + stacks * 0.5)

static func on_jolt(sim, struck: Dictionary) -> void:
	var st: Stats = sim.stats
	for e in sim.enemies:
		if not struck.has(e.id) or not e.alive:
			continue
		if st.has("plasma"):
			Status.add_burn(sim, e, st.val("plasma"))
		if st.has("static_frost"):
			Status.add_chill(sim, e, st.val("static_frost"))
	if st.has("thunderhead"):
		var n: int = int(sim.player.wstate.get("_jolts", 0)) + 1
		sim.player.wstate["_jolts"] = n
		if n % 6 == 0 and not struck.is_empty():
			var tgt = null
			for e in sim.enemies:
				if struck.has(e.id) and e.alive:
					tgt = e
					break
			if tgt != null:
				var hz := Hazards.player_blast(sim, tgt.pos, 110.0, 0.0, st.val("thunderhead"), "other", 0.8)
				hz.kind = "thunderbolt"
				sim.fire(&"lightning", {"points": [tgt.pos + Vector2(-30, -400), tgt.pos]})
				synergy(sim, tgt.pos, "+THUNDERHEAD", "storm")

static func on_slam(sim, e: SimEnemy) -> void:
	var st: Stats = sim.stats
	if st.has("boiling") and e.alive:
		for o in _near(sim, e.pos, 90.0):
			_hit(sim, o, st.val("boiling"), "other", 0.5, e.pos, "boiling", "ember")
		synergy(sim, e.pos, "+BOILING TIDE", "tide")
	if st.has("glacier") and e.alive:
		Status.freeze(sim, e)
		synergy(sim, e.pos, "+GLACIAL WAVE", "rime")
	if st.has("thunderwave") and e.alive:
		var h := HitInfo.make(0.0, "other", 0.2, Vector2.ZERO, e.pos)
		Status.jolt(sim, e, 1.2, h)
		synergy(sim, e.pos, "+THUNDERWAVE", "storm")

static func on_player_hurt(sim, source, dmg: float) -> void:
	var st: Stats = sim.stats
	var p: SimPlayer = sim.player
	if st.has("backdraft"):
		for o in _near(sim, p.pos, 130.0):
			_hit(sim, o, st.val("backdraft"), "other", 0.5, p.pos, "revenge", "ember")
			Status.add_burn(sim, o, st.val("backdraft_burn"))
		sim.fire(&"explosion", {"pos": p.pos, "radius": 130.0, "friendly": true})
	var src_enemy: SimEnemy = source if source is SimEnemy and source.alive else null
	if st.has("glacial_shell"):
		if src_enemy != null:
			Status.freeze(sim, src_enemy)
		for o in _near(sim, p.pos, 160.0):
			Status.add_chill(sim, o, st.val("glacial_shell"))
	if st.has("static_retort"):
		var targets: Array = []
		if src_enemy != null:
			targets.append(src_enemy)
		targets.append_array(_nearest(sim, p.pos, int(st.val("static_retort")), 320.0, targets))
		var pts: Array = []
		for o in targets:
			_hit(sim, o, st.jolt_dmg * 1.5, "other", 0.3, p.pos, "jolt", "storm")
			pts.append(o.pos)
		if not pts.is_empty():
			sim.fire(&"lightning", {"points": [p.pos] + pts})
	if st.has("breakwater"):
		Combat.add_barrier(sim, st.val("breakwater"))
		for o in _near(sim, p.pos, 160.0):
			if not o.no_knock:
				o.kvel += (o.pos - p.pos).normalized() * 700.0 / maxf(0.5, o.mass)
	if st.has("mercy"):
		Combat.heal_player(sim, st.val("mercy"), "mercy")
		for o in _near(sim, p.pos, 200.0):
			o.blind_t = 1.0
			o.stagger_t = maxf(o.stagger_t, 0.5) if not o.stagger_immune else o.stagger_t
	if st.has("umbral_recoil"):
		for o in _near(sim, p.pos, st.val("umbral_recoil")):
			Status.hex(sim, o)
	if st.has("updraft"):
		p.wstate["updraft_t"] = 2.0
		st.f["updraft_active"] = st.val("updraft")
	if st.has("barbed") and src_enemy != null:
		_hit(sim, src_enemy, st.val("barbed"), "other", 0.3, p.pos, "revenge", "thorn")
		Status.add_bleed(sim, src_enemy, 2.0, null)

static func on_special(sim) -> void:
	var st: Stats = sim.stats
	if st.has("gale_special"):
		var p: SimPlayer = sim.player
		var n := int(st.val("gale_special"))
		for i in n:
			wind_blade(sim, p.pos, p.aim_dir.angle() + (i - (n - 1) * 0.5) * 0.3, 10.0)

static func on_dash_start(sim) -> void:
	var st: Stats = sim.stats
	var p: SimPlayer = sim.player
	if st.has("storm_dash"):
		var t := _nearest(sim, p.pos, int(st.val("storm_dash")), 260.0)
		for o in t:
			_hit(sim, o, st.jolt_dmg, "dash", 0.3, p.pos, "jolt", "storm")
			sim.fire(&"lightning", {"points": [o.pos + Vector2(0, -300), o.pos]})
	if st.has("gale_dash"):
		for i in 3:
			wind_blade(sim, p.pos, p.dash_dir.angle() + (i - 1) * 0.25, 8.0)

static func on_dash_through(sim, e: SimEnemy) -> void:
	var st: Stats = sim.stats
	var p: SimPlayer = sim.player
	if st.has("shade_step"):
		Status.hex(sim, e)
		_hit(sim, e, 8.0, "dash", 0.2, p.pos, "shade", "umbra")
	if st.has("ride_lightning"):
		Status.jolt(sim, e, 1.0, HitInfo.make(0.0, "other", 0.2, Vector2.ZERO, p.pos))
		if p.dash_charges < p.dash_max:
			p.dash_cd = maxf(0.0, p.dash_cd - 0.12)
	if st.has("eye_storm"):
		for o in _nearest(sim, e.pos, int(st.val("eye_storm")), 300.0):
			wind_blade(sim, p.pos, (o.pos - p.pos).angle(), 10.0)

static func on_dash_end(sim) -> void:
	var st: Stats = sim.stats
	var p: SimPlayer = sim.player
	if st.has("dawn_dash"):
		p.guaranteed_crit = maxi(p.guaranteed_crit, 1)
	if st.has("sunstreak"):
		p.guaranteed_crit = maxi(p.guaranteed_crit, int(st.val("sunstreak")))
	if st.has("rime_nova"):
		for o in _near(sim, p.pos, 110.0):
			Status.add_chill(sim, o, st.val("rime_nova"))
		sim.fire(&"nova", {"pos": p.pos, "radius": 110.0, "color": "rime"})
	if st.has("tide_wave"):
		for o in _near(sim, p.pos, 130.0):
			_hit(sim, o, st.val("tide_wave"), "dash", 0.5, p.pos, "wave", "tide")
			if not o.no_knock:
				o.kvel += (o.pos - p.pos).normalized() * 600.0 / maxf(0.5, o.mass)
		sim.fire(&"nova", {"pos": p.pos, "radius": 130.0, "color": "tide"})
	if st.has("thorn_dash"):
		for i in 4:
			var hz := Hazards.player_field(sim, p.pos + Geom.dir(TAU * i / 4.0) * 26.0, 30.0, 0.0, 2.5, 0.4, 2.0, "dash", 0.1, "caltrops")
			hz.data["slow"] = true

static func on_dashing(sim, dt: float) -> void:
	var st: Stats = sim.stats
	if st.has("ember_dash"):
		var p: SimPlayer = sim.player
		p.wstate["_trail"] = float(p.wstate.get("_trail", 0.0)) - dt
		if float(p.wstate._trail) <= 0.0:
			p.wstate["_trail"] = 0.035
			Hazards.player_field(sim, p.pos, 26.0, 0.0, 1.8, 0.3, 2.0, "dash", 0.05, "fire_trail")

static func on_cast(sim, at: Vector2, hz: SimHazard) -> void:
	var st: Stats = sim.stats
	var delay: float = hz.delay
	if st.has("tide_cast"):
		hz.data["pull"] = -900.0
	if st.has("umbra_cast"):
		hz.data["pull"] = 500.0
	if st.has("ember_cast_field"):
		Hazards.player_field(sim, at, hz.radius, delay, st.val("ember_cast_field"), 0.4, 3.0, "cast", 0.05, "fire_field")
	if st.has("dawn_cast"):
		var f := Hazards.player_field(sim, at, hz.radius, delay, st.val("dawn_cast"), 0.5, 1.0, "cast", 0.05, "radiance")
		f.data["mark"] = true
	if st.has("thorn_cast"):
		var f2 := Hazards.player_field(sim, at, hz.radius, delay, st.val("thorn_cast"), 0.45, 2.0, "cast", 0.05, "brambles")
		f2.data["slow"] = true
	if st.has("storm_cloud"):
		var f3 := Hazards.player_field(sim, at, hz.radius * 1.4, delay, st.val("storm_cloud"), 0.45, 0.0, "cast", 0.1, "storm_cloud")
		f3.data["cloud"] = true
	if st.has("gale_cast") or st.has("maelstrom"):
		var dur := st.val("gale_cast") if st.has("gale_cast") else 3.0
		var pr := Projectiles.player_shot(sim, at, 0.0, 260.0, 6.0, "cast", 0.2, 50.0 if st.has("maelstrom") else 36.0, "cyclone", dur + delay)
		pr.kind = SimProj.Kind.HOMING
		pr.pierce = 9999
		pr.data["turn"] = 3.0
		pr.data["cyclone"] = true
		pr.data["pull"] = 420.0 if st.has("maelstrom") else 0.0
		pr.data["rehit"] = 0.0

static func tick(sim, dt: float) -> void:
	var st: Stats = sim.stats
	var p: SimPlayer = sim.player
	# updraft timer
	if p.wstate.has("updraft_t"):
		p.wstate.updraft_t = float(p.wstate.updraft_t) - dt
		if float(p.wstate.updraft_t) <= 0.0:
			p.wstate.erase("updraft_t")
			st.f["updraft_active"] = 0.0
	# Maelstrom Heart: periodic whirlpool at your feet
	if st.has("mael_heart") and sim.flow != null and sim.flow.state == RoomFlow.S.COMBAT:
		p.wstate["_mael"] = float(p.wstate.get("_mael", 0.0)) + dt
		if float(p.wstate._mael) >= st.val("mael_heart"):
			p.wstate["_mael"] = 0.0
			var hz := Hazards.player_field(sim, p.pos, 170.0, 0.0, 1.6, 0.3, 4.0, "other", 0.1, "whirlpool")
			hz.data["pull"] = 300.0
	# Black Static: hexed foes arc lightning to each other every second
	if st.has("black_static"):
		p.wstate["_bstatic"] = float(p.wstate.get("_bstatic", 0.0)) + dt
		if float(p.wstate._bstatic) >= 1.0:
			p.wstate["_bstatic"] = 0.0
			var hexed: Array = sim.enemies.filter(func(e): return e.targetable() and e.hex_t > 0.0)
			for i in range(hexed.size() - 1):
				var a: SimEnemy = hexed[i]
				var b: SimEnemy = hexed[i + 1]
				if a.pos.distance_to(b.pos) < 320.0:
					_hit(sim, a, st.val("black_static"), "other", 0.1, b.pos, "jolt", "storm")
					_hit(sim, b, st.val("black_static"), "other", 0.1, a.pos, "jolt", "storm")
					sim.fire(&"lightning", {"points": [a.pos, b.pos]})
	# Riptide: enemies knocked back fast damage those they crash into
	if st.has("riptide"):
		for e in sim.enemies:
			if not e.alive or e.kvel.length() < 300.0:
				continue
			for o in sim.enemies:
				if o != e and o.targetable() and o.pos.distance_to(e.pos) < e.radius + o.radius + 2.0:
					var key := "_rip%d" % o.id
					if sim.time - float(e.data.get(key, -9.0)) > 0.5:
						e.data[key] = sim.time
						_hit(sim, o, st.val("riptide"), "other", 0.4, e.pos, "riptide", "tide")
						synergy(sim, o.pos, "+RIPTIDE", "tide")
	# player fields with special behaviour
	for h in sim.hazards:
		if h.team != 0 or not h.alive or not h.active():
			continue
		if h.data.get("cloud", false):
			h.data["strike"] = float(h.data.get("strike", 0.0)) - dt
			if float(h.data.strike) <= 0.0:
				h.data["strike"] = 0.45
				var t := _nearest(sim, h.pos, 1, h.radius)
				for o in t:
					_hit(sim, o, st.jolt_dmg, "cast", 0.3, h.pos, "jolt", "storm")
					sim.fire(&"lightning", {"points": [o.pos + Vector2(10, -320), o.pos]})
		if h.data.get("mark", false) or h.data.get("slow", false):
			for o in _near(sim, h.pos, h.radius):
				if h.data.get("mark", false):
					Status.mark(sim, o)
				if h.data.get("slow", false):
					o.slow_t = maxf(o.slow_t, 0.5)
	# cyclones roam toward the nearest enemy and re-hit
	for pr in sim.projectiles:
		if pr.team == 0 and pr.alive and pr.data.get("cyclone", false):
			var n = sim.nearest_enemy(pr.pos, 600.0)
			if n != null:
				pr.data["target_pos"] = n.pos
			pr.data["rehit"] = float(pr.data.get("rehit", 0.0)) - dt
			if float(pr.data.rehit) <= 0.0:
				pr.data["rehit"] = 0.3
				pr.hits.clear()
			var pull: float = pr.data.get("pull", 0.0)
			if pull > 0.0:
				for o in _near(sim, pr.pos, 130.0):
					if not o.no_knock:
						o.kvel += (pr.pos - o.pos).normalized() * pull * dt * 4.0 / maxf(0.5, o.mass)
