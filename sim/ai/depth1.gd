class_name AIDepth1
extends RefCounted
## Depth 1 — The Ashen Gardens. Every attack is telegraphed through AI.tele_* helpers.

static func brains() -> Dictionary:
	return {
		"cinderling": Cinderling.new(), "bramblehorn": Bramblehorn.new(), "spitbloom": Spitbloom.new(),
		"ashwisp": Ashwisp.new(), "burrowmaw": Burrowmaw.new(), "kindlepod": Kindlepod.new(),
		"thornwarden": ThornWarden.new(), "grubmother": Grubmother.new(), "grub": Grub.new(),
	}

static func dmg(e: SimEnemy) -> float:
	return float(e.def.dmg) * e.dmg_mul

static func windup(e: SimEnemy) -> float:
	return float(e.def.get("windup", 0.5))

## RUSHER: sprints in, telegraphs a short lunge line, lunges, then has a punish window.
class Cinderling extends Brain:
	var lunge_len := 110.0
	var lunge_w := 30.0
	var trigger := 92.0
	var lunge_speed := 560.0
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(0.2, 0.8)
	func update(sim, e: SimEnemy, dt: float) -> void:
		var ang := AI.angle_to_player(sim, e)
		match e.st:
			0:
				e.cd -= dt
				AI.chase(sim, e, dt, 1.25 if AI.dist(sim, e) > 260.0 else 1.0)
				AI.face(e, ang, 12.0, dt)
				if AI.dist(sim, e) < trigger and e.cd <= 0.0:
					e.set_state(1)
					e.a = ang
					e.tele = AI.tele_line(sim, e, e.a, lunge_len + e.radius, lunge_w, AIDepth1.windup(e), AIDepth1.dmg(e), "Lunge", func(): e.set_state(2))
			1:
				AI.stop(e, dt, 20.0)
				if e.tele != null and e.t < e.tele.windup * 0.45:
					e.a = ang
					e.facing = ang
					e.tele.angle = ang
			2:
				e.vel = Geom.dir(e.a) * lunge_speed
				if e.t >= lunge_len / lunge_speed:
					e.set_state(3)
			3:
				AI.stop(e, dt, 6.0)
				if e.t >= 0.42:
					e.set_state(0)
					e.cd = 0.5 * e.cd_mul
			_:
				e.set_state(0)

class Grub extends Cinderling:
	func _init() -> void:
		lunge_len = 60.0
		lunge_w = 20.0
		trigger = 60.0
		lunge_speed = 420.0

## CHARGER: shows a line to the wall, charges along it, stuns itself on impact with a wall.
class Bramblehorn extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.2
		e.contact = float(e.def.dmg)
	func update(sim, e: SimEnemy, dt: float) -> void:
		var ang := AI.angle_to_player(sim, e)
		match e.st:
			0:
				e.cd -= dt
				if AI.dist(sim, e) > 240.0:
					AI.chase(sim, e, dt)
				else:
					AI.stop(e, dt)
				AI.face(e, ang, 6.0, dt)
				if e.cd <= 0.0 and AI.dist(sim, e) < 460.0:
					e.set_state(1)
					e.a = ang
					var l: float = sim.ray_to_wall(e.pos, e.a, 620.0, e.radius)
					e.tele = AI.tele_line(sim, e, e.a, l + e.radius, e.radius * 2.0 + 8.0, AIDepth1.windup(e), 0.0, "Charge", func():
						e.set_state(2)
						e.contact_on = true
						e.super_armor = true
						e.attack_name = "Charge")
			1:
				AI.stop(e, dt, 20.0)
				if e.tele != null and e.t < e.tele.windup * 0.6:
					e.a = ang
					e.facing = ang
					e.tele.angle = ang
					e.tele.length = sim.ray_to_wall(e.pos, e.a, 620.0, e.radius) + e.radius
			2:
				e.vel = Geom.dir(e.a) * 640.0
				if sim.point_blocked(e.pos + Geom.dir(e.a) * (e.radius + 8.0), e.radius) or e.t > 1.2:
					e.contact_on = false
					e.super_armor = false
					e.vel = Vector2.ZERO
					e.stagger_t = 1.2
					e.data["vuln_t"] = 1.2
					sim.fire(&"wall_slam", {"id": e.id, "pos": e.pos + Geom.dir(e.a) * e.radius, "normal": -Geom.dir(e.a), "speed": 640.0})
					e.set_state(0)
					e.cd = 2.0 * e.cd_mul
			_:
				e.set_state(0)

