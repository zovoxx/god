class_name WeaponBase
extends RefCounted
## Shared weapon logic: a melee combo state machine driven by frame data from tuning.tres
## (windup → active → recovery, damage, range/arc or length/width, power, knockback, lunge).
## Subclasses override specials, dash-attacks, forges and per-hit modifiers.

var id := ""
var W := {}
var forge_levels := {}

func setup(sim, forges: Dictionary) -> void:
	W = sim.T.weapons[id]
	forge_levels = forges

func lvl(forge_id: String) -> int:
	return int(forge_levels.get(forge_id, 0))

func display_name() -> String:
	return W.get("name", id)

func has_dash_attack() -> bool:
	return true

func auto_repeat() -> bool:
	return true

func show_weapon(p: SimPlayer) -> bool:
	return true

func passive_tick(sim, p: SimPlayer, dt: float) -> void:
	pass

func special_dash_cancel(p: SimPlayer) -> bool:
	return true

func cancel_special(sim, p: SimPlayer) -> void:
	p.state = SimPlayer.St.FREE

func visual_angle(sim, p: SimPlayer) -> float:
	if p.state == SimPlayer.St.ATTACK and p.atk.has("arc"):
		var arc := deg_to_rad(float(p.atk.arc))
		var base := p.atk_dir.angle()
		var side := 1.0 if p.atk_cur % 2 == 0 else -1.0
		match p.atk_phase:
			0: return base - arc * 0.5 * side
			1:
				var k := 1.0 - p.atk_t / maxf(0.001, float(p.atk.active) * sim.attack_speed_mul())
				return base + lerpf(-arc * 0.5, arc * 0.5, clampf(k, 0.0, 1.0)) * side
			2: return base + arc * 0.5 * side
	return p.aim_dir.angle()

# ───────── melee combo ─────────

func begin_attack(sim, p: SimPlayer, inp: InputFrame) -> void:
	var combo: Array = W.combo
	var step := p.atk_step if p.combo_timer > 0.0 or p.state == SimPlayer.St.ATTACK else 0
	step = step % combo.size()
	start_swing(sim, p, combo[step], step, false)

func begin_dash_attack(sim, p: SimPlayer, inp: InputFrame) -> void:
	start_swing(sim, p, W.dash_attack, -1, true)

func start_swing(sim, p: SimPlayer, data: Dictionary, step: int, is_dash: bool) -> void:
	p.state = SimPlayer.St.ATTACK
	p.atk = data
	p.atk_cur = step
	p.atk_phase = 0
	p.atk_t = float(data.windup) * sim.attack_speed_mul()
	p.atk_hits.clear()
	p.atk_is_dash = is_dash
	p.atk_dir = p.aim_dir
	p.facing = p.aim_dir.angle()
	p.squash = float(sim.F.squash.player_attack)
	if not is_dash:
		p.atk_step = (step + 1) % W.combo.size()
	sim.fire(&"player_attack", {"phase": "windup", "step": step, "weapon": id, "dash": is_dash})

func is_finisher_step(step: int) -> bool:
	return step == W.combo.size() - 1

