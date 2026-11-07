extends SceneTree
## Loads every script, scene, shader and resource in the project and reports any error.
## Usage: godot --headless --path . -s tools/check_all.gd     (exit code 1 on any error)

class ErrorCounter extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		if error and (message.contains("ERROR") or message.contains("Parse Error")):
			errors.append(message.strip_edges())

var counter := ErrorCounter.new()

func _initialize() -> void:
	OS.add_logger(counter)
	var files: Array = []
	_walk("res://", files)
	var n := 0
	for f in files:
		var ext: String = f.get_extension()
		if ext in ["gd", "tscn", "tres", "gdshader"]:
			var before := counter.errors.size()
			var r = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_REUSE)
			n += 1
			if r == null:
				counter.errors.append("failed to load " + f)
			elif r is GDScript and not r.can_instantiate() and not _is_abstract(r):
				counter.errors.append("script cannot instantiate: " + f)
			elif r is PackedScene:
				var inst = r.instantiate()
				if inst == null:
					counter.errors.append("scene cannot instantiate: " + f)
				else:
					inst.free()
			if counter.errors.size() > before:
				print("  ✗ ", f)
	# sanity: tuning resources have content
	var T = load("res://data/tuning.tres")
	if T == null or T.player.is_empty() or T.weapons.is_empty():
		counter.errors.append("tuning.tres is empty or invalid")
	var F = load("res://data/game_feel.tres")
	if F == null or F.hitstop.is_empty():
		counter.errors.append("game_feel.tres is empty or invalid")
	print("check_all: loaded %d files" % n)
	if counter.errors.is_empty():
		print("check_all: 0 errors")
		quit(0)
	else:
		for e in counter.errors:
			print("ERROR: ", e)
		print("check_all: %d errors" % counter.errors.size())
		quit(1)

func _is_abstract(s: GDScript) -> bool:
	return false

func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var path := dir.path_join(name)
		if d.current_is_dir():
			if name not in ["build", "addons"]:
				_walk(path, out)
		else:
			out.append(path)
		name = d.get_next()
	d.list_dir_end()
