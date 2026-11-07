class_name AIDepth3
extends RefCounted
## Depth 3 — The Clockwork Foundry.

static func brains() -> Dictionary:
	return {
		"rivethound": RivetHound.new(), "coilsentry": CoilSentry.new(), "pylon": Brain.new(),
		"ironclad": Ironclad.new(), "forgemortar": ForgeMortar.new(), "bellwether": Bellwether.new(),
		"gyrosaw": Gyrosaw.new(), "slagcrawler": Slagcrawler.new(), "sparkmite": Sparkmite.new(),
	}

static func dmg(e: SimEnemy) -> float:
	return float(e.def.dmg) * e.dmg_mul

static func windup(e: SimEnemy) -> float:
	return float(e.def.get("windup", 0.5))

## PACK FLANKER: takes a place in a ring around you, then pounces along a shown line.
class RivetHound extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.a = sim.rng.randf() * TAU
		e.cd = sim.rng.randf_range(1.2, 2.6)
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				e.a += 0.9 * dt
				var goal: Vector2 = sim.player.pos + Geom.dir(e.a) * 170.0
				AI.move_to(sim, e, goal, e.move_speed(), dt, 7.0)
				AI.face(e, AI.angle_to_player(sim, e), 10.0, dt)
				e.cd -= dt
				if e.cd <= 0.0 and AI.dist(sim, e) < 230.0:
					e.set_state(1)
					var ang := AI.angle_to_player(sim, e)
					e.data["ang"] = ang
					e.tele = AI.tele_line(sim, e, ang, AI.dist(sim, e) + 50.0, 28.0, AIDepth3.windup(e), AIDepth3.dmg(e), "Pounce", func(): e.set_state(2))
					e.tele.locked = true
			1:
				AI.stop(e, dt, 20.0)
			2:
				e.vel = Geom.dir(float(e.data.ang)) * 660.0
				if e.t > 0.28:
					e.set_state(3)
			3:
				AI.stop(e, dt, 6.0)
				if e.t > 0.45:
					e.set_state(0)
					e.cd = sim.rng.randf_range(1.6, 2.8) * e.cd_mul
			_:
				e.set_state(0)

## TRAP LAYER: plants pylons; pylons within reach of each other link into a lightning fence.
class CoilSentry extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.0
		e.data["fence"] = "off"
		e.data["fence_t"] = 2.0
	func pylons(sim, e: SimEnemy) -> Array:
		return sim.enemies.filter(func(o): return o.alive and o.kind == "pylon" and o.data.get("owner") == e and o.spawn_t <= 0.0)
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 240.0, 360.0, dt)
		AI.face(e, AI.angle_to_player(sim, e), 5.0, dt)
		e.cd -= dt
		var ps := pylons(sim, e)
		var all_p: Array = sim.enemies.filter(func(o): return o.alive and o.kind == "pylon" and o.data.get("owner") == e)
		if e.cd <= 0.0 and all_p.size() < 3 and e.tele == null:
			e.cd = 2.2 * e.cd_mul
			var at: Vector2 = sim.random_free_point(190.0, 280.0, sim.player.pos, 14.0)
			e.tele = AI.tele_circle(sim, e, at, 24.0, AIDepth3.windup(e), 0.0, "Pylon", func():
				var py := Enemies.spawn(sim, "pylon", at, e.depth, {"summoned": true, "ignore_min_dist": true, "portal": false})
				py.data["owner"] = e)
			e.tele.follow = false
		# fence cycle: off → warn → on
		e.data["fence_t"] = float(e.data.fence_t) - dt
		match String(e.data.fence):
			"off":
				if float(e.data.fence_t) <= 0.0 and ps.size() >= 2:
					e.data["fence"] = "warn"
					e.data["fence_t"] = 0.7
					sim.fire(&"telegraph_started", {"id": e.id, "name": "Lightning Fence", "boss": false, "windup": 0.7, "owner": e.id})
			"warn":
				if float(e.data.fence_t) <= 0.0:
					e.data["fence"] = "on"
					e.data["fence_t"] = 2.2
			"on":
				for i in ps.size():
					for j in range(i + 1, ps.size()):
						var a: Vector2 = ps[i].pos
						var b: Vector2 = ps[j].pos
						if a.distance_to(b) < 360.0 and Geom.seg_dist(sim.player.pos, a, b) < 10.0 + sim.player.hit_radius:
							Combat.hurt_player(sim, AIDepth3.dmg(e), sim.player.pos + (b - a).orthogonal().normalized() * 10.0, e, "Lightning Fence")
				if float(e.data.fence_t) <= 0.0:
					e.data["fence"] = "off"
					e.data["fence_t"] = 1.6
	func on_death(sim, e: SimEnemy) -> void:
		for o in sim.enemies:
			if o.alive and o.kind == "pylon" and o.data.get("owner") == e:
				o.hp = 0.0
				Enemies.kill(sim, o)

