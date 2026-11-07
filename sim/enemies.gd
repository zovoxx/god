class_name Enemies
extends RefCounted
## Enemy creation, spawning (portals), per-step update, integration and wall slams.
## Brains (AI) are registered by id in BRAINS; content scripts add themselves in `_brains()`.

static var _brain_cache := {}

static func brain_for(kind: String):
	if _brain_cache.is_empty():
		_brain_cache = Brains.all()
	return _brain_cache.get(kind, _brain_cache.get("_default"))

static func def_for(sim, kind: String) -> Dictionary:
	if sim.T.enemies.has(kind):
		return sim.T.enemies[kind]
	if sim.T.bosses.has(kind):
		return sim.T.bosses[kind]
	push_error("unknown enemy kind " + kind)
	return sim.T.enemies["dummy"]

## creates an enemy (not yet added). depth 1..4 scales HP/damage.
static func make(sim, kind: String, depth: int = 1) -> SimEnemy:
	var d := def_for(sim, kind)
	var e := SimEnemy.new()
	e.id = sim.new_id()
	e.kind = kind
	e.def = d
	e.name = d.get("name", kind)
	e.depth = depth
	e.art = d.get("art", kind)
	e.radius = float(d.get("radius", 16))
	e.mass = float(d.get("mass", 1.0))
	e.speed = float(d.get("speed", 100))
	e.flying = bool(d.get("flying", false))
	e.super_armor = bool(d.get("super_armor", false))
	e.stagger_immune = bool(d.get("stagger_immune", false))
	e.no_knock = bool(d.get("no_knock", false))
	e.optional = bool(d.get("optional", false))
	e.front_shield = deg_to_rad(float(d.get("front_shield", 0.0)))
	e.is_boss = bool(d.get("boss", false))
	e.is_guardian = bool(d.get("guardian", false))
	var S: Dictionary = sim.T.scaling
	var di := clampi(depth - 1, 0, 3)
	var hp_mul: float = float(S.hp_by_depth[di])
	var dmg_mul: float = float(S.dmg_by_depth[di])
	if e.is_boss:
		hp_mul *= float(S.boss_hp)
		dmg_mul *= float(S.boss_dmg)
	elif e.is_guardian:
		hp_mul *= float(S.guardian_hp)
		dmg_mul *= float(S.guardian_dmg)
	if sim.run != null:
		hp_mul *= sim.run.enemy_hp_mul()
		dmg_mul *= sim.run.enemy_dmg_mul()
	e.max_hp = round(float(d.get("hp", 10)) * hp_mul)
	e.hp = e.max_hp
	e.dmg_mul = dmg_mul
	e.armor = float(d.get("armor", 0)) * hp_mul
	e.max_armor = e.armor
	e.brain = brain_for(kind)
	e.facing = PI * 0.5
	return e

## spawns through a portal (harmless + invulnerable for pacing.spawn_portal seconds)
static func spawn(sim, kind: String, pos: Vector2, depth: int = 1, opts: Dictionary = {}) -> SimEnemy:
	var e := make(sim, kind, depth)
	e.pos = pos
	e.prev = pos
	if opts.get("portal", true):
		e.spawn_t = float(sim.T.pacing.spawn_portal)
	e.summoned = bool(opts.get("summoned", false))
	if opts.has("hp_mul"):
		e.max_hp = round(e.max_hp * float(opts.hp_mul))
		e.hp = e.max_hp
	if opts.has("elites") and not opts.elites.is_empty():
		Elites.apply(sim, e, opts.elites)
	if e.brain != null:
		e.brain.init(sim, e)
	sim.enemies.append(e)
	sim.fire(&"enemy_spawning", {"id": e.id, "kind": kind, "pos": pos, "time": e.spawn_t, "boss": e.is_boss, "elite": not e.elites.is_empty()})
	return e

## a point at least spawn_min_dist from the player, inside the arena
static func spawn_point(sim, r: float, near: bool = false) -> Vector2:
	var P: Dictionary = sim.T.pacing
	var mn: float = P.spawn_min_dist
	var mx: float = P.spawn_max_dist if near else P.spawn_max_dist * 1.6
	for i in 60:
		var p: Vector2 = sim.random_free_point(mn, mx, sim.player.pos, r)
		if p.distance_to(sim.player.pos) >= mn:
			return p
	# arena corner furthest from the player
	var rect: Rect2 = sim.arena.rect
	var best := rect.get_center()
	var bd := -1.0
	for c in [rect.position + Vector2(r + 20, r + 20), Vector2(rect.end.x - r - 20, rect.position.y + r + 20), rect.end - Vector2(r + 20, r + 20), Vector2(rect.position.x + r + 20, rect.end.y - r - 20)]:
		var d: float = c.distance_to(sim.player.pos)
		if d > bd:
			bd = d
			best = c
	return best

