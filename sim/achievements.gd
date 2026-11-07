class_name Achievements
extends RefCounted
## 30 achievements. `check` evaluates them against meta + the current run and returns the
## newly earned ones (the presentation shows a toast for each).

const LIST := [
	["first_blood", "First Spark", "Defeat your first enemy."],
	["first_room", "Through the Door", "Clear your first room."],
	["depth2", "Into the Archive", "Reach the Drowned Archive."],
	["depth3", "Into the Foundry", "Reach the Clockwork Foundry."],
	["depth4", "Into the Crown", "Reach the Starless Crown."],
	["boss_stag", "Antlers Doused", "Defeat Ashenhart, the Cinder Stag."],
	["boss_archivist", "Last Page", "Defeat Velloran, the Drowned Archivist."],
	["boss_engine", "Engine Stopped", "Defeat the Engine Tyrant."],
	["boss_regent", "Sunrise", "Defeat the Pale Regent."],
	["victory", "Lantern Heart", "Win a run."],
	["three_weapons", "Many Flames", "Win with three different weapons."],
	["perfect10", "Untouchable", "10 perfect dashes in a single run."],
	["counter10", "Clang!", "10 counters in a single run."],
	["finisher25", "Executioner", "25 finishers in total."],
	["supernova", "Supernova", "Reach a SUPERNOVA kill streak."],
	["synergy50", "Harmony", "Trigger 50 synergies in total."],
	["legendary", "Legend", "Take a legendary boon."],
	["duo", "Concordant", "Take a duo boon."],
	["rich", "Moth Hoard", "Hold 300 gold at once."],
	["untouched", "Flawless Guardian", "Defeat a guardian without taking damage."],
	["speedrun", "Quickfire", "Win a run in under 25 minutes."],
	["kills1000", "Thousand Embers", "Defeat 1000 enemies in total."],
	["all_lights", "Every Star", "Take boons from all eight Lights."],
	["deepening", "Going Deeper", "Unlock Deepening I."],
	["heat_win", "Kindled", "Win a run with Kindling Heat."],
	["vows3", "Oathkeeper", "Complete three Vows in one run."],
	["mastery3", "Practised Hand", "Reach mastery 3 with any weapon."],
	["bestiary30", "Naturalist", "Record 30 creatures in the bestiary."],
	["defied", "Not Yet", "Survive with a Death Defiance."],
	["daily", "Daily Ritual", "Complete a Daily Descent."],
]

static func info(id: String) -> Dictionary:
	for a in LIST:
		if a[0] == id:
			return {"id": a[0], "name": a[1], "desc": a[2]}
	return {}

static func _ok(id: String, m: Dictionary, run: RunState) -> bool:
	var tot: Dictionary = m.get("totals", {})
	var r := run != null
	match id:
		"first_blood": return int(tot.get("kills", 0)) >= 1 or (r and run.kills >= 1)
		"first_room": return int(m.get("deepest", 0)) >= 1 or (r and run.rooms_cleared >= 1)
		"depth2": return int(m.get("deepest", 0)) >= 6 or (r and run.depth >= 2)
		"depth3": return int(m.get("deepest", 0)) >= 12 or (r and run.depth >= 3)
		"depth4": return int(m.get("deepest", 0)) >= 18 or (r and run.depth >= 4)
		"boss_stag", "boss_archivist", "boss_engine", "boss_regent":
			return int((m.get("boss_kills", {}) as Dictionary).get(id, 0)) >= 1 or (r and run.bosses_killed.has(id))
		"victory": return int(m.get("wins", 0)) >= 1
		"three_weapons": return (m.get("wins_by_weapon", {}) as Dictionary).size() >= 3
		"perfect10": return r and run.perfect_dashes >= 10
		"counter10": return r and run.counters >= 10
		"finisher25": return int(tot.get("finishers", 0)) >= 25
		"supernova": return r and run.best_streak >= int(Cfg.F.streak.tiers[3])
		"synergy50": return int(tot.get("synergies", 0)) >= 50
		"legendary": return r and run.flags.get("legendary", false)
		"duo": return r and run.flags.get("duo", false)
		"rich": return r and int(run.flags.get("max_gold", 0)) >= 300
		"untouched": return r and run.flags.get("guardian_untouched", false)
		"speedrun": return r and run.won and run.time < 1500.0
		"kills1000": return int(tot.get("kills", 0)) >= 1000
		"all_lights": return (m.get("lights_taken", []) as Array).size() >= 8
		"deepening": return Meta.has(m, "deep1")
		"heat_win": return r and run.won and run.heat > 0
		"vows3": return r and run.vows.size() >= 3 and run.vows.all(func(v): return Meta.vow_met(v, run))
		"mastery3":
			for w in Weapons.IDS:
				if Meta.mastery_level(m, w) >= 3:
					return true
			return false
		"bestiary30": return (m.get("bestiary", {}) as Dictionary).size() >= 30
		"defied": return r and run.flags.get("defied", false) and not run.dead
		"daily": return int(m.get("dailies", 0)) >= 1
	return false

## evaluates all achievements; records and returns the new ones
static func check(m: Dictionary, run: RunState) -> Array:
	var have: Array = m.get("achievements", [])
	var out: Array = []
	for a in LIST:
		if have.has(a[0]):
			continue
		if _ok(a[0], m, run):
			have.append(a[0])
			out.append({"id": a[0], "name": a[1], "desc": a[2]})
	m.achievements = have
	return out
