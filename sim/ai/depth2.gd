class_name AIDepth2
extends RefCounted
## Depth 2 — The Drowned Archive.

static func brains() -> Dictionary:
	return {
		"inkshade": Inkshade.new(), "lanternist": Lanternist.new(), "scribe": Scribe.new(),
		"tidecleric": Tidecleric.new(), "hookjaw": Hookjaw.new(), "slurry": Slurry.new(),
		"slurry_small": Slurry.new(), "echo": Echo.new(), "glimmerjelly": Glimmerjelly.new(),
	}

static func dmg(e: SimEnemy) -> float:
	return float(e.def.dmg) * e.dmg_mul

static func windup(e: SimEnemy) -> float:
	return float(e.def.get("windup", 0.5))

## TELEPORTER: fades out, an ink circle marks where it will reappear (usually behind you),
## then it slashes in a cone.
class Inkshade extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(1.0, 2.0)
	func update(sim, e: SimEnemy, dt: float) -> void:
		var p: SimPlayer = sim.player
		match e.st:
			0:
				AI.kite(sim, e, 140.0, 240.0, dt)
				AI.face(e, AI.angle_to_player(sim, e), 6.0, dt)
				e.cd -= dt
				if e.cd <= 0.0:
					e.set_state(1)
					e.untargetable = true
					e.data["hidden"] = true
					var behind: Vector2 = p.pos - p.aim_dir * 80.0
					if sim.point_blocked(behind, e.radius):
						behind = sim.random_free_point(70.0, 110.0, p.pos, e.radius)
					e.tele = AI.tele_circle(sim, e, behind, 38.0, AIDepth2.windup(e), 0.0, "Ink Gate", func():
						e.pos = e.target_pos
						e.prev = e.pos
						e.untargetable = false
						e.data["hidden"] = false
						e.set_state(2)
						e.tele = AI.tele_cone(sim, e, AI.angle_to_player(sim, e), 98.0, 120.0, 0.45, AIDepth2.dmg(e), "Ink Slash", func(): e.set_state(3)))
					e.tele.follow = false
					e.target_pos = behind
			1:
				e.vel = Vector2.ZERO
			2:
				e.vel = Vector2.ZERO
				if e.tele != null and e.t < 0.2:
					e.tele.angle = AI.angle_to_player(sim, e)
					e.facing = e.tele.angle
			3:
				AI.stop(e, dt)
				if e.t > 0.6:
					e.set_state(0)
					e.cd = 2.6 * e.cd_mul
			_:
				e.set_state(0)

## SNIPER: kites; its beam tracks you, locks (white flash) and fires along the line. Pillars block it.
class Lanternist extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(1.2, 2.2)
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				AI.kite(sim, e, 340.0, 520.0, dt)
				AI.face(e, AI.angle_to_player(sim, e), 6.0, dt)
				e.cd -= dt
				if e.cd <= 0.0:
					e.set_state(1)
					var ang := AI.angle_to_player(sim, e)
					e.tele = AI.tele_line(sim, e, ang, _len(sim, e, ang), 22.0, AIDepth2.windup(e), AIDepth2.dmg(e), "Lantern Beam", func():
						sim.fire(&"beam", {"from": e.pos, "angle": e.a, "length": _len(sim, e, e.a), "width": 22.0})
						e.set_state(2))
			1:
				AI.stop(e, dt, 20.0)
				if e.tele != null and e.tele.time_left() > 0.3:
					e.a = AI.angle_to_player(sim, e)
					e.facing = e.a
					e.tele.angle = e.a
				if e.tele != null:
					e.tele.length = _len(sim, e, e.tele.angle)
			2:
				if e.t > 0.6:
					e.set_state(0)
					e.cd = 2.8 * e.cd_mul
			_:
				e.set_state(0)
	func _len(sim, e: SimEnemy, ang: float) -> float:
		return sim.ray_to_wall(e.pos, ang, 900.0, 2.0)

