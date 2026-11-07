extends Camera2D
## Follow camera with aim lookahead, trauma-based shake, a directional kick spring and zoom punches.

var target := Vector2.ZERO
var look := Vector2.ZERO
var trauma := 0.0
var kick := Vector2.ZERO
var kick_v := Vector2.ZERO
var punch := 0.0
var base_zoom := 1.4
var zoom_fit := 0.0          # >0: ease out to this zoom (whole room visible)
var _zoom_cur := 1.4
var _t := 0.0
var _noise := FastNoiseLite.new()

func _ready() -> void:
	base_zoom = float(Cfg.T.view.zoom)
	zoom = Vector2.ONE * base_zoom
	_zoom_cur = base_zoom
	_noise.seed = 7
	_noise.frequency = 1.0

func add_trauma(t: float) -> void:
	trauma = clampf(trauma + t * Cfg.shake_mul, 0.0, 1.0)

func add_kick(dir: Vector2, amount: float) -> void:
	kick_v += dir.normalized() * amount * Cfg.shake_mul * 60.0

func zoom_punch(amount: float) -> void:
	punch = maxf(punch, amount)

func snap_to(p: Vector2) -> void:
	target = p
	global_position = p

func tick(delta: float, fx_scale: float) -> void:
	var S: Dictionary = Cfg.F.shake
	_t += delta * float(S.frequency)
	var follow: float = Cfg.T.view.follow
	var goal := target + look
	global_position = global_position.lerp(goal, clampf(follow * delta, 0.0, 1.0))
	# kick spring
	var acc := -kick * float(S.kick_spring) - kick_v * float(S.kick_damping)
	kick_v += acc * delta
	kick += kick_v * delta
	trauma = maxf(0.0, trauma - float(S.decay) * delta)
	var amp := trauma * trauma
	var off := Vector2(_noise.get_noise_2d(_t, 0.0), _noise.get_noise_2d(0.0, _t)) * float(S.max_offset) * amp * 2.0
	offset = off + kick
	rotation = _noise.get_noise_2d(_t, 50.0) * float(S.max_angle) * amp * 2.0
	punch = maxf(0.0, punch - punch * float(Cfg.F.room_clear.zoom_decay) * delta)
	var goal_zoom := minf(base_zoom, zoom_fit) if zoom_fit > 0.0 else base_zoom
	_zoom_cur = lerpf(_zoom_cur, goal_zoom, clampf(delta * 2.5, 0.0, 1.0))
	zoom = Vector2.ONE * _zoom_cur * (1.0 + punch)
