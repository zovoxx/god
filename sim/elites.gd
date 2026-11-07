class_name Elites
extends RefCounted
## Combinable elite modifiers. Any set of ids from tuning.elites can be applied to any enemy
## that allows elites (not summons). Elites get +90% HP and +20% damage on top.

const ALL := ["hasted", "shielded", "volatile", "blazing", "vampiric", "brood", "hulking", "blinking", "orbiting", "mending"]

static func info(id: String) -> Dictionary:
	return Cfg.T.elites.get(id, {})

static func pool(deepening: int) -> Array:
	var E: Dictionary = Cfg.T.elites
	var p: Array = (E.base_pool as Array).duplicate()
	if deepening >= 1:
		p.append_array(E.deep_pool)
	return p

static func roll(rng: RandomNumberGenerator, count: int, deepening: int) -> Array:
	var p := pool(deepening)
	var out: Array = []
	for i in count:
		if p.is_empty():
			break
		var k := rng.randi_range(0, p.size() - 1)
		out.append(p[k])
		p.remove_at(k)
	return out

static func apply(sim, e: SimEnemy, mods: Array) -> void:
	if bool(e.def.get("no_elite", false)) or e.is_boss:
		return
	var S: Dictionary = sim.T.scaling
	e.elites = mods.duplicate()
	e.max_hp = round(e.max_hp * float(S.elite_hp))
	e.dmg_mul *= float(S.elite_dmg)
	for m in mods:
		var I := info(m)
		match String(m):
			"hasted":
				e.speed_mul *= float(I.speed_mul)
				e.cd_mul *= float(I.cd_mul)
			"hulking":
				e.max_hp = round(e.max_hp * float(I.hp_mul))
				e.radius *= float(I.radius_mul)
				e.mass *= float(I.mass_mul)
				e.dmg_mul *= float(I.dmg_mul)
				e.super_armor = true
			"orbiting":
				for i in int(I.blades):
					var pr := AI.shoot(sim, e, e.pos, 0.0, 0.0, float(I.dmg) * e.dmg_mul, "Orbiting Blade", 9.0, 9999.0)
					pr.kind = SimProj.Kind.ORBIT
					pr.data = {"ang": TAU * i / float(I.blades), "spin": 3.2, "orbit_r": e.radius + float(I.radius), "survive_owner": false}
					pr.pierce = 9999
	e.hp = e.max_hp
	if mods.has("shielded"):
		e.max_shield = round(e.max_hp * float(info("shielded").shield_frac))
		e.shield = e.max_shield

static func update(sim, e: SimEnemy, dt: float) -> void:
	for m in e.elites:
		match String(m):
			"shielded":
				var I := info("shielded")
				if e.shield < e.max_shield and sim.time - e.last_hit_t > float(I.regen_delay):
					e.shield = minf(e.max_shield, e.shield + e.max_shield * float(I.regen_rate) * dt)
			"blazing":
				var I2 := info("blazing")
				e.data["_blaze"] = float(e.data.get("_blaze", 0.0)) - dt
				if float(e.data._blaze) <= 0.0 and e.vel.length() > 30.0:
					e.data["_blaze"] = float(I2.every)
					var hz := Hazards.enemy_field(sim, e, e.pos + Vector2(0, e.radius * 0.3), float(I2.radius), float(I2.arm), float(I2.life), float(I2.dmg) * e.dmg_mul, "Blazing Trail", "fire")
					hz.name = e.name
					hz.art = e.art
			"mending":
				var I3 := info("mending")
				if sim.time - e.last_hit_t > float(I3.delay) and e.hp < e.max_hp:
					e.hp = minf(e.max_hp, e.hp + e.max_hp * float(I3.rate) * dt)
			"blinking":
				e.data["_blink_cd"] = maxf(0.0, float(e.data.get("_blink_cd", 0.0)) - dt)

static func on_hit(sim, e: SimEnemy, h: HitInfo) -> void:
	if e.has_elite("blinking") and e.alive and not h.is_dot and float(e.data.get("_blink_cd", 0.0)) <= 0.0:
		e.data["_blink_cd"] = float(info("blinking").cooldown)
		var from := e.pos
		var to: Vector2 = sim.random_free_point(180.0, 280.0, e.pos, e.radius)
		e.pos = to
		e.prev = to
		if e.tele != null:
			Tele.cancel(sim, e.tele)
			e.tele = null
		e.set_state(0)
		sim.fire(&"enemy_blink", {"id": e.id, "from": from, "to": to})

static func on_death(sim, e: SimEnemy) -> void:
	if e.has_elite("volatile"):
		var I := info("volatile")
		var t := Tele.make(sim, null, Tele.Shape.CIRCLE, float(I.windup), float(I.dmg) * e.dmg_mul, "Volatile Blast")
		t.pos = e.pos
		t.radius = float(I.radius)
		t.data["source_name"] = e.name
		var pos := e.pos
		t.on_impact = func():
			sim.fire(&"explosion", {"pos": pos, "radius": float(I.radius)})
	if e.has_elite("brood") and not e.data.get("brood_child", false):
		for i in 2:
			var a = float(i) * PI + sim.rng.randf()
			var c := Enemies.spawn(sim, e.kind, e.pos + Geom.dir(a) * 20.0, e.depth, {"portal": false, "summoned": true, "hp_mul": float(info("brood").hp_mul)})
			c.data["brood_child"] = true
			c.kvel = Geom.dir(a) * 320.0
