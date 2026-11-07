extends Control
## Death recap card: the killer (sprite + name), the killing attack, the last 5 hits, a tip
## for that enemy, the build, Embers earned and progress toward the next Wick unlock.
## "Descend again" is focused so a new run is one press away.

signal descend_again
signal to_wick

var data := {}

func setup(d: Dictionary) -> void:
	data = d

func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.01, 0.02, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var card := UI.panel(Vector2(1180, 0))
	var v := UI.vbox(14)
	card.add_child(v)
	add_child(UI.center(card))
	v.add_child(UI.title("THE LIGHT GOES OUT", 54, Color("#ff6a5a")))
	var k: Dictionary = data.get("killer", {})
	var row := UI.hbox(26)
	v.add_child(row)
	var portrait := UI.tex(String(k.get("art", "wren")), Vector2(150, 150))
	row.add_child(portrait)
	var kv := UI.vbox(6)
	row.add_child(kv)
	kv.add_child(UI.label("Slain by", 22, UI.DIM))
	kv.add_child(UI.label(String(k.get("source", "?")), 42, Color("#ff8a6a")))
	var atk := String(k.get("attack", ""))
	if atk != "":
		kv.add_child(UI.label("with %s  ·  %d damage" % [atk, int(k.get("dmg", 0))], 26, UI.INK))
	var tip := String(data.get("tip", ""))
	if tip != "":
		var tl := UI.label("TIP  " + tip, 24, Color("#7fd4ff"))
		tl.custom_minimum_size = Vector2(700, 0)
		kv.add_child(tl)
	var cols := UI.hbox(40)
	v.add_child(cols)
	var hits := UI.vbox(4)
	hits.custom_minimum_size = Vector2(540, 0)
	cols.add_child(hits)
	hits.add_child(UI.label("LAST HITS", 22, UI.GOLD))
	for h in data.get("last_hits", []):
		hits.add_child(UI.label("%s — %s   -%d" % [h.source, h.attack, int(h.dmg)], 22, UI.INK))
	var build := UI.vbox(4)
	build.custom_minimum_size = Vector2(540, 0)
	cols.add_child(build)
	build.add_child(UI.label("BUILD", 22, UI.GOLD))
	build.add_child(UI.label(String(data.get("weapon", "")), 24, UI.INK))
	var bn: Array = data.get("boons", [])
	build.add_child(UI.label(", ".join(bn) if not bn.is_empty() else "No boons yet", 20, UI.DIM))
	# embers + next unlock
	var er := UI.hbox(16)
	v.add_child(er)
	er.add_child(UI.label("✦ +%d Embers" % int(data.get("embers", 0)), 30, Color("#ffe6a0")))
	var nu: Dictionary = data.get("next_unlock", {})
	if not nu.is_empty():
		var have := float(nu.get("have", 0))
		var cost := float(nu.get("cost", 1))
		er.add_child(UI.label("Next: %s  %d / %d" % [nu.get("name", ""), int(have), int(cost)], 24, UI.INK))
		er.add_child(UI.bar(have / maxf(1.0, cost), 300, UI.GOLD))
	var story := String(data.get("story", ""))
	if story != "":
		v.add_child(UI.label(story, 22, Color("#d8c8ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var btns := UI.hbox(20)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(btns)
	var again := UI.button("Descend again", func(): descend_again.emit())
	var wick := UI.button("Return to the Wick", func(): to_wick.emit())
	btns.add_child(again)
	btns.add_child(wick)
	again.focus_neighbor_right = again.get_path_to(wick)
	wick.focus_neighbor_left = wick.get_path_to(again)
	again.call_deferred("grab_focus")
