class_name Status
extends RefCounted

## build-wide modifiers read by enemies every frame (set when stats are rebuilt)
static var chill_slow := 0.06
static var dread := 0.0
## Status effects on enemies: Burn (stacking DoT), Chill → Freeze → Shatter, Hex (more damage
## taken, spreads on death), Bleed (stacks that burst on heavy hits), Mark (crit vulnerability),
## plus Jolt (chain lightning) and Tide (extra knockback) from slot infusions.

const NAMES := {"burn": "Burn", "chill": "Chill", "freeze": "Freeze", "hex": "Hex", "bleed": "Bleed", "mark": "Mark"}

## per-step decay and damage over time
static func tick(sim, e: SimEnemy, dt: float) -> void:
	var st: Stats = sim.stats
	if e.burn > 0.0:
		e.dot_acc += e.burn * st.burn_dps * dt
		e.burn = maxf(0.0, e.burn - (0.5 + e.burn * st.burn_decay) * dt)
		if e.dot_acc >= 3.0:
			var h := HitInfo.make(e.dot_acc, "status", 0.0, Vector2.ZERO, e.pos)
			h.is_dot = true
			h.can_crit = false
			h.element = "ember"
			h.no_infuse = true
			e.dot_acc = 0.0
			Combat.deal(sim, e, h)
			if not e.alive:
				return
	if e.chill > 0.0 and e.freeze_t <= 0.0:
		e.chill = maxf(0.0, e.chill - float(sim.T.status.chill_decay) * dt)
	if e.freeze_t > 0.0:
		e.freeze_t -= dt
	e.hex_t = maxf(0.0, e.hex_t - dt)
	e.mark_t = maxf(0.0, e.mark_t - dt)
	e.ionize_t = maxf(0.0, e.ionize_t - dt)
	e.slow_t = maxf(0.0, e.slow_t - dt)
	e.blind_t = maxf(0.0, e.blind_t - dt)
	if e.bleed > 0.0 and sim.time - e.last_hit_t > 6.0:
		e.bleed = maxf(0.0, e.bleed - dt)

## applies a slot infusion after a hit landed
static func infuse(sim, e: SimEnemy, patron: String, pw: float, h: HitInfo) -> void:
	if patron == "" or not e.alive:
		return
	match patron:
		"ember": add_burn(sim, e, pw)
		"rime": add_chill(sim, e, pw)
		"storm": jolt(sim, e, pw, h)
		"tide": pass  # handled as extra knockback before damage
		"dawn": mark(sim, e)
		"umbra": hex(sim, e)
		"gale": e.slow_t = maxf(e.slow_t, 1.0)
		"thorn": add_bleed(sim, e, pw, h)

static func add_burn(sim, e: SimEnemy, n: float) -> void:
	var first := e.burn <= 0.0
	e.burn = minf(sim.stats.burn_max, e.burn + n)
	if first:
		sim.fire(&"status_applied", {"id": e.id, "status": "burn", "pos": e.pos})

static func add_chill(sim, e: SimEnemy, n: float) -> void:
	if e.freeze_t > 0.0 or e.is_boss:
		e.chill = minf(e.chill + n * 0.5, sim.stats.chill_max - 1.0) if e.is_boss else e.chill
		return
	var need = sim.stats.chill_max
	if e.hex_t > 0.0 and sim.stats.has("black_ice"):
		need *= 0.5
	e.chill += n
	if e.chill >= need:
		freeze(sim, e)

static func freeze(sim, e: SimEnemy) -> void:
	if e.is_boss:
		return
	e.chill = 0.0
	e.freeze_t = sim.stats.freeze_time * (0.5 if e.is_guardian else 1.0)
	if e.tele != null:
		Tele.cancel(sim, e.tele)
		e.tele = null
	e.set_state(0)
	e.contact_on = false
	sim.fire(&"status_applied", {"id": e.id, "status": "freeze", "pos": e.pos})
	BoonFx.on_freeze(sim, e)

static func mark(sim, e: SimEnemy) -> void:
	e.mark_t = float(sim.T.status.mark_time)

static func hex(sim, e: SimEnemy) -> void:
	var first := e.hex_t <= 0.0
	e.hex_t = float(sim.T.status.hex_time)
	if first:
		sim.fire(&"status_applied", {"id": e.id, "status": "hex", "pos": e.pos})

