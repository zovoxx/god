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

## options for a new run from meta progress (expanded in phase 8)
static func run_options(m: Dictionary, opts: Dictionary) -> Dictionary:
	var o := {"weapon": opts.get("weapon", ""), "depth": opts.get("depth", 1), "daily": opts.get("daily", false)}
	if String(o.weapon) == "":
		o.weapon = String(m.get("last_weapon", "fangs"))
	return o

## applies the end of a run to meta progress; returns data for the recap/summary
static func end_run(m: Dictionary, run: RunState, d: Dictionary) -> Dictionary:
	m.runs = int(m.get("runs", 0)) + 1
	m.embers = int(m.get("embers", 0)) + run.embers
	m.total_embers = int(m.get("total_embers", 0)) + run.embers
	if d.won:
		m.wins = int(m.get("wins", 0)) + 1
	else:
		m.deaths = int(m.get("deaths", 0)) + 1
	return {"embers": run.embers, "ending": ["The Lantern Heart burns again."]}
