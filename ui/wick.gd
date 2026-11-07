extends Control
## The Wick — the hub between runs. Pages: Descend (Vows → weapon), Daily Descent, the Wick
## tree (unlocks), Keepsakes, Kindling Heat, Weapon mastery, Bestiary, Achievements, Story.
## Every page is keyboard/gamepad navigable; Esc / B goes back.

signal start_run(opts: Dictionary)
signal open_settings
signal quit_title

var meta: Dictionary
var body: Control
var stack: Array = []
var _vows: Array = []
var _heat: Array = []
var _t := 0.0

func setup(m: Dictionary) -> void:
	meta = m

func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#0e0a0c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func(): _draw_hearth(art))
	add_child(art)
	_vows = (meta.get("vows", []) as Array).duplicate()
	_heat = (meta.get("heat_mods", []) as Array).duplicate()
	body = Control.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(body)
	show_page("main")
	Audio.music_state("wick")

func _process(d: float) -> void:
	_t += d
	for c in get_children():
		if c is Control and c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			c.queue_redraw()

func _draw_hearth(c: Control) -> void:
	var vs := c.size
	var base := Vector2(vs.x * 0.2, vs.y * 0.72)
	var g := 0.5 + 0.5 * sin(_t * 2.3) * 0.5 + 0.25 * sin(_t * 5.1)
	for k in 8:
		c.draw_circle(base, 260.0 - k * 30.0, Color(1.0, 0.7, 0.3, 0.025 + 0.015 * g))
	c.draw_texture_rect(Assets.tex("ossa"), Rect2(base + Vector2(-160, -190), Vector2(140, 180)), false)
	c.draw_texture_rect(Assets.tex("quill"), Rect2(base + Vector2(40, -150), Vector2(130, 150)), false)
	c.draw_texture_rect(Assets.tex("wren"), Rect2(base + Vector2(-50, -130), Vector2(100, 116)), false)
	for i in 14:
		var p := base + Vector2(sin(i * 3.1 + _t * 0.7) * 120.0, -fmod(_t * 40.0 + i * 37.0, 300.0))
		c.draw_circle(p, 2.0, Color(1.0, 0.8, 0.4, 0.5))

# ───────── navigation ─────────

func show_page(id: String, push: bool = true) -> void:
	if push and (stack.is_empty() or stack[-1] != id):
		stack.append(id)
	for ch in body.get_children():
		ch.queue_free()
	var page: Control
	match id:
		"main": page = _main()
		"unlocks": page = _unlocks()
		"keepsakes": page = _keepsakes()
		"vows": page = _vows_page()
		"weapons": page = _weapons()
		"heat": page = _heat_page()
		"mastery": page = _mastery()
		"bestiary": page = _bestiary()
		"achievements": page = _achievements()
		"story": page = _story()
		"daily": page = _daily()
		_: page = _main()
	body.add_child(page)

func back() -> void:
	if stack.size() <= 1:
		return
	stack.pop_back()
	show_page(stack[-1], false)
	Audio.play("ui_back")

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("pause"):
		if stack.size() > 1:
			get_viewport().set_input_as_handled()
			back()

func refresh() -> void:
	show_page(stack[-1], false)

## standard page frame: title, embers, scrolling content, a back button. Returns [root, content_vbox, focusables]
func _frame(title: String, sub: String = "") -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := UI.panel(Vector2(1060, 860))
	panel.position = Vector2(780, 110)
	panel.size = Vector2(1060, 860)
	root.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	var head := UI.hbox(20)
	head.add_child(UI.title(title, 46))
	var em := UI.label("✦ %d Embers" % int(meta.embers), 28, Color("#ffe6a0"))
	em.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	em.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(em)
	v.add_child(head)
	if sub != "":
		v.add_child(UI.para(sub, 22, UI.DIM, 1000))
	var content := UI.vbox(8)
	v.add_child(UI.scroll(content, Vector2(1000, 640)))
	return [root, content, v]

func _finish(fr: Array, items: Array, focus_idx: int = 0, back_btn: bool = true) -> Control:
	if back_btn:
		var b := UI.button("Back", back, 300)
		(fr[2] as VBoxContainer).add_child(b)
		items.append(b)
	UI.chain_focus(items, focus_idx)
	return fr[0]