## LOBBER: stationary; arcs seeds at your predicted position.
class Spitbloom extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = sim.rng.randf_range(0.8, 1.6)
	func update(sim, e: SimEnemy, dt: float) -> void:
		e.vel = Vector2.ZERO
		AI.face(e, AI.angle_to_player(sim, e), 4.0, dt)
		e.cd -= dt
		if e.cd <= 0.0 and e.tele == null:
			var target: Vector2 = sim.player.pos + sim.player.vel * 0.55
			e.tele = AI.lob(sim, e, target, AIDepth1.windup(e), 46.0, AIDepth1.dmg(e), "Seed")
			e.cd = 2.2 * e.cd_mul

## SWARM: orbits you, then darts in along a short line.
class Ashwisp extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.a = sim.rng.randf() * TAU
		e.data["dir"] = 1.0 if sim.rng.randf() < 0.5 else -1.0
		e.cd = sim.rng.randf_range(1.5, 3.5)
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				e.a += 1.7 * dt * float(e.data.dir)
				var goal: Vector2 = sim.player.pos + Geom.dir(e.a) * 150.0
				AI.move_to(sim, e, goal, e.move_speed(), dt, 6.0)
				AI.face(e, e.vel.angle(), 10.0, dt)
				e.cd -= dt
				if e.cd <= 0.0 and AI.dist(sim, e) < 240.0:
					e.set_state(1)
					var ang := AI.angle_to_player(sim, e)
					e.data["dart"] = ang
					e.tele = AI.tele_line(sim, e, ang, AI.dist(sim, e) + 40.0, 22.0, AIDepth1.windup(e), AIDepth1.dmg(e), "Dart", func(): e.set_state(2))
					e.tele.locked = true
			1:
				AI.stop(e, dt, 15.0)
			2:
				e.vel = Geom.dir(float(e.data.dart)) * 620.0
				if e.t > 0.3:
					e.set_state(0)
					e.cd = sim.rng.randf_range(2.0, 3.5) * e.cd_mul
			_:
				e.set_state(0)

## BURROWER: hunts you underground, erupts under a locked circle, then is exposed.
class Burrowmaw extends Brain:
	func init(sim, e: SimEnemy) -> void:
		_hide(e, true)
	func _hide(e: SimEnemy, on: bool) -> void:
		e.untargetable = on
		e.data["hidden"] = on
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				AI.chase(sim, e, dt)
				if AI.dist(sim, e) < 50.0 or e.t > 2.6:
					e.set_state(1)
					e.vel = Vector2.ZERO
					e.tele = AI.tele_circle(sim, e, sim.player.pos, 62.0, AIDepth1.windup(e), AIDepth1.dmg(e), "Erupt", func():
						e.pos = e.tele.pos if e.tele != null else e.pos
						_hide(e, false)
						e.set_state(2))
					e.tele.follow = false
			1:
				# the circle follows you for a moment, then locks in place
				if e.tele != null:
					if e.t < 0.4:
						e.tele.pos = e.tele.pos.lerp(sim.player.pos, clampf(dt * 8.0, 0.0, 1.0))
					e.pos = e.tele.pos
				e.vel = Vector2.ZERO
			2:
				AI.stop(e, dt)
				if e.t > 1.4:
					e.set_state(3)
			3:
				if e.t > 0.3:
					_hide(e, true)
					e.set_state(0)
			_:
				e.set_state(0)

