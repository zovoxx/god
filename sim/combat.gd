class_name Combat
extends RefCounted
## The hit pipeline (player → enemy), the hurt pipeline (enemy → player), kills, wall slams,
## the Sigil, counters, finishers, perfect dashes, kill streaks and the Overdrive meter.

# ───────────────────────── player → enemy ─────────────────────────

## Applies a hit. Returns the damage dealt (0 if blocked/immune).
static func deal(sim, e: SimEnemy, h: HitInfo) -> float:
	if not e.alive or e.spawn_t > 0.0:
		return 0.0
	if e.invuln or e.untargetable:
		if not h.is_dot:
			sim.fire(&"enemy_immune", {"id": e.id, "pos": e.pos})
		return 0.0
	var F: GameFeel = sim.F
	var st: Stats = sim.stats
	var p: SimPlayer = sim.player
	if e.brain != null and not h.is_dot and e.brain.on_hit(sim, e, h):
		return 0.0
	# frontal shields block hits from the front (not damage over time)
	if e.front_shield > 0.0 and not h.is_dot and h.slot != "cast" and e.can_act():
		var from := (h.src - e.pos).angle()
		if absf(Geom.angle_diff(e.facing, from)) < e.front_shield * 0.5 and h.armor_break < 2.0:
			e.kvel += h.dir * 120.0
			sim.fire(&"enemy_blocked", {"id": e.id, "pos": e.pos + Geom.dir(from) * e.radius})
			return 0.0
	var countered := false
	# COUNTER: hitting during the white flash of the enemy's telegraph interrupts it
	if not h.is_dot and h.slot != "status" and e.tele != null and e.tele.in_flash(float(F.telegraph.flash_window)) and not e.is_boss:
		countered = true
		Tele.cancel(sim, e.tele)
		e.tele = null
		e.set_state(0)
		e.cd = maxf(e.cd, 0.8)
		e.stagger_t = maxf(e.stagger_t, float(F.counter.stagger))
		e.countered_t = 0.6
		e.contact_on = false
		e.super_armor = bool(e.def.get("super_armor", false))
		add_overdrive(sim, float(sim.T.overdrive.per_counter))
		sim.request_hitstop(float(F.hitstop.counter))
		sim.fire(&"enemy_countered", {"id": e.id, "pos": e.pos, "dir": h.dir})
		if sim.run != null:
			sim.run.counters += 1
	# FINISHER: staggered/frozen enemies under 15 % HP are executed by the next hit
	var finisher := false
	if e.finishable and not h.is_dot and h.slot != "status":
		finisher = true
		h.tag = "finisher"
	# ── damage ──
	var dmg := h.dmg
	var mul := 1.0 + st.all_dmg + st.slot_dmg(h.slot) + streak_bonus(sim)
	if e.is_boss or e.is_guardian or not e.elites.is_empty():
		mul += st.vs_elite_dmg
	if sim.time - p.dash_ended_at < 1.0:
		mul += st.val("slipstream")
	if countered:
		mul += float(F.counter.bonus_dmg)
	dmg *= mul * Status.vuln(sim, e)
	if float(e.data.get("bell_t", 0.0)) > 0.0:
		dmg *= 0.7
	if sim.run != null and h.slot != "status":
		dmg *= sim.run.player_dmg_mul()
	# ── crit ──
	var crit := false
	if h.can_crit and not h.is_dot:
		var chance: float = float(sim.T.crit.base_chance) + st.crit_chance + h.crit_bonus
		if h.slot == "special":
			chance += st.val("dawn_special_crit")
		if e.mark_t > 0.0:
			chance += st.mark_crit
		if e.hex_t > 0.0 and st.has("eclipse"):
			chance += 0.15
		if e.burn > 0.0 and st.has("solar_flare"):
			chance += 0.12
		chance += e.bleed * st.val("sunlit")
		if h.force_crit or p.guaranteed_crit > 0 or (st.has("zenith") and not e.hit_by_player):
			chance = 1.0
		if sim.rng.randf() < chance:
			crit = true
			dmg *= float(sim.T.crit.multiplier) + st.crit_mul
		if p.guaranteed_crit > 0 and h.slot in ["attack", "special", "dash"]:
			p.guaranteed_crit -= 1
	if finisher:
		dmg = maxf(dmg * float(F.finisher.dmg_mul), e.hp + e.shield)
	if sim.one_hit and not h.is_dot:
		dmg = e.hp + e.shield + e.armor + 1.0
	dmg = maxf(1.0, dmg) if h.dmg > 0.0 else 0.0
	# ── shields & armor ──
	var dealt := dmg
	if e.shield > 0.0:
		var a := minf(e.shield, dmg)
		e.shield -= a
		dmg -= a
		if e.shield <= 0.0:
			sim.fire(&"shield_broken", {"id": e.id, "pos": e.pos})
	if e.armor > 0.0 and dmg > 0.0:
		var ad := dmg * h.armor_break
		var a2 := minf(e.armor, ad)
		e.armor -= a2
		dmg -= a2 / h.armor_break
		if e.armor <= 0.0:
			e.armor = 0.0
			e.stagger_t = maxf(e.stagger_t, 1.6)
			if e.tele != null:
				Tele.cancel(sim, e.tele)
				e.tele = null
			sim.fire(&"armor_broken", {"id": e.id, "pos": e.pos})
	e.hp -= dmg
	e.last_hit_t = sim.time
	e.data["last_hit_dmg"] = dealt
	var first_hit := not e.hit_by_player
	e.hit_by_player = true
	# ── reaction ──
	if not h.is_dot:
		e.flash_t = float(F.flash.crit_duration if crit else F.flash.duration)
		e.squash = float(F.squash.amount) * clampf(h.power, 0.15, 1.0)
		e.squash_dir = h.dir
		var knock := h.knock * (1.0 + st.knockback)
		if st.infuse.get(h.slot, "") == "tide":
			knock *= 1.0 + st.tide_knock * float(st.infuse_pow.get(h.slot, 1.0))
		if not e.no_knock and knock > 0.0:
			var heavy: float = 3.0 if e.super_armor else 1.0
			e.kvel += h.dir * float(F.knockback.base) * knock * clampf(h.power + 0.35, 0.3, 1.4) / maxf(0.3, e.mass * heavy)
		if not e.stagger_immune and not e.super_armor and h.power >= float(sim.T.status.stagger_threshold) and e.tele == null:
			e.stagger_t = maxf(e.stagger_t, lerpf(F.hitstun.min, F.hitstun.max, clampf(h.power, 0.0, 1.0)) * h.stagger)
		if h.slot in ["attack", "special", "dash"]:
			add_overdrive(sim, float(sim.T.overdrive.per_hit) * (1.0 + h.power))
	var killed := e.hp <= 0.0
	if not h.no_infuse and e.alive:
		var pat: String = st.infuse.get(h.slot, "")
		if pat != "":
			Status.infuse(sim, e, pat, float(st.infuse_pow.get(h.slot, 1.0)), h)
		if h.slot == "special" and st.infuse.get("special", "") == "thorn":
			Status.burst_bleed(sim, e)
	if not e.elites.is_empty():
		Elites.on_hit(sim, e, h)
	BoonFx.on_hit(sim, e, h, dealt, crit, first_hit)
	if finisher:
		sim.request_hitstop(float(F.hitstop.finisher))
	elif not h.no_hitstop and not h.is_dot:
		sim.request_hitstop(sim.hitstop_for_power(h.power, crit, killed))
	if run_ok(sim) and h.slot != "status":
		sim.run.stats_dmg_dealt += dealt
		if dealt > sim.run.best_hit:
			sim.run.best_hit = dealt
	sim.fire(&"enemy_hit", {"id": e.id, "pos": e.pos, "dmg": dealt, "crit": crit, "dir": h.dir, "power": h.power, "slot": h.slot, "element": h.element, "dot": h.is_dot, "tag": h.tag, "killed": killed, "blood": e.def.get("blood", "#ffffff"), "radius": e.radius})
	if finisher:
		sim.fire(&"finisher", {"id": e.id, "pos": e.pos, "dir": h.dir})
	if killed and e.alive:
		on_kill(sim, e, h, finisher)
	return dealt

