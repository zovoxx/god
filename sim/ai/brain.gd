class_name Brain
extends RefCounted
## Base class for enemy AI. Subclasses override update(); helpers live in AI.

func init(sim, e: SimEnemy) -> void:
	pass

func update(sim, e: SimEnemy, dt: float) -> void:
	pass

## return true to cancel the hit entirely (dodges, parries)
func on_hit(sim, e: SimEnemy, h: HitInfo) -> bool:
	return false

func on_death(sim, e: SimEnemy) -> void:
	pass
