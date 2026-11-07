class_name Brains
extends RefCounted
## Registry of AI brains by enemy/boss id.

static func all() -> Dictionary:
	var d := {}
	d["_default"] = Brain.new()
	d["dummy"] = DummyBrain.new()
	d["dummy_walker"] = DummyBrain.new()
	for mod in _modules():
		var m: Dictionary = mod.brains()
		for k in m.keys():
			d[k] = m[k]
	return d

static func _modules() -> Array:
	return [AITraining]

class DummyBrain extends Brain:
	func update(sim, e: SimEnemy, dt: float) -> void:
		var regen: float = e.def.get("regen", 0.0)
		if sim.time - e.last_hit_t > 2.0:
			e.hp = minf(e.max_hp, e.hp + regen * dt)
		if e.speed > 0.0:
			if e.cd <= 0.0 or e.pos.distance_to(e.target_pos) < 20.0:
				e.target_pos = sim.random_free_point(60, 260, e.pos, e.radius)
				e.cd = 3.0
			e.cd -= dt
			AI.move_to(sim, e, e.target_pos, e.move_speed(), dt)
		else:
			e.vel = Vector2.ZERO