## TETHER PAIR: a beam joins the two Scribes. It warns, burns, then rests. Kill both within 3 s.
class Scribe extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.a = sim.rng.randf() * TAU
		e.data["beam"] = "off"
		e.data["beam_t"] = sim.rng.randf_range(0.6, 1.2)
		_link(sim, e)
	func _link(sim, e: SimEnemy) -> void:
		for o in sim.enemies:
			if o != e and o.alive and o.kind == "scribe" and o.data.get("partner") == null:
				o.data["partner"] = e
				e.data["partner"] = o
				e.data["leader"] = false
				o.data["leader"] = true
				e.a = o.a + PI
				return
		e.data["partner"] = null
	func update(sim, e: SimEnemy, dt: float) -> void:
		var partner = e.data.get("partner")
		if partner != null and not partner.alive:
			# revive the fallen twin if it is not avenged within 3 seconds
			e.data["revive"] = float(e.data.get("revive", 3.0)) - dt
			if float(e.data.revive) <= 0.0:
				var twin := Enemies.spawn(sim, "scribe", partner.pos, e.depth, {"hp_mul": 0.5, "summoned": true})
				twin.data["partner"] = e
				e.data["partner"] = twin
				e.data["leader"] = true
				e.data.erase("revive")
				sim.fire(&"banner", {"text": "THE TWIN RETURNS", "sub": "", "col": Color("#ff8a6a"), "life": 1.2, "big": false})
		elif partner == null and e.t > 0.5:
			_link(sim, e)
		e.a += 0.45 * dt
		var goal: Vector2 = sim.player.pos + Geom.dir(e.a) * 210.0
		AI.move_to(sim, e, goal, e.move_speed() * 0.8, dt, 4.0)
		AI.face(e, AI.angle_to_player(sim, e), 5.0, dt)
		if not e.data.get("leader", false) or partner == null or not partner.alive:
			e.data["beam"] = "off"
			return
		# the leader owns the beam cycle: off → warn (telegraph) → on → off
		e.data["beam_t"] = float(e.data.beam_t) - dt
		match String(e.data.beam):
			"off":
				if float(e.data.beam_t) <= 0.0:
					e.data["beam"] = "warn"
					e.data["beam_t"] = maxf(0.6, float(sim.T.pacing.enemy_min_windup))
					sim.fire(&"telegraph_started", {"id": e.id, "name": "Tether", "boss": false, "windup": 0.6, "owner": e.id})
			"warn":
				if float(e.data.beam_t) <= 0.0:
					e.data["beam"] = "on"
					e.data["beam_t"] = 2.0
			"on":
				var a2: Vector2 = e.pos
				var b2: Vector2 = partner.pos
				if Geom.seg_dist(sim.player.pos, a2, b2) < 12.0 + sim.player.hit_radius:
					Combat.hurt_player(sim, AIDepth2.dmg(e), sim.player.pos + (a2 - b2).orthogonal().normalized() * 10.0, e, "Tether Beam")
				if float(e.data.beam_t) <= 0.0:
					e.data["beam"] = "off"
					e.data["beam_t"] = 1.4 * e.cd_mul
	func on_death(sim, e: SimEnemy) -> void:
		var partner = e.data.get("partner")
		if partner != null and partner.alive:
			partner.data["revive"] = 3.0
			partner.data["beam"] = "off"

