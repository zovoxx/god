class_name SimEnemy
extends SimBody
## An enemy, guardian or boss. Behaviour comes from a brain (sim/ai/*.gd) keyed by def id;
## stats come from tuning.tres `enemies` / `bosses`.

var kind := ""
var name := ""
var def := {}
var brain = null
var role := ""
var depth := 1
var hp := 10.0
var max_hp := 10.0
var shield := 0.0
var max_shield := 0.0
var armor := 0.0
var max_armor := 0.0
var mass := 1.0
var speed := 100.0
var speed_mul := 1.0
var dmg_mul := 1.0
var elites: Array = []
var is_boss := false
var is_guardian := false
var summoned := false
var optional := false
var phase := 0

# AI
var st := 0
var t := 0.0
var cd := 0.0
var a := 0.0
var data := {}
var tele = null                 # current SimTele
var attack_name := ""
var target_pos := Vector2.ZERO

# combat state
var spawn_t := 0.0              # portal time remaining (harmless + invulnerable)
var stagger_t := 0.0
var root_t := 0.0
var invuln := false
var untargetable := false
var super_armor := false
var stagger_immune := false
var no_knock := false
var front_shield := 0.0         # full arc (radians) blocked in front
var contact := 0.0              # damage on touch while `contact_on`
var contact_on := false
var contact_hit_t := 0.0
var last_hit_t := -99.0
var hit_by_player := false
var finishable := false
var countered_t := 0.0

# statuses
var burn := 0.0
var chill := 0.0
var freeze_t := 0.0
var hex_t := 0.0
var bleed := 0.0
var mark_t := 0.0
var ionize_t := 0.0
var slow_t := 0.0
var blind_t := 0.0
var dot_acc := 0.0

# presentation hints (read-only for the view)
var flash_t := 0.0
var squash := 0.0
var squash_dir := Vector2.RIGHT
var glow := 0.0
var art := ""
var tint := Color.WHITE

func targetable() -> bool:
	return alive and spawn_t <= 0.0 and not untargetable

func harmful() -> bool:
	return alive and spawn_t <= 0.0

func frozen() -> bool:
	return freeze_t > 0.0

func staggered() -> bool:
	return stagger_t > 0.0 or freeze_t > 0.0

func can_act() -> bool:
	return alive and spawn_t <= 0.0 and stagger_t <= 0.0 and freeze_t <= 0.0

func hp_frac() -> float:
	return hp / maxf(1.0, max_hp)

func move_speed() -> float:
	var s := speed * speed_mul
	if chill > 0.0:
		s *= maxf(0.25, 1.0 - chill * 0.06)
	if slow_t > 0.0:
		s *= 0.6
	if root_t > 0.0:
		s = 0.0
	return s

func has_elite(id: String) -> bool:
	return elites.has(id)

func set_state(s: int) -> void:
	st = s
	t = 0.0
