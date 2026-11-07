class_name WPike
extends WeaponBase
## Moonreach: long thrusts with tip crits; the Special is a channelled whirl.

func _init() -> void:
	id = "pike"

func visual_angle(sim, p: SimPlayer) -> float:
	if p.state == SimPlayer.St.SPECIAL:
		return sim.time * 22.0
	return p.aim_dir.angle() if p.state != SimPlayer.St.ATTACK else p.atk_dir.angle()

func modify_hit(sim, p: SimPlayer, e: SimEnemy, h: HitInfo, d: Dictionary) -> void:
	var length := float(d.get("len", 150.0))
	var f := Geom.line_frac(e.pos, p.pos, p.atk_dir.angle(), length)
	var tip := float(W.tip_fraction) * (1.0 + 0.5 * lvl("pikeTip"))
	if f >= 1.0 - tip:
		h.crit_bonus += float(W.tip_crit)
		h.tag = "tip"

func on_active_start(sim, p: SimPlayer) -> void:
	if not p.atk_is_dash and is_finisher_step(p.atk_cur) and lvl("pikeWave") > 0:
		var pr := Projectiles.player_shot(sim, p.pos, p.atk_dir.angle(), 900.0, 20.0, "attack", 0.5, 30.0, "wave", 0.6)
		pr.kind = SimProj.Kind.WAVE
		pr.pierce = 99

func begin_special(sim, p: SimPlayer, inp: InputFrame) -> bool:
	p.state = SimPlayer.St.SPECIAL
	p.special_t = 0.0
	p.wstate["tick"] = 0.0
	p.wstate["od"] = Combat.use_overdrive(sim)
	sim.fire(&"player_special", {"weapon": id, "pos": p.pos, "angle": p.aim_dir.angle(), "channel": true})
	return true

func tick_special(sim, p: SimPlayer, inp: InputFrame, dt: float) -> void:
	var S: Dictionary = W.special
	var od: bool = p.wstate.get("od", false)
	p.special_t += dt
	PlayerCtl._move(sim, p, dt, float(S.move_mul))
	p.wstate["tick"] = float(p.wstate.tick) - dt
	var radius := float(S.radius) * (float(W.overdrive.radius_mul) if od else 1.0)
	if float(p.wstate.tick) <= 0.0:
		p.wstate["tick"] = float(S.tick_every)
		var dmg := float(S.dmg) * (float(W.overdrive.dmg_mul) if od else 1.0)
		for e in sim.enemies:
			if e.targetable() and Geom.in_circle(e.pos, e.radius, p.pos, radius):
				var out = (e.pos - p.pos).normalized()
				var h := HitInfo.make(dmg, "special", float(S.power), out.orthogonal() * 0.6 + out * 0.4, p.pos)
				h.knock = 0.25
				h.no_hitstop = true
				Combat.deal(sim, e, h)
				if (lvl("pikeSpinPull") > 0 or od) and e.alive and not e.no_knock:
					e.kvel += -out * (float(W.overdrive.pull) if od else 380.0) * float(S.tick_every) * 3.0 / maxf(0.5, e.mass)
		sim.fire(&"whirl_tick", {"pos": p.pos, "radius": radius})
	var held: bool = inp.special_h
	if (not held and p.special_t > 0.25) or p.special_t >= float(S.max_time):
		p.state = SimPlayer.St.FREE
		p.special_cd = float(S.cooldown)

func cancel_special(sim, p: SimPlayer) -> void:
	p.state = SimPlayer.St.FREE
	p.special_cd = float(W.special.cooldown)
