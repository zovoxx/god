class_name TestBase
extends RefCounted
## Assertion helpers and simulation fixtures for tests.

var T: Tuning
var F: GameFeel
var current := ""
var failed: Array = []

func check(cond: bool, msg: String) -> void:
	if not cond:
		failed.append(msg)

func near(a: float, b: float, eps: float, msg: String) -> void:
	if absf(a - b) > eps:
		failed.append("%s (got %s, expected %s ±%s)" % [msg, a, b, eps])

## a sim in an empty arena with the given weapon (or none)
func make_sim(weapon_id: String = "", seed_v: int = 99) -> Sim:
	var s := Sim.new(seed_v, null)
	s.set_arena(Rect2(-600, -380, 1200, 760), [], 0)
	if weapon_id != "" and s.has_method("equip_weapon"):
		s.equip_weapon(weapon_id)
	return s

func steps(s: Sim, n: int, inp: InputFrame = null) -> void:
	for i in n:
		s.step(inp if inp != null else InputFrame.new(), 1.0 / 60.0)

func press(action: String) -> InputFrame:
	var f := InputFrame.new()
	match action:
		"attack": f.attack_p = true
		"special": f.special_p = true
		"dash": f.dash_p = true
		"cast": f.cast_p = true
	return f
