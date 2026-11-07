class_name AIDepth4
extends RefCounted
## Depth 4 — The Starless Crown.

static func brains() -> Dictionary:
	return {
		"voidcaller": Voidcaller.new(), "voidportal": VoidPortal.new(), "voidimp": AIDepth1.Grub.new(),
		"mirrorknight": MirrorKnight.new(), "gravewell": Gravewell.new(), "prism": Prism.new(),
		"wraithlancer": WraithLancer.new(), "aegisherald": AegisHerald.new(), "hexer": Hexer.new(),
		"nullshard": NullShard.new(),
	}

static func dmg(e: SimEnemy) -> float:
	return float(e.def.dmg) * e.dmg_mul

static func windup(e: SimEnemy) -> float:
	return float(e.def.get("windup", 0.5))

## SUMMONER: opens void portals that pour out imps.
class Voidcaller extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.0
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 280.0, 420.0, dt)
		AI.face(e, AI.angle_to_player(sim, e), 4.0, dt)
		if e.tele != null:
			return
		e.cd -= dt
		var portals: Array = sim.enemies.filter(func(o): return o.alive and o.kind == "voidportal" and o.data.get("owner") == e)
		if e.cd <= 0.0 and portals.size() < 2:
			e.cd = 4.0 * e.cd_mul
			var at: Vector2 = sim.random_free_point(220.0, 320.0, sim.player.pos, 24.0)
			e.tele = AI.tele_circle(sim, e, at, 40.0, AIDepth4.windup(e), 0.0, "Void Rift", func():
				var vp := Enemies.spawn(sim, "voidportal", at, e.depth, {"summoned": true})
				vp.data["owner"] = e)
			e.tele.follow = false

class VoidPortal extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.2
	func update(sim, e: SimEnemy, dt: float) -> void:
		e.vel = Vector2.ZERO
		e.cd -= dt
		var imps: Array = sim.enemies.filter(func(o): return o.alive and o.kind == "voidimp" and o.data.get("portal") == e)
		if e.cd <= 0.0 and imps.size() < 3:
			e.cd = 3.0
			var imp := Enemies.spawn(sim, "voidimp", e.pos + Geom.dir(sim.rng.randf() * TAU) * 30.0, e.depth, {"summoned": true})
			imp.data["portal"] = e

## PARRIER: raises a glowing mirror (hits are reflected back at you), then a 3-slash combo.
class MirrorKnight extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.0
	func update(sim, e: SimEnemy, dt: float) -> void:
		var ang := AI.angle_to_player(sim, e)
		match e.st:
			0:
				AI.face(e, ang, 6.0, dt)
				AI.chase(sim, e, dt)
				e.cd -= dt
				if e.cd <= 0.0 and AI.dist(sim, e) < 220.0:
					e.set_state(1)
					e.data["guard"] = true
					sim.fire(&"mirror_guard", {"id": e.id, "pos": e.pos})
			1:
				AI.stop(e, dt)
				AI.face(e, ang, 6.0, dt)
				e.glow = 1.0
				if e.t > 1.2:
					e.data["guard"] = false
					e.set_state(2)
					e.data["n"] = 0
			2:
				var n: int = e.data.n
				if e.tele == null and n < 3:
					e.data["n"] = n + 1
					e.vel = Geom.dir(ang) * 120.0
					e.tele = AI.tele_cone(sim, e, ang, 120.0, 110.0, AIDepth4.windup(e) if n == 0 else 0.4, AIDepth4.dmg(e), "Mirror Slash")
				elif e.tele == null:
					e.set_state(3)
				else:
					AI.stop(e, dt, 6.0)
			3:
				AI.stop(e, dt)
				if e.t > 0.8:
					e.set_state(0)
					e.cd = 2.2 * e.cd_mul
			_:
				e.set_state(0)
	func on_hit(sim, e: SimEnemy, h: HitInfo) -> bool:
		if e.data.get("guard", false) and not h.is_dot and h.slot in ["attack", "dash", "special"]:
			sim.fire(&"reflected", {"id": e.id, "pos": e.pos})
			if sim.player.pos.distance_to(e.pos) < 260.0:
				Combat.hurt_player(sim, AIDepth4.dmg(e) * 0.4, e.pos, e, "Mirror Riposte")
			return true
		return false

## PULLER: drops a gravity well that drags you toward a crushing core.
class Gravewell extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.5
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 260.0, 380.0, dt)
		AI.face(e, AI.angle_to_player(sim, e), 4.0, dt)
		var well = e.data.get("well")
		if well != null:
			e.data["well_t"] = float(e.data.well_t) - dt
			var p: SimPlayer = sim.player
			var to: Vector2 = well - p.pos
			if to.length() < 260.0 and p.state != SimPlayer.St.DASH:
				p.kvel += to.normalized() * 1100.0 * dt
			if to.length() < 42.0:
				Combat.hurt_player(sim, AIDepth4.dmg(e), well, e, "Crushing Core")
			if float(e.data.well_t) <= 0.0:
				e.data.erase("well")
			return
		if e.tele != null:
			return
		e.cd -= dt
		if e.cd <= 0.0:
			e.cd = 4.5 * e.cd_mul
			var at: Vector2 = sim.player.pos
			e.tele = AI.tele_ring(sim, e, at, 40.0, 260.0, AIDepth4.windup(e), 0.0, "Gravewell", func():
				e.data["well"] = at
				e.data["well_t"] = 2.4)
			e.tele.follow = false

