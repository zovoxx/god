class_name BoonData
extends Resource
## Patron Lights, their boons and the duo boons. Values live in res://data/boons.tres.
## Boon effects are data: `infuse` slot boons set the slot's element, `mods` entries are
## [stat_key, value_index] or [stat_key, "c", constant] applied through Stats.apply_mod.

@export var patrons: Dictionary
@export var order: Array
@export var boons: Array
@export var rarity: Dictionary

var _index := {}

func index() -> Dictionary:
	if _index.is_empty():
		for b in boons:
			_index[b.id] = b
	return _index