static func run_ok(sim) -> bool:
	return sim.run != null

static func on_kill(sim, e: SimEnemy, h: HitInfo, finisher: bool = false) -> void:
	Enemies.kill(sim, e)
	var st: Stats = sim.stats
	# streak
	if not e.summoned or e.is_boss:
		streak_kill(sim)
	add_overdrive(sim, float(sim.T.overdrive.per_kill))
	# drops
	if not e.summoned:
		var E: Dictionary = sim.T.economy
		var g: int = sim.rng.randi_range(int(E.gold_per_kill[0]), int(E.gold_per_kill[1]))
		if not e.elites.is_empty():
			g += int(E.gold_elite_bonus)
		g += int(sim.F.streak.gold_per_kill[sim.streak_tier])
		g = int(round(g * (1.0 + st.gold_gain)))
		Pickups.drop_gold(sim, e.pos, g)
	if finisher and sim.run != null:
		sim.run.finishers += 1
	if finisher:
		for i in int(sim.F.finisher.orbs):
			Pickups.spawn(sim, "orb", e.pos, float(sim.F.finisher.orb_heal))
	if run_ok(sim):
		sim.run.on_enemy_killed(sim, e)
	sim.fire(&"enemy_killed", {"id": e.id, "kind": e.kind, "pos": e.pos, "dir": h.dir, "power": h.power, "boss": e.is_boss, "guardian": e.is_guardian, "elite": not e.elites.is_empty(), "radius": e.radius, "blood": e.def.get("blood", "#ffffff"), "art": e.art, "finisher": finisher, "streak": sim.streak_tier})
	BoonFx.on_kill(sim, e, h)
	if sim.flow != null:
		sim.flow.on_enemy_killed(e)

