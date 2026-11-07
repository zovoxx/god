extends TestBase

func _kinds(depth: int) -> Array:
	var out: Array = []
	for k in T.enemies.keys():
		if int(T.enemies[k].get("depth", 0)) == depth:
			out.append(k)
	return out

func _bosses(depth: int) -> Array:
	var out: Array = []
	for k in T.bosses.keys():
		if int(T.bosses[k].get("depth", 0)) == depth and (T.bosses[k].get("boss", false) or T.bosses[k].get("guardian", false)):
			out.append(k)
	return out

func test_roster_sizes() -> void:
	for d in [1, 2, 3, 4]:
		var main := _kinds(d).filter(func(k): return not T.enemies[k].get("summon", false))
		check(main.size() == 8, "depth %d has 8 enemies (has %d: %s)" % [d, main.size(), main])
		var bs := _bosses(d)
		check(bs.filter(func(k): return T.bosses[k].get("guardian", false)).size() == 2, "depth %d has 2 guardians" % d)
		check(bs.filter(func(k): return T.bosses[k].get("boss", false)).size() == 1, "depth %d has a boss" % d)

func test_every_enemy_has_brain_art_and_tip() -> void:
	for d in [1, 2, 3, 4]:
		for k in _kinds(d) + _bosses(d):
			var def: Dictionary = T.enemies.get(k, T.bosses.get(k, {}))
			check(Enemies.brain_for(k) != Enemies.brain_for("_default") or k == "_default", "%s has a brain" % k)
			check(Assets.has_sprite(String(def.get("art", k))), "%s has a sprite" % k)
			check(String(def.get("tip", "")).length() > 10, "%s has a death-recap tip" % k)

func _soak(kind: String, seconds: float, depth: int) -> Dictionary:
	var s := make_sim("fangs", 7)
	s.god_mode = true
	var spy := _Spy.new()
	s.bus = spy
	s.player.pos = Vector2(0, 0)
	var group := int(T.enemies.get(kind, {}).get("group", 1))
	var e: SimEnemy = null
	for g in group:
		e = Enemies.spawn(s, kind, Vector2(260, -80 + g * 160), depth)
	var f := InputFrame.new()
	var frames := int(seconds * 60.0)
	for i in frames:
		# wander so ranged/lunge enemies have a moving target
		f.move = Vector2(cos(i * 0.02), sin(i * 0.031)) * 0.6
		s.step(f, 1.0 / 60.0)
	return {"sim": s, "spy": spy, "e": e}

func test_enemies_attack_with_telegraphs() -> void:
	for d in [1, 2, 3, 4]:
		for k in _kinds(d):
			if k in ["tidecleric", "bellwether", "aegisherald", "pylon", "voidportal"]:
				continue  # support/summons: they buff, heal or spawn instead of attacking  # support: heals allies, attacks only when nobody needs mending (covered below)
			var r := _soak(k, 9.0, d)
			var spy: _Spy = r.spy
			check(spy.count(&"telegraph_started") + spy.count(&"hazard_warn") > 0, "%s telegraphs its attacks" % k)
			check(spy.count(&"player_hurt") > 0 or spy.count(&"telegraph_impact") > 0 or spy.count(&"hazard_warn") > 0, "%s attacks resolve" % k)

func test_bosses_cycle_named_attacks_and_phase() -> void:
	for d in [1, 2, 3, 4]:
		for k in _bosses(d):
			var s := make_sim("fangs", 11)
			s.god_mode = true
			var spy := _Spy.new()
			s.bus = spy
			var e := Enemies.spawn(s, k, Vector2(300, 0), d)
			var f := InputFrame.new()
			for i in 60 * 30:
				f.move = Vector2(cos(i * 0.017), sin(i * 0.023)) * 0.7
				s.step(f, 1.0 / 60.0)
			var names := {}
			for dd in spy.data_of(&"boss_callout"):
				names[dd.text] = true
			check(names.size() >= 3, "%s uses at least 3 named attacks in 30 s (used %s)" % [k, names.keys()])
			e.hp = e.max_hp * 0.45
			for i in 10:
				s.step(f, 1.0 / 60.0)
			check(e.phase == 1 and spy.count(&"boss_phase") == 1, "%s enters phase 2 below 50%%" % k)
			check(e.invuln, "%s roars invulnerably during the phase change" % k)
			for i in 120:
				s.step(f, 1.0 / 60.0)
			check(not e.invuln, "%s becomes vulnerable again" % k)

