extends SceneTree
## Headless test runner. Discovers tests/test_*.gd suites and runs every `test_*` method.
## Prints PASS/FAIL per test and exits with code 1 on any failure.
## Usage: godot --headless --path . -s tests/run_tests.gd [-- --filter=name]

var failures := 0
var passes := 0

func _initialize() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var suites: Array = []
	var d := DirAccess.open("res://tests")
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			suites.append("res://tests/" + f)
	suites.sort()
	for path in suites:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL  could not load ", path)
			failures += 1
			continue
		var methods: Array = []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_") and not methods.has(m.name):
				methods.append(m.name)
		for m in methods:
			if filter != "" and not String(m).contains(filter) and not path.contains(filter):
				continue
			var suite = script.new()
			suite.T = root.get_node("Cfg").T
			suite.F = root.get_node("Cfg").F
			suite.current = "%s::%s" % [path.get_file().get_basename(), m]
			suite.call(m)
			if suite.failed.is_empty():
				passes += 1
				print("PASS  ", suite.current)
			else:
				failures += 1
				print("FAIL  ", suite.current)
				for msg in suite.failed:
					print("        ", msg)
	print("")
	print("%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