## SWEEPER: its beam rotates through the shaded arc.
class Prism extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(1.0, 2.0)
	func update(sim, e: SimEnemy, dt: float) -> void:
		e.vel = Vector2.ZERO
		if e.data.has("sweep_t"):
			var k := float(e.data.sweep_t) / 1.6
			var ang: float = float(e.data.a0) + float(e.data.arc) * (k - 0.5)
			e.data["beam_a"] = ang
			var end: Vector2 = e.pos + Geom.dir(ang) * 520.0
			if Geom.seg_dist(sim.player.pos, e.pos, end) < 14.0 + sim.player.hit_radius:
				Combat.hurt_player(sim, AIDepth4.dmg(e), e.pos, e, "Prism Beam")
			e.data["sweep_t"] = float(e.data.sweep_t) + dt
			if float(e.data.sweep_t) >= 1.6:
				e.data.erase("sweep_t")
				e.data.erase("beam_a")
				e.cd = 3.0 * e.cd_mul
			return
		if e.tele != null:
			return
		e.cd -= dt
		if e.cd <= 0.0:
			var a0 := AI.angle_to_player(sim, e)
			var arc := deg_to_rad(100.0)
			e.tele = AI.tele_cone(sim, e, a0, 520.0, 100.0, AIDepth4.windup(e), 0.0, "Prism Sweep", func():
				e.data["sweep_t"] = 0.0
				e.data["a0"] = a0
				e.data["arc"] = arc if sim.rng.randf() < 0.5 else -arc)

## MULTI-DASH: shows three lines, then dashes along each in order.
class WraithLancer extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.5
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				AI.kite(sim, e, 200.0, 320.0, dt)
				AI.face(e, AI.angle_to_player(sim, e), 5.0, dt)
				e.cd -= dt
				if e.cd <= 0.0:
					e.set_state(1)
					var pts: Array = [e.pos]
					var cur: Vector2 = e.pos
					for i in 3:
						var target: Vector2 = sim.player.pos + Geom.dir(sim.rng.randf() * TAU) * (60.0 if i == 0 else 140.0)
						var ang := (target - cur).angle()
						var l := minf(sim.ray_to_wall(cur, ang, 360.0, e.radius), 340.0)
						var nxt: Vector2 = cur + Geom.dir(ang) * l
						var t := Tele.make(sim, e, Tele.Shape.LINE, AIDepth4.windup(e) + i * 0.28, AIDepth4.dmg(e), "Lance Dash")
						t.pos = cur
						t.angle = ang
						t.length = l
						t.width = 34.0
						var dest := nxt
						t.on_impact = func():
							e.pos = dest
							e.prev = dest
							sim.fire(&"enemy_blink", {"id": e.id, "from": e.pos, "to": dest})
						pts.append(nxt)
						cur = nxt
					e.data["path"] = pts
			1:
				e.vel = Vector2.ZERO
				if e.t > AIDepth4.windup(e) + 0.7:
					e.set_state(0)
					e.cd = 3.0 * e.cd_mul
			_:
				e.set_state(0)

## SHIELD BUFFER: wraps allies in bubble shields.
class AegisHerald extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.5
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 320.0, 440.0, dt)
		e.cd -= dt
		if e.cd <= 0.0:
			e.cd = 4.5 * e.cd_mul
			var best = null
			var bd := 380.0
			for o in sim.enemies:
				if o != e and o.targetable() and o.shield <= 0.0 and o.pos.distance_to(e.pos) < bd and not o.is_boss:
					bd = o.pos.distance_to(e.pos)
					best = o
			if best != null:
				best.max_shield = round(best.max_hp * 0.35)
				best.shield = best.max_shield
				best.data["bubble"] = true
				sim.fire(&"bubble", {"from": e.pos, "to": best.pos, "id": best.id})

## CURSE LAYER: drops circles on your footsteps that detonate.
class Hexer extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.5
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 280.0, 400.0, dt)
		AI.face(e, AI.angle_to_player(sim, e), 4.0, dt)
		if e.data.has("chant"):
			e.data["chant"] = float(e.data.chant) - dt
			e.data["drop"] = float(e.data.get("drop", 0.0)) - dt
			if float(e.data.drop) <= 0.0:
				e.data["drop"] = 0.45
				var t := AI.tele_circle(sim, e, sim.player.pos, 52.0, AIDepth4.windup(e), AIDepth4.dmg(e), "Hex Mark")
				t.follow = false
			if float(e.data.chant) <= 0.0:
				e.data.erase("chant")
				e.cd = 3.2 * e.cd_mul
			return
		e.cd -= dt
		if e.cd <= 0.0:
			e.data["chant"] = 2.0

## BULLET RINGS: rings with a gap, then chase it down.
class NullShard extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(1.0, 1.8)
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 240.0, 380.0, dt, 0.5)
		if e.tele != null:
			return
		e.cd -= dt
		if e.cd <= 0.0:
			var n: int = int(e.data.get("ring", 0))
			e.data["ring"] = n + 1
			e.cd = (0.9 if n % 3 != 2 else 2.6) * e.cd_mul
			var gap = sim.rng.randi_range(0, 15)
			var off = sim.rng.randf() * TAU
			e.tele = AI.tele_ring(sim, e, e.pos, e.radius, 90.0, AIDepth4.windup(e), 0.0, "Null Ring", func():
				AI.ring_burst(sim, e, e.pos, 16, 240.0, AIDepth4.dmg(e), "Null Ring", off, gap))
