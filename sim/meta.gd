class_name Meta
extends RefCounted
## Persistent progress — The Wick: Embers, unlocks (weapons, Lights, Concord, hearts, Second
## Wick, rerolls, Fate Die, purse, Keepsakes, Deepening), Vows, weapon mastery, the bestiary,
## the story, achievements, the Daily Descent and the Kindling Heat. Pure data + rules so tests
## and the bot can use it; App owns the live dictionary and saves it to user://meta.json.

const PATH := "user://meta.json"

static func fresh() -> Dictionary:
	return {
		"version": 2, "embers": 0, "total_embers": 0, "spent_embers": 0, "unlocks": [], "keepsake": "",
		"runs": 0, "wins": 0, "deaths": 0, "deepest": 0, "boss_kills": {}, "story": [], "bestiary": {},
		"achievements": [], "mastery": {}, "heat_unlocked": false, "heat_mods": [], "best_heat": 0,
		"daily": {}, "vows": [], "pbs": {}, "last_weapon": "fangs", "wins_by_weapon": {},
		"totals": {"kills": 0, "perfect_dashes": 0, "counters": 0, "finishers": 0, "synergies": 0}, "lights_taken": [],
		"vows_completed": 0, "dailies": 0,
	}

static func load_meta() -> Dictionary:
	var m := fresh()
	var d = SaveIO.read_json(PATH)
	if d is Dictionary:
		for k in d.keys():
			m[k] = d[k]
	return m

static func save_meta(m: Dictionary) -> void:
	SaveIO.write_json(PATH, m)

# ───────── unlocks ─────────

static func unlock_defs() -> Array:
	return Cfg.T.meta.unlocks

static func unlock_def(id: String) -> Dictionary:
	for u in unlock_defs():
		if u.id == id:
			return u
	return {}

static func has(m: Dictionary, id: String) -> bool:
	return (m.get("unlocks", []) as Array).has(id)

static func can_buy(m: Dictionary, id: String) -> bool:
	var u := unlock_def(id)
	if u.is_empty() or has(m, id):
		return false
	for r in u.get("requires", []):
		if not has(m, r):
			return false
	return int(m.embers) >= int(u.cost)

static func buy(m: Dictionary, id: String) -> bool:
	if not can_buy(m, id):
		return false
	var u := unlock_def(id)
	m.embers = int(m.embers) - int(u.cost)
	m.spent_embers = int(m.get("spent_embers", 0)) + int(u.cost)
	(m.unlocks as Array).append(id)
	if id.begins_with("k_") and String(m.get("keepsake", "")) == "":
		m.keepsake = id
	return true

static func weapon_unlocked(m: Dictionary, w: String) -> bool:
	return w == "fangs" or has(m, "w_" + w)

static func patrons(m: Dictionary) -> Array:
	var p: Array = (Cfg.T.meta.base_patrons as Array).duplicate()
	for x in ["dawn", "gale", "umbra", "thorn"]:
		if has(m, "p_" + x):
			p.append(x)
	return p

static func deepening(m: Dictionary) -> int:
	return (1 if has(m, "deep1") else 0) + (1 if has(m, "deep2") else 0)

## the cheapest unlock not yet owned whose requirements are met (death recap progress bar)
static func next_unlock(m: Dictionary) -> Dictionary:
	var best := {}
	for u in unlock_defs():
		if has(m, u.id):
			continue
		var ok := true
		for r in u.get("requires", []):
			if not has(m, r):
				ok = false
		if ok and (best.is_empty() or int(u.cost) < int(best.cost)):
			best = u
	if best.is_empty():
		return {}
	return {"id": best.id, "name": best.name, "cost": int(best.cost), "have": int(m.embers)}

# ───────── mastery ─────────

static func mastery_level(m: Dictionary, w: String) -> int:
	var xp := int((m.get("mastery", {}) as Dictionary).get(w, 0))
	var th: Array = Cfg.T.meta.mastery.thresholds
	var lv := 0
	for i in th.size():
		if xp >= int(th[i]):
			lv = i
	return lv

