extends Control
## Title screen: animated lantern, menu (navigable with keyboard, mouse or gamepad).

signal action(id: String)

var items: Array = []    # [[id, label]]
var _t := 0.0

func setup(menu: Array) -> void:
	items = menu

func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := Control.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func(): _draw_art(art))
	add_child(art)
	var v := UI.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.title("LANTERNFALL", 110))
	v.add_child(UI.label("Wren, the last Kindler, descends to take back a stolen sun.", 26, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	v.add_child(spacer)
	var btns: Array = []
	for it in items:
		var id: String = it[0]
		var b := UI.button(String(it[1]), func(): action.emit(id), 420)
		btns.append(b)
		var row := CenterContainer.new()
		row.add_child(b)
		v.add_child(row)
	add_child(UI.center(v))
	UI.chain_focus(btns)
	var ver := UI.label("v1.0 · Godot %s" % Engine.get_version_info().string, 18, UI.DIM)
	ver.position = Vector2(24, 20)
	add_child(ver)

func _process(d: float) -> void:
	_t += d
	queue_redraw()
	for c in get_children():
		if c is Control and c.get_child_count() == 0 and c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			c.queue_redraw()

func _draw_art(c: Control) -> void:
	var vs := c.size
	var center := Vector2(vs.x * 0.5, vs.y * 0.18)
	for i in 60:
		var a := float(i) * 2.4 + _t * 0.05
		var r := 120.0 + fmod(float(i) * 37.0, 700.0)
		var p := center + Vector2(cos(a), sin(a) * 0.5) * r + Vector2(0, vs.y * 0.4)
		c.draw_circle(p, 1.5 + fmod(i, 3), Color(1.0, 0.85, 0.5, 0.15 + 0.1 * sin(_t * 2.0 + i)))
	var g := 0.5 + 0.5 * sin(_t * 1.7)
	for k in 6:
		c.draw_circle(Vector2(vs.x * 0.5, vs.y * 0.86), 160.0 - k * 22.0, Color(1.0, 0.75, 0.3, 0.03 + 0.02 * g))