static func add_bleed(sim, e: SimEnemy, n: float, h: HitInfo) -> void:
	e.bleed = minf(sim.stats.bleed_max, e.bleed + n)
	if h != null and (h.power >= float(sim.T.status.bleed_burst_power) or h.slot == "special" or h.slot == "cast" or h.tag == "finisher"):
		burst_bleed(sim, e)

static func burst_bleed(sim, e: SimEnemy) -> void:
	if e.bleed < 1.0 or not e.alive:
		return
	var stacks := e.bleed
	e.bleed = 0.0
	var bh := HitInfo.make(stacks * sim.stats.bleed_burst, "status", 0.5, Vector2.ZERO, e.pos)
	bh.is_dot = true
	bh.can_crit = false
	bh.element = "thorn"
	bh.tag = "bleed_burst"
	bh.no_infuse = true
	sim.fire(&"synergy", {"pos": e.pos, "text": "BLEED BURST", "color": "thorn"})
	Combat.deal(sim, e, bh)
	BoonFx.on_bleed_burst(sim, e, stacks)

## chain lightning from `from` to the nearest unstruck enemies
static func jolt(sim, from: SimEnemy, pw: float, h: HitInfo) -> void:
	if h != null and h.tag == "jolt":
		return
	var st: Stats = sim.stats
	var chains := int(st.jolt_chains)
	var rng_d := st.jolt_range * (1.0 + st.val("arc_reach"))
	var struck := {from.id: true}
	var cur: SimEnemy = from
	var pts: Array = [from.pos]
	for i in chains:
		var nxt = null
		var bd := rng_d
		for e in sim.enemies:
			if not e.targetable() or struck.has(e.id):
				continue
			var d := cur.pos.distance_to(e.pos)
			if d < bd:
				bd = d
				nxt = e
		if nxt == null:
			break
		struck[nxt.id] = true
		pts.append(nxt.pos)
		_jolt_hit(sim, nxt, st.jolt_dmg * pw, cur.pos)
		cur = nxt
	# the struck enemy also takes a small jolt
	_jolt_hit(sim, from, st.jolt_dmg * pw * 0.5, from.pos)
	sim.fire(&"lightning", {"points": pts})
	BoonFx.on_jolt(sim, struck)

static func _jolt_hit(sim, e: SimEnemy, dmg: float, src: Vector2) -> void:
	if not e.alive:
		return
	var h := HitInfo.make(dmg, "status", 0.25, e.pos - src, src)
	h.tag = "jolt"
	h.element = "storm"
	h.no_infuse = true
	h.no_hitstop = true
	h.can_crit = sim.stats.has("overcharge")
	h.crit_bonus = sim.stats.val("overcharge") - sim.T.crit.base_chance - sim.stats.crit_chance if h.can_crit else 0.0
	if sim.stats.has("ionize"):
		e.ionize_t = 3.0
	if sim.stats.has("static_frost") and e.frozen():
		h.dmg *= 1.4
	Combat.deal(sim, e, h)

## damage multiplier from statuses on the target
static func vuln(sim, e: SimEnemy) -> float:
	var st: Stats = sim.stats
	var m := 1.0
	if e.freeze_t > 0.0:
		m += st.freeze_vuln
	if e.hex_t > 0.0:
		m += st.hex_dmg_taken
	if e.ionize_t > 0.0:
		m += st.val("ionize")
	if e.burn > 0.0:
		m += st.val("vs_burn") + minf(0.4, e.burn * st.val("inferno_crown"))
	if e.bleed > 0.0:
		m += st.val("rending")
	if e.burn > 0.0 or e.chill > 0.0 or e.hex_t > 0.0 or e.bleed > 0.0 or e.mark_t > 0.0 or e.freeze_t > 0.0:
		m += st.vs_status_dmg
	return m

static func icons(e: SimEnemy) -> Array:
	var out: Array = []
	if e.burn >= 1.0: out.append(["burn", int(e.burn)])
	if e.freeze_t > 0.0: out.append(["freeze", 0])
	elif e.chill >= 1.0: out.append(["chill", int(e.chill)])
	if e.hex_t > 0.0: out.append(["hex", 0])
	if e.bleed >= 1.0: out.append(["bleed", int(e.bleed)])
	if e.mark_t > 0.0: out.append(["mark", 0])
	return out
