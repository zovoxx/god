extends Node
## Entry point. Routes between screens (title, the Wick, a run) and handles command-line
## modes: --bot (headless bot runs), --new-run, --continue, --daily, --weapon=<id>, --depth=<n>.

const GameView := preload("res://render/game_view.gd")

var game = null
var screen: Node = null

func _ready() -> void:
	App.main = self
	if App.arg("bot") != null:
		var bot := preload("res://bot/bot_runner.gd").new()
		add_child(bot)
		return
	await Assets.bake()
	start_test_room()

func start_test_room() -> void:
	_clear()
	game = GameView.new()
	add_child(game)
	var s := Sim.new(1234, Bus)
	s.set_arena(Rect2(-620, -380, 1240, 760), [{"pos": Vector2(-300, -120), "r": 40.0}, {"pos": Vector2(300, 120), "r": 40.0}], 0)
	s.equip_weapon(String(App.arg("weapon", "fangs")))
	for p in [Vector2(200, -100), Vector2(260, 0), Vector2(200, 100)]:
		Enemies.spawn(s, "dummy", p, 1)
	for p in [Vector2(-200, 150), Vector2(-250, -150)]:
		Enemies.spawn(s, "dummy_walker", p, 1)
	game.start_sim(s)

func _unhandled_input(ev: InputEvent) -> void:
	# training room: number keys swap weapons
	if game != null and game.sim != null and ev is InputEventKey and ev.pressed and not ev.echo and game.sim.run == null:
		var i: int = ev.keycode - KEY_1
		if i >= 0 and i < Weapons.IDS.size():
			game.sim.equip_weapon(Weapons.IDS[i])

func _clear() -> void:
	if game != null:
		game.queue_free()
		game = null
	if screen != null:
		screen.queue_free()
		screen = null

func on_quit() -> void:
	pass
