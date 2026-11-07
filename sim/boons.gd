class_name Boons
extends RefCounted
## Boon rules: rarity/level values, slot stacking, patron requirements, duo (Concord) rules,
## weighted offers and exact before/after previews. Content lives in data/boons.tres.
##
## Rules
## - attack/special/dash/cast/revenge slots hold one boon each; a new boon for an occupied
##   slot replaces the old one (the card says so).
## - passives need at least one boon from the same Light, unless marked "free".
## - legendaries need `req` (2) boons from their Light; one legendary per Light.
## - duos need Concord (Wick unlock) and at least one boon from each of the two Lights.
## - a boon is never offered twice; owned boons are improved through Kindling instead.

const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := ["#d8d2e8", "#5db7ff", "#c07bff", "#ffb33d"]
const SLOTS := ["attack", "special", "dash", "cast", "revenge"]

static func data() -> BoonData:
	return Cfg.B

static func def(id: String) -> Dictionary:
	if Cfg.B == null:
		return {}
	return Cfg.B.index().get(id, {})

static func all_ids() -> Array:
	return Cfg.B.index().keys()

static func patron(id: String) -> Dictionary:
	if Cfg.B == null:
		return {}
	return Cfg.B.patrons.get(id, {})

static func hex_of(id: String) -> String:
	var d := def(id)
	if d.is_empty():
		return "#ffffff"
	if d.patron == "duo":
		return String(patron(d.duo[0]).get("color", "#ffffff"))
	return String(patron(d.patron).get("color", "#ffffff"))

static func color_of(id: String) -> Color:
	return Color.html(hex_of(id))

static func slot_of(id: String) -> String:
	return String(def(id).get("slot", "passive"))

# ───────── values & text ─────────

static func values(d: Dictionary, rarity: int, level: int) -> Array:
	var R: Dictionary = Cfg.B.rarity
	var k: float = float(R.mul[clampi(rarity, 0, 3)]) * (1.0 + float(R.level_step) * (level - 1))
	var out: Array = []
	var base: Array = d.get("base", [])
	var fixed: Array = d.get("fixed", [])
	var fmt: Array = d.get("fmt", [])
	for i in base.size():
		var b := float(base[i])
		if i < fixed.size() and fixed[i]:
			out.append(b)
			continue
		var v := b * k
		var f: String = fmt[i] if i < fmt.size() else ""
		match f:
			"%": v = roundf(v * 100.0) / 100.0
			"s", "x": v = roundf(v * 10.0) / 10.0
			_: v = roundf(v)
		out.append(v)
	return out

static func fmt_value(v: float, f: String) -> String:
	match f:
		"%": return "%d%%" % int(round(v * 100.0))
		"s": return "%.1fs" % v
		"x": return "×%.1f" % v
	return str(int(round(v)))

static func describe(id: String, rarity: int, level: int) -> String:
	var d := def(id)
	if d.is_empty():
		return id
	var v := values(d, rarity, level)
	var t: String = d.text
	var fmt: Array = d.get("fmt", [])
	for i in v.size():
		t = t.replace("{%d}" % i, fmt_value(float(v[i]), fmt[i] if i < fmt.size() else ""))
	return t

# ───────── applying ─────────

static func apply(st: Stats, owned: Dictionary) -> void:
	var d := def(String(owned.id))
	if d.is_empty():
		return
	var v := values(d, int(owned.rarity), int(owned.get("level", 1)))
	var slot: String = d.slot
	if d.get("infuse", false) and slot in ["attack", "special", "dash", "cast"]:
		st.infuse[slot] = d.patron
		st.infuse_pow[slot] = float(v[1]) if v.size() > 1 else 1.0
		match slot:
			"attack": st.attack_dmg += float(v[0])
			"special": st.special_dmg += float(v[0])
			"dash": st.dash_dmg += float(v[0])
			"cast": st.cast_dmg += float(v[0])
		if d.patron == "umbra":
			st.add("hex_on", 1.0)
	for m in d.get("mods", []):
		var key: String = m[0]
		var val: float
		if m.size() >= 3 and String(m[1]) == "c":
			val = float(m[2])
		else:
			val = float(v[int(m[1])])
		st.apply_mod(key, val)

# ───────── rules ─────────

static func patron_count(run: RunState, p: String) -> int:
	var n := 0
	for b in run.boons:
		var d := def(b.id)
		if d.get("patron", "") == p:
			n += 1
	return n

static func slot_owner(run: RunState, slot: String):
	for b in run.boons:
		if slot_of(b.id) == slot:
			return b
	return null

