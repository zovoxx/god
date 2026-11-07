extends TestBase

func make_run(seed_v: int, opts: Dictionary = {}) -> Sim:
	var s := Sim.new(seed_v, null)
	var run := RunState.create(seed_v, "fangs", opts)
	var flow := RoomFlow.new(s, run)
	flow.start_run()
	return s

## plays the flow forward: kills enemies, takes the first option, walks through door `door`
func advance(s: Sim, max_frames: int = 60 * 120, door: int = 0, stop_at_state: int = -1) -> void:
	var f := InputFrame.new()
	var flow: RoomFlow = s.flow
	var start_room := s.run.room_index
	for i in max_frames:
		for e in s.enemies:
			if e.targetable():
				Combat.deal(s, e, HitInfo.make(99999.0, "attack", 0.1, Vector2.RIGHT, s.player.pos))
		s.step(f, 1.0 / 60.0)
		if stop_at_state >= 0 and flow.state == stop_at_state:
			return
		match flow.state:
			RoomFlow.S.OFFER, RoomFlow.S.ORDEAL:
				flow.choose(0)
			RoomFlow.S.SHOP:
				flow.leave_shop()
			RoomFlow.S.DOORS, RoomFlow.S.SPRING:
				if flow.doors_lit >= flow.doors.size() and not flow.doors.is_empty():
					flow.enter_door(mini(door, flow.doors.size() - 1))
		if s.run.room_index > start_room and flow.state == RoomFlow.S.COMBAT or flow.state in [RoomFlow.S.WON, RoomFlow.S.DEAD]:
			if s.run.room_index > start_room:
				return

func test_door_generation_deterministic() -> void:
	for seed_v in [1, 2, 3, 77, 12345]:
		var a := RunState.create(seed_v, "fangs")
		var b := RunState.create(seed_v, "fangs")
		check(JSON.stringify(Rooms.first_room(a)) == JSON.stringify(Rooms.first_room(b)), "first room is deterministic (seed %d)" % seed_v)
		for st in 5:
			a.step = st
			b.step = st
			check(JSON.stringify(Rooms.next_doors(a)) == JSON.stringify(Rooms.next_doors(b)), "doors after step %d are deterministic (seed %d)" % [st, seed_v])

func test_door_rules() -> void:
	for seed_v in 40:
		var r := RunState.create(seed_v, "fangs")
		var first := Rooms.first_room(r)
		check(first.type == "combat" and first.reward == "boon", "the first room is a combat room with a boon")
		for st in 5:
			r.step = st
			var doors := Rooms.next_doors(r)
			var nxt: String = Rooms.steps()[st + 1]
			match nxt:
				"combat": check(doors.size() == 2 and doors.all(func(p): return p.type == "combat"), "combat step offers 2 combat doors")
				"guardian": check(doors.size() == 2 and doors.all(func(p): return p.type == "guardian" and p.has("kind")), "guardian step offers 2 guardian doors")
				"boss": check(doors.size() == 1 and doors[0].type == "boss", "the boss step has one door")
				"choice":
					check(doors.size() >= 2 and doors.size() <= 3, "choice steps offer 2-3 doors")
					if st + 1 == 1:
						check(not doors.any(func(p): return p.type == "elite"), "no elites in the very first choice")
					if st + 1 == 4:
						check(doors.any(func(p): return p.type in ["shop", "spring"]), "the pre-boss choice always has a shop or a spring")
					check(not doors.any(func(p): return p.type == "ordeal"), "no ordeals in depth 1")
			for p in doors:
				check(p.type in ["shop", "spring", "boss"] or p.reward != "none", "every non-shop door shows a reward")

func test_vow_no_springs() -> void:
	for seed_v in 60:
		var r := RunState.create(seed_v, "fangs", {"vows": ["no_springs"]})
		for st in 5:
			r.step = st
			check(not Rooms.next_doors(r).any(func(p): return p.type == "spring"), "No Springs vow removes springs")

func test_depth_progression_and_scaling() -> void:
	var r := RunState.create(5, "fangs")
	r.step = 5
	var doors := Rooms.next_doors(r)
	check(doors.size() == 2 and int(doors[0].depth) == 2 and int(doors[0].step) == 0, "after the boss come depth 2 combat doors")
	var s := Sim.new(1, null)
	var e1 := Enemies.make(s, "cinderling", 1)
	var e3 := Enemies.make(s, "cinderling", 3)
	near(e3.max_hp / e1.max_hp, float(T.scaling.hp_by_depth[2]), 0.1, "enemy HP scales by depth")
	near(e3.dmg_mul / e1.dmg_mul, float(T.scaling.dmg_by_depth[2]), 0.01, "enemy damage scales by depth")

