extends Control
## Settings: volumes, game-feel sliders (shake, hit-stop, flashes, damage numbers), reduce
## flashing, damage numbers on/off, colour-blind palette, aim mode, graphics preset,
## fullscreen, and full keyboard + gamepad rebinding. Every change applies and saves at once.

var waiting_action := ""
var waiting_pad := false
var wait_label: Label
var content: VBoxContainer
var focus_list: Array = []

func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := UI.panel(Vector2(1240, 900))
	var v := UI.vbox(10)
	p.add_child(v)
	add_child(UI.center(p))
	v.add_child(UI.title("SETTINGS", 50))
	content = UI.vbox(8)
	v.add_child(UI.scroll(content, Vector2(1200, 720)))
	wait_label = UI.label("", 22, UI.GOLD)
	v.add_child(wait_label)
	var back := UI.button("Back", close, 300)
	v.add_child(back)
	build()

func build() -> void:
	for c in content.get_children():
		c.queue_free()
	focus_list.clear()
	var S: Dictionary = App.settings
	_head("AUDIO")
	_slider("Master volume", "master", 0.0, 1.0)
	_slider("Music volume", "music", 0.0, 1.0)
	_slider("Effects volume", "sfx", 0.0, 1.0)
	_head("GAME FEEL")
	_slider("Screen shake", "shake", 0.0, 1.5)
	_slider("Hit-stop", "hitstop", 0.0, 1.5)
	_slider("Flashes", "flashes", 0.0, 1.0)
	_slider("Damage number size", "numbers_scale", 0.5, 1.6)
	_toggle("Damage numbers", "numbers_on")
	_toggle("Reduce flashing", "reduce_flashing")
	_head("ACCESSIBILITY & DISPLAY")
	_toggle("Colour-blind safe palette", "colorblind")
	_choice("Aim mode", "aim_mode", [["auto", "Auto (last device)"], ["mouse", "Mouse"], ["stick", "Right stick"], ["autoaim", "Auto-aim"]])
	_choice("Graphics", "graphics", [["low", "Low"], ["medium", "Medium"], ["high", "High"]])
	_toggle("Fullscreen (F11)", "fullscreen")
	_head("CONTROLS — select a binding, then press the new key or button")
	for a in Controls.REBINDABLE:
		var row := UI.hbox(10)
		var l := UI.label(Controls.LABELS[a], 22, UI.INK)
		l.custom_minimum_size = Vector2(220, 0)
		row.add_child(l)
		var act: String = a
		var kb := UI.button("⌨ " + Controls.labels_for(a, false), func(): _wait(act, false), 440)
		var pb := UI.button("🎮 " + Controls.labels_for(a, true), func(): _wait(act, true), 440)
		kb.add_theme_font_size_override("font_size", 19)
		pb.add_theme_font_size_override("font_size", 19)
		row.add_child(kb)
		row.add_child(pb)
		content.add_child(row)
		focus_list.append(kb)
		focus_list.append(pb)
	var reset := UI.button("Reset controls to defaults", func():
		App.settings.bindings = {}
		Controls.install({})
		App.save_settings()
		build(), 520)
	content.add_child(reset)
	focus_list.append(reset)
	if not focus_list.is_empty():
		focus_list[0].call_deferred("grab_focus")

func _head(t: String) -> void:
	content.add_child(UI.label(t, 24, UI.GOLD))

func _slider(label: String, key: String, mn: float, mx: float) -> void:
	var row := UI.hbox(12)
	var l := UI.label(label, 22, UI.INK)
	l.custom_minimum_size = Vector2(320, 0)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = 0.05
	sl.value = float(App.settings.get(key, 1.0))
	sl.custom_minimum_size = Vector2(560, 32)
	sl.focus_mode = Control.FOCUS_ALL
	var val := UI.label("%d%%" % int(sl.value * 100.0), 22, UI.DIM)
	sl.value_changed.connect(func(x):
		App.settings[key] = x
		val.text = "%d%%" % int(x * 100.0)
		App.apply_settings()
		App.save_settings())
	row.add_child(sl)
	row.add_child(val)
	content.add_child(row)
	focus_list.append(sl)

func _toggle(label: String, key: String) -> void:
	var on: bool = App.settings.get(key, false)
	var b := UI.button(("☑  " if on else "☐  ") + label, func():
		App.settings[key] = not bool(App.settings.get(key, false))
		App.apply_settings()
		App.save_settings()
		build(), 900)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(b)
	focus_list.append(b)

func _choice(label: String, key: String, opts: Array) -> void:
	var cur: String = App.settings.get(key, opts[0][0])
	var idx := 0
	for i in opts.size():
		if opts[i][0] == cur:
			idx = i
	var b := UI.button("%s:  %s  ▸" % [label, opts[idx][1]], func():
		App.settings[key] = opts[(idx + 1) % opts.size()][0]
		App.apply_settings()
		App.save_settings()
		build(), 900)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(b)
	focus_list.append(b)

func _wait(action: String, pad: bool) -> void:
	waiting_action = action
	waiting_pad = pad
	wait_label.text = "Press a %s for “%s”…  (Esc cancels)" % ["gamepad button" if pad else "key or mouse button", Controls.LABELS[action]]

func _input(ev: InputEvent) -> void:
	if waiting_action == "":
		return
	if ev is InputEventKey and ev.pressed and ev.physical_keycode == KEY_ESCAPE:
		waiting_action = ""
		wait_label.text = ""
		get_viewport().set_input_as_handled()
		return
	var ok := false
	if waiting_pad:
		ok = (ev is InputEventJoypadButton and ev.pressed) or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.7)
	else:
		ok = (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed)
	if not ok:
		return
	var e := ev.duplicate()
	if e is InputEventJoypadMotion:
		e.axis_value = signf(e.axis_value)
	Controls.rebind(waiting_action, e)
	App.save_settings()
	waiting_action = ""
	wait_label.text = "Saved."
	get_viewport().set_input_as_handled()
	build()

func _unhandled_input(ev: InputEvent) -> void:
	if waiting_action == "" and (ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	Audio.play("ui_back")
	queue_free()
