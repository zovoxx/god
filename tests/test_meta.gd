extends TestBase

func test_wick_purchases_and_requirements() -> void:
	var m := Meta.fresh()
	m.embers = 30
	check(not Meta.can_buy(m, "heart2"), "Ember Heart II needs Ember Heart")
	check(Meta.buy(m, "heart1"), "buying Ember Heart works")
	check(int(m.embers) == 15, "cost is deducted")
	check(not Meta.buy(m, "heart1"), "an unlock can be bought once")
	check(not Meta.buy(m, "heart2"), "not enough Embers for Ember Heart II")
	m.embers = 100
	check(Meta.buy(m, "heart2"), "requirement met + enough Embers")
	check(not Meta.can_buy(m, "nonexistent"), "unknown unlocks are refused")

func test_unlocks_shape_runs() -> void:
	var m := Meta.fresh()
	var o := Meta.run_options(m, {})
	check(o.weapon == "fangs" and o.patrons.size() == 4 and not o.concord, "a fresh Wick: Fangs, 4 Lights, no Concord")
	check(int(o.defiance) == int(T.economy.start_defiance), "one Death Defiance")
	m.unlocks = ["w_bow", "p_dawn", "p_thorn", "concord", "heart1", "heart2", "defy2", "reroll2", "fatedie", "purse", "deep1", "k_charm"]
	m.keepsake = "k_charm"
	var o2 := Meta.run_options(m, {"weapon": "bow"})
	check(o2.weapon == "bow", "unlocked weapons can be chosen")
	check(o2.patrons.has("dawn") and o2.patrons.has("thorn") and o2.patrons.size() == 6, "unlocked Lights join the pool")
	check(o2.concord, "Concord enables duos")
	check(float(o2.max_hp_bonus) == 20.0, "both hearts add +20 max health")
	check(int(o2.defiance) == int(T.economy.start_defiance) + 1, "Second Wick adds a Death Defiance")
	check(int(o2.rerolls) == int(T.economy.start_rerolls) + 1 and int(o2.fate_dice) == 1, "rerolls and the Fate Die")
	check(int(o2.gold) == 40, "Moth Purse starts with 40 gold")
	check(int(o2.deepening) == 1, "Deepening tier")
	check(o2.keepsake == "k_charm", "the equipped keepsake comes along")
	var o3 := Meta.run_options(m, {"weapon": "halo"})
	check(o3.weapon != "halo", "locked weapons can't be chosen")

func test_keepsake_applies() -> void:
	var st := Stats.new()
	st.reset(T)
	Keepsakes.apply(st, "k_locket")
	check(st.max_hp == 15.0, "Iron Locket gives +15 max health")

func test_mastery_levels_unlock_forges() -> void:
	var m := Meta.fresh()
	check(Meta.forge_unlocks(m, "fangs") == 1, "one forge at mastery 0")
	var th: Array = T.meta.mastery.thresholds
	m.mastery = {"fangs": int(th[1])}
	check(Meta.mastery_level(m, "fangs") == 1 and Meta.forge_unlocks(m, "fangs") == 2, "mastery 1 unlocks the second forge")
	m.mastery = {"fangs": int(th[3])}
	check(Meta.forge_unlocks(m, "fangs") == 3, "mastery 3 unlocks the third forge")

func test_end_run_embers_and_bonuses() -> void:
	var m := Meta.fresh()
	var r := RunState.create(1, "fangs", {"deepening": 1, "heat": 2, "heat_mods": ["hardened"]})
	r.embers = 10
	r.depth = 2
	r.dead = true
	var res := Meta.end_run(m, r, {"won": false})
	var expect := int(round((10 + int(T.economy.ember_per_depth_reached)) * (1.0 + float(T.meta.deepening_ember_bonus) + 2.0 * float(T.meta.heat_ember_bonus))))
	check(int(res.embers) == expect and int(m.embers) == expect, "Embers include depth progress and Deepening/Heat bonuses (%d vs %d)" % [res.embers, expect])
	check(int(m.runs) == 1 and int(m.deaths) == 1, "runs and deaths counted")
	check(not res.get("next_unlock", {}).is_empty(), "the recap knows the next unlock")

func test_vows() -> void:
	var r := RunState.create(1, "fangs", {"vows": ["d2_damage", "no_defy", "guardians"]})
	r.depth = 3
	r.dmg_by_depth = [50.0, 40.0, 0.0, 0.0]
	r.guardians_killed = ["mini_thornback", "mini_librarian"]
	check(Meta.vow_met("d2_damage", r), "under 100 damage in depth 2")
	check(Meta.vow_met("no_defy", r), "no Death Defiance used")
	check(Meta.vow_met("guardians", r), "two guardians")
	r.flags["defied"] = true
	r.dmg_by_depth[1] = 150.0
	check(not Meta.vow_met("no_defy", r) and not Meta.vow_met("d2_damage", r), "broken vows don't pay")
	var m := Meta.fresh()
	var res := Meta.end_run(m, r, {"won": false})
	check(res.vows_done.size() == 1 and int(res.embers_breakdown.vows) == int(Meta.vow_def("guardians").embers), "only kept vows add Embers")