## ARMORED: plods forward; a heavy overhead slam in front. Breaking its armor stuns it.
class Ironclad extends Brain:
	func update(sim, e: SimEnemy, dt: float) -> void:
		var ang := AI.angle_to_player(sim, e)
		match e.st:
			0:
				AI.face(e, ang, 3.0, dt)
				AI.chase(sim, e, dt)
				e.cd -= dt
				if AI.dist(sim, e) < 120.0 and e.cd <= 0.0:
					e.set_state(1)
					var c: Vector2 = e.pos + Geom.dir(e.facing) * 70.0
					e.tele = AI.tele_circle(sim, e, c, 82.0, AIDepth3.windup(e), AIDepth3.dmg(e), "Hammerfall", func(): e.set_state(2))
					e.tele.follow = false
			1:
				AI.stop(e, dt, 20.0)
			2:
				if e.t > 0.7:
					e.set_state(0)
					e.cd = 1.4 * e.cd_mul
			_:
				e.set_state(0)

## ARTILLERY: stationary; shells land on and around you one after another.
class ForgeMortar extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(1.0, 2.0)
	func update(sim, e: SimEnemy, dt: float) -> void:
		e.vel = Vector2.ZERO
		AI.face(e, AI.angle_to_player(sim, e), 3.0, dt)
		e.cd -= dt
		if e.cd <= 0.0:
			e.cd = 3.4 * e.cd_mul
			var base: Vector2 = sim.player.pos
			var dirv: Vector2 = sim.player.vel.normalized() if sim.player.vel.length() > 30.0 else Geom.dir(sim.rng.randf() * TAU)
			for i in 3:
				AI.lob(sim, e, base + dirv * (i * 70.0), AIDepth3.windup(e) + i * 0.22, 60.0, AIDepth3.dmg(e), "Mortar Shell")

## BUFFER: allies inside its ring move faster and take less damage. Harmless itself.
class Bellwether extends Brain:
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 300.0, 420.0, dt, 0.9)
		for o in sim.enemies:
			if o != e and o.alive and o.pos.distance_to(e.pos) < 210.0:
				o.data["bell_t"] = 0.25
		e.data["ring"] = 210.0

