extends Node
## Application state: settings, command-line flags, persistent meta progress and screen routing.

const SETTINGS_PATH := "user://settings.json"

var settings := {}
var args := {}
var headless := false
var main = null              # scenes/main.gd registers itself
var meta: Dictionary = {}    # persistent progress (see sim/meta.gd)
var debug := {"hitboxes": false, "ai": false, "tele": false}

func default_settings() -> Dictionary:
	return {
		"master": 0.8, "music": 0.5, "sfx": 0.9,
		"shake": 1.0, "hitstop": 1.0, "flashes": 1.0, "numbers_scale": 1.0,
		"numbers_on": true, "reduce_flashing": false, "colorblind": false,
		"aim_mode": "auto", "graphics": "medium", "fullscreen": false,
		"bindings": {},
	}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	headless = DisplayServer.get_name() == "headless"
	_parse_args()
	settings = default_settings()
	var loaded = SaveIO.read_json(SETTINGS_PATH)
	if loaded is Dictionary:
		for k in loaded.keys():
			settings[k] = loaded[k]
	Controls.install(settings.get("bindings", {}))
	apply_settings()
	meta = Meta.load_meta()

func _parse_args() -> void:
	var all := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in all:
		if a.begins_with("--"):
			var s: String = a.substr(2)
			var i := s.find("=")
			if i >= 0:
				args[s.substr(0, i)] = s.substr(i + 1)
			else:
				args[s] = true

func arg(name: String, default = null):
	return args.get(name, default)

func apply_settings() -> void:
	Cfg.shake_mul = float(settings.shake)
	Cfg.hitstop_mul = float(settings.hitstop)
	Cfg.flash_mul = float(settings.flashes) * (0.35 if settings.reduce_flashing else 1.0)
	Cfg.numbers_mul = float(settings.numbers_scale)
	Cfg.numbers_on = bool(settings.numbers_on)
	Cfg.reduce_flashing = bool(settings.reduce_flashing)
	Cfg.set_colorblind(bool(settings.colorblind))
	if not headless:
		var fs: bool = settings.fullscreen
		var mode := DisplayServer.window_get_mode()
		var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if fs != is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	Audio.apply_volumes(settings)
	Bus.fire(&"settings_changed", settings)

func save_settings() -> void:
	settings.bindings = Controls.current_overrides()
	SaveIO.write_json(SETTINGS_PATH, settings)

func save_meta() -> void:
	Meta.save_meta(meta)

func _input(ev: InputEvent) -> void:
	if ev.is_action_pressed("fullscreen"):
		settings.fullscreen = not bool(settings.fullscreen)
		apply_settings()
		save_settings()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if main != null and main.has_method("on_quit"):
			main.on_quit()
		save_meta()
		save_settings()
