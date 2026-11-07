extends TestBase

func test_bot_clears_first_rooms() -> void:
	var s := Sim.new(321, null)
	var run := RunState.create(321, "pike", {"patrons": ["ember", "rime", "storm", "tide"]})
	var flow := RoomFlow.new(s, run)
	flow.start_run()
	var bot := BotBrain.new(321)
	for i in 60 * 120:
		s.step(bot.think(s), 1.0 / 60.0)
		if run.room_index >= 2 or run.dead:
			break
	check(run.room_index >= 2 or run.dead, "the bot plays through rooms (reached room %d)" % (run.room_index + 1))
	check(run.kills > 0, "the bot fights")

func test_debug_menu_builds() -> void:
	var dm = load("res://ui/debug_menu.gd")
	check(dm != null and dm.can_instantiate(), "debug menu script loads")