static func forge_unlocks(m: Dictionary, w: String) -> int:
	var lv := mastery_level(m, w)
	var n := 1
	for need in Cfg.T.meta.mastery.forge_levels:
		if lv >= int(need):
			n += 1
	return n

# ───────── heat ─────────

static func heat_level(mods: Array) -> int:
	var n := 0
	for h in Cfg.T.meta.heat:
		if mods.has(h.id):
			n += int(h.points)
	return n

# ───────── daily ─────────

static func daily_key(unix: int = -1) -> String:
	var t := Time.get_datetime_dict_from_unix_time(unix if unix >= 0 else int(Time.get_unix_time_from_system()))
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]

static func daily_seed(key: String) -> int:
	return absi(hash("lanternfall-daily-" + key)) % 2000000000 + 1

static func daily_weapon(key: String) -> String:
	var ws: Array = Weapons.IDS
	return ws[daily_seed(key) % ws.size()]

static func daily_score(run: RunState) -> int:
	var D: Dictionary = Cfg.T.meta.daily
	var sc := run.rooms_cleared * int(D.rooms) + run.kills * int(D.kills) + run.bosses_killed.size() * int(D.bosses)
	if run.won:
		sc += int(D.win)
	sc -= int(run.time * float(D.time_penalty))
	return maxi(0, sc)

# ───────── starting a run ─────────

static func run_options(m: Dictionary, opts: Dictionary) -> Dictionary:
	var o := {}
	var w: String = String(opts.get("weapon", ""))
	var daily: bool = bool(opts.get("daily", false))
	if daily:
		var key := daily_key()
		o.seed = daily_seed(key)
		w = daily_weapon(key)
		o.daily_key = key
	if w == "" or not weapon_unlocked(m, w):
		w = String(m.get("last_weapon", "fangs"))
		if not weapon_unlocked(m, w):
			w = "fangs"
	o.weapon = w
	o.daily = daily
	o.depth = int(opts.get("depth", 1))
	o.max_hp_bonus = (10.0 if has(m, "heart1") else 0.0) + (10.0 if has(m, "heart2") else 0.0)
	o.defiance = int(Cfg.T.economy.start_defiance) + (1 if has(m, "defy2") else 0)
	o.rerolls = int(Cfg.T.economy.start_rerolls) + (1 if has(m, "reroll2") else 0)
	o.fate_dice = 1 if has(m, "fatedie") else 0
	o.gold = 40 if has(m, "purse") else 0
	o.keepsake = String(m.get("keepsake", "")) if has(m, String(m.get("keepsake", ""))) else ""
	o.concord = has(m, "concord")
	o.patrons = patrons(m)
	o.deepening = deepening(m)
	o.forge_unlocks = forge_unlocks(m, w)
	o.vows = [] if daily else (opts.get("vows", m.get("vows", [])) as Array).duplicate()
	var heat_mods: Array = [] if daily or not m.get("heat_unlocked", false) else (opts.get("heat_mods", m.get("heat_mods", [])) as Array).duplicate()
	o.heat_mods = heat_mods
	o.heat = heat_level(heat_mods)
	if heat_mods.has("scarce"):
		o.rerolls = 0
	if heat_mods.has("brittle"):
		o.max_hp_bonus -= float(Cfg.T.player.max_hp) * 0.2
	if heat_mods.has("dimmed"):
		o.defiance = 0
	if daily:
		o.keepsake = ""
	return o

# ───────── vows ─────────

static func vow_def(id: String) -> Dictionary:
	for v in Cfg.T.meta.vows:
		if v.id == id:
			return v
	return {}

static func vow_met(id: String, run: RunState) -> bool:
	var reached_d2 := run.depth >= 2 or run.won
	match id:
		"no_springs", "elites": return reached_d2
		"d2_damage": return (run.depth >= 3 or run.won) and float(run.dmg_by_depth[1]) < 100.0
		"no_defy": return reached_d2 and not run.flags.get("defied", false)
		"swift": return run.flags.has("depth2_at") and float(run.flags.depth2_at) <= 420.0
		"no_shop": return reached_d2 and not run.flags.get("bought", false)
		"guardians": return run.guardians_killed.size() >= 2
		"streak": return run.best_streak >= int(Cfg.F.streak.tiers[2])
	return false

