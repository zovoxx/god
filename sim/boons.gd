class_name Boons
extends RefCounted
## Boon content access (data/boons.tres), offers, stacking and duo rules. Filled in phase 6.

const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := ["#d8d2e8", "#5db7ff", "#c07bff", "#ffb33d"]

static func def(id: String) -> Dictionary:
	if Cfg.B == null:
		return {}
	return Cfg.B.index().get(id, {})

static func color_of(id: String) -> Color:
	return Color.WHITE

static func slot_of(id: String) -> String:
	return String(def(id).get("slot", "passive"))

static func describe(id: String, rarity: int, level: int) -> String:
	return String(def(id).get("text", ""))

static func apply(st: Stats, owned: Dictionary) -> void:
	pass

static func hex_of(id: String) -> String:
	return "#ffffff"

static func offer(sim, patron: String, rarity_bonus: int, count: int = 3, rng: RandomNumberGenerator = null) -> Dictionary:
	return {}

static func grant(sim, id: String, rarity: int) -> void:
	pass

static func patron(id: String) -> Dictionary:
	if Cfg.B == null:
		return {}
	return Cfg.B.patrons.get(id, {})
