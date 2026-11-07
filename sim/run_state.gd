class_name RunState
extends RefCounted
## Everything that belongs to one descent: weapon, build, currencies, position in the depths,
## modifiers (vows, heat, keepsake, daily) and run statistics. Serialisable for mid-run resume.

var seed := 0
var weapon := "fangs"
var depth := 1                  # 1..4
var step := 0                   # index into Rooms.STEPS
var room_index := 0             # rooms entered this run
var plan := {}                  # the current room plan
var doors: Array = []           # plans offered after this room

var hp := 60.0
var max_hp_base := 60.0
var max_hp_bonus := 0.0         # from the Wick
var boons: Array = []           # [{id, rarity, level}]
var forges := {}                # forge id -> level
var gold := 0
var embers := 0
var rerolls := 1
var fate_dice := 0
var defiance := 1
var keepsake := ""
var shops_this_depth := 0
var vows: Array = []
var heat := 0
var heat_mods: Array = []
var daily := false
var deepening := 0
var concord := false
var forge_unlocks := 3          # weapon forges available (weapon mastery unlocks them)
var patrons: Array = ["ember", "rime", "storm", "tide"]
var won := false
var dead := false

# statistics (run summary, achievements, vows)
var time := 0.0
var kills := 0
var elite_kills := 0
var rooms_cleared := 0
var stats_dmg_dealt := 0.0
var dmg_taken := 0.0
var dmg_by_source := {}         # source name -> damage
var dmg_by_depth := [0.0, 0.0, 0.0, 0.0]
var best_hit := 0.0
var best_streak := 0
var perfect_dashes := 0
var counters := 0
var finishers := 0
var room_times: Array = []
var bosses_killed: Array = []
var guardians_killed: Array = []
var kills_by_kind := {}
var springs_used := 0
var synergies := 0
var killer := {}

static func create(seed_v: int, weapon_id: String, opts: Dictionary = {}) -> RunState:
	var r := RunState.new()
	r.seed = seed_v
	r.weapon = weapon_id
	var T: Tuning = Cfg.T
	r.max_hp_base = float(T.player.max_hp)
	r.max_hp_bonus = float(opts.get("max_hp_bonus", 0.0))
	r.defiance = int(opts.get("defiance", T.economy.start_defiance))
	r.rerolls = int(opts.get("rerolls", T.economy.start_rerolls))
	r.fate_dice = int(opts.get("fate_dice", 0))
	r.gold = int(opts.get("gold", 0))
	r.keepsake = String(opts.get("keepsake", ""))
	r.vows = opts.get("vows", [])
	r.heat = int(opts.get("heat", 0))
	r.heat_mods = opts.get("heat_mods", [])
	r.daily = bool(opts.get("daily", false))
	r.deepening = int(opts.get("deepening", 0))
	r.concord = bool(opts.get("concord", false))
	r.forge_unlocks = int(opts.get("forge_unlocks", 3))
	r.patrons = opts.get("patrons", ["ember", "rime", "storm", "tide"])
	r.depth = int(opts.get("depth", 1))
	r.hp = r.max_hp()
	return r

func max_hp() -> float:
	return max_hp_base + max_hp_bonus

# ───────── modifiers ─────────

func has_vow(id: String) -> bool:
	return vows.has(id)

func has_heat(id: String) -> bool:
	return heat_mods.has(id)

func enemy_hp_mul() -> float:
	var m := 1.0 + float(step) * float(Cfg.T.scaling.hp_per_step)
	if has_heat("hardened"):
		m *= 1.25
	return m

func enemy_dmg_mul() -> float:
	var m := 1.0
	if has_heat("cruel"):
		m *= 1.3
	return m

func player_dmg_mul() -> float:
	return 1.0

func hurt_mul() -> float:
	return 1.0

# ───────── events ─────────

func add_gold(n: int) -> void:
	gold += n

func on_enemy_killed(sim, e: SimEnemy) -> void:
	if e.summoned and not e.is_boss:
		return
	kills += 1
	kills_by_kind[e.kind] = int(kills_by_kind.get(e.kind, 0)) + 1
	if not e.elites.is_empty():
		elite_kills += 1
	if e.is_boss and not bosses_killed.has(e.kind):
		bosses_killed.append(e.kind)
	if e.is_guardian and not guardians_killed.has(e.kind):
		guardians_killed.append(e.kind)

func on_player_hurt(entry: Dictionary) -> void:
	var d := float(entry.dmg)
	dmg_taken += d
	var src := String(entry.source)
	dmg_by_source[src] = float(dmg_by_source.get(src, 0.0)) + d
	dmg_by_depth[clampi(depth - 1, 0, 3)] += d
	killer = entry

func boon_names() -> Array:
	var out: Array = []
	for b in boons:
		out.append(String(Boons.def(b.id).get("name", b.id)))
	return out

func has_boon(id: String) -> bool:
	for b in boons:
		if b.id == id:
			return true
	return false

func boon(id: String):
	for b in boons:
		if b.id == id:
			return b
	return null

## rebuilds derived stats from boons, forges, keepsake and run bonuses
func recompute(sim) -> void:
	var st := Stats.new()
	st.reset(sim.T)
	for b in boons:
		Boons.apply(st, b)
	for fid in forges.keys():
		var F: Dictionary = sim.T.forges.get(fid, {})
		if F.has("stat"):
			st.apply_mod(String(F.stat), float(F.per) * int(forges[fid]))
	Keepsakes.apply(st, keepsake)
	sim.stats = st
	Status.chill_slow = st.chill_per_stack
	Status.dread = st.val("dread")
	var p: SimPlayer = sim.player
	var old_max := p.max_hp
	p.max_hp = max_hp() + st.max_hp
	if p.max_hp > old_max and old_max > 0.0:
		p.hp += p.max_hp - old_max
	p.hp = minf(p.hp, p.max_hp)
	p.dash_max = int(sim.T.dash.charges) + int(st.dash_charges)
	p.dash_charges = mini(p.dash_charges, p.dash_max)
	p.cast_max = int(sim.T.cast.charges) + int(st.cast_charges)
	p.cast_charges = mini(p.cast_charges, p.cast_max)
	if sim.weapon != null:
		sim.weapon.forge_levels = forges

# ───────── save / load ─────────

const SAVE_KEYS := ["seed", "weapon", "depth", "step", "room_index", "plan", "doors", "hp", "max_hp_base", "max_hp_bonus", "boons", "forges",
	"gold", "embers", "rerolls", "fate_dice", "defiance", "keepsake", "shops_this_depth", "vows", "heat", "heat_mods", "daily", "deepening",
	"concord", "forge_unlocks", "patrons", "time", "kills", "elite_kills", "rooms_cleared", "stats_dmg_dealt", "dmg_taken", "dmg_by_source", "dmg_by_depth",
	"best_hit", "best_streak", "perfect_dashes", "counters", "finishers", "room_times", "bosses_killed", "guardians_killed", "kills_by_kind",
	"springs_used", "synergies"]

func to_dict() -> Dictionary:
	var d := {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	return d

static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	for k in SAVE_KEYS:
		if d.has(k):
			var v = d[k]
			var cur = r.get(k)
			if cur is int and v is float:
				v = int(v)
			r.set(k, v)
	# JSON turns ints into floats; normalise the nested ones we rely on
	for b in r.boons:
		b.rarity = int(b.rarity)
		b.level = int(b.get("level", 1))
	for k in r.forges.keys():
		r.forges[k] = int(r.forges[k])
	return r
