class_name WBow
extends WeaponBase
## Vesper Bow: tap for quick shots (every 4th is a volley), hold to charge a piercing power
## shot (releasing right as it fills is a PERFECT release), Special: starfall.

func _init() -> void:
	id = "bow"

func auto_repeat() -> bool:
	return false

func visual_angle(sim, p: SimPlayer) -> float:
	return p.aim_dir.angle()

func begin_attack(sim, p: SimPlayer, inp: InputFrame) -> void:
	p.state = SimPlayer.St.ATTACK
	p.atk_phase = 0
	p.atk = {}
	p.wstate["draw"] = 0.0
	p.atk_t = 0.0
	p.atk_dir = p.aim_dir

func begin_dash_attack(sim, p: SimPlayer, inp: InputFrame) -> void:
	var D: Dictionary = W.dash_attack
	var n := int(D.arrows)
	for i in n:
		var a := p.aim_dir.angle() + (i - (n - 1) * 0.5) * deg_to_rad(float(D.spread_deg)) / maxf(1.0, n - 1.0)
		var pr := _arrow(sim, p, a, float(D.dmg), float(D.speed), float(D.power))
		pr.slot = "dash"
	_recover(sim, p, float(W.shot.cooldown))
	sim.fire(&"player_attack", {"phase": "shot", "step": 0, "weapon": id, "dash": true})

func tick_attack(sim, p: SimPlayer, inp: InputFrame, dt: float) -> void:
	var C: Dictionary = W.charge
	if p.atk_phase == 2:
		p.atk_t -= dt
		PlayerCtl.move_during_attack(sim, p, dt)
		if p.atk_t <= 0.0:
			p.state = SimPlayer.St.FREE
		return
	var draw: float = float(p.wstate.get("draw", 0.0)) + dt
	p.wstate["draw"] = draw
	var charging := draw > float(C.hold_threshold)
	PlayerCtl._move(sim, p, dt, float(C.move_mul) if charging else 1.0)
	p.facing = p.aim_dir.angle()
	p.wstate["charge"] = clampf((draw - float(C.hold_threshold)) / (float(C.time) * charge_time_mul()), 0.0, 1.2) if charging else 0.0
	if not inp.attack_h:
		if charging:
			_power_shot(sim, p, draw - float(C.hold_threshold))
		else:
			_quick_shot(sim, p)

func charge_time_mul() -> float:
	return 1.0

func _quick_shot(sim, p: SimPlayer) -> void:
	var S: Dictionary = W.shot
	var n_shot: int = int(p.wstate.get("shots", 0)) + 1
	p.wstate["shots"] = n_shot
	var ang := p.aim_dir.angle()
	if n_shot % int(W.volley_every) == 0:
		var n := int(W.volley.arrows) + 2 * lvl("bowVolley")
		for i in n:
			_arrow(sim, p, ang + (i - (n - 1) * 0.5) * deg_to_rad(float(W.volley.spread_deg)), float(S.dmg), float(S.speed), float(S.power))
	else:
		_arrow(sim, p, ang, float(S.dmg), float(S.speed), float(S.power))
	sim.fire(&"player_attack", {"phase": "shot", "step": n_shot % int(W.volley_every), "weapon": id, "dash": false})
	_recover(sim, p, float(S.cooldown))

func _power_shot(sim, p: SimPlayer, held: float) -> void:
	var C: Dictionary = W.charge
	var full := float(C.time) * charge_time_mul()
	var k := clampf(held / full, 0.0, 1.0)
	var perfect := held >= full and held <= full + float(C.perfect_window)
	var dmg := lerpf(float(W.shot.dmg), float(C.dmg), k)
	if perfect:
		dmg = float(C.perfect_dmg)
	var pr := _arrow(sim, p, p.aim_dir.angle(), dmg, lerpf(float(W.shot.speed), float(C.speed), k), lerpf(0.3, float(C.power), k))
	pr.art = "arrow_power"
	pr.radius = 12.0
	if k >= 1.0:
		pr.pierce = int(C.pierce)
	if perfect:
		pr.data["force_crit"] = true
		sim.fire(&"perfect_release", {"pos": p.pos})
	if k >= 1.0 and lvl("bowSplit") > 0:
		var split_done := {"v": false}
		pr.data["on_hit"] = func(e):
			if split_done.v:
				return
			split_done.v = true
			for i in 3:
				var a: float = pr.vel.angle() + (i - 1) * 0.45
				var s2 := Projectiles.player_shot(sim, e.pos + Geom.dir(a) * (e.radius + 6.0), a, 1100.0, float(W.shot.dmg) * 1.5, "attack", 0.3, 8.0, "arrow", 0.4)
				s2.hits[e.id] = true
	sim.fire(&"player_attack", {"phase": "power", "step": 0, "weapon": id, "dash": false, "perfect": perfect, "charge": k})
	_recover(sim, p, float(W.shot.cooldown) * 1.4)

func _recover(sim, p: SimPlayer, t: float) -> void:
	p.state = SimPlayer.St.ATTACK
	p.atk_phase = 2
	p.atk_t = t * sim.attack_speed_mul()
	p.wstate["draw"] = 0.0
	p.wstate["charge"] = 0.0

func _arrow(sim, p: SimPlayer, ang: float, dmg: float, speed: float, power: float) -> SimProj:
	var pr := Projectiles.player_shot(sim, p.pos + Geom.dir(ang) * 16.0, ang, speed, dmg, "attack", power, 8.0, "arrow", float(W.shot.range) / speed)
	pr.knock = 0.5
	pr.pierce = lvl("bowPierce")
	return pr

func cancel_attack(sim, p: SimPlayer) -> void:
	p.state = SimPlayer.St.FREE
	p.wstate["draw"] = 0.0
	p.wstate["charge"] = 0.0

func begin_special(sim, p: SimPlayer, inp: InputFrame) -> bool:
	var S: Dictionary = W.special
	var od := Combat.use_overdrive(sim)
	var targets: Array = [PlayerCtl.sigil_point(sim, p, inp)]
	var dmg := float(S.dmg)
	if od:
		dmg *= float(W.overdrive.dmg_mul)
		var near: Array = sim.enemies.filter(func(e): return e.targetable())
		near.sort_custom(func(a, b): return a.pos.distance_to(p.pos) < b.pos.distance_to(p.pos))
		for i in mini(2, near.size()):
			targets.append(near[i].pos)
	var hits := int(S.hits) + 3 * lvl("bowRain")
	var radius := float(S.radius) * (1.0 + 0.2 * lvl("bowRain"))
	for t in targets:
		var hz := Hazards.player_field(sim, t, radius, float(S.delay), hits * float(S.interval), float(S.interval), dmg, "special", float(S.power), "starfall")
		hz.knock = 0.3
	instant_special(sim, p, float(S.cooldown))
	return true
