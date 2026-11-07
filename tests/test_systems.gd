extends TestBase

func test_every_sfx_renders() -> void:
	var n := 0
	for id in Synth.sfx_recipes().keys():
		var w := Synth.render_sfx(id)
		check(w != null and w.data.size() > 100, "sfx %s renders" % id)
		n += 1
	check(n >= 60, "a full procedural sound set (%d sounds)" % n)

func test_music_layers_loop_in_sync() -> void:
	for d in [0, 4]:
		var lens := {}
		for l in 4:
			var w := Synth.render_music(d, l)
			check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music layer loops")
			lens[w.data.size()] = true
		check(lens.size() == 1, "all four layers share one length (depth %d)" % d)

func test_audio_api_safe_headless() -> void:
	Audio.play("hit")
	Audio.set_intensity(true, true, true)
	Audio.set_low_hp(true)
	Audio.set_low_hp(false)
	check(true, "audio calls are harmless without a sound device")

func test_rebinding() -> void:
	Controls.install({})
	var k := InputEventKey.new()
	k.physical_keycode = KEY_L
	Controls.rebind("attack", k)
	var keys: Array = InputMap.action_get_events("attack").filter(func(e): return e is InputEventKey)
	var pads: Array = InputMap.action_get_events("attack").filter(func(e): return Controls.is_pad(e))
	check(keys.size() == 1 and keys[0].physical_keycode == KEY_L, "rebinding replaces the keyboard binding")
	check(not pads.is_empty(), "gamepad bindings survive a keyboard rebind")
	var ov := Controls.current_overrides()
	Controls.install(ov)
	var keys2: Array = InputMap.action_get_events("attack").filter(func(e): return e is InputEventKey)
	check(keys2.size() == 1 and keys2[0].physical_keycode == KEY_L, "bindings survive save/load")
	Controls.install({})

func test_default_controls() -> void:
	Controls.install({})
	var lbl := Controls.labels_for("dash", false)
	check(lbl.contains("Space") and lbl.contains("Shift"), "dash on Space / Shift")
	check(Controls.labels_for("dash", true).contains("B") and Controls.labels_for("dash", true).contains("RB"), "dash on B / RB")
	check(Controls.labels_for("cast", true).contains("LT") and Controls.labels_for("attack", true).contains("RT"), "Sigil on LT, attack on RT")
	check(Controls.labels_for("special", false).contains("Right click"), "Special on right click")

func test_settings_roundtrip() -> void:
	var path := "user://test_settings.json"
	var s := App.default_settings()
	s.shake = 0.3
	s.colorblind = true
	SaveIO.write_json(path, s)
	var back = SaveIO.read_json(path)
	check(back is Dictionary and is_equal_approx(float(back.shake), 0.3) and back.colorblind, "settings survive JSON")
	SaveIO.delete(path)

func test_colorblind_palette_swaps() -> void:
	var normal := Cfg.col("danger")
	Cfg.set_colorblind(true)
	var cb := Cfg.col("danger")
	Cfg.set_colorblind(false)
	check(normal != cb, "colour-blind palette changes the danger colour")
	check(Cfg.col("danger") == normal, "and switches back")

func test_feel_multipliers() -> void:
	var s := make_sim()
	Cfg.hitstop_mul = 0.0
	check(s.request_hitstop(0.08) == 0.0, "the hit-stop slider can turn hit-stop off")
	Cfg.hitstop_mul = 1.0

func test_mid_run_resume() -> void:
	var s := Sim.new(77, null)
	var run := RunState.create(77, "pike", {"patrons": ["ember", "rime", "storm", "tide"]})
	var flow := RoomFlow.new(s, run)
	flow.start_run()
	Boons.grant(s, "ember_attack", 1)
	run.gold = 55
	flow.enter({"type": "combat", "depth": 2, "step": 2, "reward": "forge", "seed": 1234})
	var saved := JSON.stringify(run.to_dict())
	# a new process resumes from the JSON
	var s2 := Sim.new(1, null)
	var run2 := RunState.from_dict(JSON.parse_string(saved))
	var flow2 := RoomFlow.new(s2, run2)
	flow2.resume_run()
	check(run2.depth == 2 and run2.step == 2 and int(run2.plan.seed) == 1234, "resume re-enters the saved room")
	check(run2.has_boon("ember_attack") and s2.stats.infuse.attack == "ember", "the build is restored")
	check(run2.gold == 55 and s2.weapon.id == "pike", "gold and weapon restored")
	check(s2.arena.rect.size.x > 0.0, "the room is rebuilt")
