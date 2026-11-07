extends Control
## Pause: resume / settings / abandon / quit, the last 10 hits you took (source, attack,
## damage) and your current boons with full descriptions.

signal resumed
signal settings_requested
signal abandon
signal quit_title

var sim: Sim

func setup(s: Sim) -> void:
	sim = s

func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UI.hbox(30)
	add_child(UI.center(root))
	# menu column
	var menu := UI.vbox(14)
	root.add_child(menu)
	menu.add_child(UI.title("PAUSED", 60))
	var b1 := UI.button("Resume", func(): resumed.emit())
	var b2 := UI.button("Settings", func(): settings_requested.emit())
	var b3 := UI.button("Abandon run", func(): abandon.emit())
	var b4 := UI.button("Quit to title", func(): quit_title.emit())
	for b in [b1, b2, b3, b4]:
		menu.add_child(b)
	UI.chain_focus([b1, b2, b3, b4])
	# damage log
	var logp := UI.panel(Vector2(520, 620))
	root.add_child(logp)
	var lv := UI.vbox(6)
	logp.add_child(lv)
	lv.add_child(UI.label("DAMAGE TAKEN — LAST 10", 24, UI.GOLD))
	var entries: Array = Recap.damage_log(sim, 10) if sim != null else []
	if entries.is_empty():
		lv.add_child(UI.label("Untouched so far.", 22, UI.DIM))
	for h in entries:
		var r := UI.hbox(10)
		r.add_child(UI.tex(String(h.art), Vector2(36, 36)))
		var l := UI.para("%s — %s" % [h.source, h.attack], 21, UI.INK, 360)
		r.add_child(l)
		r.add_child(UI.label("-%d" % int(h.dmg), 22, Color("#ff6a5a")))
		lv.add_child(r)
	# boons
	var bp := UI.panel(Vector2(620, 620))
	root.add_child(bp)
	var bv := UI.vbox(8)
	bv.add_child(UI.label("YOUR BOONS", 24, UI.GOLD))
	if sim != null and sim.run != null:
		if sim.run.boons.is_empty():
			bv.add_child(UI.label("No boons yet.", 22, UI.DIM))
		for b in sim.run.boons:
			var d := Boons.def(b.id)
			var col := Boons.color_of(b.id)
			bv.add_child(UI.label("%s  ·  %s" % [d.get("name", b.id), Boons.RARITY_NAMES[int(b.rarity)]], 23, col))
			var desc := UI.para(Boons.describe(b.id, int(b.rarity), int(b.get("level", 1))), 19, UI.INK, 560)
			bv.add_child(desc)
	bp.add_child(UI.scroll(bv, Vector2(600, 600)))

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("pause") or ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resumed.emit()
