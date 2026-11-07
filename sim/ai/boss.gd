class_name BossBrain
extends Brain
## Pattern brain for guardians and bosses: weighted attacks gated by phase, range and
## cooldown. Each attack shows its name as a callout. At HP thresholds the boss roars
## (short invulnerable transition that clears its bullets and telegraphs) and changes.
## Attacks are methods `atk_<id>(sim, e, dt, t) -> bool` returning true when finished.

var attacks: Array = []        # {id, name, w, cd, min_phase, max_phase, range}
var idle := 0.8
var roar_time := 1.3
var phase_text := ["", "ENRAGED"]

func init(sim, e: SimEnemy) -> void:
	e.data["cds"] = {}
	e.cd = 1.2
	e.phase = 0

func move(sim, e: SimEnemy, dt: float) -> void:
	AI.kite(sim, e, 180.0, 320.0, dt, 0.8)
	AI.face(e, AI.angle_to_player(sim, e), 5.0, dt)

func on_phase(sim, e: SimEnemy, phase: int) -> void:
	pass

func dmg(e: SimEnemy, mul: float = 1.0) -> float:
	return float(e.def.dmg) * e.dmg_mul * mul

func update(sim, e: SimEnemy, dt: float) -> void:
	var phases: Array = e.def.get("phases", [0.5])
	var target := 0
	for ph in phases:
		if e.hp_frac() <= float(ph):
			target += 1
	if target > e.phase and e.st != 99:
		e.phase = target
		_clear(sim, e)
		e.invuln = true
		e.set_state(99)
		e.vel = Vector2.ZERO
		var txt: String = phase_text[mini(target, phase_text.size() - 1)]
		sim.fire(&"boss_phase", {"id": e.id, "phase": target, "text": txt, "sub": e.name, "boss": e.is_boss})
		on_phase(sim, e, target)
	var cds: Dictionary = e.data.cds
	for k in cds.keys():
		cds[k] = float(cds[k]) - dt
	match e.st:
		99:
			AI.stop(e, dt)
			e.glow = 1.0
			if e.t >= roar_time:
				e.invuln = false
				e.set_state(0)
				e.cd = 0.4
		0:
			move(sim, e, dt)
			e.cd -= dt
			if e.cd <= 0.0:
				var a = _pick(sim, e)
				if a != null:
					e.data["cur"] = a.id
					e.data["once"] = {}
					e.attack_name = a.name
					e.set_state(1)
					sim.fire(&"boss_callout", {"id": e.id, "text": String(a.name).to_upper(), "boss": e.is_boss})
				else:
					e.cd = 0.3
		1:
			var id: String = e.data.cur
			var done: bool = call("atk_" + id, sim, e, dt, e.t)
			if done:
				for a in attacks:
					if a.id == id:
						cds[id] = float(a.cd)
				e.set_state(0)
				e.cd = idle * (0.7 if e.phase > 0 else 1.0) * e.cd_mul
				e.contact_on = false
				e.super_armor = false
		_:
			e.set_state(0)

func _pick(sim, e: SimEnemy):
	var d := AI.dist(sim, e)
	var cds: Dictionary = e.data.cds
	var total := 0.0
	var pool: Array = []
	for a in attacks:
		if e.phase < int(a.get("min_phase", 0)) or e.phase > int(a.get("max_phase", 9)):
			continue
		if float(cds.get(a.id, 0.0)) > 0.0:
			continue
		var r: Array = a.get("range", [0.0, 99999.0])
		if d < float(r[0]) or d > float(r[1]):
			continue
		if e.data.get("last") == a.id and attacks.size() > 2:
			continue
		pool.append(a)
		total += float(a.w)
	if pool.is_empty():
		return null
	var roll = sim.rng.randf() * total
	for a in pool:
		roll -= float(a.w)
		if roll <= 0.0:
			e.data["last"] = a.id
			return a
	e.data["last"] = pool[-1].id
	return pool[-1]

func _clear(sim, e: SimEnemy) -> void:
	for t in sim.telegraphs:
		if t.owner == e:
			Tele.cancel(sim, t)
	e.tele = null
	for pr in sim.projectiles:
		if pr.team == 1 and pr.owner == e and pr.kind != SimProj.Kind.ORBIT:
			pr.alive = false
	e.contact_on = false

## true exactly once per attack for a key (sequencing helper)
func once(e: SimEnemy, key: String) -> bool:
	var o: Dictionary = e.data.once
	if o.has(key):
		return false
	o[key] = true
	return true

## true once when t passes `at`
func at(e: SimEnemy, t: float, when: float, key: String) -> bool:
	return t >= when and once(e, key)

func summon(sim, e: SimEnemy, kind: String, n: int) -> void:
	for i in n:
		var p := Enemies.spawn_point(sim, 20.0, true)
		Enemies.spawn(sim, kind, p, e.depth, {"summoned": true})

## a charge along a telegraphed line (no damage at the telegraph; contact damage while charging)
func charge_start(sim, e: SimEnemy, windup: float, width_mul: float = 2.0, name: String = "Charge") -> void:
	e.a = AI.angle_to_player(sim, e)
	var l: float = sim.ray_to_wall(e.pos, e.a, 900.0, e.radius)
	e.tele = AI.tele_line(sim, e, e.a, l + e.radius, e.radius * width_mul, windup, 0.0, name)
	e.tele.data["charge"] = true
	e.contact = float(e.def.dmg)
	e.data["charge_on"] = false

## returns true when the charge has ended (wall reached or timeout)
func charge_tick(sim, e: SimEnemy, dt: float, speed: float, track_until: float = 0.5) -> bool:
	if e.tele != null and not e.tele.resolved:
		e.vel = Vector2.ZERO
		if e.tele.progress() < track_until:
			e.a = AI.angle_to_player(sim, e)
			e.tele.angle = e.a
			e.tele.length = sim.ray_to_wall(e.pos, e.a, 900.0, e.radius) + e.radius
			e.facing = e.a
		return false
	if not e.data.get("charge_on", false):
		e.data["charge_on"] = true
		e.data["charge_t"] = 0.0
		e.contact_on = true
		e.contact_hit_t = 0.0
	e.data["charge_t"] = float(e.data.charge_t) + dt
	e.vel = Geom.dir(e.a) * speed
	if sim.point_blocked(e.pos + Geom.dir(e.a) * (e.radius + 10.0), e.radius) or float(e.data.charge_t) > 2.0:
		e.vel = Vector2.ZERO
		e.contact_on = false
		e.data["charge_on"] = false
		sim.fire(&"wall_slam", {"id": e.id, "pos": e.pos + Geom.dir(e.a) * e.radius, "normal": -Geom.dir(e.a), "speed": speed})
		return true
	return false
