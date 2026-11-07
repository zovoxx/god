extends Node2D
## Hosts one Sim and its presentation: builds InputFrames from devices at 60 Hz, steps the
## simulation, and drives world view, camera, FX, audio reactions and the HUD.

const WorldView := preload("res://render/world_view.gd")
const Cam := preload("res://render/cam.gd")

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

func start_sim(s: Sim) -> void:
	sim = s
	world.bind(sim)
	cam.snap_to(sim.player.pos)
	if fx != null:
		fx.bind(sim)

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