## can this boon be offered right now?
static func eligible(run: RunState, id: String) -> bool:
	var d := def(id)
	if d.is_empty() or run.has_boon(id):
		return false
	var slot: String = d.slot
	match slot:
		"passive":
			return d.get("free", false) or patron_count(run, d.patron) >= 1
		"legendary":
			if patron_count(run, d.patron) < int(d.get("req", 2)):
				return false
			for b in run.boons:
				var o := def(b.id)
				if o.slot == "legendary" and o.patron == d.patron:
					return false
			return true
		"duo":
			if not run.concord:
				return false
			return patron_count(run, d.duo[0]) >= 1 and patron_count(run, d.duo[1]) >= 1
	return true

static func available(run: RunState, p: String) -> Array:
	var out: Array = []
	for b in Cfg.B.boons:
		if b.patron == p and eligible(run, b.id):
			out.append(b.id)
	return out

static func available_duos(run: RunState, p: String) -> Array:
	var out: Array = []
	for b in Cfg.B.boons:
		if b.slot == "duo" and (b.duo[0] == p or b.duo[1] == p) and eligible(run, b.id):
			out.append(b.id)
	return out

static func roll_rarity(rng: RandomNumberGenerator, floor_r: int) -> int:
	var R: Dictionary = Cfg.B.rarity
	var x := rng.randf()
	var r := 0
	if x < float(R.chance_legendary):
		r = 3
	elif x < float(R.chance_legendary) + float(R.chance_epic):
		r = 2
	elif x < float(R.chance_legendary) + float(R.chance_epic) + float(R.chance_rare):
		r = 1
	return clampi(maxi(r, floor_r), 0, 3)

# ───────── offers ─────────

static func offer(sim, p: String, rarity_floor: int, count: int = 3, rng: RandomNumberGenerator = null) -> Dictionary:
	var run: RunState = sim.run
	if rng == null:
		rng = Rooms.room_rng(run, 20)
	if p == "" or not Cfg.B.patrons.has(p):
		p = run.patrons[rng.randi_range(0, run.patrons.size() - 1)]
	var pool := available(run, p)
	var picks: Array = []
	while picks.size() < count and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += float(def(id).get("w", 1.0)) * _slot_weight(run, id)
		var r := rng.randf() * total
		var chosen: String = pool[-1]
		for id in pool:
			r -= float(def(id).get("w", 1.0)) * _slot_weight(run, id)
			if r <= 0.0:
				chosen = id
				break
		picks.append(chosen)
		pool.erase(chosen)
	# Concord: a duo can take one of the places
	var duos := available_duos(run, p)
	if not duos.is_empty() and rng.randf() < float(Cfg.B.rarity.duo_chance):
		var duo: String = duos[rng.randi_range(0, duos.size() - 1)]
		if picks.size() >= count:
			picks[picks.size() - 1] = duo
		else:
			picks.append(duo)
	var options: Array = []
	for id in picks:
		var d := def(id)
		var rar := roll_rarity(rng, rarity_floor)
		if d.slot in ["legendary", "duo"]:
			rar = 3 if d.slot == "legendary" else maxi(2, rar)
		options.append(option(sim, id, rar))
	var pd := patron(p)
	var greet: Array = pd.get("greet", [""])
	return {"kind": "boon", "patron": p, "title": "%s, %s" % [pd.get("name", p), pd.get("title", "")], "subtitle": "\"%s\"" % greet[rng.randi_range(0, greet.size() - 1)],
		"color": pd.get("color", "#ffffff"), "options": options, "rerollable": true}

static func _slot_weight(run: RunState, id: String) -> float:
	# empty core slots are a little more likely, so builds come together
	var s := slot_of(id)
	if s in SLOTS and slot_owner(run, s) == null:
		return 1.25
	return 1.0

static func option(sim, id: String, rarity: int) -> Dictionary:
	var run: RunState = sim.run
	var d := def(id)
	var slot: String = d.slot
	var tag := "%s · %s" % [slot.to_upper(), RARITY_NAMES[rarity].to_upper()]
	if slot == "duo":
		tag = "DUO · %s + %s" % [patron(d.duo[0]).get("name", ""), patron(d.duo[1]).get("name", "")]
	var desc := describe(id, rarity, 1)
	var replaced = slot_owner(run, slot) if slot in SLOTS else null
	if replaced != null:
		desc += "\nReplaces %s." % def(replaced.id).get("name", replaced.id)
	var pv := preview(sim, id, rarity)
	return {"id": id, "name": d.name, "desc": desc, "tag": tag, "rarity": rarity, "color": hex_of(id), "icon": "i_slot_" + slot,
		"actions": [{"type": "boon", "id": id, "rarity": rarity}], "before": pv[0], "after": pv[1], "duo": slot == "duo", "slot": slot}

