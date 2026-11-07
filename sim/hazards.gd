class_name Hazards
extends RefCounted
## Floor area effects for both teams. Enemy hazards always warn (two pulses) before they hurt.

static func _make(sim, team: int, pos: Vector2, radius: float) -> SimHazard:
	var h := SimHazard.new()
	h.id = sim.new_id()
	h.team = team
	h.pos = pos
	h.radius = radius
	sim.hazards.append(h)
	return h

## a single delayed blast that hurts enemies (Sigil, fissures, starfall hits)
static func player_blast(sim, pos: Vector2, radius: float, delay: float, dmg: float, slot: String, power: float) -> SimHazard:
	var h := _make(sim, 0, pos, radius)
	h.kind = "blast"
	h.delay = delay
	h.life = delay + 0.25
	h.dmg = dmg
	h.slot = slot
	h.power = power
	h.hits_left = 1
	h.color = Cfg.col("player_gold")
	return h

## repeated hits over time (rain / fields)
static func player_field(sim, pos: Vector2, radius: float, delay: float, duration: float, tick: float, dmg: float, slot: String, power: float, kind: String = "field") -> SimHazard:
	var h := _make(sim, 0, pos, radius)
	h.kind = kind
	h.delay = delay
	h.life = delay + duration
	h.tick = tick
	h.hits_left = 9999
	h.dmg = dmg
	h.slot = slot
	h.power = power
	h.color = Cfg.col("player_gold")
	return h

## a line strike from the player (Anvil fissure)
static func player_line(sim, pos: Vector2, ang: float, length: float, width: float, delay: float, dmg: float, slot: String, power: float) -> SimHazard:
	var h := player_blast(sim, pos, 0.0, delay, dmg, slot, power)
	h.shape = SimHazard.Shape.LINE
	h.angle = ang
	h.length = length
	h.width = width
	h.kind = "fissure"
	return h

## enemy floor hazard: warns (pulses twice) for `warn` seconds, then hurts while active
static func enemy_field(sim, owner, pos: Vector2, radius: float, warn: float, duration: float, dmg: float, name: String, kind: String = "field") -> SimHazard:
	var h := _make(sim, 1, pos, radius)
	h.owner = owner
	h.kind = kind
	h.warn = maxf(warn, float(sim.F.telegraph.hazard_warn_time) if kind == "vent" or kind == "spikes" or kind == "pool" else warn)
	h.life = h.warn + duration
	h.dmg = dmg
	h.attack_name = name
	h.tick = 0.6
	h.hits_left = 9999
	h.color = Cfg.col("danger")
	return h

static func update_all(sim, dt: float) -> void:
	var keep: Array = []
	var p: SimPlayer = sim.player
	for h in sim.hazards:
		if not h.alive:
			continue
		h.t += dt
		if h.t > h.life:
			continue
		keep.append(h)
		if not h.active():
			continue
		if h.team == 0:
			h.tick_t -= dt
			if h.tick_t <= 0.0 and h.hits_left > 0:
				h.hits_left -= 1
				h.tick_t = h.tick if h.tick > 0.0 else 999.0
				_hit_enemies(sim, h)
				if h.tick <= 0.0:
					sim.fire(&"hazard_burst", {"id": h.id, "pos": h.pos, "radius": h.radius, "kind": h.kind, "shape": h.shape, "angle": h.angle, "length": h.length, "width": h.width})
		else:
			if h.contains(p.pos, p.hit_radius):
				h.tick_t -= dt
				if h.tick_t <= 0.0:
					if Combat.hurt_player(sim, h.dmg, h.pos, h.owner if h.owner != null else h, h.attack_name):
						h.tick_t = h.tick
			else:
				h.tick_t = 0.0
	sim.hazards = keep

static func _hit_enemies(sim, h: SimHazard) -> void:
	for e in sim.enemies:
		if not e.targetable():
			continue
		if h.contains(e.pos, e.radius):
			var dir: Vector2 = (e.pos - h.pos).normalized() if h.shape != SimHazard.Shape.LINE else Geom.dir(h.angle)
			var hit := HitInfo.make(h.dmg, h.slot, h.power, dir, h.pos)
			hit.knock = h.knock
			hit.source_id = h.id
			if h.data.has("crit_bonus"):
				hit.crit_bonus = h.data.crit_bonus
			if h.data.has("armor_break"):
				hit.armor_break = h.data.armor_break
			Combat.deal(sim, e, hit)
			if h.root > 0.0 and e.alive and not e.is_boss:
				e.root_t = maxf(e.root_t, h.root * (0.5 if e.is_guardian else 1.0))
			if h.data.has("pull") and e.alive and not e.no_knock:
				e.kvel += (h.pos - e.pos).normalized() * float(h.data.pull) / maxf(0.5, e.mass)
