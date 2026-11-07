class_name Controls
extends RefCounted
## Default bindings, rebinding and (de)serialisation of InputMap events.

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack", "special", "dash", "cast", "pause",
	"aim_left", "aim_right", "aim_up", "aim_down", "debug", "fullscreen"]
const REBINDABLE := ["move_up", "move_down", "move_left", "move_right", "attack", "special", "dash", "cast", "pause"]
const LABELS := {"move_up": "Move up", "move_down": "Move down", "move_left": "Move left", "move_right": "Move right",
	"attack": "Attack", "special": "Special", "dash": "Dash", "cast": "Sigil", "pause": "Pause"}

static func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e

static func _mouse(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	return e

static func _joy(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e

static func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e

static func defaults() -> Dictionary:
	return {
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _joy(JOY_BUTTON_DPAD_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _joy(JOY_BUTTON_DPAD_RIGHT)],
		"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _joy(JOY_BUTTON_DPAD_UP)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _joy(JOY_BUTTON_DPAD_DOWN)],
		"attack": [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J), _joy(JOY_BUTTON_A), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"special": [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K), _joy(JOY_BUTTON_X), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		"dash": [_key(KEY_SPACE), _key(KEY_SHIFT), _joy(JOY_BUTTON_B), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		"cast": [_key(KEY_Q), _key(KEY_E), _joy(JOY_BUTTON_Y), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"pause": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
		"aim_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		"aim_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"debug": [_key(KEY_F1)],
		"fullscreen": [_key(KEY_F11)],
	}

## installs defaults, then applies saved overrides {action: [serialised events]}
static func install(overrides: Dictionary) -> void:
	var defs := defaults()
	for a in ACTIONS:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
		InputMap.add_action(a, 0.25 if a.begins_with("aim") else 0.2)
		var evs: Array = defs[a]
		if overrides.has(a):
			evs = []
			for d in overrides[a]:
				var ev := deserialize(d)
				if ev != null:
					evs.append(ev)
		for ev in evs:
			InputMap.action_add_event(a, ev)
	# menus: let gamepad A/B and keyboard confirm work with ui_accept / ui_cancel
	_ensure("ui_accept", _joy(JOY_BUTTON_A))
	_ensure("ui_cancel", _joy(JOY_BUTTON_B))

static func _ensure(action: String, ev: InputEvent) -> void:
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton and ev is InputEventJoypadButton and e.button_index == ev.button_index:
				return
		InputMap.action_add_event(action, ev)

static func serialize(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"t": "key", "k": int(ev.physical_keycode)}
	if ev is InputEventMouseButton:
		return {"t": "mouse", "b": int(ev.button_index)}
	if ev is InputEventJoypadButton:
		return {"t": "joy", "b": int(ev.button_index)}
	if ev is InputEventJoypadMotion:
		return {"t": "axis", "a": int(ev.axis), "v": signf(ev.axis_value)}
	return {}

static func deserialize(d: Dictionary) -> InputEvent:
	match String(d.get("t", "")):
		"key": return _key(int(d.k))
		"mouse": return _mouse(int(d.b))
		"joy": return _joy(int(d.b))
		"axis": return _axis(int(d.a), float(d.v))
	return null

static func current_overrides() -> Dictionary:
	var out := {}
	for a in REBINDABLE:
		var arr: Array = []
		for ev in InputMap.action_get_events(a):
			arr.append(serialize(ev))
		out[a] = arr
	return out

static func is_pad(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion

## replaces the keyboard/mouse (pad=false) or gamepad (pad=true) binding of an action
static func rebind(action: String, ev: InputEvent) -> void:
	var pad := is_pad(ev)
	var keep: Array = []
	for e in InputMap.action_get_events(action):
		if is_pad(e) != pad:
			keep.append(e)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	for e in keep:
		InputMap.action_add_event(action, e)

static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.physical_keycode)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "Left click"
			MOUSE_BUTTON_RIGHT: return "Right click"
			MOUSE_BUTTON_MIDDLE: return "Middle click"
		return "Mouse %d" % ev.button_index
	if ev is InputEventJoypadButton:
		var names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
			JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back", JOY_BUTTON_DPAD_UP: "D-pad up",
			JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"}
		return names.get(ev.button_index, "Pad %d" % ev.button_index)
	if ev is InputEventJoypadMotion:
		match ev.axis:
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
			JOY_AXIS_LEFT_X: return "Left stick " + ("right" if ev.axis_value > 0 else "left")
			JOY_AXIS_LEFT_Y: return "Left stick " + ("down" if ev.axis_value > 0 else "up")
		return "Axis %d" % ev.axis
	return "?"

static func labels_for(action: String, pad: bool) -> String:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		if is_pad(e) == pad:
			out.append(event_label(e))
	return " / ".join(out)
