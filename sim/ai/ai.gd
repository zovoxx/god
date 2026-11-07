class_name AI
extends RefCounted
## Movement and attack helpers shared by every enemy brain. Every attack goes through a
## telegraph (Tele) so it is always readable.

static func to_player(sim, e: SimEnemy) -> Vector2:
	return sim.player.pos - e.pos

static func dist(sim, e: SimEnemy) -> float:
	return e.pos.distance_to(sim.player.pos)

static func angle_to_player(sim, e: SimEnemy) -> float:
	return (sim.player.pos - e.pos).angle()

static func face(e: SimEnemy, ang: float, rate: float, dt: float) -> void:
	e.facing = lerp_angle(e.facing, ang, clampf(rate * dt, 0.0, 1.0))

## steers toward a point, sliding around pillars
static func move_to(sim, e: SimEnemy, target: Vector2, speed: float, dt: float, accel: float = 8.0) -> void:
	var d := target - e.pos
	if d.length() < 2.0:
		e.vel = e.vel.lerp(Vector2.ZERO, clampf(accel * dt, 0.0, 1.0))
		return
	var dirv := d.normalized()
	if not e.flying:
		for pl in sim.arena.pillars:
			var to_p: Vector2 = pl.pos - e.pos
			var pr: float = float(pl.r) + e.radius + 14.0
			var along := to_p.dot(dirv)
			if along > 0.0 and along < d.length() + pr:
				var perp := to_p - dirv * along
				if perp.length() < pr:
					var side := -signf(perp.cross(dirv)) if perp.length() > 0.5 else 1.0
					dirv = (dirv + dirv.orthogonal() * side * (1.0 - perp.length() / pr) * 1.6).normalized()
	e.vel = e.vel.lerp(dirv * speed, clampf(accel * dt, 0.0, 1.0))

static func chase(sim, e: SimEnemy, dt: float, mul: float = 1.0) -> void:
	move_to(sim, e, sim.player.pos, e.move_speed() * mul, dt)

static func stop(e: SimEnemy, dt: float, rate: float = 10.0) -> void:
	e.vel = e.vel.lerp(Vector2.ZERO, clampf(rate * dt, 0.0, 1.0))

## keeps between min_d and max_d from the player, strafing
static func kite(sim, e: SimEnemy, min_d: float, max_d: float, dt: float, mul: float = 1.0) -> void:
	var to = sim.player.pos - e.pos
	var d = to.length()
	var spd: float = e.move_speed() * mul
	var strafe: float = e.data.get("_strafe", 1.0)
	if d < min_d:
		move_to(sim, e, e.pos - to.normalized() * 120.0 + to.orthogonal().normalized() * 40.0 * strafe, spd, dt)
	elif d > max_d:
		move_to(sim, e, sim.player.pos, spd, dt)
	else:
		move_to(sim, e, e.pos + to.orthogonal().normalized() * 60.0 * strafe, spd * 0.55, dt)
	if sim.rng.randf() < dt * 0.4:
		e.data["_strafe"] = -strafe
	# don't get pinned into walls
	if sim.point_blocked(e.pos + e.vel.normalized() * (e.radius + 30.0), e.radius):
		e.data["_strafe"] = -strafe

static func lead(sim, e: SimEnemy, proj_speed: float, k: float = 0.6) -> Vector2:
	var p: SimPlayer = sim.player
	var t := e.pos.distance_to(p.pos) / maxf(1.0, proj_speed)
	return p.pos + p.vel * t * k

# ───────── telegraphed attacks ─────────

static func tele_circle(sim, e: SimEnemy, pos: Vector2, radius: float, windup: float, dmg: float, name: String, on_impact: Callable = Callable()) -> Tele:
	var t := Tele.make(sim, e, Tele.Shape.CIRCLE, windup, dmg, name)
	t.pos = pos
	t.radius = radius
	t.on_impact = on_impact
	return t

static func tele_cone(sim, e: SimEnemy, ang: float, radius: float, arc_deg: float, windup: float, dmg: float, name: String, on_impact: Callable = Callable()) -> Tele:
	var t := Tele.make(sim, e, Tele.Shape.CONE, windup, dmg, name)
	t.pos = e.pos
	t.angle = ang
	t.radius = radius
	t.arc = deg_to_rad(arc_deg)
	t.follow = true
	t.on_impact = on_impact
	return t

static func tele_line(sim, e: SimEnemy, ang: float, length: float, width: float, windup: float, dmg: float, name: String, on_impact: Callable = Callable()) -> Tele:
	var t := Tele.make(sim, e, Tele.Shape.LINE, windup, dmg, name)
	t.pos = e.pos
	t.angle = ang
	t.length = length
	t.width = width
	t.follow = true
	t.on_impact = on_impact
	return t

static func tele_ring(sim, e: SimEnemy, pos: Vector2, inner: float, outer: float, windup: float, dmg: float, name: String, on_impact: Callable = Callable()) -> Tele:
	var t := Tele.make(sim, e, Tele.Shape.RING, windup, dmg, name)
	t.pos = pos
	t.inner = inner
	t.radius = outer
	t.on_impact = on_impact
	return t

## an aim line that shows where a projectile will travel; it deals no damage itself
static func tele_aim(sim, e: SimEnemy, ang: float, length: float, width: float, windup: float, name: String, on_impact: Callable) -> Tele:
	var t := tele_line(sim, e, ang, length, width, windup, 0.0, name, on_impact)
	t.hits_player = false
	return t

# ───────── enemy projectiles (always red/orange) ─────────

static func shoot(sim, e, pos: Vector2, ang: float, speed: float, dmg: float, name: String, radius: float = 9.0, life: float = 2.5) -> SimProj:
	var pr := SimProj.new()
	pr.id = sim.new_id()
	pr.team = 1
	pr.pos = pos
	pr.prev = pos
	pr.vel = Geom.dir(ang) * speed
	pr.radius = radius
	pr.dmg = dmg
	pr.life = life
	pr.max_life = life
	pr.owner = e
	pr.attack_name = name
	pr.art = "e_bolt"
	pr.rot = ang
	sim.projectiles.append(pr)
	return pr

## lobbed projectile: lands at `target` after `time`, showing a landing circle telegraph
static func lob(sim, e: SimEnemy, target: Vector2, time: float, radius: float, dmg: float, name: String, on_land: Callable = Callable()) -> Tele:
	var t := tele_circle(sim, e, target, radius, time, dmg, name, on_land)
	t.follow = false
	t.data["lob_from"] = e.pos
	return t

static func ring_burst(sim, e, pos: Vector2, n: int, speed: float, dmg: float, name: String, offset: float = 0.0, gap: int = -1) -> void:
	for i in n:
		if gap >= 0 and (i == gap or i == (gap + 1) % n):
			continue
		shoot(sim, e, pos, offset + TAU * float(i) / float(n), speed, dmg, name)
