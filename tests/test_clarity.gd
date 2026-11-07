extends TestBase

func _enemy(s: Sim, pos: Vector2, kind: String = "effigy") -> SimEnemy:
	var e := Enemies.spawn(s, kind, pos, 1, {"portal": false})
	s.no_ai = true
	return e

func test_hurt_iframes_and_hitstop() -> void:
	var s := make_sim()
	var e := _enemy(s, Vector2(100, 0))
	check(Combat.hurt_player(s, 10.0, e.pos, e, "Test"), "first hit lands")
	near(s.hitstop, float(F.hitstop.hurt), 0.001, "getting hit causes 70 ms hit-stop")
	check(not Combat.hurt_player(s, 10.0, e.pos, e, "Test"), "second hit during i-frames is ignored")
	near(s.player.hurt_iframes, float(T.player.hurt_iframes), 0.001, "0.8 s of i-frames")
	check(s.player.kvel.length() > 0.0, "hurt knocks the player back")
	steps(s, int(float(T.player.hurt_iframes) * 60.0) + 12)
	check(Combat.hurt_player(s, 10.0, e.pos, e, "Test"), "can be hit again after the i-frames")

func test_damage_log_records_source() -> void:
	var s := make_sim()
	var e := _enemy(s, Vector2(100, 0))
	Combat.hurt_player(s, 7.0, e.pos, e, "Sweep")
	var log := Recap.damage_log(s)
	check(log.size() == 1 and log[0].source == "Sparring Effigy" and log[0].attack == "Sweep" and int(log[0].dmg) == 7, "damage log stores source, attack and damage")

func test_hitbox_smaller_than_sprite() -> void:
	check(float(T.player.hit_radius) < float(T.player.radius), "the hitbox is smaller than the body")

func test_chip_damage_timing() -> void:
	var chip := HpChip.new(60.0, float(F.hpbar.chip_delay), float(F.hpbar.chip_drain_speed), float(F.hpbar.heal_fill_speed))
	chip.update(0.016, 40.0, 60.0)
	near(chip.shown, 40.0, 0.001, "solid bar drops immediately")
	near(chip.chip, 60.0, 0.001, "white chip remains at the old value")
	var t := 0.0
	while t < float(F.hpbar.chip_delay) - 0.05:
		chip.update(0.016, 40.0, 60.0)
		t += 0.016
	near(chip.chip, 60.0, 0.001, "chip holds for %ss" % F.hpbar.chip_delay)
	for i in 120:
		chip.update(0.016, 40.0, 60.0)
	near(chip.chip, 40.0, 0.001, "chip drains after the delay")
	chip.update(0.016, 55.0, 60.0)
	check(chip.heal_to == 55.0 and chip.shown < 55.0, "heals fill gradually toward the new value")
	for i in 120:
		chip.update(0.016, 55.0, 60.0)
	near(chip.shown, 55.0, 0.001, "heal fill completes")

func test_min_windups() -> void:
	var s := make_sim()
	var e := _enemy(s, Vector2(200, 0))
	var t := AI.tele_circle(s, e, Vector2.ZERO, 50.0, 0.05, 5.0, "Quick")
	near(t.windup, float(T.pacing.enemy_min_windup), 0.0001, "regular enemies telegraph for at least 0.35 s")
	e.is_boss = true
	var t2 := AI.tele_circle(s, e, Vector2.ZERO, 50.0, 0.1, 5.0, "Quick")
	near(t2.windup, float(T.pacing.boss_min_windup), 0.0001, "bosses telegraph for at least 0.5 s")

func test_telegraph_hits_only_inside() -> void:
	var s := make_sim()
	var e := _enemy(s, Vector2(300, 0))
	AI.tele_circle(s, e, Vector2(200, 0), 60.0, 0.4, 9.0, "Far")
	steps(s, 30)
	check(s.player.hp == s.player.max_hp, "outside the shape: no damage")
	AI.tele_circle(s, e, s.player.pos, 60.0, 0.4, 9.0, "Near")
	steps(s, 30)
	check(s.player.hp < s.player.max_hp, "inside the shape: damage at impact")
	check(s.damage_log[-1].attack == "Near", "the attack name reaches the log")

