class_name UI
extends RefCounted
## The one shared Theme plus small builders so every screen looks and navigates the same.
## Focus is always visible (gold outline) for keyboard and gamepad navigation.

const BG := Color("#0c0910")
const PANEL := Color("#17121f")
const PANEL2 := Color("#211a2c")
const INK := Color("#f4ead8")
const DIM := Color("#a89cb4")
const GOLD := Color("#ffc94a")
const LINE := Color("#3a2e48")

static var _theme: Theme

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 26
	var f := ThemeDB.fallback_font
	t.default_font = f
	t.set_color("font_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	# buttons
	var normal := _box(PANEL2, LINE, 2)
	var hover := _box(Color("#2c2238"), GOLD.darkened(0.3), 2)
	var pressed := _box(Color("#3a2c48"), GOLD, 3)
	var focus := _box(Color(0, 0, 0, 0), GOLD, 4)
	focus.draw_center = false
	var disabled := _box(Color("#141018"), Color("#2a2232"), 2)
	for cls in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, focus)
		t.set_stylebox("disabled", cls, disabled)
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, GOLD.lightened(0.4))
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_disabled_color", cls, Color("#5a5064"))
		t.set_font_size("font_size", cls, 26)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, LINE, 2, 14))
	t.set_stylebox("panel", "Panel", _box(PANEL, LINE, 2, 14))
	# sliders
	var track := _box(Color("#2a2232"), LINE, 1, 6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _box(GOLD.darkened(0.4), GOLD.darkened(0.4), 0, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD, GOLD, 0, 6))
	t.set_stylebox("focus", "HSlider", focus)
	# scroll
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())
	t.set_color("font_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", 22)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", INK)
	_theme = t
	return t

static func _box(bg: Color, border: Color, bw: int, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

## a full-screen root for a screen, with the shared theme and an optional dim backdrop
static func screen(dim: float = 0.0) -> Control:
	var root := Control.new()
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	if dim > 0.0:
		var bg := ColorRect.new()
		bg.color = Color(BG, dim)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(bg)
	return root

static func label(text: String, size: int = 26, col: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	return l

## wrapped paragraph of a fixed width
static func para(text: String, size: int, col: Color, width: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, col, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

static func title(text: String, size: int = 56, col: Color = GOLD) -> Label:
	var l := label(text, size, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l

static func button(text: String, cb: Callable, min_w: float = 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 60)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", 1.0, -6.0))
	return b

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p

static func center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.add_child(c)
	return cc

static func tex(id: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Assets.tex(id)
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t

static func scroll(c: Control, min_size: Vector2) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = min_size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(c)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

static func bar(k: float, w: float, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 22)
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(Vector2(2, 2), Vector2((c.size.x - 4) * clampf(k, 0.0, 1.0), c.size.y - 4)), col))
	return c

## wires focus neighbours for a vertical list and focuses the first (or `focus_idx`)
static func chain_focus(items: Array, focus_idx: int = 0) -> void:
	for i in items.size():
		var c: Control = items[i]
		if i > 0:
			c.focus_neighbor_top = c.get_path_to(items[i - 1])
			c.focus_previous = c.focus_neighbor_top
		if i < items.size() - 1:
			c.focus_neighbor_bottom = c.get_path_to(items[i + 1])
			c.focus_next = c.focus_neighbor_bottom
	if not items.is_empty():
		var f: Control = items[clampi(focus_idx, 0, items.size() - 1)]
		f.call_deferred("grab_focus")
