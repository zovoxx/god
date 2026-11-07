class_name AIBosses34
extends RefCounted
## Guardians and bosses of depths 3–4.

static func brains() -> Dictionary:
	return {
		"mini_riveter": Riveter.new(), "mini_foreman": Foreman.new(),
		"mini_eclipse": EclipsedKnight.new(), "mini_matron": VoidMatron.new(),
		"boss_engine": EngineTyrant.new(), "boss_regent": PaleRegent.new(), "regent_mirror": RegentMirror.new(),
	}

## a rotating beam check shared by lasers
static func beam_hits(sim, from: Vector2, ang: float, length: float, width: float) -> bool:
	var end: Vector2 = from + Geom.dir(ang) * length
	return Geom.seg_dist(sim.player.pos, from, end) < width * 0.5 + sim.player.hit_radius

# ═══════════════════════ GUARDIANS — DEPTH 3 ═══════════════════════

## Twin guardians bound by a live fence. Kill both.
class Riveter extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "volley", "name": "Rivet Volley", "w": 1.2, "cd": 2.0},
			{"id": "charge", "name": "Rivet Charge", "w": 1.0, "cd": 3.0},
			{"id": "slam", "name": "Pound", "w": 0.8, "cd": 2.5, "range": [0.0, 200.0]},
		]
	func init(sim, e: SimEnemy) -> void:
		super.init(sim, e)
		e.data["fence"] = "off"
		e.data["fence_t"] = 2.5
		for o in sim.enemies:
			if o != e and o.alive and o.kind == "mini_riveter" and o.data.get("twin") == null:
				o.data["twin"] = e
				e.data["twin"] = o
				o.data["leader"] = true
				return
	func move(sim, e: SimEnemy, dt: float) -> void:
		super.move(sim, e, dt)
		var twin = e.data.get("twin")
		if not e.data.get("leader", false) or twin == null or not twin.alive:
			e.data["fence"] = "off"
			return
		e.data["fence_t"] = float(e.data.fence_t) - dt
		match String(e.data.fence):
			"off":
				if float(e.data.fence_t) <= 0.0:
					e.data["fence"] = "warn"
					e.data["fence_t"] = 0.7
					sim.fire(&"boss_callout", {"id": e.id, "text": "LIVE FENCE", "boss": false})
			"warn":
				if float(e.data.fence_t) <= 0.0:
					e.data["fence"] = "on"
					e.data["fence_t"] = 2.6
			"on":
				if Geom.seg_dist(sim.player.pos, e.pos, twin.pos) < 12.0 + sim.player.hit_radius:
					Combat.hurt_player(sim, dmg(e), sim.player.pos + (twin.pos - e.pos).orthogonal().normalized() * 10.0, e, "Live Fence")
				if float(e.data.fence_t) <= 0.0:
					e.data["fence"] = "off"
					e.data["fence_t"] = 2.0 if e.phase == 0 else 1.2
	func atk_volley(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.a = AI.angle_to_player(sim, e)
			e.tele = AI.tele_aim(sim, e, e.a, 520.0, 30.0, 0.55, "Rivet Volley", func():
				for i in 3 + e.phase * 2:
					AI.shoot(sim, e, e.pos, e.a + (i - (1 + e.phase)) * 0.16, 500.0, dmg(e, 0.8), "Rivet Volley"))
		return t > 0.9
	func atk_charge(sim, e: SimEnemy, dt: float, t: float) -> bool:
		if once(e, "c"):
			charge_start(sim, e, 0.75, 2.0, "Rivet Charge")
		return charge_tick(sim, e, dt, 720.0)
	func atk_slam(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "s"):
			e.tele = AI.tele_circle(sim, e, e.pos, 130.0, 0.7, dmg(e, 1.2), "Pound")
		return t > 1.1

class Foreman extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "hammer", "name": "Hammer", "w": 1.2, "cd": 2.0, "range": [0.0, 220.0]},
			{"id": "rockets", "name": "Rocket Barrage", "w": 1.0, "cd": 3.5},
			{"id": "charge", "name": "Steam Charge", "w": 0.9, "cd": 3.5},
			{"id": "shellburst", "name": "Shellburst", "w": 1.0, "cd": 4.0, "min_phase": 1},
		]
	func atk_hammer(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "s"):
			var c: Vector2 = e.pos + Geom.dir(AI.angle_to_player(sim, e)) * 90.0
			e.tele = AI.tele_circle(sim, e, c, 120.0, 0.8, dmg(e, 1.3), "Hammer")
			e.tele.follow = false
		return t > 1.3
	func atk_rockets(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		for i in 6:
			if at(e, t, i * 0.12, "r%d" % i):
				var off := Vector2.ZERO if i == 0 else Vector2(sim.rng.randf_range(-160, 160), sim.rng.randf_range(-160, 160))
				AI.lob(sim, e, sim.player.pos + off, 1.0, 64.0, dmg(e), "Rocket")
		return t > 1.8
	func atk_charge(sim, e: SimEnemy, dt: float, t: float) -> bool:
		if once(e, "c"):
			charge_start(sim, e, 0.8, 2.0, "Steam Charge")
		return charge_tick(sim, e, dt, 640.0)
	func atk_shellburst(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_ring(sim, e, e.pos, e.radius, 160.0, 0.6, 0.0, "Shellburst")
		if at(e, t, 0.6, "a"):
			AI.ring_burst(sim, e, e.pos, 20, 300.0, dmg(e, 0.8), "Shellburst", 0.0)
		if at(e, t, 1.0, "b"):
			AI.ring_burst(sim, e, e.pos, 20, 300.0, dmg(e, 0.8), "Shellburst", PI / 20.0)
		return t > 1.3

# ═══════════════════════ GUARDIANS — DEPTH 4 ═══════════════════════

class EclipsedKnight extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "guard", "name": "Eclipse Guard", "w": 0.9, "cd": 4.0},
			{"id": "slash", "name": "Star Slash", "w": 1.3, "cd": 2.0, "range": [0.0, 260.0]},
			{"id": "dash", "name": "Eclipse Dash", "w": 1.0, "cd": 3.0},
			{"id": "waves", "name": "Crescent Waves", "w": 1.0, "cd": 3.5, "min_phase": 1},
		]
	func atk_guard(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		AI.face(e, AI.angle_to_player(sim, e), 6.0, dt)
		e.data["guard"] = t < 1.4
		e.glow = 1.0 if t < 1.4 else 0.0
		return t > 1.5
	func on_hit(sim, e: SimEnemy, h: HitInfo) -> bool:
		if e.data.get("guard", false) and not h.is_dot and h.slot in ["attack", "dash", "special"]:
			sim.fire(&"reflected", {"id": e.id, "pos": e.pos})
			if sim.player.pos.distance_to(e.pos) < 280.0:
				Combat.hurt_player(sim, dmg(e, 0.6), e.pos, e, "Eclipse Riposte")
			return true
		return false
	func atk_slash(sim, e: SimEnemy, dt: float, t: float) -> bool:
		var n := 3 if e.phase == 0 else 4
		for i in n:
			if at(e, t, i * 0.5, "s%d" % i):
				var ang := AI.angle_to_player(sim, e)
				e.vel = Geom.dir(ang) * 160.0
				AI.tele_cone(sim, e, ang, 150.0, 120.0, 0.5 if i == 0 else 0.4, dmg(e), "Star Slash")
		AI.stop(e, dt, 5.0)
		return t > n * 0.5 + 0.5
	func atk_dash(sim, e: SimEnemy, dt: float, t: float) -> bool:
		if once(e, "c"):
			charge_start(sim, e, 0.6, 2.0, "Eclipse Dash")
		return charge_tick(sim, e, dt, 900.0)
	func atk_waves(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		for v in 2:
			if at(e, t, v * 0.7, "w%d" % v):
				var ang := AI.angle_to_player(sim, e)
				e.tele = AI.tele_aim(sim, e, ang, 520.0, 70.0, 0.5, "Crescent Waves", func():
					for i in 5:
						AI.shoot(sim, e, e.pos, ang + (i - 2) * 0.22, 430.0, dmg(e, 0.9), "Crescent Wave", 13.0))
		return t > 1.8

class VoidMatron extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "wells", "name": "Gravity Wells", "w": 1.1, "cd": 4.0},
			{"id": "imps", "name": "Imp Swarm", "w": 0.8, "cd": 7.0},
			{"id": "rings", "name": "Void Rings", "w": 1.2, "cd": 2.5},
			{"id": "collapse", "name": "Collapse", "w": 1.0, "cd": 4.0, "min_phase": 1},
		]
	func move(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 240.0, 380.0, dt, 0.8)
		var wells: Array = e.data.get("wells", [])
		var keep: Array = []
		for w in wells:
			w.t = float(w.t) - dt
			var to: Vector2 = w.pos - sim.player.pos
			if to.length() < 240.0 and sim.player.state != SimPlayer.St.DASH:
				sim.player.kvel += to.normalized() * 1300.0 * dt
			if to.length() < 40.0:
				Combat.hurt_player(sim, dmg(e), w.pos, e, "Void Well")
			if float(w.t) > 0.0:
				keep.append(w)
		e.data["wells"] = keep
	func atk_wells(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			for i in 2:
				var p: Vector2 = sim.player.pos + Geom.dir(sim.rng.randf() * TAU) * 160.0 * i
				var pos := p
				var tt := AI.tele_ring(sim, e, p, 40.0, 240.0, 0.8, 0.0, "Gravity Well", func():
					var w: Array = e.data.get("wells", [])
					w.append({"pos": pos, "t": 2.4})
					e.data["wells"] = w)
				tt.follow = false
		return t > 1.0
	func atk_imps(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 70.0, 0.6, 0.0, "Imp Swarm", func(): summon(sim, e, "voidimp", 4))
		return t > 0.9
	func atk_rings(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		for i in 3:
			if at(e, t, i * 0.7, "r%d" % i):
				var gap = sim.rng.randi_range(0, 17)
				var off = sim.rng.randf() * TAU
				AI.tele_ring(sim, e, e.pos, e.radius, 120.0, 0.5, 0.0, "Void Rings", func():
					AI.ring_burst(sim, e, e.pos, 18, 250.0, dmg(e, 0.8), "Void Ring", off, gap))
		return t > 2.4
	func atk_collapse(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "c"):
			var tt := AI.tele_circle(sim, e, sim.player.pos, 170.0, 1.0, dmg(e, 1.4), "Collapse")
			tt.follow = false
		return t > 1.4

# ═══════════════════════ BOSS 3 — THE ENGINE TYRANT ═══════════════════════

class EngineTyrant extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "lasers", "name": "Sweeping Lasers", "w": 1.2, "cd": 5.0},
			{"id": "mortars", "name": "Furnace Mortars", "w": 1.0, "cd": 3.0},
			{"id": "saws", "name": "Saw Launch", "w": 1.0, "cd": 5.0},
			{"id": "pistons", "name": "Piston Wall", "w": 1.0, "cd": 4.0},
			{"id": "hounds", "name": "Release the Hounds", "w": 0.6, "cd": 10.0},
			{"id": "vents", "name": "Steam Vents", "w": 0.9, "cd": 5.0},
			{"id": "meltdown", "name": "Meltdown", "w": 1.0, "cd": 7.0, "min_phase": 1},
		]
		phase_text = ["", "OVERHEAT"]
		idle = 0.7
	func move(sim, e: SimEnemy, dt: float) -> void:
		var home: Vector2 = Vector2(sim.player.pos.x * 0.3, sim.arena.rect.position.y + 200.0)
		AI.move_to(sim, e, home, e.move_speed(), dt, 2.0)
		e.facing = AI.angle_to_player(sim, e)
	func atk_lasers(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var n := 2 if e.phase == 0 else 4
		if at(e, t, 0.0, "w"):
			e.data["la0"] = AI.angle_to_player(sim, e) + PI * 0.5
			e.data["lspin"] = 0.6 if sim.rng.randf() < 0.5 else -0.6
			for i in n:
				AI.tele_aim(sim, e, float(e.data.la0) + TAU * i / n, 900.0, 26.0, 0.9, "Sweeping Lasers", Callable())
		if t > 0.9 and t < 3.6:
			var a0: float = float(e.data.la0) + float(e.data.lspin) * (t - 0.9)
			e.data["lasers"] = []
			for i in n:
				var ang := a0 + TAU * i / n
				e.data.lasers.append(ang)
				if AIBosses34.beam_hits(sim, e.pos, ang, 900.0, 26.0):
					Combat.hurt_player(sim, dmg(e), e.pos, e, "Sweeping Lasers")
		if t >= 3.6:
			e.data.erase("lasers")
			return true
		return false
	func atk_mortars(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var n := 8 if e.phase == 0 else 12
		for i in n:
			if at(e, t, i * 0.09, "m%d" % i):
				var off := Vector2.ZERO if i == 0 else Vector2(sim.rng.randf_range(-220, 220), sim.rng.randf_range(-180, 180))
				AI.lob(sim, e, sim.player.pos + off, 1.0, 62.0, dmg(e), "Furnace Mortar")
		return t > n * 0.09 + 1.1
	func atk_saws(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			var base := AI.angle_to_player(sim, e)
			var n := 2 + e.phase
			for i in n:
				var ang := base + (i - (n - 1) * 0.5) * 0.5
				AI.tele_aim(sim, e, ang, 600.0, 44.0, 0.7, "Saw Launch", func():
					var pr := AI.shoot(sim, e, e.pos, ang, 380.0, dmg(e), "Sawblade", 22.0, 5.0)
					pr.data["bounce"] = true
					pr.art = "e_saw")
		return t > 1.0
	func atk_pistons(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var r: Rect2 = sim.arena.rect
		if at(e, t, 0.0, "p"):
			var ys: Array = [sim.player.pos.y, sim.player.pos.y - 150.0, sim.player.pos.y + 150.0]
			for i in ys.size():
				var y: float = clampf(ys[i], r.position.y + 40.0, r.end.y - 40.0)
				var from_left := (i % 2 == 0)
				var tt := Tele.make(sim, e, Tele.Shape.LINE, 0.9 + i * 0.25, dmg(e, 1.2), "Piston Wall")
				tt.pos = Vector2(r.position.x if from_left else r.end.x, y)
				tt.angle = 0.0 if from_left else PI
				tt.length = r.size.x * (0.75 if e.phase == 0 else 1.0)
				tt.width = 70.0
		return t > 1.8
	func atk_hounds(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 90.0, 0.6, 0.0, "Release the Hounds", func(): summon(sim, e, "rivethound", 3))
		return t > 1.0
	func atk_meltdown(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "a"):
			AI.tele_ring(sim, e, e.pos, 80.0, 260.0, 0.9, dmg(e, 1.2), "Meltdown").follow = false
		if at(e, t, 0.7, "b"):
			AI.tele_ring(sim, e, e.pos, 280.0, 460.0, 0.9, dmg(e, 1.2), "Meltdown").follow = false
		if at(e, t, 1.6, "c"):
			AI.ring_burst(sim, e, e.pos, 24, 280.0, dmg(e, 0.7), "Meltdown", 0.0, sim.rng.randi_range(0, 23))
		return t > 2.0

	func atk_vents(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "v"):
			var n := 6 if e.phase == 0 else 10
			for i in n:
				var p: Vector2 = sim.player.pos + Vector2(sim.rng.randf_range(-260, 260), sim.rng.randf_range(-200, 200)) if i > 0 else sim.player.pos
				var hz := Hazards.enemy_field(sim, e, p, 56.0, 0.8, 1.2, dmg(e, 0.8), "Steam Vent", "vent")
				hz.name = e.name
				hz.art = e.art
				hz.tick = 0.5
		return t > 1.4

# ═══════════════════════ BOSS 4 — THE PALE REGENT ═══════════════════════

class PaleRegent extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "crescents", "name": "Crescent Volley", "w": 1.2, "cd": 2.5},
			{"id": "starfall", "name": "Starfall", "w": 1.0, "cd": 4.0},
			{"id": "gravity", "name": "Gravity", "w": 0.9, "cd": 6.0},
			{"id": "mirror", "name": "Mirror Dash", "w": 1.0, "cd": 4.0},
			{"id": "time", "name": "Time Sigil", "w": 0.9, "cd": 6.0},
			{"id": "knights", "name": "Summon Knights", "w": 0.6, "cd": 12.0},
			{"id": "spiral", "name": "Eclipse Spiral", "w": 1.0, "cd": 6.0, "min_phase": 1},
		]
		phase_text = ["", "THE CROWN SHATTERS"]
	func move(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 260.0, 400.0, dt, 0.9)
		e.facing = AI.angle_to_player(sim, e)
		if e.data.has("grav_t"):
			e.data["grav_t"] = float(e.data.grav_t) - dt
			var c: Vector2 = e.data.grav_c
			if sim.player.state != SimPlayer.St.DASH:
				sim.player.kvel += (c - sim.player.pos).normalized() * 900.0 * dt
			if float(e.data.grav_t) <= 0.0:
				e.data.erase("grav_t")
	func on_phase(sim, e: SimEnemy, phase: int) -> void:
		e.speed_mul *= 1.2
	func atk_crescents(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var n := 3
		for v in n:
			if at(e, t, v * 0.6, "w%d" % v):
				var ang := AI.angle_to_player(sim, e)
				AI.tele_aim(sim, e, ang, 560.0, 70.0, 0.5, "Crescent Volley", func():
					for i in 5 + e.phase * 2:
						AI.shoot(sim, e, e.pos, ang + (i - (2 + e.phase)) * 0.19, 470.0, dmg(e, 0.8), "Crescent", 12.0))
		return t > n * 0.6 + 0.7
	func atk_starfall(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var n := 10 if e.phase == 0 else 16
		for i in n:
			if at(e, t, i * 0.08, "s%d" % i):
				var off := Vector2.ZERO if i == 0 else Vector2(sim.rng.randf_range(-260, 260), sim.rng.randf_range(-200, 200))
				AI.tele_circle(sim, e, sim.player.pos + off, 64.0, 1.0, dmg(e), "Starfall").follow = false
		return t > n * 0.08 + 1.1
	func atk_gravity(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var c: Vector2 = sim.arena.rect.get_center()
		if at(e, t, 0.0, "w"):
			AI.tele_ring(sim, e, c, 60.0, 360.0, 0.9, 0.0, "Gravity").follow = false
		if at(e, t, 0.9, "g"):
			e.data["grav_t"] = 3.0
			e.data["grav_c"] = c
			AI.tele_circle(sim, e, c, 60.0, 3.0, dmg(e, 1.5), "Gravity Core").follow = false
		if t > 1.2 and t < 3.6:
			e.data["acc"] = float(e.data.get("acc", 0.0)) + dt
			if float(e.data.acc) > 0.6:
				e.data["acc"] = 0.0
				AI.ring_burst(sim, e, c, 12, 200.0, dmg(e, 0.7), "Gravity", t, sim.rng.randi_range(0, 11))
		return t > 3.9
	func atk_mirror(sim, e: SimEnemy, dt: float, t: float) -> bool:
		if once(e, "a"):
			if e.phase > 0:
				for i in 2:
					var p: Vector2 = sim.random_free_point(240.0, 320.0, sim.player.pos, 30.0)
					Enemies.spawn(sim, "regent_mirror", p, e.depth, {"summoned": true})
		var n: int = e.data.get("n", 0)
		if once(e, "c%d" % n):
			charge_start(sim, e, 0.6, 2.0, "Mirror Dash")
		if charge_tick(sim, e, dt, 980.0):
			e.data["n"] = n + 1
			if n + 1 >= 3:
				e.data["n"] = 0
				return true
		return false
	func atk_time(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			var tt := AI.tele_circle(sim, e, sim.player.pos, 170.0, 1.1, dmg(e, 0.6), "Time Sigil", func():
				var tl: Tele = e.data.get("time_tele")
				if tl != null and tl.contains(sim.player.pos, sim.player.hit_radius) and not sim.player.is_invuln():
					sim.player.slow_t = 2.5
					sim.player.slow_mul = 0.5
					sim.fire(&"time_slow", {"pos": sim.player.pos}))
			tt.follow = false
			e.data["time_tele"] = tt
		return t > 1.5
	func atk_knights(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 80.0, 0.6, 0.0, "Summon Knights", func(): summon(sim, e, "mirrorknight", 2))
		return t > 1.0
	func atk_spiral(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_ring(sim, e, e.pos, e.radius, 150.0, 0.6, 0.0, "Eclipse Spiral")
		if t > 0.6 and t < 3.4:
			e.data["acc"] = float(e.data.get("acc", 0.0)) + dt
			if float(e.data.acc) >= 0.09:
				e.data["acc"] = 0.0
				for k in 5:
					AI.shoot(sim, e, e.pos, t * -1.6 + TAU * k / 5.0, 270.0, dmg(e, 0.7), "Eclipse Spiral")
		return t > 3.6

## a reflection that dashes once at you and fades
class RegentMirror extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 0.3
	func update(sim, e: SimEnemy, dt: float) -> void:
		match e.st:
			0:
				e.cd -= dt
				AI.stop(e, dt)
				if e.cd <= 0.0:
					e.set_state(1)
					e.a = AI.angle_to_player(sim, e)
					e.tele = AI.tele_line(sim, e, e.a, sim.ray_to_wall(e.pos, e.a, 900.0, e.radius) + e.radius, e.radius * 2.0, 0.7, 0.0, "Mirror Dash", func():
						e.set_state(2)
						e.contact = float(e.def.dmg)
						e.contact_on = true
						e.attack_name = "Mirror Dash")
			1:
				e.vel = Vector2.ZERO
			2:
				e.vel = Geom.dir(e.a) * 900.0
				if e.t > 0.9 or sim.point_blocked(e.pos + Geom.dir(e.a) * (e.radius + 8.0), e.radius):
					e.hp = 0.0
					Enemies.kill(sim, e)
					sim.fire(&"enemy_killed", {"id": e.id, "kind": e.kind, "pos": e.pos, "dir": Vector2.UP, "power": 0.2, "boss": false, "guardian": false, "elite": false, "radius": e.radius, "blood": e.def.blood, "art": e.art, "finisher": false, "streak": sim.streak_tier, "self": true})
					if sim.flow != null:
						sim.flow.on_enemy_killed(e)