# ───────── end of a run ─────────

static func end_run(m: Dictionary, run: RunState, d: Dictionary) -> Dictionary:
	var res := {}
	var won: bool = d.get("won", false)
	var abandoned: bool = d.get("abandoned", false)
	m.runs = int(m.get("runs", 0)) + 1
	if won:
		m.wins = int(m.get("wins", 0)) + 1
		var wbw: Dictionary = m.get("wins_by_weapon", {})
		wbw[run.weapon] = int(wbw.get(run.weapon, 0)) + 1
		m.wins_by_weapon = wbw
		if not m.get("heat_unlocked", false):
			m.heat_unlocked = true
			res["heat_unlocked"] = true
		m.best_heat = maxi(int(m.get("best_heat", 0)), run.heat)
	elif not abandoned:
		m.deaths = int(m.get("deaths", 0)) + 1
	var depth_reached := (run.depth - 1) * 6 + run.step + (6 if won else 0)
	m.deepest = maxi(int(m.get("deepest", 0)), depth_reached)
	m.last_weapon = run.weapon
	# vows
	var vow_embers := 0
	var vows_done: Array = []
	for v in run.vows:
		if vow_met(v, run):
			vow_embers += int(vow_def(v).get("embers", 0))
			vows_done.append(v)
	m.vows_completed = int(m.get("vows_completed", 0)) + vows_done.size()
	# embers: what was picked up, plus depth progress, win bonus, multipliers
	var E: Dictionary = Cfg.T.economy
	var base := run.embers + int(E.ember_per_depth_reached) * (run.depth - 1)
	if won:
		base += int(E.embers_win_bonus)
	var mul := 1.0 + float(Cfg.T.meta.deepening_ember_bonus) * run.deepening + float(Cfg.T.meta.heat_ember_bonus) * run.heat
	var total := int(round(base * mul)) + vow_embers
	m.embers = int(m.embers) + total
	m.total_embers = int(m.get("total_embers", 0)) + total
	res["embers"] = total
	res["embers_breakdown"] = {"collected": run.embers, "depth": int(E.ember_per_depth_reached) * (run.depth - 1), "win": int(E.embers_win_bonus) if won else 0, "mul": mul, "vows": vow_embers}
	res["vows_done"] = vows_done
	# boss kills
	var bk: Dictionary = m.get("boss_kills", {})
	for b in run.bosses_killed:
		bk[b] = int(bk.get(b, 0)) + 1
	m.boss_kills = bk
	# totals
	var tot: Dictionary = m.get("totals", {})
	tot.kills = int(tot.get("kills", 0)) + run.kills
	tot.perfect_dashes = int(tot.get("perfect_dashes", 0)) + run.perfect_dashes
	tot.counters = int(tot.get("counters", 0)) + run.counters
	tot.finishers = int(tot.get("finishers", 0)) + run.finishers
	tot.synergies = int(tot.get("synergies", 0)) + run.synergies
	m.totals = tot
	var lights: Array = m.get("lights_taken", [])
	for b in run.boons:
		var bd := Boons.def(b.id)
		var pid: String = bd.get("patron", "")
		if pid != "" and pid != "duo" and not lights.has(pid):
			lights.append(pid)
	m.lights_taken = lights
	# mastery
	var MS: Dictionary = Cfg.T.meta.mastery
	var lv_before := mastery_level(m, run.weapon)
	var xp := (run.kills - run.elite_kills) * int(MS.xp_kill) + run.elite_kills * int(MS.xp_elite) + run.guardians_killed.size() * int(MS.xp_guardian) + run.bosses_killed.size() * int(MS.xp_boss)
	var ms: Dictionary = m.get("mastery", {})
	ms[run.weapon] = int(ms.get(run.weapon, 0)) + xp
	m.mastery = ms
	res["mastery"] = {"weapon": run.weapon, "xp": xp, "level": mastery_level(m, run.weapon), "level_before": lv_before}
	# bestiary
	bestiary_from_run(m, run)
	# personal bests
	res["pbs"] = update_pbs(m, run)
	# daily
	if run.daily:
		var key: String = run.daily_key if run.daily_key != "" else daily_key()
		var dd: Dictionary = m.get("daily", {})
		var scores: Array = dd.get(key, [])
		var sc := daily_score(run)
		scores.append(sc)
		scores.sort()
		scores.reverse()
		dd[key] = scores.slice(0, 10)
		m.daily = dd
		m.dailies = int(m.get("dailies", 0)) + 1
		res["daily_score"] = sc
		res["daily_best"] = scores[0]
	# story + achievements
	var line := next_story(m, {"won": won})
	if not line.is_empty():
		res["story"] = "%s: “%s”" % [line.who, line.line]
	res["achievements"] = Achievements.check(m, run)
	res["next_unlock"] = next_unlock(m)
	if won:
		res["ending"] = ending_lines(m)
	return res

