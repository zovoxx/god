extends Control
## The ending: the sun rises over the Hollow City.

signal done

var lines: Array = []

func setup(l: Array) -> void:
	lines = l

func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color("#1a0e08")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.title("THE SUN RISES", 96, Color("#ffd27a")))
	for l in lines:
		var lb := UI.label(String(l), 28, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
		lb.custom_minimum_size = Vector2(1200, 0)
		v.add_child(lb)
	var b := UI.button("Continue", func(): done.emit())
	var cc := CenterContainer.new()
	cc.add_child(b)
	v.add_child(cc)
	add_child(UI.center(v))
	b.call_deferred("grab_focus")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)