# ───────── pages ─────────

func _main() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := UI.vbox(10)
	v.position = Vector2(860, 90)
	root.add_child(v)
	v.add_child(UI.title("THE WICK", 72))
	v.add_child(UI.label("✦ %d Embers    ·    %d runs    ·    %d wins" % [int(meta.embers), int(meta.runs), int(meta.wins)], 26, Color("#ffe6a0")))
	var last: Array = Meta.story_log(meta)
	if not last.is_empty():
		var l: Dictionary = last[-1]
		v.add_child(UI.para("%s: “%s”" % [l.who, l.line], 22, Color("#d8c8ff"), 900))
	var items: Array = []
	var add := func(label: String, cb: Callable):
		var b := UI.button(label, cb, 520)
		v.add_child(b)
		items.append(b)
	add.call("Descend", func(): show_page("vows"))
	add.call("Daily Descent", func(): show_page("daily"))
	add.call("The Wick  —  unlocks", func(): show_page("unlocks"))
	add.call("Keepsakes", func(): show_page("keepsakes"))
	if meta.get("heat_unlocked", false):
		add.call("Kindling Heat  (%d)" % Meta.heat_level(_heat), func(): show_page("heat"))
	add.call("Weapon Mastery", func(): show_page("mastery"))
	add.call("Bestiary", func(): show_page("bestiary"))
	add.call("Achievements  (%d / %d)" % [(meta.get("achievements", []) as Array).size(), Achievements.LIST.size()], func(): show_page("achievements"))
	add.call("Story", func(): show_page("story"))
	add.call("Settings", func(): open_settings.emit())
	add.call("Back to title", func(): quit_title.emit())
	UI.chain_focus(items)
	return root

func _unlocks() -> Control:
	var fr := _frame("THE WICK", "Spend Embers on new weapons, Lights and blessings. Light grows when it is shared.")
	var items: Array = []
	var group := ""
	for u in Meta.unlock_defs():
		if u.group != group:
			group = u.group
			fr[1].add_child(UI.label(group.to_upper(), 24, UI.GOLD))
		var owned := Meta.has(meta, u.id)
		var reqs: Array = u.get("requires", [])
		var locked := reqs.any(func(r): return not Meta.has(meta, r))
		var txt := "%s  —  %s" % [u.name, u.desc]
		var label := ("✓  " + txt) if owned else ("%3d ✦   %s" % [int(u.cost), txt])
		if locked and not owned:
			label += "   (needs %s)" % ", ".join(reqs.map(func(r): return Meta.unlock_def(r).get("name", r)))
		var id: String = u.id
		var b := UI.button(label, func():
			if Meta.buy(meta, id):
				Audio.play("unlock")
				App.save_meta()
				refresh()
			else:
				Audio.play("deny"), 980)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 21)
		b.disabled = owned or locked or int(meta.embers) < int(u.cost)
		fr[1].add_child(b)
		items.append(b)
	var first := 0
	for i in items.size():
		if not items[i].disabled:
			first = i
			break
	return _finish(fr, items, first)

func _keepsakes() -> Control:
	var fr := _frame("KEEPSAKES", "Carry one keepsake into each descent.")
	var items: Array = []
	var ks := Keepsakes.all()
	var none := UI.button(("● " if String(meta.keepsake) == "" else "○ ") + "No keepsake", func():
		meta.keepsake = ""
		App.save_meta()
		refresh(), 980)
	fr[1].add_child(none)
	items.append(none)
	for id in ks.keys():
		var k: Dictionary = ks[id]
		var owned := Meta.has(meta, id)
		var mark := "● " if String(meta.keepsake) == id else "○ "
		var kid: String = id
		var b := UI.button((mark if owned else "🔒 ") + "%s — %s" % [k.name, k.desc], func():
			meta.keepsake = kid
			App.save_meta()
			refresh(), 980)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not owned
		fr[1].add_child(b)
		items.append(b)
	return _finish(fr, items)

