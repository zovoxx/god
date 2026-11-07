extends Node
## Entry point. Routes between screens (title / the Wick, a run, recap, ending) and handles
## command-line modes: --bot (headless bot runs), --new-run, --continue, --daily,
## --weapon=<id>, --depth=<n>.

const GameView := preload("res://render/game_view.gd")
const TitleScreen := preload("res://ui/title_screen.gd")
const VictoryScreen := preload("res://ui/victory_screen.gd")
const DeathRecap := preload("res://ui/death_recap.gd")
const RUN_SAVE := "user://run.json"

var game = null
var screen: Node = null
var ui_layer: CanvasLayer
var last_opts := {}

func _ready() -> void:
	App.main = self
	if App.arg("bot") != null:
		var bot := preload("res://bot/bot_runner.gd").new()
		add_child(bot)
		return
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)
	await Assets.bake()
	if App.arg("continue") != null and has_saved_run():
		continue_run()
	elif App.arg("new-run") != null or App.arg("daily") != null or App.arg("weapon") != null or App.arg("depth") != null:
		start_run({"weapon": String(App.arg("weapon", "")), "depth": int(App.arg("depth", 1)), "daily": App.arg("daily") != null})
	else:
		show_title()

# ───────── screens ─────────

func _clear() -> void:
	get_tree().paused = false
	if game != null:
		game.queue_free()
		game = null
	if screen != null:
		screen.queue_free()
		screen = null

func _show(s: Node) -> void:
	if screen != null:
		screen.queue_free()
	screen = s
	ui_layer.add_child(s)

func show_title() -> void:
	_clear()
	var menu: Array = []
	if has_saved_run():
		menu.append(["continue", "Continue descent"])
	menu.append(["new", "Descend"])
	menu.append(["training", "Training grounds"])
	menu.append(["quit", "Quit"])
	var t := TitleScreen.new()
	t.setup(menu)
	t.action.connect(_on_title)
	_show(t)
	Audio.music_state("title")

func _on_title(id: String) -> void:
	match id:
		"continue": continue_run()
		"new": start_run({})
		"training": start_test_room()
		"quit": get_tree().quit()

# ───────── runs ─────────

func run_options(opts: Dictionary) -> Dictionary:
	var o := Meta.run_options(App.meta, opts)
	return o

func start_run(opts: Dictionary) -> void:
	_clear()
	last_opts = opts
	var o := run_options(opts)
	var seed_v: int = int(o.get("seed", 0))
	if seed_v == 0:
		seed_v = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	var run := RunState.create(seed_v, String(o.weapon), o)
	var s := Sim.new(seed_v, Bus)
	var flow := RoomFlow.new(s, run)
	_make_game(s)
	flow.start_run()
	game.start_sim(s)

func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_SAVE)

func continue_run() -> void:
	var d = SaveIO.read_json(RUN_SAVE)
	if not (d is Dictionary):
		show_title()
		return
	_clear()
	var run := RunState.from_dict(d)
	var s := Sim.new(run.seed + run.room_index, Bus)
	var flow := RoomFlow.new(s, run)
	_make_game(s)
	flow.resume_run()
	game.start_sim(s)

func _make_game(s: Sim) -> void:
	game = GameView.new()
	add_child(game)
	game.request_title.connect(func():
		autosave_now()
		show_title())
	game.request_wick.connect(show_title)
	game.request_restart.connect(func(): start_run(last_opts))
	game.run_finished.connect(_on_run_finished)
	Audio.music_state("explore")

func autosave(run_dict: Dictionary) -> void:
	SaveIO.write_json(RUN_SAVE, run_dict)

func autosave_now() -> void:
	if game != null and game.sim != null and game.sim.run != null and not game.sim.run.dead and not game.sim.run.won:
		game.sim.run.hp = game.sim.player.hp
		SaveIO.write_json(RUN_SAVE, game.sim.run.to_dict())

func _on_run_finished(d: Dictionary) -> void:
	SaveIO.delete(RUN_SAVE)
	var s: Sim = game.sim
	var result := Meta.end_run(App.meta, s.run, d)
	App.save_meta()
	if d.won:
		var v := VictoryScreen.new()
		v.setup(result.get("ending", []))
		v.done.connect(func(): show_after_run(s, result))
		_show(v)
	else:
		var data := Recap.build(s)
		data.merge(result, true)
		var r := DeathRecap.new()
		r.setup(data)
		r.descend_again.connect(func(): start_run(last_opts))
		r.to_wick.connect(func(): show_after_run(s, result))
		_show(r)

func show_after_run(_s, _result) -> void:
	show_title()

func on_quit() -> void:
	autosave_now()

# ───────── training ─────────

func start_test_room() -> void:
	_clear()
	game = GameView.new()
	add_child(game)
	game.request_restart.connect(start_test_room)
	game.request_wick.connect(show_title)
	game.request_title.connect(show_title)
	var s := Sim.new(1234, Bus)
	s.set_arena(Rect2(-620, -380, 1240, 760), [{"pos": Vector2(-300, -120), "r": 40.0}, {"pos": Vector2(300, 120), "r": 40.0}], 0)
	s.equip_weapon(String(App.arg("weapon", "fangs")))
	for p in [Vector2(200, -100), Vector2(260, 0), Vector2(200, 100)]:
		Enemies.spawn(s, "dummy", p, 1)
	for p in [Vector2(-200, 150), Vector2(-250, -150)]:
		Enemies.spawn(s, "dummy_walker", p, 1)
	Enemies.spawn(s, "effigy", Vector2(0, -250), 1)
	game.start_sim(s)

func _unhandled_input(ev: InputEvent) -> void:
	# training room: number keys swap weapons
	if game != null and game.sim != null and ev is InputEventKey and ev.pressed and not ev.echo and game.sim.run == null:
		var i: int = ev.keycode - KEY_1
		if i >= 0 and i < Weapons.IDS.size():
			game.sim.equip_weapon(Weapons.IDS[i])
