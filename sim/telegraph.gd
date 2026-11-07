class_name Tele
extends RefCounted
## A telegraphed attack. A ground shape fills from the outside in over the windup, flashes
## white during the last `flash_window` seconds (the counter window) and resolves at impact:
## the player takes damage if inside the shape and vulnerable. Dashing through it during its
## last 0.15 s triggers a PERFECT dash. Minimum windups are enforced here for every attack.

enum Shape { CIRCLE, CONE, LINE, RING }

var id := 0
var shape := Shape.CIRCLE
var pos := Vector2.ZERO
var angle := 0.0
var radius := 50.0
var inner := 0.0
var length := 100.0
var width := 30.0
var arc := PI * 0.5
var windup := 0.5
var t := 0.0
var owner = null
var dmg := 0.0
var attack_name := ""
var boss := false
var follow := false            # pos tracks the owner
var locked := false            # stop tracking the owner's aim
var hits_player := true
var knock := 1.0
var on_impact: Callable
var resolved := false
var cancelled := false
var linger := 0.0              # how long the white impact flash stays visible
var data := {}
var perfect_candidate := false
var callout := ""              # boss attack name banner

static func make(sim, owner, shape_v: Shape, windup_v: float, dmg_v: float, name: String) -> Tele:
	var t := Tele.new()
	t.id = sim.new_id()
	t.owner = owner
	t.shape = shape_v
	t.dmg = dmg_v
	t.attack_name = name
	var is_boss: bool = owner != null and (owner.is_boss or owner.is_guardian)
	t.boss = is_boss
	var P: Dictionary = sim.T.pacing
	var min_w: float = P.boss_min_windup if is_boss else P.enemy_min_windup
	t.windup = maxf(windup_v, min_w)
	if owner != null:
		t.pos = owner.pos
		owner.glow = 1.0
	sim.telegraphs.append(t)
	sim.fire(&"telegraph_started", {"id": t.id, "name": name, "boss": is_boss, "windup": t.windup, "owner": owner.id if owner != null else 0})
	return t

func progress() -> float:
	return clampf(t / maxf(0.001, windup), 0.0, 1.0)

func time_left() -> float:
	return windup - t

func in_flash(flash_window: float) -> bool:
	return not resolved and not cancelled and time_left() <= flash_window

func contains(p: Vector2, r: float) -> bool:
	match shape:
		Shape.CIRCLE:
			return Geom.in_circle(p, r, pos, radius)
		Shape.RING:
			return Geom.in_ring(p, r, pos, inner, radius)
		Shape.CONE:
			return Geom.in_arc(p, r, pos, angle, radius, rad_to_deg(arc))
		Shape.LINE:
			return Geom.in_line(p, r, pos, angle, length, width)
	return false

static func cancel(sim, t: Tele) -> void:
	if t == null or t.resolved:
		return
	t.cancelled = true
	t.resolved = true
	t.linger = 0.0

static func update_all(sim, dt: float) -> void:
	var F: GameFeel = sim.F
	var flash_w: float = F.telegraph.flash_window
	var pd_window: float = F.perfect_dash.window
	var p: SimPlayer = sim.player
	var keep: Array = []
	for t in sim.telegraphs:
		if t.resolved:
			t.linger -= dt
			if t.linger > 0.0:
				keep.append(t)
			continue
		var o = t.owner
		if o != null and (not o.alive):
			cancel(sim, t)
			continue
		if t.follow and o != null:
			t.pos = o.pos
		if o != null:
			o.glow = maxf(o.glow, 0.5 + 0.5 * t.progress())
		t.t += dt
		# perfect-dash detection: the player starts a dash inside the shape in its last 0.15 s
		if t.hits_player and not t.perfect_candidate and p.state == SimPlayer.St.DASH and sim.time - p.dash_started_at <= dt + 0.0001:
			if t.time_left() <= pd_window and t.contains(p.dash_origin(), p.hit_radius + 6.0):
				t.perfect_candidate = true
		if t.t >= t.windup:
			_resolve(sim, t)
			t.linger = float(F.telegraph.impact_flash)
			keep.append(t)
		else:
			keep.append(t)
	sim.telegraphs = keep

static func _resolve(sim, t: Tele) -> void:
	t.resolved = true
	var p: SimPlayer = sim.player
	var hit := false
	if t.hits_player:
		var inside := t.contains(p.pos, p.hit_radius)
		if t.perfect_candidate or (inside and p.state == SimPlayer.St.DASH and p.dash_iframes > 0.0 and sim.time - p.dash_started_at <= float(sim.F.perfect_dash.window)):
			Combat.perfect_dash(sim, t.owner, t.attack_name)
		elif inside and t.dmg > 0.0:
			hit = Combat.hurt_player(sim, t.dmg, t.pos if t.shape != Shape.LINE and t.shape != Shape.CONE else (t.owner.pos if t.owner != null else t.pos), t.owner, t.attack_name)
	sim.fire(&"telegraph_impact", {"id": t.id, "pos": t.pos, "shape": t.shape, "radius": t.radius, "boss": t.boss, "hit": hit})
	if t.owner != null and t.owner.tele == t:
		t.owner.tele = null
	if t.on_impact.is_valid():
		t.on_impact.call()
