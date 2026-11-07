extends Control
## Run summary: time, rooms, damage dealt and taken (a bar per source), best hit, highest
## streak, boons, Embers and personal-best comparisons.

signal done

var run: RunState
var result := {}

func setup(r: RunState, res: Dictionary) -> void:
	run = r
	result = res

func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := UI.panel(Vector2(1500, 0))
	var v := UI.vbox(12)
	p.add_child(v)
	add_child(UI.center(p))
	v.add_child(UI.title("VICTORY" if run.won else "RUN SUMMARY", 54, UI.GOLD if run.won else Color("#ff8a6a")))
	var pbs: Dictionary = result.get("pbs", {})
	var mm := int(run.time) / 60
	var ss := int(run.time) % 60
	var cols := UI.hbox(40)
	v.add_child(cols)
	var left := UI.vbox(6)
	left.custom_minimum_size = Vector2(640, 0)
	cols.add_child(left)
	var stat := func(label: String, val: String, key: String):
		var pb: Dictionary = pbs.get(key, {})
		var extra := ""
		if pb.get("new", false) and pb.get("best") != null:
			extra = "   NEW BEST!"
		elif not pb.is_empty() and pb.get("best") != null:
			extra = "   (best %d)" % int(pb.best)
		left.add_child(UI.label("%s   %s%s" % [label, val, extra], 24, UI.GOLD if extra.begins_with("   NEW") else UI.INK))
	stat.call("Time", "%d:%02d" % [mm, ss], "win_time")
	stat.call("Reached", "%s · room %d" % [Rooms.depth_name(run.depth), run.room_index + 1], "")
	stat.call("Rooms cleared", str(run.rooms_cleared), "rooms")
	stat.call("Enemies defeated", str(run.kills), "kills")
	stat.call("Damage dealt", str(int(run.stats_dmg_dealt)), "dmg_dealt")
	stat.call("Best single hit", str(int(run.best_hit)), "best_hit")
	stat.call("Highest streak", str(run.best_streak), "streak")
	stat.call("Perfect dashes · counters · finishers", "%d · %d · %d" % [run.perfect_dashes, run.counters, run.finishers], "")
	left.add_child(UI.label("✦ +%d Embers" % int(result.get("embers", run.embers)), 30, Color("#ffe6a0")))
	var vd: Array = result.get("vows_done", [])
	if not vd.is_empty():
		left.add_child(UI.label("Vows kept: " + ", ".join(vd.map(func(x): return Meta.vow_def(x).get("name", x))), 20, UI.GOLD))
	var ms: Dictionary = result.get("mastery", {})
	if not ms.is_empty():
		left.add_child(UI.label("%s mastery +%d xp%s" % [Cfg.T.weapons[ms.weapon].name, int(ms.xp), "  —  LEVEL %d!" % int(ms.level) if int(ms.level) > int(ms.level_before) else ""], 20, UI.INK))
	var right := UI.vbox(6)
	right.custom_minimum_size = Vector2(700, 0)
	cols.add_child(right)
	right.add_child(UI.label("DAMAGE TAKEN BY SOURCE  (%d total)" % int(run.dmg_taken), 22, UI.GOLD))
	var srcs: Array = run.dmg_by_source.keys()
	srcs.sort_custom(func(a, b): return float(run.dmg_by_source[a]) > float(run.dmg_by_source[b]))
	var top := 1.0
	if not srcs.is_empty():
		top = float(run.dmg_by_source[srcs[0]])
	for sname in srcs.slice(0, 7):
		var row := UI.hbox(10)
		var l := UI.label(String(sname), 19, UI.INK)
		l.custom_minimum_size = Vector2(250, 0)
		row.add_child(l)
		row.add_child(UI.bar(float(run.dmg_by_source[sname]) / maxf(1.0, top), 330, Color("#ff6a5a")))
		row.add_child(UI.label(str(int(run.dmg_by_source[sname])), 19, UI.DIM))
		right.add_child(row)
	right.add_child(UI.label("BOONS", 22, UI.GOLD))
	var names := run.boon_names()
	right.add_child(UI.para(", ".join(names) if not names.is_empty() else "none", 19, UI.INK, 680))
	var ach: Array = result.get("achievements", [])
	if not ach.is_empty():
		right.add_child(UI.label("ACHIEVEMENTS: " + ", ".join(ach.map(func(a): return a.name)), 19, UI.GOLD))
	var b := UI.button("Return to the Wick", func(): done.emit())
	var cc := CenterContainer.new()
	cc.add_child(b)
	v.add_child(cc)
	b.call_deferred("grab_focus")
