class_name Sim
extends RefCounted
## The game simulation: rooms, combat, enemies, boons and run state. No nodes, no rendering,
## no Input. Presentation reads its state and listens to `bus` events. The headless bot drives
## it with synthetic InputFrames. Fixed 60 Hz step; hit-stop and slow motion live here.

var T: Tuning
var F: GameFeel
var bus = null                   # object with fire(name, dict); null = silent (tests)
var rng := RandomNumberGenerator.new()

var time := 0.0                  # simulation time (affected by slow-mo, frozen by hit-stop)
var real_time := 0.0
var tick := 0
var advanced := false            # did the world move this step? (render interpolation)
var _next_id := 1

# hit-stop / slow motion
var hitstop := 0.0
var hitstop_log: Array = []      # [real_time, amount]
var hitstop_ready_at := 0.0
var slow_scale := 1.0
var slow_t := 0.0
var slow_dur := 0.0

var arena := {"rect": Rect2(-620, -380, 1240, 760), "pillars": [], "style": 0}
var player: SimPlayer
var enemies: Array = []
var projectiles: Array = []
var hazards: Array = []
var telegraphs: Array = []
var pickups: Array = []
var stats := Stats.new()
var weapon = null
var run: RunState = null
var flow = null                  # RoomFlow
var input := InputFrame.new()
var damage_log: Array = []       # last hits the player took (pause screen, death recap)
var streak_kills := 0
var streak_timer := 0.0
var streak_tier := 0

# debug
var god_mode := false
var one_hit := false
var no_ai := false

func _init(seed_value: int = 0, event_bus = null) -> void:
	T = Cfg.T
	F = Cfg.F
	bus = event_bus
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	player = SimPlayer.new()
	player.setup(T)
	player.id = new_id()
	stats.reset(T)

func new_id() -> int:
	_next_id += 1
	return _next_id

func fire(name: StringName, d: Dictionary = {}) -> void:
	if bus != null:
		bus.fire(name, d)

# ───────────────────────── stepping ─────────────────────────

func step(inp: InputFrame, dt: float) -> void:
	input = inp
	real_time += dt
	advanced = false
	_update_slowmo(dt)
	if hitstop > 0.0:
		hitstop -= dt
		if hitstop <= 0.0:
			hitstop_ready_at = real_time + float(F.hitstop.cooldown)
		return
	var sdt := dt * slow_scale
	advanced = true
	time += sdt
	tick += 1
	player.prev = player.pos
	for e in enemies:
		e.prev = e.pos
	for pr in projectiles:
		pr.prev = pr.pos
	PlayerCtl.update(self, player, inp, sdt)
	_integrate_player(sdt)
	World.update(self, sdt)
	if flow != null:
		flow.update(sdt)

func _integrate_player(dt: float) -> void:
	var p := player
	p.kvel = p.kvel * exp(-float(F.knockback.friction) * dt)
	p.pos += (p.vel + p.kvel) * dt
	collide_arena(p, p.radius)

func fx_scale() -> float:
	if hitstop > 0.0:
		return float(F.hitstop.fx_speed_during_stop)
	return slow_scale

# ───────────────────────── hit-stop & slow-mo ─────────────────────────

## Requests a hit-stop. Capped per rolling second so fast weapons stay fluid. Returns the time added.
func request_hitstop(amount: float) -> float:
	amount *= Cfg.hitstop_mul
	if amount <= 0.0:
		return 0.0
	if real_time < hitstop_ready_at and hitstop <= 0.0:
		return 0.0
	var budget: float = F.hitstop.budget_per_second
	var used := 0.0
	var keep: Array = []
	for entry in hitstop_log:
		if real_time - float(entry[0]) < 1.0:
			keep.append(entry)
			used += float(entry[1])
	hitstop_log = keep
	var allowed := minf(amount, budget - used)
	if allowed <= 0.005:
		return 0.0
	if allowed > hitstop:
		var add := allowed - maxf(0.0, hitstop)
		hitstop = allowed
		hitstop_log.append([real_time, add])
		fire(&"hitstop", {"amount": allowed})
		return add
	return 0.0

func hitstop_for_power(power: float, crit: bool, kill: bool) -> float:
	var H: Dictionary = F.hitstop
	var a := lerpf(H.min, H.max, clampf(power, 0.0, 1.0))
	if crit:
		a += float(H.crit_bonus)
	if kill:
		a += float(H.kill_bonus)
	return a

func slowmo(scale: float, duration: float) -> void:
	if slow_t > 0.0 and scale > slow_scale:
		return
	slow_scale = scale
	slow_t = duration
	slow_dur = duration
	_slow_target = scale
	fire(&"slowmo", {"scale": scale, "duration": duration})

var _slow_target := 1.0

func _update_slowmo(dt: float) -> void:
	if slow_t <= 0.0:
		slow_scale = 1.0
		return
	slow_t -= dt
	var ease_frac: float = F.slowmo.ease_out
	var k := slow_t / maxf(0.001, slow_dur)
	if k < ease_frac:
		slow_scale = lerpf(1.0, _slow_target, k / ease_frac)
	else:
		slow_scale = _slow_target
	if slow_t <= 0.0:
		slow_scale = 1.0

