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
	game.start_sim(s)

func _clear() -> void:
	if game != null:
		game.queue_free()
		game = null
	if screen != null:
		screen.queue_free()
		screen = null

func on_quit() -> void:
	pass
