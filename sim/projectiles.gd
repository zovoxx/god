class_name Projectiles
extends RefCounted
## Moves projectiles and resolves their hits. Player projectiles (team 0) hit enemies;
## enemy projectiles (team 1) hit the player's small hitbox.

static func player_shot(sim, pos: Vector2, ang: float, speed: float, dmg: float, slot: String, power: float, radius: float, art: String, life: float = 1.0) -> SimProj:
	var pr := SimProj.new()
	pr.id = sim.new_id()
	pr.team = 0
	pr.pos = pos
	pr.prev = pos
	pr.vel = Geom.dir(ang) * speed
	pr.rot = ang
	pr.dmg = dmg
	pr.slot = slot
	pr.power = power
	pr.radius = radius
	pr.art = art
	pr.life = life
	pr.max_life = life
	sim.projectiles.append(pr)
	return pr

static func update_all(sim, dt: float) -> void:
	var p: SimPlayer = sim.player
	var keep: Array = []
	for pr in sim.projectiles:
		if not pr.alive:
			continue
		pr.life -= dt
		match pr.kind:
			SimProj.Kind.HALO:
				if sim.weapon != null and sim.weapon.has_method("update_halo"):
					sim.weapon.update_halo(sim, pr, dt)
			SimProj.Kind.ORBIT:
				_orbit(sim, pr, dt)
			SimProj.Kind.HOMING:
				var tgt: Vector2 = p.pos if pr.team == 1 else pr.data.get("target_pos", pr.pos + pr.vel)
				var want = (tgt - pr.pos).normalized() * pr.vel.length()
				pr.vel = pr.vel.lerp(want, clampf(float(pr.data.get("turn", 2.0)) * dt, 0.0, 1.0))
				pr.pos += pr.vel * dt
			_:
				pr.pos += pr.vel * dt
		if pr.kind != SimProj.Kind.ORBIT:
			pr.rot = pr.vel.angle() if pr.vel.length() > 1.0 else pr.rot
		if pr.life <= 0.0:
			_expire(sim, pr)
			continue
		if pr.data.get("bounce", false):
			var r: Rect2 = sim.arena.rect
			if pr.pos.x < r.position.x + pr.radius or pr.pos.x > r.end.x - pr.radius:
				pr.vel.x = -pr.vel.x
				pr.pos.x = clampf(pr.pos.x, r.position.x + pr.radius, r.end.x - pr.radius)
			if pr.pos.y < r.position.y + pr.radius or pr.pos.y > r.end.y - pr.radius:
				pr.vel.y = -pr.vel.y
				pr.pos.y = clampf(pr.pos.y, r.position.y + pr.radius, r.end.y - pr.radius)
		elif pr.hit_walls and pr.kind != SimProj.Kind.HALO and pr.kind != SimProj.Kind.ORBIT and sim.point_blocked(pr.pos, 2.0):
			sim.fire(&"projectile_wall", {"pos": pr.pos, "team": pr.team})
			_expire(sim, pr)
			continue
		if pr.team == 0:
			for e in sim.enemies:
				if not e.targetable() or pr.hits.has(e.id):
					continue
				if Geom.in_circle(pr.pos, pr.radius, e.pos, e.radius):
					pr.hits[e.id] = true
					var h := HitInfo.make(pr.dmg, pr.slot, pr.power, pr.vel if pr.vel != Vector2.ZERO else (e.pos - pr.pos), pr.pos)
					h.knock = pr.knock
					h.crit_bonus = pr.crit_bonus
					h.source_id = pr.id
					if pr.data.has("force_crit"):
						h.force_crit = true
					Combat.deal(sim, e, h)
					if pr.data.has("on_hit"):
						pr.data.on_hit.call(e)
					pr.pierce -= 1
					if pr.pierce < 0 and pr.kind != SimProj.Kind.HALO and pr.kind != SimProj.Kind.ORBIT:
						pr.alive = false
						break
		elif pr.owner == null or not (pr.owner is SimEnemy) or pr.owner.alive or pr.data.get("survive_owner", true):
			if Geom.in_circle(pr.pos, pr.radius, p.pos, p.hit_radius):
				if p.is_invuln():
					pass
				elif Combat.hurt_player(sim, pr.dmg, pr.owner.pos if pr.owner != null and pr.owner is SimEnemy else pr.pos - pr.vel.normalized() * 30.0, pr.owner if pr.owner == null or pr.owner.alive else SourceRef.of(pr.owner), pr.attack_name):
					if pr.data.has("on_hit_player"):
						pr.data.on_hit_player.call()
					if pr.kind != SimProj.Kind.ORBIT:
						pr.alive = false
		if pr.alive:
			keep.append(pr)
	sim.projectiles = keep

static func _orbit(sim, pr: SimProj, dt: float) -> void:
	var o = pr.owner if pr.team == 1 else sim.player
	if o == null or not o.alive:
		pr.alive = false
		return
	pr.data["ang"] = float(pr.data.get("ang", 0.0)) + float(pr.data.get("spin", 3.2)) * dt
	var r: float = float(pr.data.get("orbit_r", 40.0))
	pr.pos = o.pos + Geom.dir(pr.data.ang) * r
	pr.rot = float(pr.data.ang) * 2.0
	if pr.team == 0:
		# player orbiters re-hit each enemy on a timer
		pr.data["rehit"] = float(pr.data.get("rehit", 0.0)) - dt
		if pr.data.rehit <= 0.0:
			pr.data["rehit"] = float(pr.data.get("tick", 0.15))
			pr.hits.clear()

static func _expire(sim, pr: SimProj) -> void:
	pr.alive = false
	if pr.data.has("on_expire"):
		pr.data.on_expire.call()