static func wall_slam(sim, e: SimEnemy, n: Vector2, speed: float) -> void:
	var F: GameFeel = sim.F
	var st: Stats = sim.stats
	var base: float = maxf(float(F.knockback.slam_min_damage), float(e.data.get("last_hit_dmg", 0.0)) * float(F.knockback.slam_damage_frac))
	base *= speed / float(F.knockback.slam_speed)
	if st.infuse.get("attack", "") == "tide" or st.infuse.get("special", "") == "tide" or st.infuse.get("cast", "") == "tide":
		base += st.tide_slam_dmg
	e.kvel = e.kvel.bounce(n) * 0.25
	var h := HitInfo.make(base, "other", 0.6, n, e.pos - n * e.radius)
	h.tag = "slam"
	h.no_infuse = true
	h.can_crit = false
	if not e.stagger_immune:
		e.stagger_t = maxf(e.stagger_t, 0.45)
	sim.fire(&"wall_slam", {"id": e.id, "pos": e.pos - n * e.radius, "normal": n, "speed": speed})
	deal(sim, e, h)
	BoonFx.on_slam(sim, e)

# ───────────────────────── enemy → player ─────────────────────────

## Applies damage to the player. Returns true if it landed.
static func hurt_player(sim, dmg: float, src: Vector2, source, attack_name: String) -> bool:
	var p: SimPlayer = sim.player
	if p.state == SimPlayer.St.DEAD or p.is_invuln() or dmg <= 0.0:
		return false
	if sim.flow != null and not sim.flow.combat_live():
		return false
	var st: Stats = sim.stats
	if st.dodge > 0.0 and sim.rng.randf() < st.dodge:
		sim.fire(&"player_dodged", {"pos": p.pos})
		p.hurt_iframes = 0.3
		return true
	var d := dmg * maxf(0.2, 1.0 + st.damage_taken)
	if sim.run != null:
		d *= sim.run.hurt_mul()
	d = maxf(1.0, round(d))
	var absorbed := 0.0
	if p.barrier > 0.0:
		absorbed = minf(p.barrier, d)
		p.barrier -= absorbed
	var taken := d - absorbed
	var before := p.hp
	if not sim.god_mode:
		p.hp -= taken
	var dir := (p.pos - src).normalized() if p.pos.distance_to(src) > 1.0 else Vector2.RIGHT
	p.hurt_iframes = float(sim.T.player.hurt_iframes)
	p.hurt_lock = float(sim.T.player.hurt_lock)
	p.kvel = dir * float(sim.T.player.hurt_knock)
	sim.request_hitstop(float(sim.F.hitstop.hurt))
	var sname: String = source.name if source != null and "name" in source else "Hazard"
	var art: String = source.art if source != null and "art" in source else "hazard"
	var kind: String = source.kind if source != null and "kind" in source else "hazard"
	var entry := {"source": sname, "kind": kind, "attack": attack_name, "dmg": d, "time": sim.time, "art": art, "depth": sim.run.depth if sim.run != null else 1}
	sim.damage_log.append(entry)
	if sim.damage_log.size() > 30:
		sim.damage_log.pop_front()
	if sim.run != null:
		sim.run.on_player_hurt(entry)
	if sim.flow != null:
		sim.flow.on_hurt(d)
	sim.fire(&"player_hurt", {"dmg": d, "absorbed": absorbed, "src": src, "dir": dir, "source": sname, "attack": attack_name, "art": art, "hp": p.hp, "max_hp": p.max_hp, "before": before})
	if source != null and source is SimEnemy and source.has_elite("vampiric"):
		source.hp = minf(source.max_hp, source.hp + d * 2.0)
	BoonFx.on_player_hurt(sim, source, d)
	if p.hp <= 0.0:
		player_down(sim, entry)
	return true