func tick_attack(sim, p: SimPlayer, inp: InputFrame, dt: float) -> void:
	var k: float = sim.attack_speed_mul()
	var d: Dictionary = p.atk
	p.atk_t -= dt
	match p.atk_phase:
		0:
			PlayerCtl.move_during_attack(sim, p, dt)
			if p.atk_t <= 0.0:
				p.atk_phase = 1
				p.atk_t = float(d.active) * k
				sim.fire(&"player_attack", {"phase": "active", "step": p.atk_cur, "weapon": id, "dash": p.atk_is_dash, "shape": d.get("shape", "arc"),
					"range": float(d.get("range", 0.0)) + reach_bonus(), "arc": float(d.get("arc", 0.0)), "len": float(d.get("len", 0.0)) + reach_bonus(), "width": float(d.get("width", 0.0)),
					"angle": p.atk_dir.angle(), "pos": p.pos, "finisher": not p.atk_is_dash and is_finisher_step(p.atk_cur), "power": float(d.power), "life": float(d.active) * k + 0.06})
				on_active_start(sim, p)
		1:
			var lunge: float = float(d.get("lunge", 0.0))
			if p.aim_target != null and p.aim_target.alive and p.aim_target.pos.distance_to(p.pos) < float(d.get("range", d.get("len", 80.0))) * 0.55:
				lunge *= 0.2
			p.vel = p.atk_dir * lunge
			melee_hits(sim, p, d)
			if p.atk_t <= 0.0:
				p.atk_phase = 2
				p.atk_t = float(d.recovery) * k
		2:
			p.vel = p.vel.move_toward(Vector2.ZERO, float(sim.T.player.decel) * dt)
			PlayerCtl.move_during_attack(sim, p, dt)
			var total := float(d.recovery) * k
			var done := 1.0 - p.atk_t / maxf(0.001, total)
			var wants: bool = p.buffered("attack", sim.time, float(sim.T.input.buffer)) or (inp.attack_h and auto_repeat())
			if wants and not p.atk_is_dash and done >= float(W.get("chain_at", 0.35)):
				p.consume("attack")
				begin_attack(sim, p, inp)
			elif p.atk_t <= 0.0:
				end_attack(sim, p)

func end_attack(sim, p: SimPlayer) -> void:
	p.state = SimPlayer.St.FREE
	p.combo_timer = float(W.get("combo_reset", 0.32))
	if p.atk_is_dash:
		p.combo_timer = 0.0
		p.atk_step = 0

func cancel_attack(sim, p: SimPlayer) -> void:
	p.state = SimPlayer.St.FREE
	p.combo_timer = float(W.get("combo_reset", 0.32))

func reach_bonus() -> float:
	return 0.0

func on_active_start(sim, p: SimPlayer) -> void:
	pass

func melee_hits(sim, p: SimPlayer, d: Dictionary) -> void:
	var ang := p.atk_dir.angle()
	var shape: String = d.get("shape", "arc")
	for e in sim.enemies:
		if not e.targetable() or p.atk_hits.has(e.id):
			continue
		var inside := false
		if shape == "arc":
			inside = Geom.in_arc(e.pos, e.radius, p.pos, ang, float(d.range) + reach_bonus(), float(d.arc))
		else:
			inside = Geom.in_line(e.pos, e.radius, p.pos - p.atk_dir * 10.0, ang, float(d.len) + reach_bonus() + 10.0, float(d.width))
		if not inside:
			continue
		p.atk_hits[e.id] = true
		var dirv = ((e.pos - p.pos).normalized() + p.atk_dir).normalized()
		var h := HitInfo.make(float(d.dmg), "dash" if p.atk_is_dash else "attack", float(d.power), dirv, p.pos)
		h.knock = float(d.get("knock", 1.0))
		if not p.atk_is_dash and is_finisher_step(p.atk_cur):
			h.tag = "combo_finisher"
		modify_hit(sim, p, e, h, d)
		Combat.deal(sim, e, h)

func modify_hit(sim, p: SimPlayer, e: SimEnemy, h: HitInfo, d: Dictionary) -> void:
	pass

# ───────── special ─────────

func begin_special(sim, p: SimPlayer, inp: InputFrame) -> bool:
	return false

func tick_special(sim, p: SimPlayer, inp: InputFrame, dt: float) -> void:
	p.special_t -= dt
	PlayerCtl.move_during_attack(sim, p, dt)
	if p.special_t <= 0.0:
		p.state = SimPlayer.St.FREE

func special_mul(sim) -> float:
	return 1.0

## common: brief "throw" pose after an instant special
func instant_special(sim, p: SimPlayer, cooldown: float) -> void:
	p.state = SimPlayer.St.SPECIAL
	p.special_t = 0.14
	p.special_cd = cooldown / maxf(0.4, 1.0 + sim.stats.special_speed)
	p.facing = p.aim_dir.angle()
	sim.fire(&"player_special", {"weapon": id, "pos": p.pos, "angle": p.aim_dir.angle()})
