class_name BotBrain
extends RefCounted
## A simple but honest bot: it only uses information a player can see (telegraph shapes,
## projectiles, hazards, HP) and produces the same InputFrames as a keyboard or gamepad.

var rng := RandomNumberGenerator.new()
var t := 0
var door_choice := -1
var special_cd := 0.0
var cast_cd := 0.0
var charge_t := 0
var strafe := 1.0

const RANGE := {"fangs": 70.0, "pike": 135.0, "anvil": 95.0, "bow": 360.0, "halo": 240.0}

func _init(seed_v: int) -> void:
	rng.seed = seed_v

func think(sim: Sim) -> InputFrame:
	t += 1
	var f := InputFrame.new()
	f.aim_source = InputFrame.Aim.MOUSE
	var p := sim.player
	var flow: RoomFlow = sim.flow
	f.aim_point = p.pos + p.aim_dir * 100.0
	if p.state == SimPlayer.St.DEAD:
		return f
	special_cd -= 1.0 / 60.0
	cast_cd -= 1.0 / 60.0
	if t % 180 == 0:
		strafe = -strafe
	match flow.state:
		RoomFlow.S.OFFER, RoomFlow.S.ORDEAL, RoomFlow.S.SHOP:
			_choose(sim)
			return f
		RoomFlow.S.DOORS, RoomFlow.S.SPRING:
			return _walk_doors(sim, f)
		RoomFlow.S.REWARD, RoomFlow.S.CLEAR, RoomFlow.S.ENTER, RoomFlow.S.EXIT:
			door_choice = -1
			return f
	door_choice = -1
	return _fight(sim, f)

# ───────── combat ─────────

func _fight(sim: Sim, f: InputFrame) -> InputFrame:
	var p := sim.player
	var target = _target(sim)
	var danger := _danger(sim)
	var move := Vector2.ZERO
	var wid: String = sim.weapon.id
	var rng_want: float = RANGE.get(wid, 90.0)
	if target != null:
		f.aim_point = target.pos + target.vel * 0.1
		var to: Vector2 = target.pos - p.pos
		var d := to.length()
		if target.front_shield > 0.0 and target.st == 0:
			# flank shielded enemies and Sigil them
			var behind: Vector2 = target.pos - Geom.dir(target.facing) * 70.0
			to = behind - p.pos
			if cast_cd <= 0.0 and p.cast_charges > 0 and d < 260.0:
				f.cast_p = true
				cast_cd = 2.0
		if d > rng_want * 0.9:
			move = to.normalized()
		elif d < rng_want * (0.45 if rng_want > 150.0 else 0.25):
			move = -to.normalized()
		else:
			move = to.normalized().orthogonal() * strafe * 0.5
		var guarded: bool = target.data.get("guard", false)
		if guarded:
			move = -to.normalized()
		# attacks
		if not guarded and (d < rng_want * 1.15 or wid == "bow" or wid == "halo"):
			if wid == "bow":
				charge_t += 1
				if charge_t % 40 < 32 and d > 200.0:
					f.attack_h = true
					f.attack_p = charge_t % 40 == 1
				else:
					f.attack_p = charge_t % 12 == 0
			else:
				f.attack_p = t % 6 == 0
				f.attack_h = true
		if special_cd <= 0.0 and d < rng_want * 1.6:
			f.special_p = true
			f.special_h = true
			special_cd = rng.randf_range(2.5, 4.5)
		if p.state == SimPlayer.St.SPECIAL:
			f.special_h = t % 90 < 50
		if cast_cd <= 0.0 and p.cast_charges > 0:
			var crowd := 0
			for e in sim.enemies:
				if e.targetable() and e.pos.distance_to(target.pos) < 140.0:
					crowd += 1
			if crowd >= 3 or target.is_boss or target.is_guardian:
				f.cast_p = true
				cast_cd = 2.0
	# danger overrides movement
	if danger.v != Vector2.ZERO:
		move = (danger.v.normalized() * 1.6 + move * 0.3).normalized()
		if danger.urgent and p.dash_charges > 0:
			f.dash_p = true
	# don't hug walls
	var r: Rect2 = sim.arena.rect
	var c := r.get_center()
	if not r.grow(-80.0).has_point(p.pos):
		move = (move + (c - p.pos).normalized() * 0.8).normalized()
	# shake off clinging mites
	if p.latched >= 2 and p.dash_charges > 0:
		f.dash_p = true
	f.move = move
	return f

func _target(sim: Sim):
	var p := sim.player
	var best = null
	var bs := INF
	for e in sim.enemies:
		if not e.targetable() or e.invuln:
			continue
		var s: float = e.pos.distance_to(p.pos) + e.hp * 0.3
		if e.kind == "pylon" or e.kind == "voidportal":
			s -= 120.0
		if s < bs:
			bs = s
			best = e
	return best

