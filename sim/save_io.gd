class_name SaveIO
extends RefCounted
## JSON helpers for user:// saves. Writes go through a temp file + rename so a crash never
## leaves a half-written save behind.

static func read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(txt) != OK:
		push_warning("save: could not parse %s" % path)
		return null
	return j.data

static func write_json(path: String, data) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK

static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
