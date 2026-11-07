extends TestBase

func _run_sim(seed_v: int = 3, opts: Dictionary = {}) -> Sim:
	var s := Sim.new(seed_v, null)
	s.set_arena(Rect2(-600, -380, 1200, 760), [], 0)
	var o := {"patrons": ["ember", "rime", "storm", "tide", "dawn", "gale", "umbra", "thorn"], "concord": true}
	o.merge(opts, true)
	var run := RunState.create(seed_v, "fangs", o)
	s.run = run
	s.equip_weapon("fangs")
	run.recompute(s)
	return s

func test_content_counts() -> void:
	var B: BoonData = Cfg.B
	check(B.patrons.size() == 8, "8 patron Lights")
	var per := {}
	var duos := 0
	for b in B.boons:
		if b.slot == "duo":
			duos += 1
		else:
			per[b.patron] = int(per.get(b.patron, 0)) + 1
	var total := 0
	for p in per.keys():
		total += int(per[p])
	check(total == 88, "88 patron boons (got %d)" % total)
	check(duos == 18, "18 duo boons (got %d)" % duos)
	for p in B.order:
		var slots := {}
		for b in B.boons:
			if b.patron == p:
				slots[b.slot] = true
		for sl in ["attack", "special", "dash", "cast", "revenge", "passive", "legendary"]:
			check(slots.has(sl), "%s has a %s boon" % [p, sl])
		var pd: Dictionary = B.patrons[p]
		check(pd.has("color") and (pd.greet as Array).size() >= 3, "%s has a colour and greetings" % p)
		check(Assets.has_sprite("p_" + p), "%s has a portrait" % p)

func test_boon_text_and_values() -> void:
	for b in Cfg.B.boons:
		var base: Array = b.base
		check((b.get("fmt", []) as Array).size() == base.size(), "%s fmt matches base" % b.id)
		var txt := Boons.describe(b.id, 0, 1)
		check(not txt.contains("{"), "%s description fills every value" % b.id)

func test_rarity_and_level_scaling() -> void:
	var d := Boons.def("ember_attack")
	var c := Boons.values(d, 0, 1)
	var r := Boons.values(d, 1, 1)
	var e := Boons.values(d, 2, 1)
	var l := Boons.values(d, 3, 1)
	check(c[0] < r[0] and r[0] < e[0] and e[0] < l[0], "common < rare < epic < legendary")
	var lv2 := Boons.values(d, 0, 2)
	check(lv2[0] > c[0], "levels raise values")
	var z := Boons.def("rime_zero")
	check(Boons.values(z, 0, 1)[0] == Boons.values(z, 3, 3)[0], "fixed values never scale")

func test_apply_every_boon() -> void:
	var s := _run_sim()
	for b in Cfg.B.boons:
		var st := Stats.new()
		st.reset(T)
		var before := JSON.stringify(st.to_dict())
		Boons.apply(st, {"id": b.id, "rarity": 1, "level": 1})
		check(JSON.stringify(st.to_dict()) != before, "%s changes the build" % b.id)

func test_infusion_and_stats() -> void:
	var st := Stats.new()
	st.reset(T)
	Boons.apply(st, {"id": "ember_attack", "rarity": 0, "level": 1})
	check(st.infuse.attack == "ember" and is_equal_approx(st.attack_dmg, 0.15), "Kiln Strike infuses attacks with Burn and +15%")
	Boons.apply(st, {"id": "gale_dash", "rarity": 0, "level": 1})
	check(st.dash_charges == 1.0, "Tailwind adds a dash charge")
	Boons.apply(st, {"id": "thorn_bark", "rarity": 0, "level": 1})
	check(st.damage_taken < 0.0, "Thick Bark reduces damage taken")
	Boons.apply(st, {"id": "ember_stoked", "rarity": 0, "level": 1})
	check(st.burn_dps > float(T.status.burn_dps), "Stoked multiplies Burn damage")

func test_slot_replacement() -> void:
	var s := _run_sim()
	Boons.grant(s, "ember_attack", 0)
	Boons.grant(s, "rime_attack", 1)
	check(not s.run.has_boon("ember_attack") and s.run.has_boon("rime_attack"), "a new attack boon replaces the old one")
	check(s.stats.infuse.attack == "rime", "the slot now inflicts Chill")
	check(s.run.boons.size() == 1, "one boon per slot")

func test_passive_and_legendary_requirements() -> void:
	var s := _run_sim()
	check(not Boons.eligible(s.run, "ember_stoked"), "a passive needs a boon from its Light")
	check(Boons.eligible(s.run, "ember_hearth"), "free passives are always available")
	Boons.grant(s, "ember_attack", 0)
	check(Boons.eligible(s.run, "ember_stoked"), "with one Ashka boon her passives unlock")
	check(not Boons.eligible(s.run, "ember_crown"), "the legendary needs two boons")
	Boons.grant(s, "ember_special", 0)
	check(Boons.eligible(s.run, "ember_crown"), "two Ashka boons unlock Inferno Crown")
	Boons.grant(s, "ember_crown", 3)
	check(not Boons.eligible(s.run, "ember_crown"), "owned boons are never offered again")

