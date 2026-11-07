extends Control
## Quill's shop: buy with gold, leave when done. Keyboard/gamepad navigable list.

signal buy(i: int)
signal leave

var flow: RoomFlow
var list: VBoxContainer
var gold_label: Label

func setup(f: RoomFlow) -> void:
	flow = f

func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := UI.panel(Vector2(980, 0))
	var v := UI.vbox(12)
	p.add_child(v)
	add_child(UI.center(p))
	var head := UI.hbox(16)
	head.add_child(UI.tex("quill", Vector2(90, 100)))
	var hv := UI.vbox(2)
	hv.add_child(UI.title("QUILL'S WARES", 46))
	hv.add_child(UI.label("\"Gold down there, embers up here. Don't ask me how. I only sell.\"", 21, UI.DIM))
	head.add_child(hv)
	v.add_child(head)
	gold_label = UI.label("", 28, Color("#ffd166"))
	v.add_child(gold_label)
	list = UI.vbox(8)
	v.add_child(list)
	refresh()

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	gold_label.text = "◆ %d gold" % flow.run.gold
	var buttons: Array = []
	for i in flow.shop.size():
		var it: Dictionary = flow.shop[i]
		var label := "%s — %s" % [it.name, it.desc]
		if it.sold:
			label = "SOLD — " + String(it.name)
		var b := UI.button("", func():
			buy.emit(i), 920)
		b.text = ("%4d ◆   " % int(it.price)) + label
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = it.sold or flow.run.gold < int(it.price)
		b.add_theme_font_size_override("font_size", 22)
		list.add_child(b)
		buttons.append(b)
	var lv := UI.button("Leave the shop", func(): leave.emit(), 920)
	list.add_child(lv)
	buttons.append(lv)
	var first := 0
	for i in buttons.size():
		if not buttons[i].disabled:
			first = i
			break
	UI.chain_focus(buttons, first)

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave.emit()
