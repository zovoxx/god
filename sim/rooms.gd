class_name Rooms
extends RefCounted
## Depth structure, door generation and arena layouts. Each depth is a short corridor:
##   0 combat · 1 choice · 2 choice · 3 guardian · 4 choice (recovery likely) · 5 boss
## Choice steps offer 2–3 doors; every door shows its room type and reward in advance.

const DEPTH_COUNT := 4
const REWARDS := ["boon", "forge", "kindle", "heart", "gold"]

static func steps() -> Array:
	return Cfg.T.rooms.steps

static func depth_name(d: int) -> String:
	return ["The Ashen Gardens", "The Drowned Archive", "The Clockwork Foundry", "The Starless Crown"][clampi(d - 1, 0, 3)]

static func room_rng(run: RunState, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([run.seed, run.room_index, run.depth, run.step, salt])
	return r

static func _pick_patron(rng: RandomNumberGenerator, run: RunState, avoid: Array) -> String:
	var pool: Array = run.patrons.filter(func(p): return not avoid.has(p))
	if pool.is_empty():
		pool = run.patrons
	return pool[rng.randi_range(0, pool.size() - 1)]

static func _weighted_key(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights.keys():
		total += maxf(0.0, float(weights[k]))
	if total <= 0.0:
		return weights.keys()[0]
	var r := rng.randf() * total
	for k in weights.keys():
		r -= maxf(0.0, float(weights[k]))
		if r <= 0.0:
			return k
	return weights.keys()[-1]

static func _reward(rng: RandomNumberGenerator, run: RunState, avoid: Array, allow_other: bool) -> Dictionary:
	var W: Dictionary = (Cfg.T.rooms.reward_weights as Dictionary).duplicate()
	if not allow_other:
		W = {"boon": 1.0}
	if run.boons.size() < 2:
		W["kindle"] = 0.0
	var r := _weighted_key(rng, W)
	if r == "boon":
		return {"reward": "boon", "patron": _pick_patron(rng, run, avoid)}
	return {"reward": r}

static func first_room(run: RunState) -> Dictionary:
	var rng := room_rng(run, 1)
	return {"type": "combat", "depth": run.depth, "step": 0, "reward": "boon", "patron": _pick_patron(rng, run, []), "seed": rng.randi()}

## the doors offered after clearing the current room (deterministic for a run seed)
static func next_doors(run: RunState) -> Array:
	var rng := room_rng(run, 2)
	var d := run.depth
	var st := run.step + 1
	if st >= steps().size():
		d += 1
		st = 0
	if d > DEPTH_COUNT:
		return []
	var kind: String = steps()[st]
	var plans: Array = []
	var used: Array = []
	var mk := func(type: String, force_boon: bool) -> Dictionary:
		var r := _reward(rng, run, used, not force_boon)
		if r.has("patron"):
			used.append(r.patron)
		var p := {"type": type, "depth": d, "step": st, "reward": r.reward, "patron": r.get("patron", ""), "seed": rng.randi(), "rarity": 1 if type in ["elite", "guardian"] else 0}
		if type == "guardian":
			var g: Array = Cfg.T.rooms.guardians[str(d)]
			p.kind = g[rng.randi_range(0, g.size() - 1)]
		return p
	match kind:
		"combat":
			plans.append(mk.call("combat", true))
			plans.append(mk.call("combat", true))
		"guardian":
			plans.append(mk.call("guardian", true))
			plans.append(mk.call("guardian", true))
		"boss":
			plans.append({"type": "boss", "depth": d, "step": st, "reward": "none", "seed": rng.randi(), "kind": Cfg.T.rooms.bosses[str(d)]})
		_:
			var n := 3 if rng.randf() < float(Cfg.T.rooms.choice_three_chance) else 2
			var hp_low := run.hp < run.max_hp() * 0.55
			var TW: Dictionary = (Cfg.T.rooms.type_weights as Dictionary).duplicate()
			if d == 1 and st == 1:
				TW.elite = 0
			if run.shops_this_depth > 0:
				TW.shop = 0
			elif st == 4:
				TW.shop = 30
			TW.spring = (34 if hp_low else 18) if st == 4 else (16 if hp_low else 6)
			if d == 1:
				TW.ordeal = 0
			if run.has_vow("no_springs"):
				TW.spring = 0
			if run.has_vow("elites"):
				TW.elite = float(TW.elite) * 3.0 + 20.0
			var types_used := {}
			for i in n:
				var w2 := {}
				for k in TW.keys():
					w2[k] = 0.0 if (types_used.has(k) and k != "combat") else float(TW[k])
				var t := _weighted_key(rng, w2)
				types_used[t] = true
				if t == "shop" or t == "spring":
					plans.append({"type": t, "depth": d, "step": st, "reward": "none", "seed": rng.randi()})
				elif t == "ordeal":
					var ords := ["altar", "gauntlet", "wager"]
					plans.append({"type": "ordeal", "depth": d, "step": st, "reward": "boon", "patron": _pick_patron(rng, run, used), "seed": rng.randi(), "ordeal": ords[rng.randi_range(0, 2)], "rarity": 1})
				else:
					plans.append(mk.call(t, false))
			# the pre-boss choice always offers a way to recover
			if st == 4 and not plans.any(func(p): return p.type == "shop" or p.type == "spring"):
				var rec := "spring" if run.shops_this_depth > 0 and not run.has_vow("no_springs") else "shop"
				plans[-1] = {"type": rec, "depth": d, "step": st, "reward": "none", "seed": rng.randi()}
	return plans

# ───────────────────────── arenas ─────────────────────────

static func _layout(i: int, w: float, h: float) -> Array:
	match i:
		1: return [[-w * 0.25, -h * 0.15, 40.0], [w * 0.25, h * 0.15, 40.0]]
		2: return [[-w * 0.28, -h * 0.22, 34.0], [w * 0.28, -h * 0.22, 34.0], [-w * 0.28, h * 0.22, 34.0], [w * 0.28, h * 0.22, 34.0]]
		3: return [[0.0, -20.0, 62.0]]
		4: return [[-w * 0.32, 0.0, 30.0], [w * 0.32, 0.0, 30.0], [0.0, -h * 0.28, 30.0]]
		5: return [[-w * 0.18, -h * 0.25, 28.0], [w * 0.18, -h * 0.25, 28.0], [-w * 0.36, h * 0.12, 28.0], [w * 0.36, h * 0.12, 28.0]]
		6: return [[-w * 0.2, 0.0, 36.0], [w * 0.2, 0.0, 36.0]]
		7: return [[0.0, -h * 0.3, 30.0], [-w * 0.35, h * 0.2, 30.0], [w * 0.35, h * 0.2, 30.0], [0.0, h * 0.05, 22.0]]
	return []

static func make_arena(plan: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plan.get("seed", 1))
	var w := 1240.0
	var h := 760.0
	var depth := int(plan.get("depth", 1))
	# each depth prefers its own layouts
	var prefs = [[0, 1, 2, 4], [1, 3, 5, 6], [2, 4, 5, 7], [0, 3, 6, 7]][clampi(depth - 1, 0, 3)]
	var layout: int = prefs[rng.randi_range(0, prefs.size() - 1)]
	match String(plan.type):
		"combat", "ordeal":
			w = [1100.0, 1200.0, 1300.0][rng.randi_range(0, 2)]
			h = [680.0, 740.0, 800.0][rng.randi_range(0, 2)]
			if plan.type == "ordeal" and plan.get("ordeal", "") == "altar":
				layout = 0
		"elite":
			w = 1300.0
			h = 800.0
		"guardian":
			w = 1300.0
			h = 820.0
			layout = [0, 2, 5][rng.randi_range(0, 2)]
		"boss":
			w = 1480.0
			h = 900.0
			layout = 2 if depth == 3 else 0
		"shop", "spring":
			w = 960.0
			h = 600.0
			layout = 0
	var pillars: Array = []
	for p in _layout(layout, w, h):
		pillars.append({"pos": Vector2(p[0], p[1]), "r": p[2]})
	var hz: Array = []
	if plan.type in ["combat", "elite", "ordeal"] and int(plan.get("step", 0)) > 0:
		var kind: String = Cfg.T.rooms.hazards[str(depth)]
		var n := 2 + int(plan.get("step", 0)) / 2
		for i in n:
			for tries in 20:
				var p2 := Vector2(rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(-h * 0.35, h * 0.3))
				var ok := p2.distance_to(Vector2(0, h * 0.5 - 90)) > 200.0
				for pl in pillars:
					if p2.distance_to(pl.pos) < float(pl.r) + 80.0:
						ok = false
				for o in hz:
					if p2.distance_to(o.pos) < 160.0:
						ok = false
				if ok:
					hz.append({"kind": kind, "pos": p2, "radius": 58.0 if kind != "pool" else 74.0, "phase": rng.randf()})
					break
	return {"rect": Rect2(-w * 0.5, -h * 0.5, w, h), "pillars": pillars, "style": depth - 1, "hazards": hz}

## where the doors sit along the top wall
static func door_positions(arena: Dictionary, n: int) -> Array:
	var r: Rect2 = arena.rect
	var sp: float = Cfg.T.rooms.door_spacing
	var out: Array = []
	for i in n:
		out.append(Vector2((i - (n - 1) * 0.5) * sp, r.position.y + 84.0))
	return out

static func entry_point(arena: Dictionary) -> Vector2:
	var r: Rect2 = arena.rect
	return Vector2(0, r.end.y - 70.0)