static func update_pbs(m: Dictionary, run: RunState) -> Dictionary:
	var pb: Dictionary = m.get("pbs", {})
	var out := {}
	var cmp := {"rooms": [run.rooms_cleared, true], "kills": [run.kills, true], "best_hit": [run.best_hit, true], "streak": [run.best_streak, true], "dmg_dealt": [run.stats_dmg_dealt, true]}
	if run.won:
		cmp["win_time"] = [run.time, false]
	for k in cmp.keys():
		var v: float = float(cmp[k][0])
		var higher: bool = cmp[k][1]
		var old = pb.get(k)
		var better: bool = old == null or (v > float(old) if higher else v < float(old))
		out[k] = {"value": v, "best": old, "new": better}
		if better:
			pb[k] = v
	m.pbs = pb
	return out

static func bestiary_from_run(m: Dictionary, run: RunState) -> void:
	var b: Dictionary = m.get("bestiary", {})
	for k in run.kills_by_kind.keys():
		var e: Dictionary = b.get(k, {"seen": true, "kills": 0, "deaths": 0})
		e.seen = true
		e.kills = int(e.get("kills", 0)) + int(run.kills_by_kind[k])
		b[k] = e
	for src in run.dmg_by_source.keys():
		pass
	var killer: Dictionary = run.killer
	if run.dead and not killer.is_empty() and String(killer.get("kind", "")) != "":
		var kk: String = killer.kind
		var e2: Dictionary = b.get(kk, {"seen": true, "kills": 0, "deaths": 0})
		e2.seen = true
		e2.deaths = int(e2.get("deaths", 0)) + 1
		b[kk] = e2
	m.bestiary = b

static func note_seen(m: Dictionary, kind: String) -> void:
	var b: Dictionary = m.get("bestiary", {})
	if not b.has(kind):
		b[kind] = {"seen": true, "kills": 0, "deaths": 0}
		m.bestiary = b

# ───────── story ─────────