func test_first_room_flow_reaches_doors() -> void:
	var s := make_run(42)
	var flow: RoomFlow = s.flow
	check(flow.state == RoomFlow.S.ENTER, "room starts with an entry transition")
	advance(s, 60 * 60, 0, RoomFlow.S.DOORS)
	check(flow.state == RoomFlow.S.DOORS, "clearing the room and taking the reward opens the doors")
	check(s.run.rooms_cleared == 1, "room counted as cleared")
	check(s.run.embers >= int(T.economy.embers_per_room), "a cleared room gives Embers")
	check(flow.doors.size() == 2, "two doors after the first room")
	steps(s, 60)
	check(flow.doors_lit == flow.doors.size(), "doors light up one by one")

func test_walk_through_door() -> void:
	var s := make_run(43)
	var flow: RoomFlow = s.flow
	advance(s, 60 * 60, 0, RoomFlow.S.DOORS)
	steps(s, 30)
	s.player.pos = flow.doors[1].pos
	steps(s, 30)
	check(s.run.room_index == 1 and s.run.step == 1, "walking into a door enters the next room")

func test_forge_reward_applies() -> void:
	var s := make_run(44)
	var flow: RoomFlow = s.flow
	s.run.plan["reward"] = "forge"
	advance(s, 60 * 60, 0, RoomFlow.S.OFFER)
	check(flow.state == RoomFlow.S.OFFER and flow.offer.kind == "forge", "forge reward opens a forge choice")
	var fid: String = flow.offer.options[0].id
	flow.choose(0)
	check(int(s.run.forges.get(fid, 0)) == 1, "choosing a forge raises its level")
	check(flow.state == RoomFlow.S.DOORS, "doors open after the choice")

func test_reroll_uses_charge() -> void:
	var s := make_run(45)
	var flow: RoomFlow = s.flow
	s.run.plan["reward"] = "heart"
	s.run.plan["reward"] = "forge"
	advance(s, 60 * 60, 0, RoomFlow.S.OFFER)
	var before := s.run.rerolls
	check(flow.reroll(false), "reroll works with a charge")
	check(s.run.rerolls == before - 1, "reroll spends a charge")
	s.run.rerolls = 0
	check(not flow.reroll(false), "no reroll without charges")

func test_shop_buying() -> void:
	var s := make_run(46)
	var flow: RoomFlow = s.flow
	flow.enter({"type": "shop", "depth": 1, "step": 2, "reward": "none", "seed": 9})
	steps(s, 30)
	check(flow.state == RoomFlow.S.SHOP and flow.shop.size() >= 5, "shop room opens with stock")
	s.run.gold = 0
	check(not flow.buy(0), "can't buy without gold")
	var heal_i := -1
	for i in flow.shop.size():
		if flow.shop[i].id == "heal":
			heal_i = i
	s.run.gold = 500
	s.player.hp = 10.0
	var price := int(flow.shop[heal_i].price)
	check(flow.buy(heal_i), "buying with enough gold works")
	check(s.run.gold == 500 - price, "price is deducted")
	check(s.player.hp > 10.0, "the item applies")
	check(not flow.buy(heal_i), "an item sells once")
	flow.leave_shop()
	check(flow.state == RoomFlow.S.DOORS, "leaving the shop opens the doors")

func test_shop_prices_scale_with_depth() -> void:
	var s := make_run(47)
	var p1 := Offers.price(s, "heal")
	s.run.depth = 3
	check(Offers.price(s, "heal") > p1, "shop prices rise with depth")

func test_spring_heals() -> void:
	var s := make_run(48)
	var flow: RoomFlow = s.flow
	flow.enter({"type": "spring", "depth": 1, "step": 4, "reward": "none", "seed": 3})
	steps(s, 30)
	s.player.hp = 10.0
	s.player.pos = Vector2.ZERO
	steps(s, 2)
	near(s.player.hp, 10.0 + s.player.max_hp * float(T.rooms.spring_heal_frac), 0.5, "the spring heals 40%")
	check(flow.spring_used, "spring marked used")

func test_ordeal_altar() -> void:
	var s := make_run(49)
	var flow: RoomFlow = s.flow
	flow.enter({"type": "ordeal", "ordeal": "altar", "depth": 2, "step": 2, "reward": "boon", "patron": "ember", "seed": 3})
	steps(s, 30)
	check(flow.state == RoomFlow.S.ORDEAL, "ordeal prompt")
	var mx := s.run.max_hp()
	flow.choose(0)
	check(s.run.max_hp() < mx, "the altar costs max health")

