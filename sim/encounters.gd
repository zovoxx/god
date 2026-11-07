class_name Encounters
extends RefCounted
## Builds combat waves from ROLE templates (front line, back line, support...) filled with
## enemies of that role from the current depth's pool (plus a few from the previous depth,
## and invaders from the next one at Deepening II). Then runs the waves: a new wave comes in
## when the current one is down to a third, or after a timeout.

const TEMPLATES := [
	{"name": "Rush", "slots": [["front", 2, 3], ["swarm", 0, 1]], "w": 1.2},
	{"name": "Wall & Guns", "slots": [["tank", 1, 2], ["back", 1, 2]]},
	{"name": "Siege", "slots": [["zone", 1, 2], ["front", 1, 3]]},
	{"name": "Protected Core", "slots": [["support", 1, 1], ["tank", 1, 1], ["front", 1, 2]], "min_step": 1},
	{"name": "Hunters", "slots": [["disrupt", 2, 2], ["front", 1, 1]]},
	{"name": "Swarm", "slots": [["swarm", 2, 3], ["zone", 0, 1]]},
	{"name": "Crossfire", "slots": [["back", 2, 2], ["disrupt", 1, 1]], "min_step": 1},
	{"name": "Artillery Line", "slots": [["zone", 1, 1], ["back", 1, 1], ["tank", 1, 1]], "min_step": 2},
	{"name": "Warband", "slots": [["support", 1, 1], ["front", 2, 3]], "min_step": 1},
	{"name": "Ambush", "slots": [["disrupt", 1, 1], ["swarm", 1, 2], ["front", 1, 1]]},
	{"name": "Fortress", "slots": [["tank", 2, 2], ["support", 0, 1], ["zone", 0, 1]], "min_step": 2},
	{"name": "Chaos", "slots": [["front", 1, 1], ["back", 1, 1], ["zone", 1, 1], ["disrupt", 1, 1]], "min_step": 3},
]

const PLACE := {"front": "near", "tank": "near", "swarm": "ring", "back": "far", "zone": "far", "support": "far", "disrupt": "flank"}

## candidates for a role at a depth (1..4), weighted
static func candidates(T: Tuning, depth: int, role: String, deepening: int) -> Array:
	var out: Array = []
	for id in T.enemies.keys():
		var d: Dictionary = T.enemies[id]
		var dd := int(d.get("depth", 0))
		if dd <= 0 or d.get("summon", false):
			continue
		if int(d.get("unlock", 0)) > deepening:
			continue
		var roles: Array = d.get("roles", [])
		if not roles.has(role):
			continue
		var w := 0.0
		if dd == depth:
			w = 1.0
		elif dd == depth - 1:
			w = 0.28
		elif deepening >= 2 and dd == depth + 1:
			w = 0.12
		if w <= 0.0:
			continue
		if roles[0] == role:
			w *= 1.3
		out.append({"id": id, "w": w, "def": d})
	return out

static func _weighted(rng: RandomNumberGenerator, items: Array, weight: Callable):
	var total := 0.0
	for it in items:
		total += maxf(0.0, weight.call(it))
	if total <= 0.0:
		return null
	var r := rng.randf() * total
	for it in items:
		r -= maxf(0.0, weight.call(it))
		if r <= 0.0:
			return it
	return items[-1]