# ───────────────────────── arena ─────────────────────────

func set_arena(rect: Rect2, pillars: Array, style: int) -> void:
	arena = {"rect": rect, "pillars": pillars, "style": style}

## pushes a body out of walls and pillars. Returns the collision normal (ZERO if none).
func collide_arena(b: SimBody, r: float) -> Vector2:
	var rect: Rect2 = arena.rect
	var n := Vector2.ZERO
	if b.pos.x < rect.position.x + r:
		b.pos.x = rect.position.x + r
		n.x = 1.0
	elif b.pos.x > rect.end.x - r:
		b.pos.x = rect.end.x - r
		n.x = -1.0
	if b.pos.y < rect.position.y + r:
		b.pos.y = rect.position.y + r
		n.y = 1.0
	elif b.pos.y > rect.end.y - r:
		b.pos.y = rect.end.y - r
		n.y = -1.0
	if b.flying:
		return n.normalized() if n != Vector2.ZERO else n
	for pl in arena.pillars:
		var c: Vector2 = pl.pos
		var rr: float = float(pl.r) + r
		var d := b.pos - c
		var dl := d.length()
		if dl < rr:
			var nn := d / maxf(0.001, dl) if dl > 0.001 else Vector2.RIGHT
			b.pos = c + nn * rr
			n += nn
	return n.normalized() if n != Vector2.ZERO else n

func point_blocked(p: Vector2, r: float) -> bool:
	var rect: Rect2 = arena.rect
	if not rect.grow(-r).has_point(p):
		return true
	for pl in arena.pillars:
		if p.distance_to(pl.pos) < float(pl.r) + r:
			return true
	return false

## line of sight test against pillars
func los(a: Vector2, b: Vector2) -> bool:
	for pl in arena.pillars:
		if Geom.seg_dist(pl.pos, a, b) < float(pl.r) - 2.0:
			return false
	return true

## distance along a ray until a wall/pillar
func ray_to_wall(from: Vector2, ang: float, max_d: float, r: float) -> float:
	var step := 12.0
	var d := 0.0
	var dv := Geom.dir(ang)
	while d < max_d:
		if point_blocked(from + dv * (d + step), r):
			return d
		d += step
	return max_d

func random_free_point(min_d: float, max_d: float, from: Vector2, r: float) -> Vector2:
	var rect: Rect2 = arena.rect
	for i in 40:
		var a := rng.randf() * TAU
		var d := rng.randf_range(min_d, max_d)
		var p := from + Geom.dir(a) * d
		if not point_blocked(p, r + 8.0):
			return p
	for i in 40:
		var p := Vector2(rng.randf_range(rect.position.x + r, rect.end.x - r), rng.randf_range(rect.position.y + r, rect.end.y - r))
		if not point_blocked(p, r + 4.0) and p.distance_to(player.pos) >= min_d:
			return p
	return rect.get_center()

func equip_weapon(id: String, forges: Dictionary = {}) -> void:
	weapon = Weapons.make(id)
	weapon.setup(self, forges)
	player.wstate.clear()

# ───────────────────────── derived player numbers ─────────────────────────

func move_speed() -> float:
	return float(T.player.max_speed) * (1.0 + stats.move_speed + stats.val("updraft_active"))

func dash_cooldown() -> float:
	return float(T.dash.cooldown) * maxf(0.3, 1.0 - stats.dash_cooldown)

func dash_distance() -> float:
	return float(T.dash.distance) * (1.0 + stats.dash_distance)

func cast_recharge_time() -> float:
	return float(T.cast.recharge) * maxf(0.3, 1.0 - stats.cast_recharge)

func attack_speed_mul() -> float:
	return 1.0 / maxf(0.4, 1.0 + stats.attack_speed)

# ───────────────────────── player hooks (filled by combat) ─────────────────────────

func on_player_dash_start() -> void:
	fire(&"player_dash", {"pos": player.pos, "dir": player.dash_dir})
	Combat.on_dash_start(self)

func on_player_dashing(dt: float) -> void:
	Combat.on_dashing(self, dt)

func on_player_dash_end() -> void:
	Combat.on_dash_end(self)

func cast_sigil() -> void:
	Combat.cast_sigil(self)

# ───────────────────────── queries ─────────────────────────

func enemies_in_circle(c: Vector2, r: float) -> Array:
	var out: Array = []
	for e in enemies:
		if e.targetable() and Geom.in_circle(e.pos, e.radius, c, r):
			out.append(e)
	return out

func nearest_enemy(p: Vector2, max_d: float = INF, exclude = null):
	var best = null
	var bd := max_d
	for e in enemies:
		if e == exclude or not e.targetable():
			continue
		var d := p.distance_to(e.pos)
		if d < bd:
			bd = d
			best = e
	return best

func living_enemies(count_optional: bool = false) -> int:
	var n := 0
	for e in enemies:
		if e.alive and (count_optional or not e.optional):
			n += 1
	return n
