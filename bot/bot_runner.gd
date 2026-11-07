extends Node
## Headless bot: plays full runs and reports crashes (engine/script errors), soft-locks,
## room times, damage sources and win rate.
##   godot --headless --path . -- --bot --runs=20 --weapon=all [--fresh] [--seed=N] [--max-minutes=40] [--out=path]
## By default the bot plays with a fully unlocked ("veteran") Wick; --fresh uses a new save.
## Exit code 1 if any run crashed or soft-locked.

class ErrorCounter extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		errors.append("%s:%d %s %s" % [file, line, code, rationale])

const DT := 1.0 / 60.0

var counter := ErrorCounter.new()
var runs := 20
var weapons: Array = []
var base_seed := 1000
var max_minutes := 40.0
var out_path := "user://bot_report.json"
var results: Array = []
var run_i := 0
var sim: Sim
var brain: BotBrain
var room_enter_t := 0.0
var last_room := -1
var stuck_t := 0.0
var nav_assists := 0
var errors_at_start := 0
var started_ms := 0
var boon_picks := {}

func _ready() -> void:
	OS.add_logger(counter)
	runs = int(App.arg("runs", 20))
	var w := String(App.arg("weapon", "all"))
	weapons = Weapons.IDS.duplicate() if w == "all" else [w]
	base_seed = int(App.arg("seed", 1000))
	max_minutes = float(App.arg("max-minutes", 40.0))
	out_path = String(App.arg("out", out_path))
	print("bot: %d runs, weapons %s, %s Wick" % [runs, weapons, "fresh" if App.arg("fresh") != null else "veteran"])
	started_ms = Time.get_ticks_msec()
	_start_run()

## a veteran Wick: everything unlocked so every system gets exercised
func _veteran_meta() -> Dictionary:
	var m := Meta.fresh()
	for u in Meta.unlock_defs():
		(m.unlocks as Array).append(u.id)
	m.mastery = {}
	for wid in Weapons.IDS:
		m.mastery[wid] = 400
	return m

func _start_run() -> void:
	var wid: String = weapons[run_i % weapons.size()]
	var seed_v := base_seed + run_i * 7919
	var m := Meta.fresh() if App.arg("fresh") != null else _veteran_meta()
	var o := Meta.run_options(m, {"weapon": wid})
	o.keepsake = ""
	sim = Sim.new(seed_v, null)
	var run := RunState.create(seed_v, wid, o)
	var flow := RoomFlow.new(sim, run)
	flow.start_run()
	brain = BotBrain.new(seed_v)
	last_room = -1
	room_enter_t = 0.0
	stuck_t = 0.0
	errors_at_start = counter.errors.size()

func _process(_d: float) -> void:
	var budget := Time.get_ticks_msec() + 40
	while Time.get_ticks_msec() < budget:
		if _tick():
			return

## one simulation step; returns true when all runs are finished
func _tick() -> bool:
	var run: RunState = sim.run
	var flow: RoomFlow = sim.flow
	var f = brain.think(sim)
	sim.step(f, DT)
	if run.room_index != last_room:
		if last_room >= 0:
			pass
		last_room = run.room_index
		room_enter_t = run.time
		stuck_t = 0.0
	# soft-lock detection: no room progress for too long, or doors that are never taken
	if flow.state == RoomFlow.S.DOORS or flow.state == RoomFlow.S.SPRING:
		stuck_t += DT
		if stuck_t > 10.0 and not flow.doors.is_empty() and flow.doors_lit >= flow.doors.size():
			nav_assists += 1
			flow.enter_door(maxi(0, brain.door_choice))
			stuck_t = 0.0
	var reason := ""
	if run.won:
		reason = "won"
	elif run.dead or flow.state == RoomFlow.S.DEAD:
		reason = "died"
	elif run.time - room_enter_t > 240.0:
		reason = "softlock"
	elif run.time > max_minutes * 60.0:
		reason = "timeout"
	elif counter.errors.size() > errors_at_start + 20:
		reason = "crash"
	if reason == "softlock" or reason == "timeout":
		var alive: Array = []
		for e in sim.enemies:
			if e.alive:
				alive.append("%s st=%d spawn=%.1f targ=%s inv=%s hid=%s pos=%s" % [e.kind, e.st, e.spawn_t, e.targetable(), e.invuln, e.data.get("hidden", false), e.pos.round()])
		print("   softlock diag: state=%s waves_done=%s idx=%d living=%d  %s" % [flow.state, flow.waves.done, flow.waves.index, sim.living_enemies(), alive])
	if reason != "":
		_finish_run(reason)
		run_i += 1
		if run_i >= runs:
			_report()
			return true
		_start_run()
	return false

