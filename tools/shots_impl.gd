extends RefCounted
## Screenshot scenarios. Each scenario sets up a state, waits a number of frames, then saves.

var tree: SceneTree
var out := "res://screenshots"
var only := ""
var queue: Array = []
var cur: Dictionary = {}
var frame := 0
var main

func start() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	queue = scenarios().filter(func(s): return only == "" or s.name == only)

func scenarios() -> Array:
	return [
		{"name": "doors", "setup": _doors, "wait": 0, "until": _doors_ready},
		{"name": "boss_telegraph", "setup": _boss, "wait": 0, "until": _boss_ready},
		{"name": "death_recap", "setup": _death, "wait": 200},
		{"name": "boon_choice", "setup": _boon, "wait": 0, "until": _boon_ready},
		{"name": "wick", "setup": _wick, "wait": 60},
		{"name": "depth3", "setup": _depth3, "wait": 200},
		{"name": "depth4", "setup": _depth4, "wait": 200},
	]

func tick(_d: float) -> bool:
	frame += 1
	if frame < 8:
		return false
	if not Assets.is_baked:
		return false
	if cur.is_empty():
		if queue.is_empty():
			print("screenshots: done")
			tree.quit(0)
			return true
		cur = queue.pop_front()
		cur["t"] = 0
		cur.setup.call()
		return false
	cur.t += 1
	var ready := false
	if cur.has("until"):
		ready = cur.until.call() or cur.t > 60 * 20
	else:
		ready = cur.t >= int(cur.wait)
	if ready:
		var path: String = out.path_join(String(cur.name) + ".png")
		var img := tree.root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
		print("screenshot: ", path)
		cur = {}
	return false

func _game() -> Sim:
	return main.game.sim if main.game != null else null

func _kill_all() -> void:
	var s := _game()
	for e in s.enemies:
		if e.targetable():
			var h := HitInfo.make(99999.0, "attack", 0.5, Vector2.UP, e.pos + Vector2(0, 10))
			h.armor_break = 9.0
			Combat.deal(s, e, h)

# ───────── scenarios ─────────

func _doors() -> void:
	main.start_run({"weapon": "pike"})
	var s := _game()
	s.god_mode = true
	s.run.plan["reward"] = "gold"
	# clear the room as soon as enemies arrive and pick the reward
	var t := Timer.new()
	t.wait_time = 0.1
	t.autostart = true
	t.timeout.connect(func():
		if main.game == null or main.game.sim == null:
			return
		_kill_all()
		var fl: RoomFlow = main.game.sim.flow
		if fl.state == RoomFlow.S.OFFER:
			main.game._close_choice()
			fl.choose(0))
	main.game.add_child(t)

func _doors_ready() -> bool:
	var s := _game()
	return s != null and s.flow.state == RoomFlow.S.DOORS and s.flow.doors_lit == s.flow.doors.size() and cur.t > 30 and _settle()

var _settle_t := 0
func _settle() -> bool:
	_settle_t += 1
	return _settle_t > 40

func _boss() -> void:
	main.start_run({"weapon": "fangs"})
	var s := _game()
	s.god_mode = true
	s.flow.enter({"type": "boss", "kind": "boss_stag", "depth": 1, "step": 5, "reward": "none", "seed": 11})

func _boss_ready() -> bool:
	var s := _game()
	if s == null:
		return false
	var n := 0
	for t in s.telegraphs:
		if not t.resolved and t.boss and t.progress() > 0.55:
			n += 1
	return n > 0 and cur.t > 90

func _death() -> void:
	main.start_run({"weapon": "bow"})
	var s := _game()
	var e := Enemies.spawn(s, "hookjaw", Vector2(200, 0), 2, {"portal": false})
	s.player.hp = 5.0
	s.run.defiance = 0
	s.flow.state = RoomFlow.S.COMBAT
	Combat.hurt_player(s, 6.0, e.pos, e, "Bite")

func _boon() -> void:
	main.start_run({"weapon": "halo"})
	var s := _game()
	s.god_mode = true
	var t := Timer.new()
	t.wait_time = 0.1
	t.autostart = true
	t.timeout.connect(func():
		if main.game != null and main.game.sim != null and main.game.sim.flow.state == RoomFlow.S.COMBAT:
			_kill_all())
	main.game.add_child(t)

var _choice_frames := 0
func _boon_ready() -> bool:
	if main.game != null and main.game.choice != null:
		_choice_frames += 1
	return _choice_frames > 45

func _wick() -> void:
	App.meta.embers = maxi(int(App.meta.embers), 64)
	main.show_wick()

func _depth3() -> void:
	main.start_run({"weapon": "anvil"})
	var s := _game()
	s.god_mode = true
	s.flow.enter({"type": "boss", "kind": "boss_engine", "depth": 3, "step": 5, "reward": "none", "seed": 21})
	for k in ["coilsentry", "ironclad", "gyrosaw", "bellwether"]:
		Enemies.spawn(s, k, Enemies.spawn_point(s, 20.0), 3)

func _depth4() -> void:
	main.start_run({"weapon": "bow"})
	var s := _game()
	s.god_mode = true
	s.flow.enter({"type": "boss", "kind": "boss_regent", "depth": 4, "step": 5, "reward": "none", "seed": 22})
	for k in ["mirrorknight", "prism", "nullshard", "aegisherald", "hexer"]:
		Enemies.spawn(s, k, Enemies.spawn_point(s, 20.0), 4)