static func player_down(sim, entry: Dictionary) -> void:
	var p: SimPlayer = sim.player
	if sim.run != null and sim.run.defiance > 0:
		sim.run.defiance -= 1
		p.hp = maxf(1.0, round(p.max_hp * float(sim.T.player.defy_heal_frac)))
		p.invuln_t = float(sim.T.player.defy_iframes)
		sim.slowmo(float(sim.F.slowmo.defied_scale), float(sim.F.slowmo.defied_duration))
		# clear nearby threats
		var push: float = sim.T.player.defy_push_radius
		for pr in sim.projectiles:
			if pr.team == 1 and pr.pos.distance_to(p.pos) < push * 2.0:
				pr.alive = false
		for e in sim.enemies:
			if e.alive and e.pos.distance_to(p.pos) < push:
				e.kvel += (e.pos - p.pos).normalized() * 700.0 / maxf(0.5, e.mass)
		sim.fire(&"player_defied", {"pos": p.pos, "left": sim.run.defiance, "hp": p.hp})
		return
	p.hp = 0.0
	p.state = SimPlayer.St.DEAD
	p.vel = Vector2.ZERO
	sim.slowmo(float(sim.F.slowmo.death_scale), float(sim.F.slowmo.death_duration))
	sim.fire(&"player_died", {"pos": p.pos, "killer": entry})
	if sim.flow != null:
		sim.flow.on_player_died(entry)

static func heal_player(sim, amount: float, source: String = "") -> float:
	var p: SimPlayer = sim.player
	if p.state == SimPlayer.St.DEAD or amount <= 0.0:
		return 0.0
	var before := p.hp
	p.hp = minf(p.max_hp, p.hp + amount)
	var got := p.hp - before
	if got > 0.0:
		sim.fire(&"player_healed", {"amount": got, "hp": p.hp, "max_hp": p.max_hp, "source": source, "pos": p.pos})
	return got

static func add_barrier(sim, amount: float) -> void:
	var p: SimPlayer = sim.player
	p.barrier = minf(p.max_hp, p.barrier + amount)
	sim.fire(&"player_barrier", {"amount": amount, "barrier": p.barrier})

static func perfect_dash(sim, source, attack_name: String) -> void:
	var p: SimPlayer = sim.player
	if sim.time - float(p.wstate.get("_last_perfect", -9.0)) < 0.25:
		return
	p.wstate["_last_perfect"] = sim.time
	var PD: Dictionary = sim.F.perfect_dash
	sim.slowmo(float(PD.slowmo_scale), float(PD.slowmo_duration))
	if PD.guaranteed_crit:
		p.guaranteed_crit = maxi(p.guaranteed_crit, 1)
	add_overdrive(sim, float(sim.T.overdrive.per_perfect_dash))
	if sim.run != null:
		sim.run.perfect_dashes += 1
	sim.fire(&"perfect_dash", {"pos": p.pos, "attack": attack_name})

# ───────────────────────── dash interactions ─────────────────────────

static func on_dash_start(sim) -> void:
	var p: SimPlayer = sim.player
	# projectiles about to hit count as a perfect dash too
	for pr in sim.projectiles:
		if pr.team == 1 and pr.alive:
			var rel: Vector2 = pr.pos - p.pos
			var closing: float = -rel.dot(pr.vel.normalized()) if pr.vel != Vector2.ZERO else 0.0
			var speed: float = pr.vel.length()
			if speed > 1.0 and rel.length() < speed * float(sim.F.perfect_dash.window) + p.hit_radius + pr.radius and closing > 0.0:
				var miss := absf(rel.cross(pr.vel.normalized()))
				if miss < p.hit_radius + pr.radius + 4.0:
					perfect_dash(sim, pr.owner, pr.attack_name)
					break
	BoonFx.on_dash_start(sim)

