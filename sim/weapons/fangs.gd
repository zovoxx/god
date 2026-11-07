class_name WFangs
extends WeaponBase
## Kestrel Fangs: fast 4-hit combo with a spin finisher, backstab crits, thrown knives.

func _init() -> void:
	id = "fangs"

func modify_hit(sim, p: SimPlayer, e: SimEnemy, h: HitInfo, d: Dictionary) -> void:
	# backstab: striking from behind the enemy's facing
	var from_enemy := (p.pos - e.pos).angle()
	if absf(Geom.angle_diff(e.facing, from_enemy)) > deg_to_rad(110.0):
		h.crit_bonus += float(W.backstab_crit)
		h.tag = "backstab"
	if p.atk_is_dash:
		h.crit_bonus += 0.35 * lvl("fangsDashCrit")

func on_active_start(sim, p: SimPlayer) -> void:
	if not p.atk_is_dash and is_finisher_step(p.atk_cur) and lvl("fangsFinisherKnives") > 0:
		var S: Dictionary = W.special
		for i in 6:
			_knife(sim, p, p.aim_dir.angle() + TAU * i / 6.0, float(S.dmg), int(S.pierce))

func begin_special(sim, p: SimPlayer, inp: InputFrame) -> bool:
	var S: Dictionary = W.special
	var od := Combat.use_overdrive(sim)
	var n := int(S.knives) + 2 * lvl("fangsKnives")
	var dmg := float(S.dmg)
	var spread := deg_to_rad(float(S.spread_deg))
	if od:
		n = int(W.overdrive.knives)
		dmg *= float(W.overdrive.dmg_mul)
		for i in n:
			_knife(sim, p, p.aim_dir.angle() + TAU * i / n, dmg, int(S.pierce) + 2)
	else:
		for i in n:
			_knife(sim, p, p.aim_dir.angle() + (i - (n - 1) * 0.5) * spread, dmg, int(S.pierce))
	instant_special(sim, p, float(S.cooldown))
	return true

func _knife(sim, p: SimPlayer, ang: float, dmg: float, pierce: int) -> void:
	var S: Dictionary = W.special
	var pr := Projectiles.player_shot(sim, p.pos + Geom.dir(ang) * 14.0, ang, float(S.speed), dmg, "special", float(S.power), 9.0, "knife", float(S.range) / float(S.speed))
	pr.pierce = pierce