func _vows_page() -> Control:
	var mx := int(Cfg.T.meta.vow_max)
	var fr := _frame("VOWS", "Choose up to %d optional challenges for bonus Embers. Then pick your weapon." % mx)
	var items: Array = []
	for v in Cfg.T.meta.vows:
		var on := _vows.has(v.id)
		var vid: String = v.id
		var b := UI.button("%s  %s  —  %s   (+%d ✦)" % ["☑" if on else "☐", v.name, v.desc, int(v.embers)], func():
			if _vows.has(vid):
				_vows.erase(vid)
			elif _vows.size() < mx:
				_vows.append(vid)
			else:
				Audio.play("deny")
			meta.vows = _vows.duplicate()
			refresh(), 980)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fr[1].add_child(b)
		items.append(b)
	var go := UI.button("Choose weapon  →", func(): show_page("weapons"), 400)
	(fr[2] as VBoxContainer).add_child(go)
	items.append(go)
	return _finish(fr, items, items.size() - 1)

func _weapons() -> Control:
	var fr := _frame("CHOOSE YOUR WEAPON", "Mastery grows with every kill and unlocks weapon forges.")
	var items: Array = []
	for w in Weapons.IDS:
		var W: Dictionary = Cfg.T.weapons[w]
		var ok := Meta.weapon_unlocked(meta, w)
		var lv := Meta.mastery_level(meta, w)
		var wid: String = w
		var row := UI.hbox(14)
		row.add_child(UI.tex("w_" + w, Vector2(80, 60)))
		var b := UI.button(("%s  ·  mastery %d  —  %s" % [W.name, lv, W.desc]) if ok else ("🔒 %s — unlock at the Wick" % W.name), func():
			meta.last_weapon = wid
			App.save_meta()
			start_run.emit({"weapon": wid, "vows": _vows.duplicate(), "heat_mods": _heat.duplicate()}), 880)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 21)
		b.disabled = not ok
		row.add_child(b)
		fr[1].add_child(row)
		items.append(b)
	var focus := maxi(0, Weapons.IDS.find(String(meta.get("last_weapon", "fangs"))))
	return _finish(fr, items, focus)

func _heat_page() -> Control:
	var fr := _frame("KINDLING HEAT", "Stack modifiers for a harder descent. Each point of Heat adds %d%% Embers." % int(float(Cfg.T.meta.heat_ember_bonus) * 100.0))
	var items: Array = []
	fr[1].add_child(UI.label("Heat %d   ·   best win at Heat %d" % [Meta.heat_level(_heat), int(meta.get("best_heat", 0))], 26, Color("#ff9a6a")))
	for h in Cfg.T.meta.heat:
		var on := _heat.has(h.id)
		var hid: String = h.id
		var b := UI.button("%s  %s  (+%d)  —  %s" % ["☑" if on else "☐", h.name, int(h.points), h.desc], func():
			if _heat.has(hid):
				_heat.erase(hid)
			else:
				_heat.append(hid)
			meta.heat_mods = _heat.duplicate()
			App.save_meta()
			refresh(), 980)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fr[1].add_child(b)
		items.append(b)
	return _finish(fr, items)

func _mastery() -> Control:
	var fr := _frame("WEAPON MASTERY", "Kills earn mastery. Levels 1 and 3 unlock weapon forges; the others add a glow to the weapon.")
	var th: Array = Cfg.T.meta.mastery.thresholds
	for w in Weapons.IDS:
		var W: Dictionary = Cfg.T.weapons[w]
		var xp := int((meta.get("mastery", {}) as Dictionary).get(w, 0))
		var lv := Meta.mastery_level(meta, w)
		var nxt: int = int(th[mini(lv + 1, th.size() - 1)])
		var row := UI.hbox(14)
		row.add_child(UI.tex("w_" + w, Vector2(70, 52)))
		var col := UI.vbox(2)
		col.add_child(UI.label("%s  —  level %d   (%d xp)" % [W.name, lv, xp], 24, UI.INK))
		col.add_child(UI.bar(float(xp - int(th[lv])) / maxf(1.0, nxt - int(th[lv])) if lv < th.size() - 1 else 1.0, 600, UI.GOLD))
		var forges: Array = W.forges
		var unlocked := Meta.forge_unlocks(meta, w)
		var names: Array = []
		for i in forges.size():
			names.append(("✓ " if i < unlocked else "🔒 ") + String(Cfg.T.forges[forges[i]].name))
		col.add_child(UI.label("Forges: " + "   ".join(names), 19, UI.DIM))
		row.add_child(col)
		fr[1].add_child(row)
	return _finish(fr, [])