## escape vector from everything that is about to hurt
func _danger(sim: Sim) -> Dictionary:
	var p := sim.player
	var v := Vector2.ZERO
	var urgent := false
	for tl in sim.telegraphs:
		if tl.resolved or not tl.hits_player:
			continue
		if tl.contains(p.pos, p.hit_radius + 18.0):
			var away: Vector2
			match tl.shape:
				Tele.Shape.LINE:
					var dirv := Geom.dir(tl.angle)
					var rel = p.pos - tl.pos
					var side := signf(rel.cross(dirv))
					away = dirv.orthogonal() * (-side if side != 0.0 else 1.0)
				Tele.Shape.RING:
					var dd := p.pos.distance_to(tl.pos)
					away = (p.pos - tl.pos).normalized() * (1.0 if dd > (tl.inner + tl.radius) * 0.5 else -1.0)
				_:
					away = (p.pos - tl.pos).normalized()
			if away == Vector2.ZERO:
				away = Vector2.RIGHT
			v += away * (2.0 if tl.time_left() < 0.4 else 1.0)
			if tl.time_left() < 0.22 and tl.dmg > 0.0:
				urgent = true
	for pr in sim.projectiles:
		if pr.team != 1 or not pr.alive:
			continue
		var rel: Vector2 = p.pos - pr.pos
		if rel.length() > 220.0 or pr.vel.length() < 10.0:
			continue
		if rel.dot(pr.vel) <= 0.0:
			continue
		var miss: float = absf(rel.cross(pr.vel.normalized()))
		if miss < p.hit_radius + pr.radius + 14.0:
			var side := signf(rel.cross(pr.vel))
			v += pr.vel.normalized().orthogonal() * (side if side != 0.0 else 1.0) * 1.5
			if rel.length() < 90.0:
				urgent = true
	for e in sim.enemies:
		if not e.alive:
			continue
		var beams: Array = []
		if e.data.has("beam_a"):
			beams.append(float(e.data.beam_a))
		for la in e.data.get("lasers", []):
			beams.append(float(la))
		for ang in beams:
			var dv := Geom.dir(ang)
			var rel2: Vector2 = p.pos - e.pos
			if absf(rel2.cross(dv)) < 90.0 and rel2.dot(dv) > 0.0:
				v += dv.orthogonal() * signf(rel2.cross(dv)) * -1.5
		if e.data.has("well") or e.data.has("grav_t") or not (e.data.get("wells", []) as Array).is_empty():
			var c: Vector2 = e.data.get("well", e.data.get("grav_c", e.pos))
			if p.pos.distance_to(c) < 280.0:
				v += (p.pos - c).normalized() * 2.0
				urgent = urgent or p.pos.distance_to(c) < 120.0
	for h in sim.hazards:
		if h.team == 1 and h.alive and h.contains(p.pos, p.hit_radius + 10.0):
			v += (p.pos - h.pos).normalized()
	for e in sim.enemies:
		if e.alive and e.contact_on and e.pos.distance_to(p.pos) < e.radius + 80.0:
			v += (p.pos - e.pos).normalized() * 1.5
			urgent = true
	return {"v": v, "urgent": urgent}

# ───────── choices ─────────

func _choose(sim: Sim) -> void:
	var flow: RoomFlow = sim.flow
	var p := sim.player
	match flow.state:
		RoomFlow.S.OFFER:
			var opts: Array = flow.offer.get("options", [])
			var best := 0
			var bs := -INF
			for i in opts.size():
				var o: Dictionary = opts[i]
				var s := float(o.get("rarity", 0)) * 2.0 + rng.randf()
				if o.get("slot", "") in ["attack", "special"]:
					s += 2.0
				if o.get("duo", false) or o.get("slot", "") == "legendary":
					s += 4.0
				if o.get("id", "") in ["vital", "mend"] and p.hp < p.max_hp * 0.5:
					s += 6.0
				if s > bs:
					bs = s
					best = i
			flow.choose(best)
		RoomFlow.S.ORDEAL:
			flow.choose(0 if p.hp > p.max_hp * 0.6 else 1)
		RoomFlow.S.SHOP:
			for i in flow.shop.size():
				var it: Dictionary = flow.shop[i]
				if it.sold:
					continue
				var want := false
				if it.id == "heal" and p.hp < p.max_hp * 0.7:
					want = true
				elif it.get("actions", [{}])[0].get("type", "") == "boon":
					want = true
				elif it.id == "heart":
					want = true
				if want and sim.run.gold >= int(it.price):
					flow.buy(i)
			flow.leave_shop()

func _walk_doors(sim: Sim, f: InputFrame) -> InputFrame:
	var flow: RoomFlow = sim.flow
	var p := sim.player
	if flow.state == RoomFlow.S.SPRING and not flow.spring_used and p.hp < p.max_hp * 0.95:
		f.move = (Vector2.ZERO - p.pos).normalized()
		return f
	if flow.doors.is_empty() or flow.doors_lit < flow.doors.size():
		return f
	if door_choice < 0:
		door_choice = 0
		var bs := -INF
		for i in flow.doors.size():
			var plan: Dictionary = flow.doors[i].plan
			var s := rng.randf()
			if plan.type == "spring" and p.hp < p.max_hp * 0.6:
				s += 5.0
			if plan.type == "shop" and sim.run.gold >= 120:
				s += 2.0
			if plan.get("reward", "") == "boon":
				s += 1.0
			if plan.type == "elite" and p.hp < p.max_hp * 0.5:
				s -= 3.0
			if s > bs:
				bs = s
				door_choice = i
	var target: Vector2 = flow.doors[door_choice].pos
	f.move = (target - p.pos).normalized()
	return f
