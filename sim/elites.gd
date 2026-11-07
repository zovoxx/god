class_name Elites
extends RefCounted
## Combinable elite modifiers (filled in phase 4).

static func apply(sim, e: SimEnemy, mods: Array) -> void:
	e.elites = mods.duplicate()

static func update(sim, e: SimEnemy, dt: float) -> void:
	pass

static func on_death(sim, e: SimEnemy) -> void:
	pass
