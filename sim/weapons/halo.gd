class_name WHalo
extends WeaponBase
## Sunwheel Halo: a returning chakram that cuts on the way out and on the way back. Every 3rd
## throw grinds at its apex. Special: the halo orbits Wren.

func _init() -> void:
	id = "halo"

func auto_repeat() -> bool:
	return true

func show_weapon(p: SimPlayer) -> bool:
	return int(p.wstate.get("out", 0)) == 0

func max_out() -> int:
	return 2 if lvl("haloTwin") > 0 else 1

func begin_attack(sim, p: SimPlayer, inp: InputFrame) -> void:
	if int(p.wstate.get("out", 0)) > 0 or float(p.wstate.get("cd", 0.0)) > 0.0:
		return
	var throws: int = int(p.wstate.get("throws", 0)) + 1
	p.wstate["throws"] = throws
	var finisher := throws % int(W.finisher_every) == 0
	var T: Dictionary = W.throw
	var rng := float(T.range) * (1.0 + 0.3 * lvl("haloRange"))
	if lvl("haloTwin") > 0:
		for s in [-1.0, 1.0]:
			_throw(sim, p, p.aim_dir.angle() + s * 0.2, rng, float(T.dmg), finisher, "attack")
	else:
		_throw(sim, p, p.aim_dir.angle(), rng, float(T.dmg), finisher, "attack")
	p.state = SimPlayer.St.ATTACK
	p.atk_phase = 2
	p.atk_is_dash = false
	p.atk = {"recovery": 0.12}
	p.atk_t = 0.12 * sim.attack_speed_mul()
	sim.fire(&"player_attack", {"phase": "throw", "step": throws % int(W.finisher_every), "weapon": id, "dash": false, "finisher": finisher})

func begin_dash_attack(sim, p: SimPlayer, inp: InputFrame) -> void:
	if int(p.wstate.get("out", 0)) >= max_out():
		begin_attack(sim, p, inp)
		return
	var D: Dictionary = W.dash_attack
	_throw(sim, p, p.aim_dir.angle(), float(D.range), float(D.dmg), false, "dash")
	p.state = SimPlayer.St.ATTACK
	p.atk_phase = 2
	p.atk_is_dash = true
	p.atk = {"recovery": 0.1}
	p.atk_t = 0.1
	sim.fire(&"player_attack", {"phase": "throw", "step": 0, "weapon": id, "dash": true})

func tick_attack(sim, p: SimPlayer, inp: InputFrame, dt: float) -> void:
	p.atk_t -= dt
	PlayerCtl.move_during_attack(sim, p, dt)
	if p.atk_t <= 0.0:
		p.state = SimPlayer.St.FREE

func _throw(sim, p: SimPlayer, ang: float, rng: float, dmg: float, finisher: bool, slot: String) -> SimProj:
	var T: Dictionary = W.throw
	var mul := float(W.finisher.dmg_mul) if finisher else 1.0
	var r := float(T.radius) * (1.25 if finisher else 1.0)
	var pr := Projectiles.player_shot(sim, p.pos, ang, 0.0, dmg * mul, slot, float(T.power), r, "w_halo", 30.0)
	pr.kind = SimProj.Kind.HALO
	pr.pierce = 9999
	pr.knock = float(T.knock)
	pr.data = {"phase": "out", "t": 0.0, "origin": p.pos, "dir": Geom.dir(ang), "range": rng, "finisher": finisher, "out_time": float(T.out_time) / (1.0 + 0.25 * lvl("haloSpeed"))}
	p.wstate["out"] = int(p.wstate.get("out", 0)) + 1
	return pr

func update_halo(sim, pr: SimProj, dt: float) -> void:
	var p: SimPlayer = sim.player
	var d: Dictionary = pr.data
	d.t = float(d.t) + dt
	pr.rot += dt * 24.0
	match String(d.phase):
		"out":
			var k := clampf(float(d.t) / float(d.out_time), 0.0, 1.0)
			var e := 1.0 - (1.0 - k) * (1.0 - k)
			var target: Vector2 = d.origin + d.dir * float(d.range) * e
			pr.vel = (target - pr.pos) / maxf(dt, 0.0001)
			pr.pos = target
			if sim.point_blocked(pr.pos, 4.0):
				k = 1.0
			if k >= 1.0:
				pr.vel = Vector2.ZERO
				if lvl("haloBlast") > 0:
					var hz := Hazards.player_blast(sim, pr.pos, 70.0, 0.0, 12.0, pr.slot, 0.5)
					hz.kind = "apex"
				if d.finisher:
					d.phase = "grind"
					d.t = 0.0
					pr.dmg = float(W.finisher.grind_dmg)
				else:
					_turn_back(pr)
		"grind":
			d["rehit"] = float(d.get("rehit", 0.0)) - dt
			if float(d.rehit) <= 0.0:
				d["rehit"] = float(W.finisher.grind_tick)
				pr.hits.clear()
			if float(d.t) >= float(W.finisher.grind_time):
				pr.dmg = float(W.throw.dmg) * float(W.finisher.dmg_mul)
				_turn_back(pr)
		"back":
			var to := p.pos - pr.pos
			var spd := float(W.throw.return_speed) * (1.0 + 0.25 * lvl("haloSpeed")) * minf(1.0, 0.4 + float(d.t) * 3.0)
			pr.vel = to.normalized() * spd
			pr.pos += pr.vel * dt
			if to.length() < 22.0 + spd * dt:
				pr.alive = false
				p.wstate["out"] = maxi(0, int(p.wstate.get("out", 1)) - 1)
				p.wstate["cd"] = float(W.throw.cooldown)
				sim.fire(&"halo_caught", {"pos": p.pos})

func _turn_back(pr: SimProj) -> void:
	pr.data.phase = "back"
	pr.data.t = 0.0
	pr.hits.clear()

func passive_tick(sim, p: SimPlayer, dt: float) -> void:
	p.wstate["cd"] = maxf(0.0, float(p.wstate.get("cd", 0.0)) - dt)
	# safety: if no halo projectile exists, the halo is back in hand
	if int(p.wstate.get("out", 0)) > 0:
		var n := 0
		for pr in sim.projectiles:
			if pr.kind == SimProj.Kind.HALO and pr.alive:
				n += 1
		p.wstate["out"] = n

func begin_special(sim, p: SimPlayer, inp: InputFrame) -> bool:
	var S: Dictionary = W.special
	var od := Combat.use_overdrive(sim)
	var n := int(W.overdrive.halos) if od else 1
	var dur := float(S.duration) + 1.2 * lvl("haloOrbit")
	for i in n:
		var pr := Projectiles.player_shot(sim, p.pos, 0.0, 0.0, float(S.tick_dmg) * (float(W.overdrive.dmg_mul) if od else 1.0), "special", float(S.power), 24.0, "w_halo", dur)
		pr.kind = SimProj.Kind.ORBIT
		pr.pierce = 9999
		pr.knock = 0.4
		pr.data = {"ang": TAU * i / n, "spin": float(S.angular_speed), "orbit_r": float(S.orbit_radius) * (1.3 if od else 1.0), "tick": float(S.tick_every)}
	instant_special(sim, p, float(S.cooldown) + dur * 0.5)
	return true
