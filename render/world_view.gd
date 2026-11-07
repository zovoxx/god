extends Node2D
## Presentation of the arena: floor, under-layer (decals, telegraphs, hazards, shadows),
## y-sorted sprites (player, enemies, pillars) and over-layer (projectiles, FX, numbers).
## Reads Sim state; never changes it.

const DrawLayer := preload("res://render/draw_layer.gd")
const FloorView := preload("res://render/floor_view.gd")

var sim: Sim
var floor_view
var under
var ents: Node2D
var over
var fx                     # FxView (particles, numbers) set by GameView
var _sprites := {}         # id -> {node: Sprite2D, mat: ShaderMaterial, art: String}
var _pillar_nodes: Array = []
var alpha := 1.0
var time := 0.0

func _ready() -> void:
	floor_view = FloorView.new()
	add_child(floor_view)
	under = DrawLayer.new()
	under.drawer = _draw_under
	add_child(under)
	ents = Node2D.new()
	ents.y_sort_enabled = true
	add_child(ents)
	over = DrawLayer.new()
	over.drawer = _draw_over
	add_child(over)

func bind(s: Sim) -> void:
	sim = s
	for id in _sprites.keys():
		_sprites[id].node.queue_free()
	_sprites.clear()
	rebuild_room(0)

func rebuild_room(room_seed: int) -> void:
	floor_view.setup(sim.arena, room_seed)
	for n in _pillar_nodes:
		n.queue_free()
	_pillar_nodes.clear()
	var P := Palettes.get_depth(int(sim.arena.style))
	for pl in sim.arena.pillars:
		var n := DrawLayer.new()
		n.position = pl.pos
		var r: float = pl.r
		var col: Color = P.pillar
		n.drawer = func(ci: CanvasItem):
			ci.draw_circle(Vector2(0, r * 0.35), r * 1.05, Color(0, 0, 0, 0.35))
			ci.draw_circle(Vector2(0, 0), r + 3.0, Paint.OUT)
			ci.draw_circle(Vector2(0, 0), r, col)
			ci.draw_circle(Vector2(0, -r * 0.25), r * 0.75, col.lightened(0.12))
			ci.draw_arc(Vector2.ZERO, r * 0.6, PI * 1.1, PI * 1.6, 10, col.lightened(0.3), 3.0)
		ents.add_child(n)
		_pillar_nodes.append(n)

func ipos(b: SimBody) -> Vector2:
	return b.prev.lerp(b.pos, alpha)

func _process(delta: float) -> void:
	if sim == null:
		return
	time += delta
	alpha = Engine.get_physics_interpolation_fraction() if sim.advanced else 1.0
	_sync_sprites()

func _sprite_for(id: int, art: String) -> Dictionary:
	if _sprites.has(id):
		var e: Dictionary = _sprites[id]
		if e.art != art:
			e.node.texture = Assets.tex(art)
			e.base = Assets.draw_scale(art)
			e.art = art
		return e
	var s := Sprite2D.new()
	var m := Assets.flash_material()
	s.material = m
	s.texture = Assets.tex(art)
	ents.add_child(s)
	var e := {"node": s, "mat": m, "art": art, "base": Assets.draw_scale(art), "seen": true}
	_sprites[id] = e
	return e