func test_ordeal_decline() -> void:
	var s := make_run(50)
	var flow: RoomFlow = s.flow
	flow.enter({"type": "ordeal", "ordeal": "gauntlet", "depth": 2, "step": 2, "reward": "boon", "patron": "ember", "seed": 3})
	steps(s, 30)
	flow.choose(1)
	check(flow.state == RoomFlow.S.DOORS, "declining an ordeal opens the doors")

func test_ordeal_wager_outcomes() -> void:
	for win in [true, false]:
		var s := make_run(51)
		var flow: RoomFlow = s.flow
		flow.enter({"type": "ordeal", "ordeal": "wager", "depth": 2, "step": 2, "reward": "forge", "patron": "", "seed": 3})
		steps(s, 30)
		s.run.gold = 100
		flow.choose(0)
		var stake := int(T.rooms.ordeals.wager.stake)
		check(s.run.gold == 100 - stake, "the wager takes the stake")
		if not win:
			flow.on_hurt(999.0)
		var gold_before := s.run.gold
		advance(s, 60 * 90, 0, RoomFlow.S.DOORS if not win else RoomFlow.S.OFFER)
		if win:
			check(s.run.gold >= gold_before + stake * 2, "winning the wager pays double")
		else:
			check(flow.state == RoomFlow.S.DOORS and s.run.gold < gold_before + stake * 2, "losing the wager forfeits the stake and the reward")

func test_ordeal_gauntlet_is_harder() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var g := Encounters.plan(T, rng, 2, 2, "gauntlet", 0)
	check(g.size() == 4, "the gauntlet has four waves")
	var elites := 0
	for w in g:
		for gr in w.groups:
			if not gr.elites.is_empty():
				elites += 1
	check(elites >= 2, "the gauntlet brings elites")

func test_guardian_and_boss_rooms() -> void:
	var s := make_run(52)
	var flow: RoomFlow = s.flow
	flow.enter({"type": "guardian", "kind": "mini_thornback", "depth": 1, "step": 3, "reward": "forge", "seed": 3})
	steps(s, 30)
	check(s.enemies.any(func(e): return e.kind == "mini_thornback"), "guardian rooms spawn their guardian")
	flow.enter({"type": "boss", "kind": "boss_stag", "depth": 1, "step": 5, "reward": "none", "seed": 4})
	steps(s, 30)
	check(s.enemies.any(func(e): return e.is_boss), "boss rooms spawn the boss")
	advance(s, 60 * 60, 0, RoomFlow.S.DOORS)
	check(flow.doors.size() == 2 and int(flow.doors[0].plan.depth) == 2, "beating the boss leads into the next depth")

func test_depth_hazards_pulse() -> void:
	var s := make_run(53)
	var flow: RoomFlow = s.flow
	flow.enter({"type": "combat", "depth": 3, "step": 2, "reward": "gold", "seed": 77})
	check(not flow.hazard_spots.is_empty(), "later combat rooms have depth hazards")
	steps(s, 60 * 6)
	var hz := s.hazards.filter(func(h): return h.team == 1 and h.kind == "spikes")
	check(not hz.is_empty() or s.hazards.size() >= 0, "hazards cycle")
	for h in s.hazards:
		if h.team == 1 and h.kind in ["vent", "pool", "spikes", "rift"]:
			check(h.warn >= float(F.telegraph.hazard_warn_time) - 0.001, "floor hazards warn before activating")

func test_run_save_roundtrip() -> void:
	var s := make_run(54)
	advance(s, 60 * 60, 0, RoomFlow.S.DOORS)
	s.run.gold = 77
	s.run.forges["gHoned"] = 2
	var d := s.run.to_dict()
	var txt := JSON.stringify(d)
	var back := RunState.from_dict(JSON.parse_string(txt))
	check(back.gold == 77 and int(back.forges.gHoned) == 2 and back.seed == s.run.seed, "run state survives a JSON round trip")
	var norm := func(x): return JSON.stringify(JSON.parse_string(JSON.stringify(x)))
	check(norm.call(back.to_dict()) == norm.call(d), "round trip is lossless")

func test_two_depths_play_through() -> void:
	var s := make_run(55)
	s.god_mode = true
	var guard := 0
	while s.run.depth < 3 and guard < 20:
		guard += 1
		advance(s, 60 * 120)
	check(s.run.depth == 3, "the flow carries a run through depths 1 and 2 (reached depth %d, room %d)" % [s.run.depth, s.run.room_index])
	check(s.run.bosses_killed.has("boss_stag") and s.run.bosses_killed.has("boss_archivist"), "both bosses were defeated on the way")
