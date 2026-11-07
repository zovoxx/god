class_name Stats
extends RefCounted
## Derived build stats. Rebuilt from scratch whenever boons/forges/keepsakes change.
## Gameplay code only reads this. Boon data in boons.tres writes into it through `apply_mod`.

var attack_dmg := 0.0
var special_dmg := 0.0
var dash_dmg := 0.0
var cast_dmg := 0.0
var all_dmg := 0.0
var vs_status_dmg := 0.0
var vs_elite_dmg := 0.0
var crit_chance := 0.0
var crit_mul := 0.0
var attack_speed := 0.0
var special_speed := 0.0
var move_speed := 0.0
var dash_charges := 0.0
var dash_cooldown := 0.0
var dash_distance := 0.0
var max_hp := 0.0
var cast_charges := 0.0
var cast_radius := 0.0
var cast_recharge := 0.0
var damage_taken := 0.0
var dodge := 0.0
var gold_gain := 0.0
var heal_on_room_clear := 0.0
var knockback := 0.0
var overdrive_gain := 0.0

## slot -> patron id ("" = none) and its power (rarity scaled)
var infuse := {"attack": "", "special": "", "dash": "", "cast": ""}
var infuse_pow := {"attack": 0.0, "special": 0.0, "dash": 0.0, "cast": 0.0}

# element parameters (initialised from tuning.status, boons modify them)
var burn_dps := 2.2
var burn_max := 20.0
var burn_decay := 0.18
var chill_per_stack := 0.06
var chill_max := 10.0
var freeze_time := 1.4
var freeze_vuln := 0.4
var shatter_dmg := 0.0
var jolt_chains := 2.0
var jolt_dmg := 10.0
var jolt_range := 170.0
var tide_knock := 0.6
var tide_slam_dmg := 18.0
var mark_crit := 0.25
var hex_dmg_taken := 0.25
var hex_spread := 2.0
var hex_burst := 22.0
var bleed_burst := 6.0
var bleed_max := 12.0

## free-form flags & numbers for unique mechanics, keyed by name
var f := {}

func reset(T: Tuning) -> void:
	var S: Dictionary = T.status
	burn_dps = S.burn_dps
	burn_max = S.burn_max
	burn_decay = S.burn_decay
	chill_per_stack = S.chill_per_stack
	chill_max = S.chill_max
	freeze_time = S.freeze_time
	freeze_vuln = S.freeze_vuln
	jolt_chains = S.jolt_chains
	jolt_dmg = S.jolt_dmg
	jolt_range = S.jolt_range
	tide_knock = S.tide_knock
	tide_slam_dmg = S.tide_slam_dmg
	mark_crit = T.crit.mark_bonus
	hex_dmg_taken = S.hex_dmg_taken
	hex_spread = S.hex_spread
	hex_burst = S.hex_burst
	bleed_burst = S.bleed_burst
	bleed_max = S.bleed_max

func has(flag: String) -> bool:
	return float(f.get(flag, 0.0)) > 0.0

func val(flag: String) -> float:
	return float(f.get(flag, 0.0))

func add(flag: String, v: float) -> void:
	f[flag] = float(f.get(flag, 0.0)) + v

## key forms: "name" adds, "-name" subtracts, "*name" multiplies by (1+v), "f:name" adds to a flag,
## "=name" sets. Unknown plain names are treated as flags so content can grow freely.
func apply_mod(key: String, v: float) -> void:
	if key.begins_with("f:"):
		add(key.substr(2), v)
		return
	var op := "+"
	var k := key
	if key[0] in ["-", "*", "="]:
		op = key[0]
		k = key.substr(1)
	if not (k in self):
		if op == "-":
			add(k, -v)
		else:
			add(k, v)
		return
	var cur: float = get(k)
	match op:
		"+": set(k, cur + v)
		"-": set(k, cur - v)
		"*": set(k, cur * (1.0 + v))
		"=": set(k, v)

func slot_dmg(slot: String) -> float:
	match slot:
		"attack": return attack_dmg
		"special": return special_dmg
		"dash": return dash_dmg
		"cast": return cast_dmg
	return 0.0

func to_dict() -> Dictionary:
	var d := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d[p.name] = get(p.name)
	return d