func _sync_sprites() -> void:
	for id in _sprites.keys():
		_sprites[id].seen = false
	# player
	var p := sim.player
	var ps := _sprite_for(p.id, "wren")
	ps.seen = true
	var n: Sprite2D = ps.node
	n.position = ipos(p)
	n.offset = Vector2(0, -8) / ps.base
	var sq := p.squash
	n.scale = Vector2(1.0 + sq * 0.6, 1.0 - sq * 0.5) * ps.base
	n.flip_h = p.aim_dir.x < 0.0
	var flick := p.hurt_iframes > 0.0 and fmod(time * float(Cfg.F.hurt.flicker_rate), 1.0) < 0.5
	n.modulate = Color(1, 1, 1, 0.45 if flick else 1.0)
	if p.state == SimPlayer.St.DASH:
		n.modulate = Color(0.8, 0.95, 1.2, 0.85)
	ps.mat.set_shader_parameter("flash", 0.0)
	_sync_weapon(ps, p)
	# enemies
	for e in sim.enemies:
		if not e.alive:
			continue
		var es := _sprite_for(e.id, e.art)
		es.seen = true
		var en: Sprite2D = es.node
		en.position = ipos(e)
		var s: float = es.base * (e.radius / maxf(1.0, float(e.def.get("radius", e.radius))))
		var q: float = e.squash
		var spawn_k := 1.0
		if e.spawn_t > 0.0:
			spawn_k = clampf(1.0 - e.spawn_t / float(sim.T.pacing.spawn_portal), 0.0, 1.0)
		en.scale = Vector2(1.0 + q, 1.0 - q * 0.7) * s * spawn_k
		var face := Geom.dir(e.facing)
		en.flip_h = face.x < 0.0 and e.def.get("orient", "flip") == "flip"
		en.rotation = e.facing if e.def.get("orient", "flip") == "rotate" else 0.0
		en.modulate = Color(1, 1, 1, 0.5 + 0.5 * spawn_k)
		if e.frozen():
			en.modulate = Color(0.7, 0.9, 1.3)
		es.mat.set_shader_parameter("flash", clampf(e.flash_t / 0.085, 0.0, 1.0) * Cfg.flash_mul)
		es.mat.set_shader_parameter("glow", clampf(e.glow, 0.0, 1.0))
	for id in _sprites.keys():
		if not _sprites[id].seen:
			_sprites[id].node.queue_free()
			_sprites.erase(id)

var _weapon_node: Sprite2D

func _sync_weapon(ps: Dictionary, p: SimPlayer) -> void:
	if _weapon_node == null:
		_weapon_node = Sprite2D.new()
		ents.add_child(_weapon_node)
	var w := _weapon_node
	if sim.weapon == null:
		w.visible = false
		return
	var art: String = "w_" + String(sim.weapon.id)
	w.texture = Assets.tex(art)
	var ang := p.aim_dir.angle()
	if sim.weapon.has_method("visual_angle"):
		ang = sim.weapon.visual_angle(sim, p)
	w.scale = Vector2.ONE * Assets.draw_scale(art)
	var d := Vector2(cos(ang), sin(ang))
	w.position = ps.node.position + d * 18.0 + Vector2(0, -6)
	w.offset = Vector2(0, 0)
	w.rotation = ang
	w.flip_v = d.x < 0.0
	# y-sort: draw in front of Wren when aiming down, behind when aiming up
	w.z_index = 0
	w.position.y += 0.0
	w.visible = sim.weapon.show_weapon(p)

func _draw_under(ci: CanvasItem) -> void:
	if sim == null:
		return
	# shadows
	var p := sim.player
	ci.draw_circle(ipos(p) + Vector2(0, 14), 13.0, Color(0, 0, 0, 0.35))
	for e in sim.enemies:
		if e.alive and not e.flying:
			ci.draw_colored_polygon(Paint.ell(ipos(e) + Vector2(0, e.radius * 0.7), e.radius * 0.95, e.radius * 0.4, 14), Color(0, 0, 0, 0.32))
	if fx != null:
		fx.draw_under(ci, self)

func _draw_over(ci: CanvasItem) -> void:
	if sim == null:
		return
	if fx != null:
		fx.draw_over(ci, self)
	_draw_enemy_info(ci)
	_draw_player_clarity(ci)

const STATUS_COL := {"burn": "#ff9a3d", "chill": "#8fe8ff", "freeze": "#d8f6ff", "hex": "#b45cff", "bleed": "#86e04a", "mark": "#fff1a6"}

