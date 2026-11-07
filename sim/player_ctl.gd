class_name PlayerCtl
extends RefCounted
## Player update: buffering, aim, movement, dash and the action state machine.
## Weapon behaviour is delegated to sim.weapon (WeaponBase subclasses).

static func update(sim, p: SimPlayer, inp: InputFrame, dt: float) -> void:
	var T: Tuning = sim.T
	var now: float = sim.time
	var win: float = T.input.buffer
	if inp.attack_p: p.press("attack", now)
	if inp.special_p: p.press("special", now)
	if inp.dash_p: p.press("dash", now)
	if inp.cast_p: p.press("cast", now)

	# --- timers ---
	p.dash_iframes = maxf(0.0, p.dash_iframes - dt)
	p.hurt_iframes = maxf(0.0, p.hurt_iframes - dt)
	p.invuln_t = maxf(0.0, p.invuln_t - dt)
	p.hurt_lock = maxf(0.0, p.hurt_lock - dt)
	p.special_cd = maxf(0.0, p.special_cd - dt)
	p.squash = move_toward(p.squash, 0.0, dt * 3.0)
	if p.dash_charges < p.dash_max:
		p.dash_cd -= dt
		if p.dash_cd <= 0.0:
			p.dash_charges += 1
			p.dash_cd = sim.dash_cooldown() if p.dash_charges < p.dash_max else 0.0
	if p.cast_charges < p.cast_max:
		p.cast_recharge -= dt
		if p.cast_recharge <= 0.0:
			p.cast_charges += 1
			p.cast_recharge = sim.cast_recharge_time() if p.cast_charges < p.cast_max else 0.0
	if p.state == SimPlayer.St.DEAD:
		p.vel = Vector2.ZERO
		return

	# --- aim ---
	p.move_dir = inp.move.limit_length(1.0)
	if p.move_dir.length() < T.input.deadzone:
		p.move_dir = Vector2.ZERO
	update_aim(sim, p, inp)

	var weapon = sim.weapon
	match p.state:
		SimPlayer.St.FREE:
			_move(sim, p, dt, 1.0)
			if p.combo_timer > 0.0:
				p.combo_timer -= dt
				if p.combo_timer <= 0.0:
					p.atk_step = 0
			if p.hurt_lock <= 0.0:
				_try_actions(sim, p, inp, win)
		SimPlayer.St.DASH:
			p.dash_t -= dt
			p.vel = p.dash_dir * p.dash_speed
			sim.on_player_dashing(dt)
			if p.dash_t <= 0.0:
				p.state = SimPlayer.St.FREE
				p.dash_ended_at = now
				p.vel = p.dash_dir * p.dash_speed * T.dash.exit_speed_frac
				sim.on_player_dash_end()
			elif p.buffered("attack", now, win) and weapon != null and weapon.has_dash_attack():
				# attacking during the dash triggers the dash-attack as soon as the dash ends
				pass
		SimPlayer.St.ATTACK:
			if weapon != null:
				weapon.tick_attack(sim, p, inp, dt)
			# recovery can always be cancelled by a dash
			if p.state == SimPlayer.St.ATTACK and p.atk_phase == 2 and p.buffered("dash", now, win) and p.dash_charges > 0:
				start_dash(sim, p)
		SimPlayer.St.SPECIAL:
			if weapon != null:
				weapon.tick_special(sim, p, inp, dt)
			else:
				p.state = SimPlayer.St.FREE
			if p.state == SimPlayer.St.SPECIAL and p.buffered("dash", now, win) and p.dash_charges > 0 and (weapon == null or weapon.special_dash_cancel(p)):
				if weapon != null:
					weapon.cancel_special(sim, p)
				start_dash(sim, p)
		SimPlayer.St.CAST:
			_move(sim, p, dt, 0.5)
			p.cast_t -= dt
			if p.cast_t <= 0.0:
				p.state = SimPlayer.St.FREE

static func _try_actions(sim, p: SimPlayer, inp: InputFrame, win: float) -> void:
	var now: float = sim.time
	var weapon = sim.weapon
	if p.buffered("dash", now, win) and p.dash_charges > 0:
		start_dash(sim, p)
		return
	if p.buffered("cast", now, win) and p.cast_charges > 0:
		p.consume("cast")
		sim.cast_sigil()
		return
	if weapon == null:
		return
	if p.buffered("special", now, win) and p.special_cd <= 0.0:
		p.consume("special")
		if weapon.begin_special(sim, p, inp):
			return
	if p.buffered("attack", now, win):
		var dash_window: bool = now - p.dash_ended_at <= sim.T.dash.dash_attack_window
		p.consume("attack")
		if dash_window and weapon.has_dash_attack():
			weapon.begin_dash_attack(sim, p, inp)
		else:
			weapon.begin_attack(sim, p, inp)
	elif inp.attack_h and weapon.auto_repeat():
		weapon.begin_attack(sim, p, inp)