static func update_all(sim, dt: float) -> void:
	var F: GameFeel = sim.F
	for e in sim.enemies:
		if not e.alive:
			continue
		e.flash_t = maxf(0.0, e.flash_t - dt)
		e.countered_t = maxf(0.0, e.countered_t - dt)
		e.glow = maxf(0.0, e.glow - dt * 3.0)
		_squash_spring(e, dt, F)
		if e.spawn_t > 0.0:
			e.spawn_t -= dt
			if e.spawn_t <= 0.0:
				sim.fire(&"enemy_spawned", {"id": e.id, "kind": e.kind, "pos": e.pos})
			continue
		Status.tick(sim, e, dt)
		if not e.alive:
			continue
		if not e.elites.is_empty():
			Elites.update(sim, e, dt)
		e.stagger_t = maxf(0.0, e.stagger_t - dt)
		e.root_t = maxf(0.0, e.root_t - dt)
		if e.can_act() and not sim.no_ai and e.brain != null:
			e.brain.update(sim, e, dt)
		elif not e.can_act():
			e.vel = e.vel * 0.8
			if e.tele != null and e.freeze_t > 0.0:
				Tele.cancel(sim, e.tele)
				e.tele = null
		_finisher_state(sim, e)
		_integrate(sim, e, dt)
		if e.contact_on and e.contact > 0.0:
			e.contact_hit_t -= dt
			if e.contact_hit_t <= 0.0 and Geom.in_circle(sim.player.pos, sim.player.hit_radius, e.pos, e.radius):
				if Combat.hurt_player(sim, e.contact * e.dmg_mul, e.pos, e, e.attack_name if e.attack_name != "" else "Contact"):
					e.contact_hit_t = 0.6
	_separate(sim)

static func _finisher_state(sim, e: SimEnemy) -> void:
	var thr: float = sim.F.finisher.hp_frac
	e.finishable = e.staggered() and e.hp_frac() <= thr and not e.is_boss

static func _squash_spring(e: SimEnemy, dt: float, F: GameFeel) -> void:
	# damped spring back to 0 (overshoots a little for a wobble)
	var k: float = F.squash.freq
	var d: float = F.squash.damp
	var v: float = e.data.get("_sqv", 0.0)
	v += (-e.squash * k * k - v * d) * dt
	e.squash += v * dt
	e.data["_sqv"] = v

static func _integrate(sim, e: SimEnemy, dt: float) -> void:
	var F: GameFeel = sim.F
	e.kvel = e.kvel * exp(-float(F.knockback.friction) * dt)
	var mv := e.vel
	if e.root_t > 0.0 or e.freeze_t > 0.0:
		mv = Vector2.ZERO
	e.pos += (mv + e.kvel) * dt
	var speed_before: float = e.kvel.length()
	var n: Vector2 = sim.collide_arena(e, e.radius)
	if n != Vector2.ZERO and speed_before > float(F.knockback.slam_speed) and e.kvel.dot(n) < 0.0:
		Combat.wall_slam(sim, e, n, speed_before)
	elif n != Vector2.ZERO and e.kvel.dot(n) < 0.0:
		e.kvel = e.kvel.slide(n)

static func _separate(sim) -> void:
	var list: Array = sim.enemies
	var n := list.size()
	for i in n:
		var a: SimEnemy = list[i]
		if not a.alive or a.spawn_t > 0.0:
			continue
		for j in range(i + 1, n):
			var b: SimEnemy = list[j]
			if not b.alive or b.spawn_t > 0.0 or a.flying != b.flying:
				continue
			var d := b.pos - a.pos
			var rr := a.radius + b.radius
			var l2 := d.length_squared()
			if l2 < rr * rr and l2 > 0.0001:
				var l := sqrt(l2)
				var push := (rr - l) * 0.5
				var nn := d / l
				var wa := b.mass / (a.mass + b.mass)
				a.pos -= nn * push * wa
				b.pos += nn * push * (1.0 - wa)
		# never overlap the player (keeps the hitbox honest)
		var pd = a.pos - sim.player.pos
		var pr = a.radius + sim.player.radius * 0.7
		if pd.length_squared() < pr * pr and pd.length_squared() > 0.0001 and not a.flying:
			a.pos = sim.player.pos + pd.normalized() * pr

static func kill(sim, e: SimEnemy) -> void:
	e.alive = false
	if e.tele != null:
		Tele.cancel(sim, e.tele)
		e.tele = null
	if e.brain != null:
		e.brain.on_death(sim, e)
	if not e.elites.is_empty():
		Elites.on_death(sim, e)

static func cleanup(sim) -> void:
	var keep: Array = []
	for e in sim.enemies:
		if e.alive:
			keep.append(e)
	sim.enemies = keep
