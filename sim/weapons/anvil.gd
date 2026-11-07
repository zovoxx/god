class_name WAnvil
extends WeaponBase
## Anvilheart: slow armor-breaking swings; the Special charges a fissure on release.

func _init() -> void:
	id = "anvil"

func auto_repeat() -> bool:
	return true

func modify_hit(sim, p: SimPlayer, e: SimEnemy, h: HitInfo, d: Dictionary) -> void:
	h.armor_break = float(W.armor_break_mul)
	h.stagger = 1.4

func on_active_start(sim, p: SimPlayer) -> void:
	if not p.atk_is_dash and is_finisher_step(p.atk_cur) and lvl("anvilEarthsplit") > 0:
		var hz := Hazards.player_blast(sim, p.pos, 200.0, 0.1, 20.0, "attack", 0.6)
		hz.kind = "shockwave"
		hz.data["armor_break"] = float(W.armor_break_mul)

func begin_special(sim, p: SimPlayer, inp: InputFrame) -> bool:
	p.state = SimPlayer.St.SPECIAL
	p.special_charge = 0.0
	p.special_t = 0.0
	sim.fire(&"player_special", {"weapon": id, "pos": p.pos, "angle": p.aim_dir.angle(), "charge": true})
	return true

func charge_frac() -> float:
	return 0.0

func fissure_len(p: SimPlayer) -> float:
	var S: Dictionary = W.special
	var k := clampf(p.special_charge / float(S.charge_max), 0.0, 1.0)
	return lerpf(float(S.range_min), float(S.range_max), k)

func tick_special(sim, p: SimPlayer, inp: InputFrame, dt: float) -> void:
	var S: Dictionary = W.special
	p.special_t += dt
	p.special_charge += dt * (1.0 + 0.3 * lvl("anvilCharge"))
	PlayerCtl._move(sim, p, dt, float(S.move_mul))
	p.facing = p.aim_dir.angle()
	var held: bool = inp.special_h
	if (not held and p.special_t > 0.06) or p.special_charge >= float(S.charge_max) + 0.5:
		_release(sim, p)

func _release(sim, p: SimPlayer) -> void:
	var S: Dictionary = W.special
	var k := clampf(p.special_charge / float(S.charge_max), 0.0, 1.0)
	var dmg := lerpf(float(S.dmg_min), float(S.dmg_max), k)
	var length := fissure_len(p)
	var od := Combat.use_overdrive(sim)
	var angs: Array = [p.aim_dir.angle()]
	if od:
		dmg *= float(W.overdrive.dmg_mul)
		angs = [p.aim_dir.angle() - 0.35, p.aim_dir.angle(), p.aim_dir.angle() + 0.35]
	for a in angs:
		var hz := Hazards.player_line(sim, p.pos, a, length, float(S.width), 0.06, dmg, "special", float(S.power) * (0.5 + 0.5 * k))
		hz.data["armor_break"] = float(W.armor_break_mul)
		if lvl("anvilAftershock") > 0:
			var hz2 := Hazards.player_line(sim, p.pos, a, length, float(S.width) * 1.2, 0.45, dmg * 0.6, "special", 0.6)
			hz2.data["armor_break"] = float(W.armor_break_mul)
	p.state = SimPlayer.St.FREE
	p.special_cd = float(S.cooldown)
	p.squash = 0.3
	sim.fire(&"player_fissure", {"pos": p.pos, "angle": p.aim_dir.angle(), "length": length, "power": k})

func cancel_special(sim, p: SimPlayer) -> void:
	if p.special_charge > 0.15:
		_release(sim, p)
	p.state = SimPlayer.St.FREE

func special_dash_cancel(p: SimPlayer) -> bool:
	return true
