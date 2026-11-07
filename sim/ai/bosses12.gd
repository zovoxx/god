class_name AIBosses12
extends RefCounted
## Guardians and bosses of depths 1–2.

static func brains() -> Dictionary:
	return {
		"mini_thornback": Thornback.new(), "mini_bloom": BloomMother.new(),
		"mini_librarian": Librarian.new(), "mini_deepmaw": Deepmaw.new(),
		"boss_stag": Ashenhart.new(), "boss_archivist": Velloran.new(), "archivist_copy": VelloranCopy.new(),
	}

# ═══════════════════════ GUARDIANS — DEPTH 1 ═══════════════════════

class Thornback extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "charges", "name": "Triple Charge", "w": 1.2, "cd": 4.0},
			{"id": "burst", "name": "Thorn Burst", "w": 1.0, "cd": 3.0},
			{"id": "stomp", "name": "Stomp", "w": 1.0, "cd": 2.5, "range": [0.0, 220.0]},
		]
		idle = 0.9
	func atk_charges(sim, e: SimEnemy, dt: float, t: float) -> bool:
		var n: int = e.data.get("n", 0)
		if once(e, "c%d" % n):
			charge_start(sim, e, 0.7 if e.phase == 0 else 0.55, 2.0, "Thorn Charge")
		if charge_tick(sim, e, dt, 700.0 + 60.0 * n):
			e.data["n"] = n + 1
			if n + 1 >= 3:
				e.data["n"] = 0
				return true
		return false
	func atk_burst(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_ring(sim, e, e.pos, e.radius, 160.0, 0.6, 0.0, "Thorn Burst")
		if at(e, t, 0.6, "f1"):
			AI.ring_burst(sim, e, e.pos, 16, 330.0, dmg(e, 0.8), "Thorn Burst", sim.rng.randf() * TAU)
		if e.phase > 0 and at(e, t, 1.0, "f2"):
			AI.ring_burst(sim, e, e.pos, 16, 300.0, dmg(e, 0.8), "Thorn Burst", PI / 16.0)
		return t > 1.3
	func atk_stomp(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "s"):
			e.tele = AI.tele_circle(sim, e, e.pos, 150.0, 0.75, dmg(e, 1.2), "Stomp")
		return t > 1.2

class BloomMother extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "volley", "name": "Seed Volley", "w": 1.2, "cd": 2.5},
			{"id": "vine", "name": "Vine Sweep", "w": 1.0, "cd": 3.0, "range": [0.0, 300.0]},
			{"id": "pods", "name": "Kindle Pods", "w": 0.7, "cd": 7.0},
			{"id": "petals", "name": "Petal Storm", "w": 1.0, "cd": 5.0, "min_phase": 1},
		]
	func move(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 200.0, 340.0, dt, 0.6)
		AI.face(e, AI.angle_to_player(sim, e), 3.0, dt)
	func atk_volley(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var n := 5 if e.phase == 0 else 7
		for i in n:
			if at(e, t, i * 0.14, "v%d" % i):
				var off := Vector2(sim.rng.randf_range(-110, 110), sim.rng.randf_range(-110, 110)) if i > 0 else Vector2.ZERO
				AI.lob(sim, e, sim.player.pos + sim.player.vel * 0.4 + off, 0.95, 52.0, dmg(e), "Seed Volley")
		return t > n * 0.14 + 0.9
	func atk_vine(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "s"):
			e.tele = AI.tele_cone(sim, e, AI.angle_to_player(sim, e), 270.0, 200.0, 0.9, dmg(e, 1.2), "Vine Sweep")
		return t > 1.4
	func atk_pods(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 60.0, 0.6, 0.0, "Kindle Pods", func(): summon(sim, e, "kindlepod", 2 + e.phase))
		return t > 0.9
	func atk_petals(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_ring(sim, e, e.pos, e.radius, 120.0, 0.6, 0.0, "Petal Storm")
		if t > 0.6 and t < 2.6:
			e.data["acc"] = float(e.data.get("acc", 0.0)) + dt
			if float(e.data.acc) > 0.12:
				e.data["acc"] = 0.0
				for k in 3:
					AI.shoot(sim, e, e.pos, t * 2.2 + TAU * k / 3.0, 260.0, dmg(e, 0.7), "Petal Storm")
		return t > 2.8

# ═══════════════════════ GUARDIANS — DEPTH 2 ═══════════════════════

class Librarian extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "pages", "name": "Homing Pages", "w": 1.2, "cd": 3.0},
			{"id": "blink", "name": "Blink", "w": 0.8, "cd": 4.0},
			{"id": "snipe", "name": "Ink Snipe", "w": 1.0, "cd": 3.0},
			{"id": "shades", "name": "Summon Shades", "w": 0.8, "cd": 8.0, "min_phase": 1},
		]
	func move(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 260.0, 420.0, dt, 0.8)
		AI.face(e, AI.angle_to_player(sim, e), 5.0, dt)
	func atk_pages(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 70.0, 0.55, 0.0, "Homing Pages")
		if at(e, t, 0.55, "f"):
			for i in 3 + e.phase:
				var pr := AI.shoot(sim, e, e.pos, AI.angle_to_player(sim, e) + (i - 1.5) * 0.6, 240.0, dmg(e, 0.8), "Homing Page", 11.0, 4.5)
				pr.kind = SimProj.Kind.HOMING
				pr.data["turn"] = 1.4
				pr.art = "e_page"
		return t > 1.0
	func atk_blink(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			var to: Vector2 = sim.random_free_point(220.0, 300.0, sim.player.pos, e.radius)
			e.target_pos = to
			e.tele = AI.tele_circle(sim, e, to, 44.0, 0.5, 0.0, "Blink")
			e.tele.follow = false
		if at(e, t, 0.5, "go"):
			sim.fire(&"enemy_blink", {"id": e.id, "from": e.pos, "to": e.target_pos})
			e.pos = e.target_pos
			e.prev = e.pos
			e.tele = AI.tele_ring(sim, e, e.pos, e.radius, 130.0, 0.5, 0.0, "Ink Burst")
		if at(e, t, 1.0, "b"):
			AI.ring_burst(sim, e, e.pos, 12, 300.0, dmg(e, 0.8), "Ink Burst", sim.rng.randf() * TAU)
		return t > 1.3
	func atk_snipe(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.a = AI.angle_to_player(sim, e)
			e.tele = AI.tele_line(sim, e, e.a, sim.ray_to_wall(e.pos, e.a, 1000.0, 2.0), 26.0, 0.95, dmg(e, 1.4), "Ink Snipe")
		if e.tele != null and not e.tele.resolved and e.tele.time_left() > 0.3:
			e.a = AI.angle_to_player(sim, e)
			e.tele.angle = e.a
			e.tele.length = sim.ray_to_wall(e.pos, e.a, 1000.0, 2.0)
		return t > 1.3
	func atk_shades(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 60.0, 0.6, 0.0, "Summon Shades", func(): summon(sim, e, "inkshade", 2))
		return t > 0.9

class Deepmaw extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "erupt", "name": "Eruption Line", "w": 1.3, "cd": 3.0},
			{"id": "spit", "name": "Spit", "w": 1.0, "cd": 2.0},
			{"id": "pools", "name": "Ink Pools", "w": 0.8, "cd": 6.0},
		]
	func move(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 160.0, 300.0, dt, 0.7)
		AI.face(e, AI.angle_to_player(sim, e), 4.0, dt)
	func atk_erupt(sim, e: SimEnemy, dt: float, t: float) -> bool:
		if at(e, t, 0.0, "dive"):
			e.untargetable = true
			e.data["hidden"] = true
			e.vel = Vector2.ZERO
			var dirv: Vector2 = AI.to_player(sim, e).normalized()
			var n := 6 if e.phase == 0 else 8
			var last := e.pos
			for i in n:
				var p: Vector2 = e.pos + dirv * (80.0 + i * 75.0)
				if sim.point_blocked(p, 30.0):
					break
				last = p
				AI.tele_circle(sim, e, p, 58.0, 0.7 + i * 0.12, dmg(e), "Eruption")
			e.target_pos = last
		AI.stop(e, dt)
		if at(e, t, 1.5, "rise"):
			e.pos = e.target_pos
			e.prev = e.pos
			e.untargetable = false
			e.data["hidden"] = false
		return t > 2.2
	func atk_spit(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.a = AI.angle_to_player(sim, e)
			e.tele = AI.tele_aim(sim, e, e.a, 520.0, 18.0, 0.55, "Spit", func():
				for i in 3 + e.phase * 2:
					AI.shoot(sim, e, e.pos, e.a + (i - (1 + e.phase)) * 0.2, 460.0, dmg(e, 0.8), "Spit"))
		return t > 0.9
	func atk_pools(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "p"):
			for i in 3:
				var p: Vector2 = sim.player.pos + Vector2(sim.rng.randf_range(-140, 140), sim.rng.randf_range(-140, 140))
				var hz := Hazards.enemy_field(sim, e, p, 70.0, 0.8, 4.0, dmg(e, 0.6), "Ink Pool", "pool")
				hz.name = e.name
				hz.art = e.art
		return t > 0.8

# ═══════════════════════ BOSS 1 — ASHENHART, THE CINDER STAG ═══════════════════════

class Ashenhart extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "charge", "name": "Cinder Charge", "w": 1.3, "cd": 3.5},
			{"id": "sweep", "name": "Antler Sweep", "w": 1.0, "cd": 2.5, "range": [0.0, 260.0]},
			{"id": "firefall", "name": "Firefall", "w": 1.0, "cd": 4.0},
			{"id": "ring", "name": "Flame Ring", "w": 0.9, "cd": 5.0},
			{"id": "brood", "name": "Kindle Brood", "w": 0.6, "cd": 9.0},
			{"id": "spiral", "name": "Ember Spiral", "w": 1.0, "cd": 6.0, "min_phase": 1},
		]
		phase_text = ["", "THE ANTLERS IGNITE"]
	func move(sim, e: SimEnemy, dt: float) -> void:
		var d := AI.dist(sim, e)
		if d > 260.0:
			AI.chase(sim, e, dt, 0.9)
		else:
			AI.kite(sim, e, 180.0, 280.0, dt, 0.7)
		AI.face(e, AI.angle_to_player(sim, e), 4.0, dt)
	func on_phase(sim, e: SimEnemy, phase: int) -> void:
		e.speed_mul *= 1.25
	func atk_charge(sim, e: SimEnemy, dt: float, t: float) -> bool:
		var n: int = e.data.get("n", 0)
		if once(e, "c%d" % n):
			charge_start(sim, e, 0.9 if e.phase == 0 else 0.7, 2.2, "Cinder Charge")
		if charge_tick(sim, e, dt, 760.0):
			if e.phase > 0 and n == 0:
				e.data["n"] = 1
				return false
			e.data["n"] = 0
			return true
		return false
	func atk_sweep(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "a"):
			e.tele = AI.tele_cone(sim, e, AI.angle_to_player(sim, e), 210.0, 170.0, 0.75, dmg(e, 1.2), "Antler Sweep")
		if e.phase > 0 and at(e, t, 0.95, "b"):
			e.tele = AI.tele_cone(sim, e, AI.angle_to_player(sim, e) + PI * 0.15, 240.0, 170.0, 0.6, dmg(e, 1.2), "Antler Sweep")
		return t > (1.2 if e.phase == 0 else 1.8)
	func atk_firefall(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt, 4.0)
		var n := 6 if e.phase == 0 else 10
		for i in n:
			if at(e, t, i * 0.1, "f%d" % i):
				var off := Vector2.ZERO if i == 0 else Vector2(sim.rng.randf_range(-170, 170), sim.rng.randf_range(-170, 170))
				var p: Vector2 = sim.player.pos + off
				var pos2 := p
				AI.tele_circle(sim, e, p, 70.0, 0.9 + i * 0.05, dmg(e), "Firefall", func():
					if e.phase > 0:
						var hz := Hazards.enemy_field(sim, e, pos2, 55.0, 0.6, 3.0, dmg(e, 0.4), "Burning Ground", "fire")
						hz.name = e.name
						hz.art = e.art)
		return t > n * 0.1 + 1.1
	func atk_ring(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "a"):
			AI.tele_ring(sim, e, e.pos, 90.0, 220.0, 1.0, dmg(e, 1.1), "Flame Ring").follow = false
		if at(e, t, 0.6, "b"):
			AI.tele_ring(sim, e, e.pos, 240.0, 380.0 if e.phase > 0 else 340.0, 1.0, dmg(e, 1.1), "Flame Ring").follow = false
		return t > 1.9
	func atk_brood(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 80.0, 0.6, 0.0, "Kindle Brood", func():
				summon(sim, e, "cinderling", 3 + e.phase)
				if e.phase > 0:
					summon(sim, e, "ashwisp", 2))
		return t > 1.0
	func atk_spiral(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_ring(sim, e, e.pos, e.radius, 140.0, 0.6, 0.0, "Ember Spiral")
		if t > 0.6 and t < 3.0:
			e.data["acc"] = float(e.data.get("acc", 0.0)) + dt
			if float(e.data.acc) >= 0.1:
				e.data["acc"] = 0.0
				for k in 4:
					AI.shoot(sim, e, e.pos, t * 1.8 + TAU * k / 4.0, 280.0, dmg(e, 0.7), "Ember Spiral")
		return t > 3.2

# ═══════════════════════ BOSS 2 — VELLORAN, THE DROWNED ARCHIVIST ═══════════════════════

class Velloran extends BossBrain:
	func _init() -> void:
		attacks = [
			{"id": "quills", "name": "Quill Storm", "w": 1.2, "cd": 2.5},
			{"id": "pages", "name": "Seeking Pages", "w": 1.0, "cd": 4.0},
			{"id": "tide", "name": "Drowning Tide", "w": 0.9, "cd": 6.0},
			{"id": "snipe", "name": "Ink Snipe", "w": 1.0, "cd": 3.0},
			{"id": "blink", "name": "Blink", "w": 0.8, "cd": 4.5},
			{"id": "copies", "name": "Mirror Copies", "w": 1.0, "cd": 10.0, "min_phase": 1},
		]
		phase_text = ["", "THE ARCHIVE FLOODS"]
	func move(sim, e: SimEnemy, dt: float) -> void:
		AI.kite(sim, e, 260.0, 420.0, dt, 0.9)
		AI.face(e, AI.angle_to_player(sim, e), 5.0, dt)
	func atk_quills(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var volleys := 2 if e.phase == 0 else 3
		for v in volleys:
			if at(e, t, v * 0.75, "w%d" % v):
				var ang := AI.angle_to_player(sim, e) + (0.12 if v % 2 == 1 else 0.0)
				e.tele = AI.tele_aim(sim, e, ang, 520.0, 60.0, 0.55, "Quill Storm", func():
					for i in 7:
						AI.shoot(sim, e, e.pos, ang + (i - 3) * 0.16, 520.0, dmg(e, 0.8), "Quill Storm"))
		return t > volleys * 0.75 + 0.6
	func atk_pages(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 80.0, 0.6, 0.0, "Seeking Pages")
		if at(e, t, 0.6, "f"):
			for i in 4 + e.phase * 2:
				var pr := AI.shoot(sim, e, e.pos, TAU * i / (4.0 + e.phase * 2), 250.0, dmg(e, 0.8), "Seeking Page", 11.0, 5.0)
				pr.kind = SimProj.Kind.HOMING
				pr.data["turn"] = 1.3
				pr.art = "e_page"
		return t > 1.0
	func atk_tide(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		var rect: Rect2 = sim.arena.rect
		if at(e, t, 0.0, "a"):
			# a wall of water across the arena, through the player's position
			var vertical = sim.rng.randf() < 0.5
			var tt: Tele
			if vertical:
				tt = Tele.make(sim, e, Tele.Shape.LINE, 1.2, dmg(e, 1.3), "Drowning Tide")
				tt.pos = Vector2(sim.player.pos.x, rect.position.y)
				tt.angle = PI * 0.5
				tt.length = rect.size.y
			else:
				tt = Tele.make(sim, e, Tele.Shape.LINE, 1.2, dmg(e, 1.3), "Drowning Tide")
				tt.pos = Vector2(rect.position.x, sim.player.pos.y)
				tt.angle = 0.0
				tt.length = rect.size.x
			tt.width = 130.0
			e.data["vert"] = vertical
		if e.phase > 0 and at(e, t, 0.7, "b"):
			var tt2 := Tele.make(sim, e, Tele.Shape.LINE, 1.1, dmg(e, 1.3), "Drowning Tide")
			if e.data.get("vert", false):
				tt2.pos = Vector2(rect.position.x, sim.player.pos.y)
				tt2.angle = 0.0
				tt2.length = rect.size.x
			else:
				tt2.pos = Vector2(sim.player.pos.x, rect.position.y)
				tt2.angle = PI * 0.5
				tt2.length = rect.size.y
			tt2.width = 130.0
		return t > (1.6 if e.phase == 0 else 2.2)
	func atk_snipe(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.a = AI.angle_to_player(sim, e)
			e.tele = AI.tele_line(sim, e, e.a, sim.ray_to_wall(e.pos, e.a, 1100.0, 2.0), 28.0, 1.0, dmg(e, 1.4), "Ink Snipe")
		if e.tele != null and not e.tele.resolved and e.tele.time_left() > 0.3:
			e.a = AI.angle_to_player(sim, e)
			e.tele.angle = e.a
			e.tele.length = sim.ray_to_wall(e.pos, e.a, 1100.0, 2.0)
		return t > 1.4
	func atk_blink(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.target_pos = sim.random_free_point(260.0, 360.0, sim.player.pos, e.radius)
			var tt := AI.tele_circle(sim, e, e.target_pos, 50.0, 0.5, 0.0, "Blink")
			tt.follow = false
		if at(e, t, 0.5, "go"):
			sim.fire(&"enemy_blink", {"id": e.id, "from": e.pos, "to": e.target_pos})
			e.pos = e.target_pos
			e.prev = e.pos
			e.tele = AI.tele_ring(sim, e, e.pos, e.radius, 150.0, 0.5, 0.0, "Page Burst")
		if at(e, t, 1.0, "burst"):
			AI.ring_burst(sim, e, e.pos, 14, 300.0, dmg(e, 0.8), "Page Burst", sim.rng.randf() * TAU)
		return t > 1.3
	func atk_copies(sim, e: SimEnemy, dt: float, t: float) -> bool:
		AI.stop(e, dt)
		if at(e, t, 0.0, "w"):
			e.tele = AI.tele_circle(sim, e, e.pos, 90.0, 0.6, 0.0, "Mirror Copies", func():
				for i in 2:
					var p: Vector2 = sim.random_free_point(240.0, 340.0, sim.player.pos, 30.0)
					var c := Enemies.spawn(sim, "archivist_copy", p, e.depth, {"summoned": true}))
		return t > 1.0

## a fading duplicate that casts two quill fans, then dissolves
class VelloranCopy extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 0.4
	func update(sim, e: SimEnemy, dt: float) -> void:
		AI.face(e, AI.angle_to_player(sim, e), 5.0, dt)
		AI.kite(sim, e, 240.0, 380.0, dt, 0.6)
		if e.tele != null:
			return
		e.cd -= dt
		var casts: int = e.data.get("casts", 0)
		if casts >= 2 and e.cd <= 0.0:
			e.hp = 0.0
			Enemies.kill(sim, e)
			sim.fire(&"enemy_killed", {"id": e.id, "kind": e.kind, "pos": e.pos, "dir": Vector2.UP, "power": 0.2, "boss": false, "guardian": false, "elite": false, "radius": e.radius, "blood": e.def.blood, "art": e.art, "finisher": false, "streak": sim.streak_tier, "self": true})
			if sim.flow != null:
				sim.flow.on_enemy_killed(e)
			return
		if e.cd <= 0.0:
			var ang := AI.angle_to_player(sim, e)
			e.tele = AI.tele_aim(sim, e, ang, 480.0, 50.0, 0.6, "Mirror Quills", func():
				for i in 5:
					AI.shoot(sim, e, e.pos, ang + (i - 2) * 0.18, 460.0, float(e.def.dmg) * e.dmg_mul, "Mirror Quills"))
			e.data["casts"] = casts + 1
			e.cd = 1.4