func test_every_duo_requirement() -> void:
	for b in Cfg.B.boons:
		if b.slot != "duo":
			continue
		var a: String = b.duo[0]
		var c: String = b.duo[1]
		var s := _run_sim(5, {"concord": false})
		Boons.grant(s, a + "_attack", 0)
		Boons.grant(s, c + "_special", 0)
		check(not Boons.eligible(s.run, b.id), "%s needs Concord" % b.id)
		s.run.concord = true
		check(Boons.eligible(s.run, b.id), "%s is available with %s + %s and Concord" % [b.id, a, c])
		var s2 := _run_sim(5)
		Boons.grant(s2, a + "_attack", 0)
		check(not Boons.eligible(s2.run, b.id), "%s needs a %s boon too" % [b.id, c])
		check(Boons.available_duos(s.run, a).has(b.id), "%s is listed for %s" % [b.id, a])

func test_offers_follow_rules() -> void:
	for seed_v in 20:
		var s := _run_sim(seed_v)
		var o := Boons.offer(s, "storm", 0, 3, null)
		check(o.options.size() == 3, "three choices")
		var ids := {}
		for op in o.options:
			ids[op.id] = true
			check(Boons.eligible(s.run, op.id), "offered boon %s is eligible" % op.id)
			check(Boons.def(op.id).patron in ["storm", "duo"], "offered by the right Light")
			check(op.has("before") and op.has("after"), "cards carry before/after numbers")
		check(ids.size() == 3, "no duplicates")
		var o2 := Boons.offer(s, "storm", 2, 3, null)
		for op in o2.options:
			check(int(op.rarity) >= 2, "rarity floor is respected")

func test_offer_determinism() -> void:
	var a := _run_sim(9)
	var b := _run_sim(9)
	var oa := Boons.offer(a, "tide", 0)
	var ob := Boons.offer(b, "tide", 0)
	check(JSON.stringify(oa.options.map(func(o): return [o.id, o.rarity])) == JSON.stringify(ob.options.map(func(o): return [o.id, o.rarity])), "boon offers are deterministic per seed")

func test_burn_math() -> void:
	var s := _run_sim()
	var e := Enemies.spawn(s, "dummy", Vector2(200, 0), 1, {"portal": false})
	e.def = e.def.duplicate()
	e.def["regen"] = 0.0
	Status.add_burn(s, e, 50.0)
	check(e.burn == s.stats.burn_max, "Burn stacks cap at burn_max")
	var hp0 := e.hp
	steps(s, 60)
	var dps_expected := s.stats.burn_max * s.stats.burn_dps
	check(e.hp < hp0 and hp0 - e.hp > dps_expected * 0.5, "Burn deals stacks × dps per second (lost %.1f)" % (hp0 - e.hp))

func test_chill_freeze_shatter() -> void:
	var s := _run_sim()
	s.run.boons.append({"id": "rime_shatter", "rarity": 0, "level": 1})
	s.run.recompute(s)
	var e := Enemies.spawn(s, "cinderling", Vector2(200, 0), 1, {"portal": false})
	var o := Enemies.spawn(s, "cinderling", Vector2(250, 0), 1, {"portal": false})
	Status.add_chill(s, e, s.stats.chill_max - 1.0)
	check(not e.frozen(), "below the threshold: chilled, not frozen")
	Status.add_chill(s, e, 1.0)
	check(e.frozen(), "%d Chill freezes" % s.stats.chill_max)
	var h := HitInfo.make(10.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO)
	h.can_crit = false
	var d := Combat.deal(s, e, h)
	near(d, 10.0 * (1.0 + s.stats.freeze_vuln), 0.01, "frozen enemies take more damage")
	var ohp := o.hp
	Combat.deal(s, e, HitInfo.make(9999.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO))
	check(o.hp < ohp, "frozen enemies shatter on death")

func test_hex_spreads_on_death() -> void:
	var s := _run_sim()
	var spy := _Spy.new()
	s.bus = spy
	var e := Enemies.spawn(s, "cinderling", Vector2(200, 0), 1, {"portal": false})
	var others: Array = []
	for i in 3:
		others.append(Enemies.spawn(s, "bramblehorn", Vector2(260 + i * 40, 60), 1, {"portal": false}))
	Status.hex(s, e)
	Combat.deal(s, e, HitInfo.make(9999.0, "attack", 0.3, Vector2.RIGHT, Vector2.ZERO))
	var hexed := others.filter(func(o): return o.hex_t > 0.0).size()
	check(hexed == int(s.stats.hex_spread), "Hex spreads to %d enemies on death (got %d)" % [s.stats.hex_spread, hexed])
	check(spy.names.has(&"synergy"), "spreading a Hex shows a +COMBO callout")