## small HP bar once damaged, elite modifier icons, status stack icons, cracking armor pips
func _draw_enemy_info(ci: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	for e in sim.enemies:
		if not e.alive or e.spawn_t > 0.0:
			continue
		var pos := ipos(e)
		var top := pos + Vector2(0, -e.radius - 18.0)
		if e.is_boss:
			top.y -= 10.0
		var bw := clampf(e.radius * 2.2, 34.0, 90.0)
		if (e.hp < e.max_hp or e.shield > 0.0) and not e.is_boss:
			draw_bar(ci, top, bw, e.hp_frac(), Color("#ff5a5a") if not e.finishable else Cfg.col("player_gold"))
			if e.shield > 0.0:
				ci.draw_rect(Rect2(top + Vector2(-bw * 0.5, -5), Vector2(bw * clampf(e.shield / maxf(1.0, e.max_shield), 0.0, 1.0), 3)), Color("#7fe3ff"))
		# armor pips crack as armor is chipped away
		if e.max_armor > 0.0:
			var pips := 4
			var left = e.armor / e.max_armor * pips
			for i in pips:
				var c := top + Vector2(-bw * 0.5 + 6 + i * 12, -12)
				var full = float(i) < left - 0.001
				var cracked = not full and float(i) < left + 1.0 and left > float(i)
				ci.draw_rect(Rect2(c - Vector2(5, 4), Vector2(10, 8)), Paint.OUT)
				if full:
					ci.draw_rect(Rect2(c - Vector2(4, 3), Vector2(8, 6)), Color("#c8d0dc"))
				elif cracked:
					ci.draw_rect(Rect2(c - Vector2(4, 3), Vector2(8, 6)), Color("#7a8290"))
					ci.draw_line(c - Vector2(3, 3), c + Vector2(2, 3), Paint.OUT, 1.5)
		# elite modifier icons
		if not e.elites.is_empty():
			var ex = top.x - (e.elites.size() - 1) * 9.0
			for m in e.elites:
				var it := Assets.tex("i_elite_" + String(m))
				ci.draw_texture_rect(it, Rect2(Vector2(ex - 8, top.y - 30), Vector2(16, 16)), false)
				ex += 18.0
		# status icons with stack counts
		var icons := Status.icons(e)
		if not icons.is_empty():
			var sx := pos.x - (icons.size() - 1) * 11.0
			var sy = pos.y + e.radius + 14.0
			for ic in icons:
				var c2 := Vector2(sx, sy)
				ci.draw_circle(c2, 9.0, Paint.OUT)
				ci.draw_circle(c2, 7.0, Color(STATUS_COL[ic[0]]))
				ci.draw_texture_rect(Assets.tex("i_st_" + String(ic[0])), Rect2(c2 - Vector2(6, 6), Vector2(12, 12)), false, Color(0, 0, 0, 0.85))
				if int(ic[1]) > 1:
					ci.draw_string_outline(font, c2 + Vector2(5, 11), str(ic[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
					ci.draw_string(font, c2 + Vector2(5, 11), str(ic[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
				sx += 22.0
		# finisher glow + countered stagger marker
		if e.finishable:
			ci.draw_arc(pos, e.radius + 8.0 + sin(time * 10.0) * 2.0, 0, TAU, 28, Color(Cfg.col("player_gold"), 0.9), 3.0, true)
		if e.countered_t > 0.0:
			ci.draw_string_outline(font, top + Vector2(-30, -20), "STAGGER", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, 4, Color.BLACK)
			ci.draw_string(font, top + Vector2(-30, -20), "STAGGER", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color.WHITE)

func draw_bar(ci: CanvasItem, top: Vector2, w: float, k: float, col: Color) -> void:
	ci.draw_rect(Rect2(top - Vector2(w * 0.5 + 2, 2), Vector2(w + 4, 8)), Color(0, 0, 0, 0.8))
	ci.draw_rect(Rect2(top - Vector2(w * 0.5, 0), Vector2(w * clampf(k, 0.0, 1.0), 4)), col)

## the true hitbox dot appears whenever danger is close; a shield outline shows i-frames
func _draw_player_clarity(ci: CanvasItem) -> void:
	var p := sim.player
	if p.state == SimPlayer.St.DEAD:
		return
	var pos := ipos(p)
	var near := false
	var rr: float = Cfg.F.hurt.hitbox_dot_radius
	for pr in sim.projectiles:
		if pr.team == 1 and pr.alive and pr.pos.distance_squared_to(p.pos) < rr * rr:
			near = true
			break
	if not near:
		for t in sim.telegraphs:
			if not t.resolved and t.hits_player and t.contains(p.pos, 30.0):
				near = true
				break
	if near:
		ci.draw_circle(pos, p.hit_radius + 3.0, Color(0, 0, 0, 0.9))
		ci.draw_circle(pos, p.hit_radius, Color.WHITE)
		ci.draw_circle(pos, p.hit_radius * 0.45, Cfg.col("player_gold"))
	if p.hurt_iframes > 0.0 or p.invuln_t > 0.0:
		var a := 0.5 + 0.3 * sin(time * 20.0)
		ci.draw_arc(pos + Vector2(0, -6), p.radius + 12.0, 0, TAU, 32, Color(Cfg.col("player"), a), 3.0, true)
		ci.draw_arc(pos + Vector2(0, -6), p.radius + 15.0, 0, TAU, 32, Color(Cfg.col("player_gold"), a * 0.5), 1.5, true)