func test_boss_attack_lists_have_six() -> void:
	for k in ["boss_stag", "boss_archivist", "boss_engine", "boss_regent"]:
		var b = Enemies.brain_for(k)
		check(b.attacks.size() >= 6, "%s has 6+ named attacks" % k)
		check(b.attacks.any(func(a): return int(a.get("min_phase", 0)) >= 1), "%s unlocks something in phase 2" % k)

func test_elite_modifiers() -> void:
	var s := make_sim()
	var base := Enemies.spawn(s, "cinderling", Vector2(300, 0), 1, {"portal": false})
	for m in Elites.ALL:
		var e := Enemies.spawn(s, "cinderling", Vector2(300, 100), 1, {"portal": false, "elites": [m]})
		check(e.max_hp > base.max_hp, "%s elites are tougher" % m)
		match m:
			"shielded": check(e.shield > 0.0, "shielded has a shield")
			"hulking": check(e.radius > base.radius and e.super_armor, "hulking is huge and steady")
			"hasted": check(e.speed_mul > 1.0, "hasted is faster")
			"orbiting":
				var n := s.projectiles.filter(func(p): return p.owner == e and p.kind == SimProj.Kind.ORBIT).size()
				check(n == int(T.elites.orbiting.blades), "orbiting has %d blades" % T.elites.orbiting.blades)

func test_elite_combinations() -> void:
	var s := make_sim()
	for i in Elites.ALL.size():
		for j in range(i + 1, Elites.ALL.size()):
			var mods := [Elites.ALL[i], Elites.ALL[j]]
			var e := Enemies.spawn(s, "bramblehorn", Vector2(300, 0), 2, {"portal": false, "elites": mods})
			check(e.elites.size() == 2, "combination %s applies" % [mods])
			e.alive = false
	Enemies.cleanup(s)
	s.projectiles.clear()

func test_elite_death_effects() -> void:
	var s := make_sim()
	var v := Enemies.spawn(s, "cinderling", Vector2(300, 0), 1, {"portal": false, "elites": ["volatile"]})
	var b := Enemies.spawn(s, "cinderling", Vector2(-300, 0), 1, {"portal": false, "elites": ["brood"]})
	var n_before := s.enemies.size()
	for e in [v, b]:
		Combat.deal(s, e, HitInfo.make(99999.0, "attack", 0.5, Vector2.RIGHT, Vector2.ZERO))
	check(s.telegraphs.any(func(t): return t.attack_name == "Volatile Blast"), "volatile elites explode after death (telegraphed)")
	var kids := s.enemies.filter(func(e): return e.alive and e.data.get("brood_child", false)).size()
	check(kids == 2, "brood elites split into two copies")

func test_blinking_and_vampiric() -> void:
	var s := make_sim()
	var e := Enemies.spawn(s, "bramblehorn", Vector2(300, 0), 1, {"portal": false, "elites": ["blinking"]})
	var p0 := e.pos
	Combat.deal(s, e, HitInfo.make(5.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO))
	check(e.pos.distance_to(p0) > 100.0, "blinking elites teleport when struck")
	var vamp := Enemies.spawn(s, "bramblehorn", Vector2(300, 0), 1, {"portal": false, "elites": ["vampiric"]})
	vamp.hp = vamp.max_hp * 0.5
	var before := vamp.hp
	Combat.hurt_player(s, 10.0, vamp.pos, vamp, "Charge")
	check(vamp.hp > before, "vampiric elites heal when they hurt you")

func test_wave_plan_determinism() -> void:
	for depth in [1, 2]:
		var a := RandomNumberGenerator.new()
		a.seed = 4242
		var b := RandomNumberGenerator.new()
		b.seed = 4242
		var pa := Encounters.plan(T, a, depth, 2, "combat", 0)
		var pb := Encounters.plan(T, b, depth, 2, "combat", 0)
		check(JSON.stringify(pa) == JSON.stringify(pb), "same seed → same waves (depth %d)" % depth)
		check(pa.size() == 3, "combat rooms have 3 waves")
		var c := RandomNumberGenerator.new()
		c.seed = 999
		check(JSON.stringify(Encounters.plan(T, c, depth, 2, "combat", 0)) != JSON.stringify(pa), "different seeds vary")

