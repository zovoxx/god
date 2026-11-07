extends Control
## Debug menu (F1): jump to any depth/room type, spawn any enemy (with elite modifiers),
## guardian or boss, grant any boon or weapon, god mode, one-hit kills, and overlays for
## hitboxes, AI states and telegraph shapes.

var game
var elites: Array = []
var tab := "room"
var body: VBoxContainer

func setup(g) -> void:
	game = g

func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := UI.panel(Vector2(1300, 920))
	p.position = Vector2(310, 80)
	add_child(p)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.title("DEBUG", 40, Color("#7fd4ff")))
	var tabs := UI.hbox(8)
	v.add_child(tabs)
	var tab_btns: Array = []
	for t in [["room", "Rooms"], ["spawn", "Spawn"], ["boons", "Boons"], ["toggles", "Toggles"]]:
		var tid: String = t[0]
		var b := UI.button(t[1], func():
			tab = tid
			build(), 220)
		tabs.add_child(b)
		tab_btns.append(b)
	body = UI.vbox(6)
	v.add_child(UI.scroll(body, Vector2(1260, 720)))
	v.add_child(UI.label("F1 / Esc closes", 18, UI.DIM))
	build()
	tab_btns[0].call_deferred("grab_focus")

func sim() -> Sim:
	return game.sim

func _grid(items: Array, cols: int = 4) -> void:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for it in items:
		var b := UI.button(String(it[0]), it[1], 300)
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(300, 44)
		g.add_child(b)
	body.add_child(g)

func build() -> void:
	for c in body.get_children():
		c.queue_free()
	var s := sim()
	match tab:
		"room":
			if s.flow == null:
				body.add_child(UI.label("Start a run to jump between rooms.", 22, UI.DIM))
				return
			for d in [1, 2, 3, 4]:
				body.add_child(UI.label("DEPTH %d — %s" % [d, Rooms.depth_name(d)], 22, UI.GOLD))
				var items: Array = []
				for t in ["combat", "elite", "guardian", "shop", "spring", "ordeal", "boss"]:
					var dd: int = d
					var tt: String = t
					items.append([t.capitalize(), func(): _jump(dd, tt)])
				_grid(items, 4)
		"spawn":
			body.add_child(UI.label("Elite modifiers for the next spawn: " + (", ".join(elites) if not elites.is_empty() else "none"), 20, UI.INK))
			var mods: Array = []
			for m in Elites.ALL:
				var mm: String = m
				mods.append([("✓ " if elites.has(m) else "") + m.capitalize(), func():
					if elites.has(mm):
						elites.erase(mm)
					else:
						elites.append(mm)
					build()])
			_grid(mods, 5)
			for depth in [1, 2, 3, 4]:
				body.add_child(UI.label("DEPTH %d ENEMIES" % depth, 20, UI.GOLD))
				var es: Array = []
				for k in Cfg.T.enemies.keys():
					if int(Cfg.T.enemies[k].get("depth", 0)) == depth:
						var kk: String = k
						es.append([Cfg.T.enemies[k].name, func(): _spawn(kk)])
				_grid(es, 4)
			body.add_child(UI.label("GUARDIANS & BOSSES", 20, UI.GOLD))
			var bs: Array = []
			for k in Cfg.T.bosses.keys():
				var kk2: String = k
				bs.append([Cfg.T.bosses[k].name, func(): _spawn(kk2)])
			_grid(bs, 3)
		"boons":
			if s.run == null:
				body.add_child(UI.label("Start a run to grant boons.", 22, UI.DIM))
			body.add_child(UI.label("WEAPON", 20, UI.GOLD))
			var ws: Array = []
			for w in Weapons.IDS:
				var wid: String = w
				ws.append([Cfg.T.weapons[w].name, func():
					s.equip_weapon(wid, s.run.forges if s.run != null else {})
					if s.run != null:
						s.run.weapon = wid])
			_grid(ws, 5)
			if s.run == null:
				return
			for p in Cfg.B.order + ["duo"]:
				body.add_child(UI.label(String(p).to_upper(), 20, Boons.color_of(p + "_attack") if p != "duo" else UI.GOLD))
				var items2: Array = []
				for b in Cfg.B.boons:
					if b.patron == p:
						var bid: String = b.id
						items2.append([("✓ " if s.run.has_boon(bid) else "") + String(b.name), func():
							Boons.grant(s, bid, 2)
							build()])
				_grid(items2, 4)
		"toggles":
			var D: Dictionary = App.debug
			var items3: Array = [
				[("✓ " if s.god_mode else "") + "God mode", func():
					s.god_mode = not s.god_mode
					build()],
				[("✓ " if s.one_hit else "") + "One-hit kills", func():
					s.one_hit = not s.one_hit
					build()],
				[("✓ " if s.no_ai else "") + "Freeze AI", func():
					s.no_ai = not s.no_ai
					build()],
				[("✓ " if D.hitboxes else "") + "Show hitboxes", func():
					D.hitboxes = not D.hitboxes
					build()],
				[("✓ " if D.ai else "") + "Show AI states", func():
					D.ai = not D.ai
					build()],
				[("✓ " if D.tele else "") + "Show telegraph shapes", func():
					D.tele = not D.tele
					build()],
				["Kill all enemies", func():
					for e in s.enemies:
						if e.targetable():
							var h := HitInfo.make(99999.0, "attack", 0.3, Vector2.UP, e.pos)
							h.armor_break = 9.0
							Combat.deal(s, e, h)],
				["Full heal", func(): Combat.heal_player(s, 9999.0, "debug")],
				["+500 gold", func():
					if s.run != null:
						s.run.gold += 500],
				["+100 Embers (Wick)", func():
					App.meta.embers = int(App.meta.embers) + 100
					App.save_meta()],
				["Fill Overdrive", func(): Combat.add_overdrive(s, 999.0)],
				["Hurt 10", func(): Combat.hurt_player(s, 10.0, s.player.pos + Vector2(60, 0), null, "Debug")],
			]
			_grid(items3, 3)

func _jump(depth: int, type: String) -> void:
	var s := sim()
	var plan := {"type": type, "depth": depth, "step": {"combat": 0, "elite": 2, "guardian": 3, "shop": 2, "spring": 4, "ordeal": 2, "boss": 5}[type], "reward": "boon", "patron": s.run.patrons[0], "seed": randi()}
	match type:
		"guardian": plan.kind = Cfg.T.rooms.guardians[str(depth)][randi() % 2]
		"boss":
			plan.kind = Cfg.T.rooms.bosses[str(depth)]
			plan.reward = "none"
		"shop", "spring": plan.reward = "none"
		"ordeal": plan.ordeal = ["altar", "gauntlet", "wager"][randi() % 3]
	s.flow.enter(plan)
	close()

func _spawn(kind: String) -> void:
	var s := sim()
	var depth := int(Enemies.def_for(s, kind).get("depth", 1))
	Enemies.spawn(s, kind, Enemies.spawn_point(s, 24.0, true), maxi(1, depth), {"elites": elites.duplicate()})

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("debug") or ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if game != null:
		game.debug_menu = null
		game.paused = false
		game.ui_blocking = false
	queue_free()