func _finish_run(reason: String) -> void:
	var run: RunState = sim.run
	for b in run.boons:
		boon_picks[b.id] = int(boon_picks.get(b.id, 0)) + 1
	var errs := counter.errors.slice(errors_at_start)
	var times: Array = run.room_times
	var avg := 0.0
	var mx := 0.0
	for x in times:
		avg += float(x)
		mx = maxf(mx, float(x))
	if not times.is_empty():
		avg /= times.size()
	var r := {
		"run": run_i + 1, "weapon": run.weapon, "seed": run.seed, "result": reason,
		"depth": run.depth, "step": run.step, "rooms": run.room_index + 1, "cleared": run.rooms_cleared,
		"time": snappedf(run.time, 0.1), "kills": run.kills, "dmg_taken": int(run.dmg_taken), "dmg_dealt": int(run.stats_dmg_dealt),
		"avg_room": snappedf(avg, 0.1), "max_room": snappedf(mx, 0.1), "killer": String(run.killer.get("source", "")) + " / " + String(run.killer.get("attack", "")),
		"dmg_by_source": run.dmg_by_source, "boons": run.boons.size(), "errors": errs.size(), "error_samples": errs.slice(0, 3),
		"perfect": run.perfect_dashes, "counters": run.counters, "finishers": run.finishers, "defiance_used": run.flags.get("defied", false),
	}
	results.append(r)
	print("bot run %2d  %-6s %-8s depth %d room %2d  %5.0fs  kills %3d  taken %4d  avg room %4.1fs  %s%s" % [r.run, r.weapon, reason, r.depth, r.rooms, r.time, r.kills, r.dmg_taken, r.avg_room,
		("killed by " + r.killer) if reason == "died" else "", ("  ERRORS: %d" % errs.size()) if not errs.is_empty() else ""])
	for e in errs.slice(0, 3):
		print("      ", e)

func _report() -> void:
	var wins := 0
	var crashes := 0
	var softlocks := 0
	var killers := {}
	var sources := {}
	var depth_reached := [0, 0, 0, 0, 0]
	var by_weapon := {}
	var total_room := 0.0
	var n_rooms := 0
	for r in results:
		if r.result == "won":
			wins += 1
		if r.result == "crash" or int(r.errors) > 0:
			crashes += 1
		if r.result == "softlock" or r.result == "timeout":
			softlocks += 1
		if r.result == "died":
			killers[r.killer] = int(killers.get(r.killer, 0)) + 1
		for s in r.dmg_by_source.keys():
			sources[s] = float(sources.get(s, 0.0)) + float(r.dmg_by_source[s])
		depth_reached[clampi(int(r.depth), 0, 4)] += 1
		var bw: Dictionary = by_weapon.get(r.weapon, {"runs": 0, "wins": 0, "depth": 0.0})
		bw.runs += 1
		bw.wins += 1 if r.result == "won" else 0
		bw.depth += float(r.depth) + float(r.step) / 6.0
		by_weapon[r.weapon] = bw
		total_room += float(r.avg_room) * float(r.cleared)
		n_rooms += int(r.cleared)
	print("")
	print("══════════ BOT REPORT ══════════")
	print("runs %d   wins %d (%.0f%%)   crashes %d   soft-locks %d   nav assists %d   wall time %.1fs" % [results.size(), wins, 100.0 * wins / maxf(1, results.size()), crashes, softlocks, nav_assists, (Time.get_ticks_msec() - started_ms) / 1000.0])
	print("average room time %.1fs over %d rooms" % [total_room / maxf(1, n_rooms), n_rooms])
	print("runs ending in depth 1..4: %s" % [depth_reached.slice(1)])
	for w in by_weapon.keys():
		var bw: Dictionary = by_weapon[w]
		print("  %-6s runs %d  wins %d  avg progress %.2f depths" % [w, bw.runs, bw.wins, bw.depth / bw.runs])
	var ks := killers.keys()
	ks.sort_custom(func(a, b): return killers[a] > killers[b])
	print("top killers: ", ", ".join(ks.slice(0, 6).map(func(k): return "%s ×%d" % [k, killers[k]])))
	var ss := sources.keys()
	ss.sort_custom(func(a, b): return sources[a] > sources[b])
	print("damage taken by source: ", ", ".join(ss.slice(0, 8).map(func(k): return "%s %d" % [k, int(sources[k])])))
	var report := {"runs": results, "wins": wins, "crashes": crashes, "softlocks": softlocks, "killers": killers, "sources": sources, "by_weapon": by_weapon, "boon_picks": boon_picks}
	SaveIO.write_json(out_path, report)
	print("report written to ", ProjectSettings.globalize_path(out_path))
	var ok := crashes == 0 and softlocks == 0
	print("bot: %s" % ("OK — no crashes, no soft-locks" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
