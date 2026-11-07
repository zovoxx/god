extends Node2D
## Hosts one Sim and its presentation: builds InputFrames from devices at 60 Hz, steps the
## simulation, and drives world view, camera, FX, audio reactions and the HUD.

const WorldView := preload("res://render/world_view.gd")
const Cam := preload("res://render/cam.gd")
const FxView := preload("res://render/fx_view.gd")
const Hud := preload("res://ui/hud.gd")
const PauseMenu := preload("res://ui/pause_menu.gd")
const DeathRecap := preload("res://ui/death_recap.gd")

signal request_restart
signal request_wick
signal request_title

var sim: Sim
var world
var cam
var fx
var hud
var paused := false
var ui_blocking := false        # an overlay (boon choice, shop...) has focus
var _last_device := InputFrame.Aim.MOUSE
var _mouse_moved_at := 0.0

func _ready() -> void:
	world = WorldView.new()
	add_child(world)
	cam = Cam.new()
	add_child(cam)
	cam.make_current()
	fx = FxView.new()
	fx.cam = cam
	fx.world = world
	world.fx = fx
	add_child(fx)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)
	overlay = CanvasLayer.new()
	overlay.layer = 20
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	Bus.player_died.connect(_on_player_died)

var overlay: CanvasLayer
var pause_menu = null
var recap = null

func _on_player_died(_d: Dictionary) -> void:
	if sim == null or (sim.flow != null and sim.flow.handles_death()):
		return
	await get_tree().create_timer(float(Cfg.T.pacing.death_recap_delay), true, false, true).timeout
	show_recap(Recap.build(sim))

func show_recap(data: Dictionary) -> void:
	if recap != null:
		return
	recap = DeathRecap.new()
	recap.setup(data)
	recap.descend_again.connect(func(): request_restart.emit())
	recap.to_wick.connect(func(): request_wick.emit())
	overlay.add_child(recap)
	ui_blocking = true

func open_pause() -> void:
	if pause_menu != null or recap != null:
		return
	get_tree().paused = true
	pause_menu = PauseMenu.new()
	pause_menu.setup(sim)
	pause_menu.resumed.connect(close_pause)
	pause_menu.settings_requested.connect(func():
		if App.main != null and App.main.has_method("open_settings"):
			App.main.open_settings(overlay))
	pause_menu.abandon.connect(func():
		close_pause()
		if sim != null and sim.flow != null:
			sim.flow.abandon()
		else:
			request_wick.emit())
	pause_menu.quit_title.connect(func():
		close_pause()
		request_title.emit())
	overlay.add_child(pause_menu)
	Audio.play("ui_open")

func close_pause() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null
	get_tree().paused = false

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("pause") and pause_menu == null and recap == null and not ui_blocking:
		get_viewport().set_input_as_handled()
		open_pause()

func start_sim(s: Sim) -> void:
	sim = s
	world.bind(sim)
	cam.snap_to(sim.player.pos)
	if fx != null:
		fx.bind(sim)
	hud.bind(sim, world)

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and ev.relative.length() > 2.0:
		_last_device = InputFrame.Aim.MOUSE
	elif ev is InputEventMouseButton:
		_last_device = InputFrame.Aim.MOUSE
	elif ev is InputEventJoypadButton:
		_last_device = InputFrame.Aim.STICK
	elif ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.4:
		_last_device = InputFrame.Aim.STICK

func build_input() -> InputFrame:
	var f := InputFrame.new()
	f.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	f.aim = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	f.aim_point = get_global_mouse_position()
	match String(App.settings.get("aim_mode", "auto")):
		"mouse": f.aim_source = InputFrame.Aim.MOUSE
		"stick": f.aim_source = InputFrame.Aim.STICK
		"autoaim": f.aim_source = InputFrame.Aim.AUTO
		_: f.aim_source = _last_device
	if ui_blocking:
		return f
	f.attack_p = Input.is_action_just_pressed("attack")
	f.attack_h = Input.is_action_pressed("attack")
	f.special_p = Input.is_action_just_pressed("special")
	f.special_h = Input.is_action_pressed("special")
	f.dash_p = Input.is_action_just_pressed("dash")
	f.cast_p = Input.is_action_just_pressed("cast")
	return f

func _physics_process(delta: float) -> void:
	if sim == null or paused:
		return
	sim.step(build_input(), delta)

func _process(delta: float) -> void:
	if sim == null:
		return
	var p := sim.player
	cam.target = world.ipos(p)
	var la: float = Cfg.T.view.lookahead
	var goal_look := p.aim_dir * la
	if p.move_dir != Vector2.ZERO:
		goal_look = (p.aim_dir * 0.6 + p.move_dir * 0.4) * la
	cam.look = cam.look.lerp(goal_look, clampf(delta * 4.0, 0.0, 1.0))
	cam.tick(delta, sim.fx_scale())