## EXPLODER: lights a fuse near you. Killing it mid-fuse blows up its friends instead.
class Kindlepod extends Brain:
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				AI.chase(sim, e, dt)
				AI.face(e, AI.angle_to_player(sim, e), 8.0, dt)
				if AI.dist(sim, e) < 84.0:
					e.set_state(1)
					e.vel = Vector2.ZERO
					e.tele = AI.tele_circle(sim, e, e.pos, 92.0, AIDepth1.windup(e), AIDepth1.dmg(e), "Kindle Blast", func():
						_blast(sim, e, true)
						e.hp = 0.0
						Enemies.kill(sim, e)
						sim.fire(&"enemy_killed", {"id": e.id, "kind": e.kind, "pos": e.pos, "dir": Vector2.UP, "power": 0.8, "boss": false, "guardian": false, "elite": false, "radius": e.radius, "blood": e.def.blood, "art": e.art, "finisher": false, "streak": sim.streak_tier, "self": true})
						if sim.flow != null:
							sim.flow.on_enemy_killed(e))
					e.tele.data["hit_enemies"] = AIDepth1.dmg(e) * 2.0
			1:
				e.vel = Vector2.ZERO
			_:
				e.set_state(0)
	func on_death(sim, e: SimEnemy) -> void:
		if e.st == 1 and e.data.get("blasted", false) == false:
			_blast(sim, e, false)
	func _blast(sim, e: SimEnemy, hurt_player: bool) -> void:
		e.data["blasted"] = true
		sim.fire(&"explosion", {"pos": e.pos, "radius": 92.0})
		if not hurt_player:
			for o in sim.enemies:
				if o != e and o.targetable() and o.pos.distance_to(e.pos) < 92.0 + o.radius:
					var h := HitInfo.make(AIDepth1.dmg(e) * 2.5, "other", 0.7, o.pos - e.pos, e.pos)
					h.tag = "chain_blast"
					Combat.deal(sim, o, h)
			sim.fire(&"synergy", {"pos": e.pos, "text": "CHAIN BLAST", "color": "ember"})

## SHIELDER: blocks frontal hits and turns slowly; swipes in a cone.
class ThornWarden extends Brain:
	func update(sim, e: SimEnemy, dt: float) -> void:
		var ang := AI.angle_to_player(sim, e)
		match e.st:
			0:
				e.cd -= dt
				AI.face(e, ang, 2.2, dt)
				if AI.dist(sim, e) > 90.0:
					AI.move_to(sim, e, sim.player.pos, e.move_speed(), dt)
				else:
					AI.stop(e, dt)
				if AI.dist(sim, e) < 130.0 and e.cd <= 0.0:
					e.set_state(1)
					e.tele = AI.tele_cone(sim, e, e.facing, 125.0, 100.0, AIDepth1.windup(e), AIDepth1.dmg(e), "Thorn Swipe", func(): e.set_state(2))
			1:
				AI.stop(e, dt, 20.0)
				if e.tele != null:
					e.tele.angle = e.facing
			2:
				if e.t > 0.55:
					e.set_state(0)
					e.cd = 1.2 * e.cd_mul
			_:
				e.set_state(0)

## SUMMONER: keeps its distance and births grubs.
class Grubmother extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.5
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 260.0, 380.0, dt)
		AI.face(e, AI.angle_to_player(sim, e), 4.0, dt)
		if e.tele != null:
			return
		e.cd -= dt
		var grubs := 0
		for o in sim.enemies:
			if o.alive and o.kind == "grub":
				grubs += 1
		if e.cd <= 0.0 and grubs < 6:
			e.cd = 3.5 * e.cd_mul
			e.tele = AI.tele_circle(sim, e, e.pos, 50.0, AIDepth1.windup(e), 0.0, "Brood", func():
				for i in 3:
					Enemies.spawn(sim, "grub", e.pos + Geom.dir(TAU * i / 3.0) * 34.0, e.depth, {"summoned": true}))
			e.tele.follow = true
