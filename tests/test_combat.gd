extends TestBase

func _dummy(s: Sim, pos: Vector2, kind: String = "dummy") -> SimEnemy:
	var e := Enemies.spawn(s, kind, pos, 1, {"portal": false})
	return e

func _frames(t: float) -> int:
	return int(ceil(t * 60.0 - 0.001))

func test_weapon_frame_data_present() -> void:
	for id in Weapons.IDS:
		var W: Dictionary = T.weapons[id]
		check(W.has("special") and W.has("dash_attack") and W.has("overdrive"), "%s has special, dash attack and overdrive" % id)
		check((W.get("forges", []) as Array).size() == 3, "%s has exactly 3 weapon forges" % id)
		for f in W.forges:
			check(T.forges.has(f), "forge %s is defined" % f)
		if W.has("combo"):
			for step in W.combo:
				for k in ["windup", "active", "recovery", "dmg", "power", "knock", "lunge"]:
					check(step.has(k), "%s combo step has %s" % [id, k])

func test_fangs_combo_timing() -> void:
	var s := make_sim("fangs")
	var W: Dictionary = T.weapons.fangs
	var c0: Dictionary = W.combo[0]
	s.step(press("attack"), 1.0 / 60.0)
	check(s.player.state == SimPlayer.St.ATTACK and s.player.atk_phase == 0, "attack starts in windup")
	steps(s, _frames(float(c0.windup)))
	check(s.player.atk_phase == 1, "windup lasts %ss" % c0.windup)
	steps(s, _frames(float(c0.active)))
	check(s.player.atk_phase == 2, "active lasts %ss" % c0.active)
	steps(s, _frames(float(c0.recovery)) + 1)
	check(s.player.state == SimPlayer.St.FREE, "recovery ends the swing")
	check(s.player.atk_step == 1, "combo advanced to step 2")
	steps(s, _frames(float(W.combo_reset)) + 2)
	check(s.player.atk_step == 0, "combo resets after %ss idle" % W.combo_reset)

func test_combo_chains_four_steps() -> void:
	var s := make_sim("fangs")
	var held := InputFrame.new()
	held.attack_h = true
	held.attack_p = true
	var seen := {}
	for i in 120:
		s.step(held, 1.0 / 60.0)
		held.attack_p = false
		if s.player.state == SimPlayer.St.ATTACK:
			seen[s.player.atk_cur] = true
	check(seen.size() == 4, "holding attack walks the full 4-hit combo (saw %s)" % [seen.keys()])

func test_dash_cancels_recovery() -> void:
	var s := make_sim("anvil")
	s.step(press("attack"), 1.0 / 60.0)
	var c0: Dictionary = T.weapons.anvil.combo[0]
	steps(s, _frames(float(c0.windup) + float(c0.active)) + 1)
	check(s.player.atk_phase == 2, "in recovery")
	s.step(press("dash"), 1.0 / 60.0)
	check(s.player.state == SimPlayer.St.DASH, "dash cancels attack recovery")

func test_dash_attack_window() -> void:
	var s := make_sim("fangs")
	s.step(press("dash"), 1.0 / 60.0)
	steps(s, _frames(float(T.dash.duration)) + 1)
	s.step(press("attack"), 1.0 / 60.0)
	check(s.player.state == SimPlayer.St.ATTACK and s.player.atk_is_dash, "attack right after a dash is the dash-attack")
	var s2 := make_sim("fangs")
	s2.step(press("dash"), 1.0 / 60.0)
	steps(s2, _frames(float(T.dash.duration) + float(T.dash.dash_attack_window)) + 6)
	s2.step(press("attack"), 1.0 / 60.0)
	check(s2.player.state == SimPlayer.St.ATTACK and not s2.player.atk_is_dash, "late attack is a normal attack")

func test_every_weapon_damages() -> void:
	for id in Weapons.IDS:
		var s := make_sim(id)
		var e := _dummy(s, Vector2(70, 0))
		var f := InputFrame.new()
		f.attack_p = true
		f.attack_h = false
		for i in 90:
			s.step(f, 1.0 / 60.0)
			f.attack_p = i % 10 == 0
		check(e.hp < e.max_hp, "%s attack damages a target in front" % id)

func test_every_special_damages() -> void:
	for id in Weapons.IDS:
		var s := make_sim(id)
		var e := _dummy(s, Vector2(90, 0))
		var f := InputFrame.new()
		f.special_p = true
		f.special_h = true
		for i in 70:
			s.step(f, 1.0 / 60.0)
			f.special_p = false
			f.special_h = i < 40
		check(e.hp < e.max_hp, "%s special damages a target" % id)

func test_hitstop_budget() -> void:
	var s := make_sim()
	var budget: float = F.hitstop.budget_per_second
	var total := 0.0
	for i in 60:
		total += s.request_hitstop(0.09)
		steps(s, 1)
	check(total <= budget + 0.001, "hit-stop per rolling second is capped at %s (got %.3f)" % [budget, total])
	check(total >= budget * 0.5, "hit-stop still happens under spam (got %.3f)" % total)