const LINES := [
	["s1", "Ossa", "You came back. Good. The dark down there keeps what it kills — except you, it seems.", "runs", 1],
	["s2", "Ossa", "The Regent took our sun and sank it beneath four depths. Every descent, you learn the way a little better.", "runs", 2],
	["s3", "Wren", "The Gardens were ours once. Now they burn cold.", "runs", 3],
	["b1", "Ossa", "Ashenhart was the first guardian. The Regent fed it our hearth-fires, one by one.", "boss", "boss_stag"],
	["a1", "Ashka", "That stag wore my flames like a crown. Thank you for taking them back.", "boss", "boss_stag"],
	["q1", "Quill", "Moth-wings and paper — that's the Archive. Mind the ink. It remembers faces.", "deepest", 6],
	["s4", "Ossa", "Spend your Embers here at the Wick. Light grows when it is shared.", "total_embers", 20],
	["q2", "Quill", "Gold down there, Embers up here. Don't ask me how. I only sell.", "runs", 4],
	["b2", "Wren", "Velloran wrote down every name the Regent erased. I saw mine in the margins.", "boss", "boss_archivist"],
	["i1", "Ilvra", "The Archive drowned slowly. I froze what I could. It was not enough.", "boss", "boss_archivist"],
	["s5", "Ossa", "Each Light that answers you was a star once. They remember shining.", "runs", 5],
	["k1", "Korr", "HA! You strike like a storm with a grudge. Keep it.", "runs", 6],
	["f1", "Quill", "The Foundry hums like a heartbeat. Whose heart, I wonder?", "deepest", 12],
	["b3", "Ossa", "The Engine was built to pump our sun's warmth to the Crown. You broke the pipe. Feel that? It's warmer here.", "boss", "boss_engine"],
	["m1", "Maelis", "Every tide returns. So do you. That is not a curse, child.", "deaths", 6],
	["s6", "Wren", "Sometimes I hear the Regent laugh when I fall. Then it goes quiet when I rise.", "deaths", 8],
	["c1", "The Regent", "Little wick. Do you know why the dark is patient? Because it always wins.", "deepest", 18],
	["o1", "Oruun", "I see the Regent's face beneath the mask. It is wearing yours.", "unlock_deepest", "p_umbra"],
	["s7", "Ossa", "The Crown sits where the sky used to be. Go carefully. Go quickly.", "deepest", 18],
	["w1", "Ossa", "The sun rose over the Hollow City today. Only for a moment — but it rose. You did that.", "won", true],
	["w2", "The Regent", "You only took back a spark. The rest is still mine. Come down again.", "wins", 1],
	["w3", "Solenne", "Dawn is not a moment, Wren. It is a habit. Keep rising.", "wins", 2],
	["d1", "Ossa", "Deeper paths open as the Wick grows. New horrors, new chances.", "unlock", "deep1"],
	["g1", "Siffra", "Faster, faster! The dark can't catch what it can't see.", "unlock", "p_gale"],
	["t1", "Brakka", "Plant a thorn in everything that bites you. Let them carry it home.", "unlock", "p_thorn"],
	["h1", "Ossa", "The Heat rises in the Wick. Kindle it if you dare — the Lights reward the bold.", "heat", true],
	["w4", "Wren", "Every time I win, the Regent is waiting again. Maybe the point isn't to end it. Maybe it's to keep the light moving.", "wins", 3],
	["e1", "Ossa", "Rest if you need to. The Lantern Heart is patient too.", "runs", 12],
]

static func story_count() -> int:
	return LINES.size()

static func _line_ok(m: Dictionary, l: Array, ctx: Dictionary) -> bool:
	match String(l[3]):
		"runs": return int(m.get("runs", 0)) >= int(l[4])
		"deaths": return int(m.get("deaths", 0)) >= int(l[4])
		"wins": return int(m.get("wins", 0)) >= int(l[4])
		"deepest": return int(m.get("deepest", 0)) >= int(l[4])
		"total_embers": return int(m.get("total_embers", 0)) >= int(l[4])
		"boss": return int((m.get("boss_kills", {}) as Dictionary).get(l[4], 0)) >= 1
		"unlock": return has(m, String(l[4]))
		"unlock_deepest": return has(m, String(l[4])) and int(m.get("deepest", 0)) >= 18
		"won": return ctx.get("won", false)
		"heat": return m.get("heat_unlocked", false)
	return false

## the first unseen line whose condition is met (one per run end)
static func next_story(m: Dictionary, ctx: Dictionary) -> Dictionary:
	var seen: Array = m.get("story", [])
	for l in LINES:
		if seen.has(l[0]):
			continue
		if _line_ok(m, l, ctx):
			seen.append(l[0])
			m.story = seen
			return {"id": l[0], "who": l[1], "line": l[2]}
	return {}

static func story_log(m: Dictionary) -> Array:
	var out: Array = []
	var seen: Array = m.get("story", [])
	for l in LINES:
		if seen.has(l[0]):
			out.append({"who": l[1], "line": l[2]})
	return out

static func ending_lines(m: Dictionary) -> Array:
	var lines := [
		"Wren lifts the Lantern Heart from the Pale Regent's broken crown.",
		"Far above, in the Hollow City, the sky turns from black to bruise to gold.",
		"The Eight Lights sing in the lantern — not as dead stars, but as a dawn.",
	]
	if int(m.get("wins", 0)) > 1:
		lines.append("Again the sun rises. Again the dark remembers. Again, Wren will be ready.")
	else:
		lines.append("Ossa is waiting at the Wick with tea gone cold. “You did it,” she says. “Now keep it lit.”")
	return lines