## HEALER: keeps away and channels a heal beam into injured allies. Hitting it breaks the channel.
class Tidecleric extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 2.0
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 250.0, 380.0, dt, 0.9)
		AI.face(e, AI.angle_to_player(sim, e), 5.0, dt)
		var tgt = e.data.get("heal")
		if tgt != null:
			if not tgt.alive or tgt.hp >= tgt.max_hp or e.t > 3.0 or tgt.pos.distance_to(e.pos) > 420.0:
				e.data["heal"] = null
				e.set_state(0)
				e.cd = 2.0 * e.cd_mul
			else:
				tgt.hp = minf(tgt.max_hp, tgt.hp + tgt.max_hp * 0.08 * dt)
			return
		e.cd -= dt
		if e.cd > 0.0 or e.tele != null:
			return
		var best = null
		var lowest := 0.98
		for o in sim.enemies:
			if o != e and o.targetable() and o.hp_frac() < lowest and o.pos.distance_to(e.pos) < 340.0:
				lowest = o.hp_frac()
				best = o
		if best != null:
			e.data["heal"] = best
			e.set_state(5)
		else:
			# no one to mend: a slow tide orb
			var ang := AI.angle_to_player(sim, e)
			e.tele = AI.tele_aim(sim, e, ang, 420.0, 18.0, AIDepth2.windup(e), "Tide Orb", func():
				var pr := AI.shoot(sim, e, e.pos, ang, 300.0, AIDepth2.dmg(e), "Tide Orb", 12.0, 3.0))
			e.cd = 3.4 * e.cd_mul
	func on_hit(sim, e: SimEnemy, h: HitInfo) -> bool:
		if e.data.get("heal") != null and not h.is_dot:
			e.data["heal"] = null
			e.set_state(0)
			e.stagger_t = 0.5
			e.cd = 2.5
			sim.fire(&"channel_broken", {"pos": e.pos})
		return false

## GRAPPLER: throws a hook along a shown line; if it connects you are dragged in and bitten.
## The hook is a projectile: dashing makes it pass through you.
class Hookjaw extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(1.0, 2.0)
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				AI.kite(sim, e, 200.0, 320.0, dt)
				AI.face(e, AI.angle_to_player(sim, e), 6.0, dt)
				e.cd -= dt
				if e.cd <= 0.0 and AI.dist(sim, e) < 400.0:
					e.set_state(1)
					e.a = AI.angle_to_player(sim, e)
					e.tele = AI.tele_aim(sim, e, e.a, 400.0, 20.0, AIDepth2.windup(e), "Hook", func():
						var pr := AI.shoot(sim, e, e.pos, e.a, 950.0, AIDepth2.dmg(e) * 0.5, "Hook", 11.0, 0.45)
						pr.art = "e_hook"
						pr.data["on_hit_player"] = func():
							sim.player.kvel = (e.pos - sim.player.pos).normalized() * 950.0
							e.data["hooked"] = true
						e.set_state(2))
			1:
				AI.stop(e, dt, 20.0)
				if e.tele != null and e.t < 0.3:
					e.a = AI.angle_to_player(sim, e)
					e.tele.angle = e.a
					e.facing = e.a
			2:
				AI.stop(e, dt)
				if e.t > 0.45:
					if e.data.get("hooked", false):
						e.data["hooked"] = false
						e.set_state(3)
						e.tele = AI.tele_circle(sim, e, e.pos, 70.0, 0.45, AIDepth2.dmg(e), "Bite", func(): e.set_state(4))
					else:
						e.set_state(4)
			3:
				AI.stop(e, dt)
			4:
				if e.t > 0.7:
					e.set_state(0)
					e.cd = 3.2 * e.cd_mul
			_:
				e.set_state(0)