func test_bleed_bursts_on_heavy_hit() -> void:
	var s := _run_sim()
	var e := Enemies.spawn(s, "bramblehorn", Vector2(200, 0), 2, {"portal": false})
	e.bleed = 6.0
	var hp0 := e.hp
	var h := HitInfo.make(1.0, "attack", 0.9, Vector2.RIGHT, Vector2.ZERO)
	h.can_crit = false
	Status.add_bleed(s, e, 0.0, h)
	check(e.bleed == 0.0, "a heavy hit bursts the Bleed")
	near(hp0 - e.hp, 6.0 * s.stats.bleed_burst, 0.5, "burst deals stacks × bleed_burst")

func test_mark_raises_crit() -> void:
	var s := _run_sim()
	var e := Enemies.spawn(s, "dummy", Vector2(200, 0), 1, {"portal": false})
	var crits := [0, 0]
	for marked in [0, 1]:
		for i in 400:
			e.hp = e.max_hp
			e.mark_t = 5.0 if marked == 1 else 0.0
			var h := HitInfo.make(10.0, "attack", 0.0, Vector2.RIGHT, Vector2.ZERO)
			h.no_hitstop = true
			if Combat.deal(s, e, h) > 15.0:
				crits[marked] += 1
	check(crits[1] > crits[0] + 40, "Marked foes are crit far more often (%d vs %d)" % [crits[1], crits[0]])

func test_jolt_chains() -> void:
	var s := _run_sim()
	var es: Array = []
	for i in 4:
		es.append(Enemies.spawn(s, "dummy", Vector2(100 + i * 60, 0), 1, {"portal": false}))
	Status.jolt(s, es[0], 1.0, HitInfo.make(0.0, "attack", 0.2, Vector2.RIGHT, Vector2.ZERO))
	var hurt := es.filter(func(e): return e.hp < e.max_hp).size()
	check(hurt == 1 + int(s.stats.jolt_chains), "lightning chains to %d foes" % s.stats.jolt_chains)

func test_synergy_freeze_plus_lightning() -> void:
	var s := _run_sim()
	var spy := _Spy.new()
	s.bus = spy
	var e := Enemies.spawn(s, "cinderling", Vector2(200, 0), 1, {"portal": false})
	var o := Enemies.spawn(s, "cinderling", Vector2(260, 0), 1, {"portal": false})
	Status.freeze(s, o)
	Status.jolt(s, e, 1.0, HitInfo.make(0.0, "attack", 0.2, Vector2.RIGHT, Vector2.ZERO))
	check(spy.names.has(&"synergy"), "lightning striking a frozen foe is a synergy")

func test_every_boon_mechanic_runs() -> void:
	# grant each boon (with prerequisites) and fight dummies with every action
	for b in Cfg.B.boons:
		var s := _run_sim(7)
		var d: Dictionary = b
		var pats: Array = d.duo if d.slot == "duo" else [d.patron]
		for p in pats:
			Boons.grant(s, p + "_attack", 0)
			Boons.grant(s, p + "_special", 0)
		Boons.grant(s, d.id, 1)
		check(s.run.has_boon(d.id), "%s granted" % d.id)
		s.flow = null
		for i in 4:
			var e := Enemies.spawn(s, "cinderling", Vector2(80 + i * 30, -40 + i * 25), 1, {"portal": false})
		var f := InputFrame.new()
		for i in 150:
			f.attack_p = i % 8 == 0
			f.attack_h = true
			f.special_p = i == 40
			f.dash_p = i == 70 or i == 100
			f.cast_p = i == 20
			f.move = Vector2(1, 0) if i < 90 else Vector2(-1, 0.3)
			if i == 60:
				Combat.hurt_player(s, 3.0, s.player.pos + Vector2(40, 0), s.enemies[0] if not s.enemies.is_empty() else null, "Test")
			s.step(f, 1.0 / 60.0)

func test_overdrive_fills_and_empowers() -> void:
	var s := _run_sim()
	var e := Enemies.spawn(s, "dummy", Vector2(60, 0), 1, {"portal": false})
	for i in 200:
		Combat.deal(s, e, HitInfo.make(1.0, "attack", 0.5, Vector2.RIGHT, Vector2.ZERO))
		e.hp = e.max_hp
	check(s.player.overdrive_ready, "hits fill the Overdrive meter")
	var n_before := s.projectiles.size()
	s.step(press("special"), 1.0 / 60.0)
	steps(s, 20)
	check(not s.player.overdrive_ready, "the next Special consumes it")
	check(s.projectiles.size() - n_before >= int(T.weapons.fangs.overdrive.knives), "the empowered Fangs special throws a full ring of knives")
	var s2 := _run_sim()
	var before := s2.player.overdrive
	Combat.perfect_dash(s2, null, "Test")
	check(s2.player.overdrive > before, "a perfect dash fills Overdrive too")

class _Spy extends RefCounted:
	var names: Array = []
	func fire(n: StringName, _d: Dictionary) -> void:
		names.append(n)