func test_perfect_dash_window() -> void:
	var s := make_sim()
	var spy := _Spy.new()
	s.bus = spy
	var e := _enemy(s, Vector2(300, 0))
	var t := AI.tele_circle(s, e, s.player.pos, 60.0, 0.5, 9.0, "Slam")
	steps(s, int((0.5 - 0.1) * 60.0))  # 0.1 s left
	var f := press("dash")
	f.move = Vector2.DOWN
	s.step(f, 1.0 / 60.0)
	steps(s, 12)
	check(spy.names.has(&"perfect_dash"), "dashing through in the last 0.15 s is a PERFECT dash")
	check(s.player.guaranteed_crit > 0, "perfect dash guarantees the next crit")
	check(s.player.hp == s.player.max_hp, "and no damage is taken")
	# too early: not perfect
	var s2 := make_sim()
	var spy2 := _Spy.new()
	s2.bus = spy2
	var e2 := _enemy(s2, Vector2(300, 0))
	AI.tele_circle(s2, e2, s2.player.pos, 60.0, 0.6, 9.0, "Slam")
	steps(s2, 6)   # 0.5 s left
	var f2 := press("dash")
	f2.move = Vector2.DOWN
	s2.step(f2, 1.0 / 60.0)
	steps(s2, 40)
	check(not spy2.names.has(&"perfect_dash"), "an early dash is not perfect")

func test_spawn_portal_harmless_and_invulnerable() -> void:
	var s := make_sim()
	var e := Enemies.spawn(s, "effigy", Vector2(200, 0), 1)
	near(e.spawn_t, float(T.pacing.spawn_portal), 0.0001, "spawn portal lasts 0.42 s")
	var h := HitInfo.make(50.0, "attack", 0.5, Vector2.RIGHT, Vector2.ZERO)
	check(Combat.deal(s, e, h) == 0.0, "invulnerable while in the portal")
	check(not e.harmful(), "harmless while in the portal")
	steps(s, int(float(T.pacing.spawn_portal) * 60.0) + 2)
	check(e.targetable(), "targetable after the portal")

func test_spawn_min_distance() -> void:
	var s := make_sim()
	for i in 200:
		s.player.pos = Vector2(randf_range(-500, 500), randf_range(-300, 300))
		var p := Enemies.spawn_point(s, 20.0)
		if p.distance_to(s.player.pos) < float(T.pacing.spawn_min_dist):
			check(false, "spawn point %s too close to player %s" % [p, s.player.pos])
			return
	check(true, "")

func test_counter_interrupts() -> void:
	var s := make_sim()
	var spy := _Spy.new()
	s.bus = spy
	var e := _enemy(s, Vector2(60, 0))
	e.tele = AI.tele_circle(s, e, Vector2(60, 0), 60.0, 0.5, 9.0, "Slam")
	steps(s, int((0.5 - 0.06) * 60.0))
	check(e.tele.in_flash(float(F.telegraph.flash_window)), "telegraph is in its white flash")
	var tele: Tele = e.tele
	var h := HitInfo.make(5.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO)
	Combat.deal(s, e, h)
	check(tele.cancelled, "hitting during the flash interrupts the attack")
	check(e.stagger_t > 0.5, "the attacker is staggered")
	check(spy.names.has(&"enemy_countered"), "a counter event fires (clang)")
	steps(s, 10)
	check(s.player.hp == s.player.max_hp, "the interrupted attack deals no damage")

func test_finisher_executes() -> void:
	var s := make_sim()
	var e := _enemy(s, Vector2(60, 0), "dummy_walker")
	e.hp = e.max_hp * 0.1
	e.stagger_t = 1.0
	steps(s, 1)
	check(e.finishable, "staggered enemy under 15% HP glows as finishable")
	var h := HitInfo.make(1.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO)
	Combat.deal(s, e, h)
	check(not e.alive, "the next hit executes it")
	var orbs := s.pickups.filter(func(p): return p.kind == "orb").size()
	check(orbs == int(F.finisher.orbs), "finishers drop HP orbs")

func test_enemy_projectile_hurts_hitbox() -> void:
	var s := make_sim()
	var e := _enemy(s, Vector2(300, 0))
	AI.shoot(s, e, Vector2(200, 0), PI, 600.0, 6.0, "Bolt")
	steps(s, 30)
	check(s.player.hp == s.player.max_hp - 6.0, "an enemy projectile that reaches the hitbox deals its damage")
	# a projectile that passes the sprite edge but misses the small hitbox does nothing
	var s2 := make_sim()
	var e2 := _enemy(s2, Vector2(300, 0))
	var off := float(T.player.hit_radius) + 9.0 + 3.0
	AI.shoot(s2, e2, Vector2(200, off), PI, 600.0, 6.0, "Bolt")
	steps(s2, 40)
	check(s2.player.hp == s2.player.max_hp, "grazing the sprite outside the hitbox is safe")

class _Spy extends RefCounted:
	var names: Array = []
	func fire(n: StringName, _d: Dictionary) -> void:
		names.append(n)
