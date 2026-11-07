extends Control
## Choice screen for boons, forges, kindling, hearts, gold and ordeal prompts. Cards flip in
## one by one with rarity-specific glow and sound, show exact before/after numbers, and can be
## rerolled (Moth Wing) or re-rolled with +1 rarity (Fate Die). Full keyboard/gamepad support.

signal picked(i: int)
signal reroll_requested(fate: bool)

var offer := {}
var run: RunState
var cards: Array = []
var _t := 0.0
var _concord := false

func setup(o: Dictionary, r: RunState) -> void:
	offer = o
	run = r

func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var head_col := Color.html(String(offer.get("color", "#ffc94a")))
	var pat := String(offer.get("patron", ""))
	var head := UI.hbox(20)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	if pat != "":
		head.add_child(UI.tex("p_" + pat, Vector2(110, 110)))
	var hv := UI.vbox(4)
	hv.add_child(UI.title(String(offer.get("title", "")), 52, head_col))
	var sub := UI.label(String(offer.get("subtitle", "")), 26, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	hv.add_child(sub)
	head.add_child(hv)
	v.add_child(head)
	var row := UI.hbox(26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var opts: Array = offer.get("options", [])
	for i in opts.size():
		var c := _card(opts[i], i)
		row.add_child(c)
		cards.append(c)
		if opts[i].get("duo", false):
			_concord = true
	# reroll row
	var rr := UI.hbox(18)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(rr)
	var extra: Array = []
	if offer.get("rerollable", false) and run != null:
		var b1 := UI.button("Reroll  (%d)" % run.rerolls, func(): reroll_requested.emit(false), 260)
		b1.disabled = run.rerolls <= 0
		rr.add_child(b1)
		extra.append(b1)
		var b2 := UI.button("Fate Die  (%d)" % run.fate_dice, func(): reroll_requested.emit(true), 260)
		b2.disabled = run.fate_dice <= 0
		rr.add_child(b2)
		extra.append(b2)
	add_child(UI.center(v))
	# focus: left/right between cards, down to reroll buttons
	for i in cards.size():
		var c: Control = cards[i]
		if i > 0:
			c.focus_neighbor_left = c.get_path_to(cards[i - 1])
		if i < cards.size() - 1:
			c.focus_neighbor_right = c.get_path_to(cards[i + 1])
		if not extra.is_empty():
			c.focus_neighbor_bottom = c.get_path_to(extra[0])
	for b in extra:
		if not cards.is_empty():
			b.focus_neighbor_top = b.get_path_to(cards[0])
	if not cards.is_empty():
		cards[0].call_deferred("grab_focus")
	# flip-in
	for i in cards.size():
		var c2: Control = cards[i]
		c2.pivot_offset = c2.custom_minimum_size * 0.5
		c2.scale = Vector2(0.0, 1.0)
		var tw := create_tween()
		tw.tween_interval(0.08 + i * 0.12)
		tw.tween_callback(func(): Audio.play("card_" + Boons.RARITY_NAMES[clampi(int(opts[i].get("rarity", 0)), 0, 3)].to_lower()))
		tw.tween_property(c2, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c2, "scale", Vector2.ONE, 0.08)
	if _concord:
		Audio.play("concord")
		Bus.fire(&"banner", {"text": "CONCORD", "sub": "two Lights shine together", "col": Color("#ffe6a0"), "life": 1.4, "big": false})

func _card(o: Dictionary, i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 470)
	b.focus_mode = Control.FOCUS_ALL
	b.text = ""
	var rar := clampi(int(o.get("rarity", 0)), 0, 3)
	var rcol := Color.html(Boons.RARITY_COLORS[rar])
	var col := Color.html(String(o.get("color", "#ffffff")))
	var normal := StyleBoxFlat.new()
	normal.bg_color = UI.PANEL2
	normal.border_color = rcol.darkened(0.2)
	normal.set_border_width_all(3 + rar)
	normal.set_corner_radius_all(16)
	normal.shadow_color = Color(rcol, 0.25 + 0.12 * rar)
	normal.shadow_size = 6 + rar * 6
	var hover := normal.duplicate()
	hover.bg_color = Color("#2c2238")
	hover.border_color = UI.GOLD
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var v := UI.vbox(8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.offset_top = 18
	v.offset_bottom = -18
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tag := UI.label(String(o.get("tag", "")), 18, rcol)
	v.add_child(tag)
	var ic := UI.tex(String(o.get("icon", "i_slot_passive")), Vector2(64, 64))
	ic.modulate = col if String(o.get("icon", "")).begins_with("i_slot") else Color.WHITE
	v.add_child(ic)
	v.add_child(UI.label(String(o.get("name", "")), 30, col.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER))
	var desc := UI.label(String(o.get("desc", "")), 21, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	desc.custom_minimum_size = Vector2(350, 0)
	v.add_child(desc)
	if o.has("before") and o.has("after") and String(o.before) != String(o.after):
		v.add_child(UI.label("NOW", 15, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var bl := UI.label(String(o.before), 17, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		bl.custom_minimum_size = Vector2(350, 0)
		v.add_child(bl)
		v.add_child(UI.label("AFTER", 15, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var al := UI.label(String(o.after), 17, Color("#bfffd0"), HORIZONTAL_ALIGNMENT_CENTER)
		al.custom_minimum_size = Vector2(350, 0)
		v.add_child(al)
	for c in v.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func():
		Audio.play("ui_pick")
		picked.emit(i))
	b.focus_entered.connect(func(): Audio.play("ui_move", 1.0 + i * 0.05, -6.0))
	return b

func _process(delta: float) -> void:
	_t += delta
