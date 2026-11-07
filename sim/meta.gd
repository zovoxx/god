class_name Meta
extends RefCounted
## Persistent progress (The Wick). Expanded in phase 8.

const PATH := "user://meta.json"

static func fresh() -> Dictionary:
	return {"version": 1, "embers": 0, "total_embers": 0, "unlocks": [], "runs": 0, "wins": 0, "deaths": 0}

static func load_meta() -> Dictionary:
	var m := fresh()
	var d = SaveIO.read_json(PATH)
	if d is Dictionary:
		for k in d.keys():
			m[k] = d[k]
	return m

static func save_meta(m: Dictionary) -> void:
	SaveIO.write_json(PATH, m)