## plan the waves for a room. type: combat | elite | guardian-adds | gauntlet
static func plan(T: Tuning, rng: RandomNumberGenerator, depth: int, step: int, type: String, deepening: int, extra_elites: int = 0) -> Array:
	var waves: Array = []
	var n_waves := 3
	var budget := 7.4 + step * 0.9 + (depth - 1) * 1.5
	var elite_count := 0
	if type == "elite":
		budget *= 1.1
		elite_count = 2 + (1 if depth >= 3 else 0)
	elif type == "gauntlet":
		n_waves = 4
		budget *= 1.2
		elite_count = 2
	if depth == 1 and step == 0:
		budget = 4.5
	elite_count += extra_elites
	var used := {}
	for w in n_waves:
		var wave_budget := budget * (0.8 if w == 0 else 1.0 + w * 0.12)
		var pool: Array = TEMPLATES.filter(func(t): return int(t.get("min_step", 0)) <= step + (depth - 1) * 2 and not used.has(t.name))
		if pool.is_empty():
			pool = TEMPLATES.duplicate()
		var tpl: Dictionary = _weighted(rng, pool, func(t): return float(t.get("w", 1.0)))
		used[tpl.name] = true
		var groups: Array = []
		var counts := {}
		var spent := 0.0
		for slot in tpl.slots:
			var role: String = slot[0]
			var cands := candidates(T, depth, role, deepening)
			if cands.is_empty():
				continue
			var units := rng.randi_range(int(slot[1]), int(slot[2]))
			for u in units:
				var pick = _weighted(rng, cands, func(c):
					var mx := int(c.def.get("max", 99))
					if int(counts.get(c.id, 0)) >= mx:
						return 0.0
					return float(c.w) * (0.55 if counts.has(c.id) else 1.0))
				if pick == null:
					continue
				var size := int(pick.def.get("group", 1))
				var cost := float(pick.def.get("cost", 1.0)) * size
				if spent + cost > wave_budget * 1.25 and not groups.is_empty():
					continue
				spent += cost
				counts[pick.id] = int(counts.get(pick.id, 0)) + size
				groups.append({"kind": pick.id, "count": size, "place": PLACE.get(role, "near"), "elites": []})
		var guard := 0
		while spent < wave_budget and guard < 8:
			guard += 1
			var cands2 := candidates(T, depth, "front" if rng.randf() < 0.5 else "swarm", deepening)
			var fill = _weighted(rng, cands2, func(c): return 0.0 if int(counts.get(c.id, 0)) >= int(c.def.get("max", 99)) else float(c.w))
			if fill == null:
				break
			var size2 := int(fill.def.get("group", 1))
			spent += float(fill.def.get("cost", 1.0)) * size2
			counts[fill.id] = int(counts.get(fill.id, 0)) + size2
			groups.append({"kind": fill.id, "count": size2, "place": "near", "elites": []})
		# elites: promote single units
		var singles: Array = groups.filter(func(g): return g.count == 1 and not T.enemies[g.kind].get("no_elite", false))
		var k := 0
		if elite_count > 0:
			k = 1 if w == 0 else int(ceil(float(elite_count) / maxf(1.0, n_waves - 1.0)))
		elif depth >= 2 and rng.randf() < 0.12 + (depth - 1) * 0.06:
			k = 1
		for i in k:
			if singles.is_empty():
				break
			var gidx := rng.randi_range(0, singles.size() - 1)
			var g: Dictionary = singles[gidx]
			singles.remove_at(gidx)
			var mods := 2 if deepening >= 2 and rng.randf() < 0.4 else 1
			g.elites = Elites.roll(rng, mods, deepening)
		waves.append({"name": tpl.name, "groups": groups})
	return waves

# ───────────────────────── running waves ─────────────────────────

class Runner extends RefCounted:
	var waves: Array = []
	var index := -1
	var wave_ids: Array = []
	var wave_t := 0.0
	var delay := 0.0
	var depth := 1
	var done := false

	func start(w: Array, d: int, first_delay: float) -> void:
		waves = w
		depth = d
		index = -1
		delay = first_delay
		done = waves.is_empty()

	func update(sim, dt: float) -> void:
		if done:
			return
		if delay > 0.0:
			delay -= dt
			if delay <= 0.0:
				_spawn_next(sim)
			return
		wave_t += dt
		var alive := 0
		for e in sim.enemies:
			if e.alive and wave_ids.has(e.id):
				alive += 1
		var P: Dictionary = sim.T.pacing
		var thresh := int(floor(float(wave_ids.size()) * float(P.next_wave_at)))
		if index < waves.size() - 1 and (alive <= thresh or wave_t > float(P.wave_max_time)):
			_spawn_next(sim)
		elif index >= waves.size() - 1:
			done = true

	func _spawn_next(sim) -> void:
		index += 1
		wave_t = 0.0
		wave_ids.clear()
		var wave: Dictionary = waves[index]
		sim.fire(&"wave_started", {"index": index, "count": waves.size(), "name": wave.name})
		var p: SimPlayer = sim.player
		var ring_i := 0
		for g in wave.groups:
			var base := _place(sim, String(g.place), ring_i)
			ring_i += 1
			for u in int(g.count):
				var pos := base
				if int(g.count) > 1:
					pos = base + Geom.dir(TAU * u / float(g.count) + sim.rng.randf()) * 34.0
				var e := Enemies.spawn(sim, g.kind, pos, depth, {"elites": g.elites})
				wave_ids.append(e.id)

	func _place(sim, place: String, i: int) -> Vector2:
		var p: SimPlayer = sim.player
		var P: Dictionary = sim.T.pacing
		var mn: float = P.spawn_min_dist
		match place:
			"far":
				return sim.random_free_point(320.0, 560.0, p.pos, 30.0)
			"flank":
				var side := p.aim_dir.orthogonal() * (1.0 if i % 2 == 0 else -1.0)
				var c: Vector2 = p.pos + side * 260.0
				if sim.point_blocked(c, 30.0):
					return Enemies.spawn_point(sim, 30.0, true)
				return c
			"ring":
				var a = sim.rng.randf() * TAU
				var c2: Vector2 = p.pos + Geom.dir(a) * (mn + 50.0)
				if sim.point_blocked(c2, 30.0):
					return Enemies.spawn_point(sim, 30.0, true)
				return c2
		return Enemies.spawn_point(sim, 30.0, true)

	func remaining_waves() -> int:
		return waves.size() - 1 - index
