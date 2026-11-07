extends Control
## Achievement toasts (and other short notices) that slide in at the top right.

var items: Array = []   # {title, desc, t}
var font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	Bus.achievement.connect(func(d): push("ACHIEVEMENT · " + String(d.name), String(d.desc)))
	Bus.toast.connect(func(d): push(String(d.get("title", "")), String(d.get("desc", ""))))

func push(title: String, desc: String) -> void:
	items.append({"title": title, "desc": desc, "t": 0.0})
	Audio.play("achievement")

func _process(d: float) -> void:
	for it in items:
		it.t += d
	items = items.filter(func(it): return it.t < 4.0)
	size = get_viewport_rect().size
	queue_redraw()

func _draw() -> void:
	var y := 140.0
	for it in items:
		var k := clampf(minf(it.t / 0.25, (4.0 - it.t) / 0.4), 0.0, 1.0)
		var w := 520.0
		var x := size.x - (w + 30.0) * k
		draw_rect(Rect2(x, y, w, 84), Color(0.08, 0.06, 0.12, 0.92 * k))
		draw_rect(Rect2(x, y, w, 84), Color(1.0, 0.79, 0.29, k), false, 3.0)
		draw_string(font, Vector2(x + 18, y + 34), it.title, HORIZONTAL_ALIGNMENT_LEFT, w - 30, 24, Color(1.0, 0.85, 0.4, k))
		draw_string(font, Vector2(x + 18, y + 66), it.desc, HORIZONTAL_ALIGNMENT_LEFT, w - 30, 19, Color(1, 1, 1, 0.85 * k))
		y += 96.0
