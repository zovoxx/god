class_name Recap
extends RefCounted
## Builds the data shown on the death recap card and the pause damage log.

static func tip_for(sim, kind: String) -> String:
	if sim.T.enemies.has(kind):
		return String(sim.T.enemies[kind].get("tip", ""))
	if sim.T.bosses.has(kind):
		return String(sim.T.bosses[kind].get("tip", ""))
	return "Floor hazards pulse twice before they hurt. Step off when they start to glow."

static func build(sim) -> Dictionary:
	var log: Array = sim.damage_log
	var killer: Dictionary = log[-1] if not log.is_empty() else {"source": "The Dark", "kind": "", "attack": "", "dmg": 0, "art": "wren"}
	var last: Array = log.slice(maxi(0, log.size() - 5))
	last.reverse()
	var d := {
		"killer": killer,
		"last_hits": last,
		"tip": tip_for(sim, String(killer.get("kind", ""))),
		"weapon": sim.weapon.display_name() if sim.weapon != null else "",
		"weapon_id": sim.weapon.id if sim.weapon != null else "",
		"boons": [],
		"embers": 0,
		"depth": 1,
		"room": 0,
	}
	if sim.run != null:
		d.boons = sim.run.boon_names()
		d.embers = sim.run.embers
		d.depth = sim.run.depth
		d.room = sim.run.room_index
	return d

static func damage_log(sim, n: int = 10) -> Array:
	var log: Array = sim.damage_log
	var out: Array = log.slice(maxi(0, log.size() - n))
	out.reverse()
	return out