func test_deepening_gates_enemies() -> void:
	for i in 30:
		var r := RandomNumberGenerator.new()
		r.seed = i
		for w in Encounters.plan(T, r, 1, 2, "combat", 0):
			for g in w.groups:
				check(int(T.enemies[g.kind].get("unlock", 0)) == 0, "Deepening-locked enemies stay out at tier 0 (%s)" % g.kind)

func test_waves_run_and_clear() -> void:
	var s := make_sim("fangs", 5)
	s.one_hit = true
	s.god_mode = true
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var run := Encounters.Runner.new()
	run.start(Encounters.plan(T, r, 1, 1, "combat", 0), 1, 0.2)
	var f := InputFrame.new()
	var spawned := 0
	for i in 60 * 90:
		run.update(s, 1.0 / 60.0)
		# auto-kill everything once it is targetable
		for e in s.enemies:
			if e.targetable():
				Combat.deal(s, e, HitInfo.make(1.0, "attack", 0.1, Vector2.RIGHT, s.player.pos))
		s.step(f, 1.0 / 60.0)
		if run.done and s.living_enemies() == 0:
			break
	check(run.done, "all waves spawned")
	check(s.living_enemies() == 0, "room can be cleared")

class _Spy extends RefCounted:
	var names: Array = []
	var datas: Array = []
	func fire(n: StringName, d: Dictionary) -> void:
		names.append(n)
		datas.append([n, d])
	func count(n: StringName) -> int:
		return names.count(n)
	func data_of(n: StringName) -> Array:
		return datas.filter(func(x): return x[0] == n).map(func(x): return x[1])

func test_depth34_specials() -> void:
	var s := make_sim()
	s.god_mode = true
	# Gyrosaw is invulnerable while spinning
	var g := Enemies.spawn(s, "gyrosaw", Vector2(300, 0), 3, {"portal": false})
	for i in 180:
		s.step(InputFrame.new(), 1.0 / 60.0)
		if g.data.get("spin", false):
			break
	check(g.data.get("spin", false) and g.invuln, "Gyrosaw spins invulnerably")
	# Mirror Knight reflects hits while guarding
	var m := Enemies.spawn(s, "mirrorknight", Vector2(100, 0), 4, {"portal": false})
	m.data["guard"] = true
	check(Combat.deal(s, m, HitInfo.make(10.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO)) == 0.0, "Mirror Knight's guard reflects the hit")
	# Ironclad armor breaks into a stun
	var ic := Enemies.spawn(s, "ironclad", Vector2(-200, 0), 3, {"portal": false})
	var h := HitInfo.make(ic.armor + 5.0, "attack", 0.8, Vector2.RIGHT, Vector2.ZERO)
	Combat.deal(s, ic, h)
	check(ic.armor == 0.0 and ic.stagger_t > 1.0, "breaking Ironclad armor stuns it")
	# Bellwether buff reduces damage
	var b := Enemies.spawn(s, "bellwether", Vector2(0, -200), 3, {"portal": false})
	var ally := Enemies.spawn(s, "rivethound", Vector2(30, -200), 3, {"portal": false})
	s.no_ai = false
	steps(s, 20)
	ally.pos = b.pos + Vector2(30, 0)
	steps(s, 2)
	var hh := HitInfo.make(10.0, "attack", 0.0, Vector2.RIGHT, Vector2.ZERO)
	hh.can_crit = false
	near(Combat.deal(s, ally, hh), 7.0, 0.01, "allies in the Bellwether's ring take 30% less")

func test_sparkmites_shake_off() -> void:
	var s := make_sim()
	var m := Enemies.spawn(s, "sparkmite", Vector2(60, 0), 3, {"portal": false})
	m.data["latched"] = true
	m.data["off"] = Vector2(10, 0)
	s.step(InputFrame.new(), 1.0 / 60.0)
	check(s.player.latched == 1 and s.move_speed() < float(T.player.max_speed), "a clinging mite slows you")
	s.step(press("dash"), 1.0 / 60.0)
	s.step(InputFrame.new(), 1.0 / 60.0)
	check(not m.data.get("latched", false), "dashing shakes it off")