static func on_dashing(sim, dt: float) -> void:
	BoonFx.on_dashing(sim, dt)
	var p: SimPlayer = sim.player
	for e in sim.enemies:
		if e.targetable() and not p.dash_hit.has(e.id) and Geom.in_circle(p.pos, p.radius, e.pos, e.radius + 6.0):
			p.dash_hit[e.id] = true
			BoonFx.on_dash_through(sim, e)

static func on_dash_end(sim) -> void:
	BoonFx.on_dash_end(sim)

# ───────────────────────── the Sigil ─────────────────────────

static func cast_sigil(sim) -> void:
	var p: SimPlayer = sim.player
	var C: Dictionary = sim.T.cast
	if p.cast_charges == p.cast_max:
		p.cast_recharge = sim.cast_recharge_time()
	p.cast_charges -= 1
	p.state = SimPlayer.St.CAST
	p.cast_t = 0.12
	var at: Vector2 = PlayerCtl.sigil_point(sim, p, sim.input)
	at.x = clampf(at.x, sim.arena.rect.position.x + 10, sim.arena.rect.end.x - 10)
	at.y = clampf(at.y, sim.arena.rect.position.y + 10, sim.arena.rect.end.y - 10)
	var hz := Hazards.player_blast(sim, at, float(C.radius) * (1.0 + sim.stats.cast_radius), float(C.delay), float(C.damage), "cast", float(C.power))
	hz.root = float(C.root_time)
	hz.kind = "sigil"
	sim.fire(&"player_cast", {"pos": at, "radius": hz.radius, "delay": hz.delay})
	BoonFx.on_cast(sim, at, hz)

# ───────────────────────── streak & overdrive ─────────────────────────

static func streak_kill(sim) -> void:
	var S: Dictionary = sim.F.streak
	sim.streak_kills += 1
	var tiers: Array = S.tiers
	var tier := 0
	for i in tiers.size():
		if sim.streak_kills >= int(tiers[i]):
			tier = i + 1
	sim.streak_timer = float(S.window) + float(S.window_per_tier) * tier
	if tier > sim.streak_tier:
		sim.streak_tier = tier
		sim.fire(&"streak_tier", {"tier": tier, "name": S.names[tier], "kills": sim.streak_kills})
	if run_ok(sim):
		sim.run.best_streak = maxi(sim.run.best_streak, sim.streak_kills)

static func streak_tick(sim, dt: float) -> void:
	if sim.streak_kills <= 0:
		return
	if sim.flow != null and sim.flow.streak_paused():
		return
	sim.streak_timer -= dt
	if sim.streak_timer <= 0.0:
		if sim.streak_tier > 0:
			sim.fire(&"streak_broken", {"tier": sim.streak_tier, "kills": sim.streak_kills})
		sim.streak_kills = 0
		sim.streak_tier = 0

static func streak_bonus(sim) -> float:
	return float(sim.F.streak.damage_bonus[sim.streak_tier])

static func add_overdrive(sim, amount: float) -> void:
	var p: SimPlayer = sim.player
	if p.overdrive_ready:
		return
	var O: Dictionary = sim.T.overdrive
	p.overdrive = minf(float(O.max), p.overdrive + amount * (1.0 + sim.stats.overdrive_gain))
	p.overdrive_idle = 0.0
	if p.overdrive >= float(O.max):
		p.overdrive_ready = true
		sim.fire(&"overdrive_full", {})

static func overdrive_tick(sim, dt: float) -> void:
	var p: SimPlayer = sim.player
	if p.overdrive_ready:
		return
	var O: Dictionary = sim.T.overdrive
	p.overdrive_idle += dt
	if p.overdrive_idle > float(O.decay_delay):
		p.overdrive = maxf(0.0, p.overdrive - float(O.decay_per_sec) * dt)

## consumed by the weapon when the Special is used; returns true if it was empowered
static func use_overdrive(sim) -> bool:
	var p: SimPlayer = sim.player
	if not p.overdrive_ready:
		return false
	p.overdrive_ready = false
	p.overdrive = 0.0
	sim.fire(&"overdrive_used", {"weapon": sim.weapon.id if sim.weapon != null else ""})
	return true