## BOUNCER: telegraphs a direction, spins invulnerably bouncing off walls, then stops and glows.
class Gyrosaw extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.0
		e.contact = float(e.def.dmg)
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				e.vel = Vector2.ZERO
				e.invuln = false
				e.cd -= dt
				if e.cd <= 0.0:
					e.set_state(1)
					e.a = AI.angle_to_player(sim, e)
					e.tele = AI.tele_line(sim, e, e.a, sim.ray_to_wall(e.pos, e.a, 800.0, e.radius) + e.radius, e.radius * 2.0, AIDepth3.windup(e), 0.0, "Spin", func():
						e.set_state(2)
						e.invuln = true
						e.contact_on = true
						e.attack_name = "Sawblade")
			1:
				e.vel = Vector2.ZERO
			2:
				e.vel = Geom.dir(e.a) * 460.0
				e.data["spin"] = true
				var r: Rect2 = sim.arena.rect
				var nx: Vector2 = e.pos + e.vel * dt
				if nx.x < r.position.x + e.radius + 2.0 or nx.x > r.end.x - e.radius - 2.0:
					e.a = PI - e.a
				if nx.y < r.position.y + e.radius + 2.0 or nx.y > r.end.y - e.radius - 2.0:
					e.a = -e.a
				for pl in sim.arena.pillars:
					if nx.distance_to(pl.pos) < float(pl.r) + e.radius:
						e.a = ((e.pos - pl.pos).normalized()).angle()
				if e.t > 3.0:
					e.set_state(3)
					e.invuln = false
					e.contact_on = false
					e.data["spin"] = false
			3:
				# exposed: glows, can be hit
				e.vel = Vector2.ZERO
				e.glow = 0.6
				if e.t > 1.6:
					e.set_state(0)
					e.cd = 0.5 * e.cd_mul
			_:
				e.set_state(0)

## TRAIL LAYER: circles you laying molten slag (floor hazards that arm before hurting).
class Slagcrawler extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.a = AI.angle_to_player(sim, e) + PI
		e.data["dir"] = 1.0 if sim.rng.randf() < 0.5 else -1.0
	func update(sim, e: SimEnemy, dt: float) -> void:
		e.a += 1.1 * dt * float(e.data.dir)
		var goal: Vector2 = sim.player.pos + Geom.dir(e.a) * 200.0
		AI.move_to(sim, e, goal, e.move_speed(), dt, 5.0)
		AI.face(e, e.vel.angle(), 8.0, dt)
		e.cd -= dt
		if e.cd <= 0.0 and e.vel.length() > 60.0:
			e.cd = 0.22
			var hz := Hazards.enemy_field(sim, e, e.pos, 24.0, AIDepth3.windup(e), 4.0, AIDepth3.dmg(e), "Molten Slag", "slag")
			hz.name = e.name
			hz.art = e.art

## LATCHING SWARM: lunges and clings; every clinging mite slows you and stings. Dash to shake off.
class Sparkmite extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(0.3, 1.0)
	func update(sim, e: SimEnemy, dt: float) -> void:
		var p: SimPlayer = sim.player
		if e.data.get("latched", false):
			if p.state == SimPlayer.St.DASH or p.invuln_t > 0.0:
				e.data["latched"] = false
				e.kvel = (e.pos - p.pos).normalized() * 500.0
				e.stagger_t = 0.8
				e.set_state(0)
				e.cd = 1.5
				sim.fire(&"shake_off", {"pos": e.pos})
				return
			var off: Vector2 = e.data.off
			e.pos = p.pos + off
			e.vel = Vector2.ZERO
			e.data["sting"] = float(e.data.get("sting", 1.0)) - dt
			if float(e.data.sting) <= 0.0:
				e.data["sting"] = 1.2
				Combat.hurt_player(sim, AIDepth3.dmg(e), e.pos, e, "Sting")
			return
		match e.st:
			0:
				AI.chase(sim, e, dt)
				e.cd -= dt
				if AI.dist(sim, e) < 80.0 and e.cd <= 0.0:
					e.set_state(1)
					var ang := AI.angle_to_player(sim, e)
					e.tele = AI.tele_line(sim, e, ang, 90.0, 18.0, AIDepth3.windup(e), 0.0, "Latch", func():
						e.set_state(0)
						e.cd = 1.0
						if not p.is_invuln() and Geom.in_line(p.pos, p.hit_radius, e.pos, ang, 90.0, 18.0):
							e.data["latched"] = true
							e.data["off"] = Geom.dir(sim.rng.randf() * TAU) * 16.0
							Combat.hurt_player(sim, AIDepth3.dmg(e), e.pos, e, "Latch"))
					e.tele.locked = true
			1:
				AI.stop(e, dt, 20.0)
			_:
				e.set_state(0)