static func start_dash(sim, p: SimPlayer) -> void:
	var T: Tuning = sim.T
	p.consume("dash")
	if p.state == SimPlayer.St.ATTACK and sim.weapon != null:
		sim.weapon.cancel_attack(sim, p)
	p.state = SimPlayer.St.DASH
	var d := p.move_dir if p.move_dir.length() > 0.1 else p.aim_dir
	p.dash_dir = d.normalized()
	var dur: float = T.dash.duration
	p.dash_t = dur
	p.dash_speed = sim.dash_distance() / dur
	p.dash_iframes = T.dash.iframes
	p.dash_started_at = sim.time
	p.dash_hit.clear()
	if p.dash_charges == p.dash_max:
		p.dash_cd = sim.dash_cooldown()
	p.dash_charges -= 1
	p.squash = sim.F.squash.player_dash
	p.facing = p.dash_dir.angle()
	sim.on_player_dash_start()

static func _move(sim, p: SimPlayer, dt: float, mul: float) -> void:
	var T: Tuning = sim.T
	var max_speed: float = sim.move_speed() * mul
	var target := p.move_dir * max_speed
	var rate: float = T.player.accel if p.move_dir != Vector2.ZERO else T.player.decel
	p.vel = p.vel.move_toward(target, rate * dt)
	if p.move_dir != Vector2.ZERO and p.state == SimPlayer.St.FREE:
		p.facing = lerp_angle(p.facing, p.move_dir.angle(), clampf(dt * 18.0, 0.0, 1.0))

static func move_during_attack(sim, p: SimPlayer, dt: float) -> void:
	_move(sim, p, dt, sim.T.player.attack_move_mul)

## Aim: mouse points at the cursor (with a soft snap); stick aims with the right stick and
## falls back to a smart auto-aim cone in the movement direction.
static func update_aim(sim, p: SimPlayer, inp: InputFrame) -> void:
	var A: Dictionary = sim.T.aim
	var dir := Vector2.ZERO
	match inp.aim_source:
		InputFrame.Aim.MOUSE:
			var d := inp.aim_point - p.pos
			if d.length() > 4.0:
				dir = d.normalized()
				dir = _snap(sim, p, dir, deg_to_rad(A.mouse_snap_deg))
		InputFrame.Aim.STICK:
			if inp.aim.length() > sim.T.input.aim_deadzone:
				dir = _snap(sim, p, inp.aim.normalized(), deg_to_rad(A.mouse_snap_deg))
	if dir == Vector2.ZERO:
		var base := p.move_dir.normalized() if p.move_dir != Vector2.ZERO else p.aim_dir
		var t = auto_target(sim, p, base)
		p.aim_target = t
		dir = (t.pos - p.pos).normalized() if t != null else base
	if dir != Vector2.ZERO:
		p.aim_dir = dir.normalized()

static func _snap(sim, p: SimPlayer, dir: Vector2, max_ang: float) -> Vector2:
	var best = null
	var best_da := max_ang
	var max_range: float = sim.T.aim.max_range
	for e in sim.enemies:
		if not e.targetable():
			continue
		var d: Vector2 = e.pos - p.pos
		if d.length() > max_range:
			continue
		var da := absf(Geom.angle_diff(dir.angle(), d.angle()))
		if da < best_da:
			best_da = da
			best = e
	p.aim_target = best
	if best == null:
		return dir
	return (best.pos - p.pos).normalized()

static func auto_target(sim, p: SimPlayer, base: Vector2):
	var A: Dictionary = sim.T.aim
	var cone := deg_to_rad(A.cone_deg)
	var max_range: float = A.max_range
	var best = null
	var best_score := INF
	for e in sim.enemies:
		if not e.targetable():
			continue
		var d: Vector2 = e.pos - p.pos
		var dist := d.length()
		if dist > max_range:
			continue
		var da := absf(Geom.angle_diff(base.angle(), d.angle()))
		if da > cone and dist > float(A.close_radius):
			continue
		var score := float(A.angle_weight) * (da / cone) + dist / max_range
		if e == p.aim_target:
			score -= float(A.stickiness)
		if score < best_score:
			best_score = score
			best = e
	return best

static func sigil_point(sim, p: SimPlayer, inp: InputFrame) -> Vector2:
	var rng: float = sim.T.cast.range
	if inp != null and inp.aim_source == InputFrame.Aim.MOUSE:
		var d := inp.aim_point - p.pos
		return p.pos + d.limit_length(rng)
	if p.aim_target != null and p.aim_target.pos.distance_to(p.pos) <= rng * 1.2:
		return p.aim_target.pos
	return p.pos + p.aim_dir * rng * 0.7