func test_hitstop_scales_with_power() -> void:
	var s := make_sim()
	var lo := s.hitstop_for_power(0.0, false, false)
	var hi := s.hitstop_for_power(1.0, false, false)
	near(lo, float(F.hitstop.min), 0.0001, "power 0 → min hit-stop")
	near(hi, float(F.hitstop.max), 0.0001, "power 1 → max hit-stop")
	check(s.hitstop_for_power(1.0, true, true) > hi, "crit + kill add extra hit-stop")

func test_hitstop_freezes_world() -> void:
	var s := make_sim()
	s.request_hitstop(0.08)
	var t0 := s.time
	steps(s, 3)
	check(s.time == t0, "simulation time does not advance during hit-stop")
	check(absf(s.fx_scale() - float(F.hitstop.fx_speed_during_stop)) < 0.001, "FX run at 12% during hit-stop")
	steps(s, 10)
	check(s.time > t0, "time resumes after hit-stop")

func test_crit_multiplier() -> void:
	var s := make_sim()
	var e := _dummy(s, Vector2(100, 0))
	var h := HitInfo.make(10.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO)
	h.force_crit = true
	var d := Combat.deal(s, e, h)
	near(d, 10.0 * float(T.crit.multiplier), 0.01, "forced crit deals base × crit multiplier")

func test_knockback_and_wall_slam() -> void:
	var s := make_sim()
	var e := _dummy(s, Vector2(s.arena.rect.end.x - 60.0, 0), "dummy_walker")
	var slammed := [false]
	var bus := _Spy.new()
	s.bus = bus
	var h := HitInfo.make(20.0, "attack", 1.0, Vector2.RIGHT, e.pos - Vector2(40, 0))
	h.knock = 3.0
	Combat.deal(s, e, h)
	check(e.kvel.x > float(F.knockback.slam_speed), "a strong hit launches the enemy")
	steps(s, 30)
	check(bus.names.has(&"wall_slam"), "hitting the wall at speed triggers a wall slam")

func test_sigil_blast_roots() -> void:
	var s := make_sim("fangs")
	var e := _dummy(s, Vector2(150, 0), "dummy_walker")
	var f := press("cast")
	f.aim_source = InputFrame.Aim.MOUSE
	f.aim_point = e.pos
	s.step(f, 1.0 / 60.0)
	check(s.player.cast_charges == int(T.cast.charges) - 1, "Sigil uses a charge")
	steps(s, _frames(float(T.cast.delay)) + 3)
	check(e.hp < e.max_hp, "Sigil blast damages after its delay")
	check(e.root_t > 0.0, "Sigil roots enemies")

func test_sigil_recharge() -> void:
	var s := make_sim()
	s.step(press("cast"), 1.0 / 60.0)
	steps(s, 10)
	s.step(press("cast"), 1.0 / 60.0)
	check(s.player.cast_charges == 0, "two charges")
	steps(s, _frames(float(T.cast.recharge)) + 2)
	check(s.player.cast_charges == 1, "one charge returns after %ss" % T.cast.recharge)

func test_bow_perfect_release() -> void:
	var s := make_sim("bow")
	var C: Dictionary = T.weapons.bow.charge
	var f := InputFrame.new()
	f.attack_p = true
	f.attack_h = true
	s.step(f, 1.0 / 60.0)
	f.attack_p = false
	steps(s, _frames(float(C.hold_threshold) + float(C.time)) + 2, f)
	var spy := _Spy.new()
	s.bus = spy
	s.step(InputFrame.new(), 1.0 / 60.0)
	check(spy.names.has(&"perfect_release"), "releasing right as the charge fills is a perfect release")

func test_halo_returns() -> void:
	var s := make_sim("halo")
	s.step(press("attack"), 1.0 / 60.0)
	check(int(s.player.wstate.get("out", 0)) == 1, "halo thrown")
	steps(s, 120)
	check(int(s.player.wstate.get("out", 0)) == 0, "halo comes back")

func test_streak_tiers() -> void:
	var s := make_sim()
	var tiers: Array = F.streak.tiers
	for i in int(tiers[0]):
		var e := _dummy(s, Vector2(100 + i, 0), "dummy_walker")
		var h := HitInfo.make(9999.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO)
		Combat.deal(s, e, h)
	check(s.streak_tier == 1, "%d kills reach KINDLED" % tiers[0])
	steps(s, int(float(F.streak.window) * 60.0) + 30)
	check(s.streak_tier == 0, "streak breaks after its window")

class _Spy extends RefCounted:
	var names: Array = []
	func fire(n: StringName, _d: Dictionary) -> void:
		names.append(n)

func test_slowmo_eases_back() -> void:
	var s := make_sim()
	s.slowmo(0.2, 0.5)
	steps(s, 2)
	check(s.slow_scale < 0.5, "slow motion slows time")
	steps(s, 40)
	near(s.slow_scale, 1.0, 0.001, "time returns to normal after the slow-mo")
