class_name Keepsakes
extends RefCounted
## Keepsakes: one is equipped per run (bought at the Wick). Data lives in tuning.meta.keepsakes.

static func all() -> Dictionary:
	return Cfg.T.meta.get("keepsakes", {})

static func apply(st: Stats, id: String) -> void:
	if id == "":
		return
	var k: Dictionary = all().get(id, {})
	for m in k.get("mods", []):
		st.apply_mod(String(m[0]), float(m[1]))
