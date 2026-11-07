extends Node2D
## Hosts one Sim and its presentation: builds InputFrames from devices at 60 Hz, steps the
## simulation, and drives world view, camera, FX, audio reactions and the HUD.

const WorldView := preload("res://render/world_view.gd")
const Cam := preload("res://render/cam.gd")
const FxView := preload("res://render/fx_view.gd")
const Hud := preload("res://ui/hud.gd")
const PauseMenu := preload("res://ui/pause_menu.gd")
const DeathRecap := preload("res://ui/death_recap.gd")
const OfferScreen := preload("res://ui/offer_screen.gd")
const ShopScreen := preload("res://ui/shop_screen.gd")

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
	Bus.event.connect(_on_bus)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 15
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade)

var fade: ColorRect
var choice = null
signal run_finished(data: Dictionary)

func _on_bus(name: StringName, d: Dictionary) -> void:
	if sim == null:
		return
	match name:
		&"room_entered":
			world.rebuild_room(int(d.seed))
			cam.snap_to(sim.player.pos)
			fade.color.a = 1.0
			create_tween().tween_property(fade, "color:a", 0.0, float(Cfg.T.pacing.get("transition_in", 0.25)))
			if int(d.step) == 0:
				Bus.fire(&"banner", {"text": String(d.name).to_upper(), "sub": "Depth %d" % int(d.depth), "col": Palettes.get_depth(int(d.depth) - 1).accent, "life": 2.4, "big": true})
		&"door_entered":
			create_tween().tween_property(fade, "color:a", 1.0, 0.25)
			Audio.play("door")
		&"offer_opened":
			_open_choice(String(d.kind))
		&"run_ended":
			_on_run_ended(d)
		&"autosave":
			if App.main != null and App.main.has_method("autosave"):
				App.main.autosave(d.run)
		&"room_cleared":
			cam.zoom_punch(float(Cfg.F.room_clear.boss_zoom_punch if d.boss else Cfg.F.room_clear.zoom_punch))
			Audio.play("room_clear")
		&"door_lit":
			Audio.play("door_lit", 1.0 + int(d.index) * 0.12)

func _open_choice(kind: String) -> void:
	_close_choice()
	var flow: RoomFlow = sim.flow
	if kind == "shop":
		var sh := ShopScreen.new()
		sh.setup(flow)
		sh.buy.connect(func(i):
			if flow.buy(i):
				Audio.play("buy")
			else:
				Audio.play("deny")
			sh.refresh())
		sh.leave.connect(func():
			flow.leave_shop()
			_close_choice())
		choice = sh
	else:
		var os := OfferScreen.new()
		os.setup(flow.offer, sim.run)
		os.picked.connect(func(i):
			_close_choice()
			flow.choose(i))
		os.reroll_requested.connect(func(fate):
			if flow.reroll(fate):
				Audio.play("reroll")
			else:
				Audio.play("deny"))
		choice = os
	overlay.add_child(choice)
	ui_blocking = true
	paused = true

func _close_choice() -> void:
	if choice != null:
		choice.queue_free()
		choice = null
	ui_blocking = false
	paused = false

func _on_run_ended(d: Dictionary) -> void:
	await get_tree().create_timer(float(Cfg.T.pacing.death_recap_delay) if not d.won else 1.6, true, false, true).timeout
	run_finished.emit(d)

var overlay: CanvasLayer
var pause_menu = null
var recap = null

func _on_player_died(_d: Dictionary) -> void:
	if sim == null or sim.flow != null:
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
	if sim.flow == null:
		fade.color.a = 0.0
	else:
		create_tween().tween_property(fade, "color:a", 0.0, 0.35)
	world.bind(sim)
	if sim.run != null:
		world.rebuild_room(int(sim.run.plan.get("seed", 0)))
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
	cam.zoom_fit = 0.0
	if sim.flow != null and sim.flow.state in [RoomFlow.S.DOORS, RoomFlow.S.SPRING, RoomFlow.S.EXIT]:
		var r: Rect2 = sim.arena.rect
		var vs := get_viewport_rect().size
		cam.zoom_fit = minf(vs.x / (r.size.x + 160.0), vs.y / (r.size.y + 260.0))
		cam.target = cam.target.lerp(r.get_center() + Vector2(0, -40), 0.6)
		cam.look = Vector2.ZERO
	cam.tick(delta, sim.fx_scale())