## SPLITTER: hops at you and splashes where it lands; splits into two smaller blobs on death.
class Slurry extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(0.6, 1.2)
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				AI.stop(e, dt)
				e.cd -= dt
				if e.cd <= 0.0:
					var hop := 140.0 if e.kind == "slurry" else 110.0
					var to: Vector2 = AI.to_player(sim, e)
					var dest: Vector2 = e.pos + to.normalized() * minf(hop, to.length())
					if sim.point_blocked(dest, e.radius):
						dest = e.pos
					var w := AIDepth2.windup(e)
					e.data["from"] = e.pos
					e.data["to"] = dest
					e.set_state(1)
					e.tele = AI.tele_circle(sim, e, dest, e.radius * 2.1, w, AIDepth2.dmg(e), "Splash", func():
						e.set_state(2)
						sim.fire(&"splash", {"pos": e.pos, "radius": e.radius * 2.1}))
					e.tele.follow = false
			1:
				var w2: float = e.tele.windup if e.tele != null else 0.5
				var k := clampf(e.t / w2, 0.0, 1.0)
				var target: Vector2 = (e.data.from as Vector2).lerp(e.data.to, k)
				e.vel = (target - e.pos) / maxf(dt, 0.001)
				e.data["hop_h"] = sin(k * PI) * 40.0
			2:
				e.vel = Vector2.ZERO
				e.data["hop_h"] = 0.0
				if e.t > 0.5:
					e.set_state(0)
					e.cd = sim.rng.randf_range(0.7, 1.3) * e.cd_mul
			_:
				e.set_state(0)
	func on_death(sim, e: SimEnemy) -> void:
		if e.kind != "slurry":
			return
		for i in 2:
			var a = (float(i) - 0.5) * PI + sim.rng.randf_range(-0.4, 0.4)
			var c := Enemies.spawn(sim, "slurry_small", e.pos + Geom.dir(a) * 18.0, e.depth, {"portal": false, "summoned": true})
			c.kvel = Geom.dir(a) * 300.0
			c.cd = 0.8

## DODGER: sidesteps the first hit aimed at it (then needs a moment), fires bolt spreads.
class Echo extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.5
	func update(sim, e: SimEnemy, dt: float) -> void:
		e.data["dodge_cd"] = maxf(0.0, float(e.data.get("dodge_cd", 0.0)) - dt)
		AI.kite(sim, e, 240.0, 360.0, dt)
		AI.face(e, AI.angle_to_player(sim, e), 6.0, dt)
		if e.tele != null:
			return
		e.cd -= dt
		if e.cd <= 0.0:
			var ang := AI.angle_to_player(sim, e)
			e.tele = AI.tele_aim(sim, e, ang, 460.0, 16.0, AIDepth2.windup(e), "Echo Bolts", func():
				for i in 3:
					AI.shoot(sim, e, e.pos, ang + (i - 1) * 0.22, 520.0, AIDepth2.dmg(e), "Echo Bolts"))
			e.cd = 2.4 * e.cd_mul
	func on_hit(sim, e: SimEnemy, h: HitInfo) -> bool:
		if h.is_dot or h.slot == "cast" or h.slot == "status" or float(e.data.get("dodge_cd", 0.0)) > 0.0 or e.root_t > 0.0:
			return false
		e.data["dodge_cd"] = 1.4
		var side := h.dir.orthogonal() * (1.0 if sim.rng.randf() < 0.5 else -1.0)
		var to: Vector2 = e.pos + side * 90.0
		if sim.point_blocked(to, e.radius):
			to = e.pos - side * 90.0
		var from := e.pos
		e.pos = to
		e.prev = to
		sim.fire(&"enemy_dodged", {"id": e.id, "from": from, "to": to})
		return true

## MINE DROPPER: drifts and leaves mines that arm, beep when approached, and burst.
class Glimmerjelly extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.2
		e.target_pos = e.pos
	func update(sim, e: SimEnemy, dt: float) -> void:
		if e.pos.distance_to(e.target_pos) < 30.0 or e.t > 3.0:
			e.target_pos = sim.random_free_point(80.0, 260.0, sim.player.pos, e.radius)
			e.t = 0.0
		AI.move_to(sim, e, e.target_pos, e.move_speed(), dt, 2.0)
		e.cd -= dt
		if e.cd <= 0.0:
			e.cd = 2.6 * e.cd_mul
			var mines := 0
			for h in sim.hazards:
				if h.kind == "mine" and h.owner == e and h.alive:
					mines += 1
			if mines < 3:
				var hz := Hazards.enemy_field(sim, e, e.pos, 16.0, 1.0, 12.0, AIDepth2.dmg(e), "Glimmer Mine", "mine")
				hz.data["src_ref"] = SourceRef.of(e)
				hz.data["blast"] = 80.0
				hz.name = e.name
				hz.art = e.art