func test_heat_unlock_and_level() -> void:
	var m := Meta.fresh()
	var r := RunState.create(1, "fangs")
	r.won = true
	Meta.end_run(m, r, {"won": true})
	check(m.heat_unlocked, "the Kindling Heat unlocks after the first win")
	check(Meta.heat_level(["hardened", "cruel", "swarming"]) == 5, "heat points stack")
	var o := Meta.run_options(m, {"heat_mods": ["dimmed", "scarce"]})
	check(int(o.defiance) == 0 and int(o.rerolls) == 0, "heat modifiers change the run")

func test_story_one_line_per_run() -> void:
	var m := Meta.fresh()
	m.runs = 1
	var a := Meta.next_story(m, {})
	check(not a.is_empty() and a.id == "s1", "the first story line after the first run")
	var b := Meta.next_story(m, {})
	check(b.is_empty(), "no line repeats; nothing new until conditions are met")
	m.runs = 3
	check(not Meta.next_story(m, {}).is_empty(), "more lines unlock with more runs")
	check(Meta.story_count() >= 25, "a story of 25+ lines")

func test_achievements() -> void:
	check(Achievements.LIST.size() == 30, "30 achievements")
	var m := Meta.fresh()
	var r := RunState.create(1, "fangs")
	r.kills = 1
	r.rooms_cleared = 1
	var got := Achievements.check(m, r).map(func(a): return a.id)
	check(got.has("first_blood") and got.has("first_room"), "first kill and first room")
	check(Achievements.check(m, r).is_empty(), "achievements are awarded once")
	r.perfect_dashes = 10
	r.flags["duo"] = true
	got = Achievements.check(m, r).map(func(a): return a.id)
	check(got.has("perfect10") and got.has("duo"), "run achievements")

func test_daily_seed() -> void:
	var k := Meta.daily_key(1700000000)
	check(k == Meta.daily_key(1700000000 + 3600), "same day → same key")
	check(Meta.daily_seed(k) == Meta.daily_seed(k), "fixed seed per day")
	check(Meta.daily_weapon(k) == Meta.daily_weapon(k) and Weapons.IDS.has(Meta.daily_weapon(k)), "fixed weapon per day")
	check(Meta.daily_seed(k) != Meta.daily_seed(Meta.daily_key(1700000000 + 86400)), "a new seed each day")
	var m := Meta.fresh()
	var o := Meta.run_options(m, {"daily": true})
	check(o.daily and int(o.seed) == Meta.daily_seed(Meta.daily_key()) and o.vows.is_empty(), "daily runs use the daily seed and no vows")
	var r := RunState.create(int(o.seed), String(o.weapon), o)
	r.rooms_cleared = 5
	r.kills = 40
	var res := Meta.end_run(m, r, {"won": false})
	check(int(res.daily_score) > 0 and ((m.daily as Dictionary)[Meta.daily_key()] as Array).size() == 1, "daily scores are recorded locally")

func test_bestiary() -> void:
	var m := Meta.fresh()
	var r := RunState.create(1, "fangs")
	r.kills_by_kind = {"cinderling": 4}
	r.dead = true
	r.killer = {"kind": "hookjaw", "source": "Hookjaw"}
	Meta.end_run(m, r, {"won": false})
	check(int(m.bestiary.cinderling.kills) == 4, "kills recorded")
	check(int(m.bestiary.hookjaw.deaths) == 1, "deaths recorded against the killer")

func test_personal_bests() -> void:
	var m := Meta.fresh()
	var r := RunState.create(1, "fangs")
	r.rooms_cleared = 5
	var res := Meta.end_run(m, r, {"won": false})
	check(res.pbs.rooms.new, "first run sets bests")
	var r2 := RunState.create(2, "fangs")
	r2.rooms_cleared = 3
	var res2 := Meta.end_run(m, r2, {"won": false})
	check(not res2.pbs.rooms.new and int(res2.pbs.rooms.best) == 5, "worse runs compare against the best")

func test_meta_save_roundtrip() -> void:
	var m := Meta.fresh()
	m.embers = 123
	m.unlocks = ["w_pike", "concord"]
	m.mastery = {"pike": 77}
	var txt := JSON.stringify(m)
	var back: Dictionary = JSON.parse_string(txt)
	check(int(back.embers) == 123 and (back.unlocks as Array).has("concord") and int(back.mastery.pike) == 77, "meta survives JSON")
	check(Meta.has(back, "w_pike") and Meta.weapon_unlocked(back, "pike"), "unlocks still apply after loading")