func _bestiary() -> Control:
	var b: Dictionary = meta.get("bestiary", {})
	var fr := _frame("BESTIARY", "%d creatures recorded. Notes fill in as you fight — and fall to — them." % b.size())
	for src in [Cfg.T.enemies, Cfg.T.bosses]:
		for k in src.keys():
			var d: Dictionary = src[k]
			if int(d.get("depth", 0)) <= 0 or k in ["archivist_copy", "regent_mirror"]:
				continue
			var e: Dictionary = b.get(k, {})
			var row := UI.hbox(14)
			var seen := not e.is_empty()
			var icon := UI.tex(String(d.get("art", k)), Vector2(64, 64))
			if not seen:
				icon.modulate = Color(0, 0, 0, 0.8)
			row.add_child(icon)
			var col := UI.vbox(2)
			var role := String(d.get("role", "guardian" if d.get("guardian", false) else ("boss" if d.get("boss", false) else "")))
			col.add_child(UI.label(("%s  ·  depth %d  ·  %s" % [d.name, int(d.depth), role]) if seen else "???  ·  depth %d" % int(d.depth), 23, UI.INK if seen else UI.DIM))
			if seen:
				col.add_child(UI.label("Defeated %d   ·   fell to it %d" % [int(e.get("kills", 0)), int(e.get("deaths", 0))], 18, UI.DIM))
				if int(e.get("kills", 0)) >= 3 or int(e.get("deaths", 0)) >= 1:
					col.add_child(UI.para(String(d.get("tip", "")), 18, Color("#7fd4ff"), 860))
				else:
					col.add_child(UI.label("Defeat 3 to learn more.", 18, UI.DIM))
			row.add_child(col)
			fr[1].add_child(row)
	return _finish(fr, [])

func _achievements() -> Control:
	var have: Array = meta.get("achievements", [])
	var fr := _frame("ACHIEVEMENTS", "%d of %d earned." % [have.size(), Achievements.LIST.size()])
	for a in Achievements.LIST:
		var got := have.has(a[0])
		fr[1].add_child(UI.label(("★  " if got else "☆  ") + "%s — %s" % [a[1], a[2]], 22, UI.GOLD if got else UI.DIM))
	return _finish(fr, [])

func _story() -> Control:
	var log := Meta.story_log(meta)
	var fr := _frame("STORY", "%d of %d lines heard. One more after every descent." % [log.size(), Meta.story_count()])
	if log.is_empty():
		fr[1].add_child(UI.label("Descend, and come back. Ossa will be waiting.", 22, UI.DIM))
	for l in log:
		fr[1].add_child(UI.para("%s: “%s”" % [l.who, l.line], 22, Color("#d8c8ff"), 960))
	return _finish(fr, [])

func _daily() -> Control:
	var key := Meta.daily_key()
	var w := Meta.daily_weapon(key)
	var fr := _frame("DAILY DESCENT", "Everyone gets the same seed today: %s with the %s. No vows, no keepsake, no Heat." % [key, Cfg.T.weapons[w].name])
	var scores: Array = (meta.get("daily", {}) as Dictionary).get(key, [])
	fr[1].add_child(UI.label("TODAY'S BEST", 24, UI.GOLD))
	if scores.is_empty():
		fr[1].add_child(UI.label("No attempts yet.", 22, UI.DIM))
	for i in scores.size():
		fr[1].add_child(UI.label("%2d.  %d" % [i + 1, int(scores[i])], 24, UI.INK))
	var items: Array = []
	var go := UI.button("Begin the Daily Descent", func(): start_run.emit({"daily": true}), 480)
	(fr[2] as VBoxContainer).add_child(go)
	items.append(go)
	return _finish(fr, items)