## grant a boon (replacing whatever held its slot)
static func grant(sim, id: String, rarity: int) -> void:
	var run: RunState = sim.run
	var slot := slot_of(id)
	if slot in SLOTS:
		var old = slot_owner(run, slot)
		if old != null:
			run.boons.erase(old)
	for b in run.boons:
		if b.id == id:
			b.rarity = maxi(int(b.rarity), rarity)
			run.recompute(sim)
			return
	run.boons.append({"id": id, "rarity": rarity, "level": 1})
	if slot == "legendary":
		run.flags["legendary"] = true
	if slot == "duo":
		run.flags["duo"] = true
	run.recompute(sim)
	sim.fire(&"boon_gained", {"id": id, "rarity": rarity, "slot": slot})

# ───────── before / after ─────────

const PREVIEW := {
	"attack_dmg": ["Attack damage", "%"], "special_dmg": ["Special damage", "%"], "dash_dmg": ["Dash-strike damage", "%"], "cast_dmg": ["Sigil damage", "%"],
	"crit_chance": ["Crit chance", "%"], "crit_mul": ["Crit damage", "%"], "attack_speed": ["Attack speed", "%"], "move_speed": ["Move speed", "%"],
	"dash_charges": ["Dash charges", "n"], "dash_cooldown": ["Dash recovery", "%"], "max_hp": ["Max health", "n"], "damage_taken": ["Damage taken", "%"],
	"dodge": ["Dodge chance", "%"], "heal_on_room_clear": ["Heal per room", "n"], "burn_dps": ["Burn damage/stack", "f"], "burn_max": ["Max Burn", "n"],
	"chill_max": ["Chill to freeze", "n"], "chill_per_stack": ["Slow per Chill", "%"], "freeze_time": ["Freeze time", "s"], "freeze_vuln": ["Frozen damage taken", "%"],
	"shatter_dmg": ["Shatter damage", "n"], "jolt_chains": ["Lightning chains", "n"], "jolt_dmg": ["Lightning damage", "n"], "tide_slam_dmg": ["Slam damage", "n"],
	"hex_dmg_taken": ["Hexed damage taken", "%"], "hex_spread": ["Hex spread", "n"], "hex_burst": ["Hex burst", "n"], "bleed_burst": ["Bleed burst/stack", "n"], "bleed_max": ["Max Bleed", "n"],
}

static func _fmt_stat(v: float, kind: String) -> String:
	match kind:
		"%": return "%+d%%" % int(round(v * 100.0)) if absf(v) > 0.0001 else "0%"
		"s": return "%.1fs" % v
		"f": return "%.1f" % v
	return str(int(round(v)))

## exact numbers that change: returns [before_text, after_text]
static func preview(sim, id: String, rarity: int) -> Array:
	var run: RunState = sim.run
	var before: Stats = sim.stats
	var test_boons: Array = run.boons.duplicate(true)
	var slot := slot_of(id)
	if slot in SLOTS:
		test_boons = test_boons.filter(func(b): return slot_of(b.id) != slot)
	test_boons.append({"id": id, "rarity": rarity, "level": 1})
	var after := Stats.new()
	after.reset(sim.T)
	for b in test_boons:
		apply(after, b)
	Keepsakes.apply(after, run.keepsake)
	for fid in run.forges.keys():
		var F: Dictionary = sim.T.forges.get(fid, {})
		if F.has("stat"):
			after.apply_mod(String(F.stat), float(F.per) * int(run.forges[fid]))
	var b_lines: Array = []
	var a_lines: Array = []
	for k in PREVIEW.keys():
		var bv: float = before.get(k)
		var av: float = after.get(k)
		if absf(bv - av) > 0.0001:
			var info: Array = PREVIEW[k]
			b_lines.append("%s %s" % [info[0], _fmt_stat(bv, info[1])])
			a_lines.append("%s %s" % [info[0], _fmt_stat(av, info[1])])
	for s2 in ["attack", "special", "dash", "cast"]:
		if String(before.infuse[s2]) != String(after.infuse[s2]):
			b_lines.append("%s: %s" % [s2.capitalize(), _elem(String(before.infuse[s2]))])
			a_lines.append("%s: %s" % [s2.capitalize(), _elem(String(after.infuse[s2]))])
	if b_lines.is_empty():
		return ["New effect", def(id).get("name", id)]
	return ["\n".join(b_lines.slice(0, 3)), "\n".join(a_lines.slice(0, 3))]

static func _elem(p: String) -> String:
	match p:
		"ember": return "Burn"
		"rime": return "Chill"
		"storm": return "Lightning"
		"tide": return "Knockback"
		"dawn": return "Mark"
		"umbra": return "Hex"
		"gale": return "Buffet"
		"thorn": return "Bleed"
	return "—"
