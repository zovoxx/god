class_name AITraining
extends RefCounted
## The Sparring Effigy: a training enemy that cycles every telegraph shape.

static func brains() -> Dictionary:
	return {"effigy": Effigy.new()}

class Effigy extends Brain:
	func init(sim, e: SimEnemy) -> void:
		e.cd = 1.0
	func update(sim, e: SimEnemy, dt: float) -> void:
		var D: Dictionary = e.def
		AI.face(e, AI.angle_to_player(sim, e), 6.0, dt)
		if e.tele != null:
			AI.stop(e, dt)
			return
		e.cd -= dt
		if AI.dist(sim, e) > 220.0:
			AI.chase(sim, e, dt)
		else:
			AI.stop(e, dt)
		if e.cd > 0.0:
			return
		var dmg: float = float(D.dmg) * e.dmg_mul
		var w: float = D.windup
		var n: int = int(e.data.get("n", 0))
		e.data["n"] = n + 1
		match n % 5:
			0:
				e.tele = AI.tele_circle(sim, e, sim.player.pos, 80.0, w, dmg, "Slam")
			1:
				e.tele = AI.tele_cone(sim, e, AI.angle_to_player(sim, e), 210.0, 90.0, w, dmg, "Sweep")
			2:
				var ang := AI.angle_to_player(sim, e)
				e.tele = AI.tele_line(sim, e, ang, 420.0, 50.0, w, dmg, "Lance")
			3:
				e.tele = AI.tele_ring(sim, e, e.pos, 90.0, 230.0, w, dmg, "Shockwave")
				e.tele.follow = false
			4:
				var a2 := AI.angle_to_player(sim, e)
				e.tele = AI.tele_aim(sim, e, a2, 600.0, 16.0, w, "Bolt", func():
					for i in 3:
						AI.shoot(sim, e, e.pos, a2 + (i - 1) * 0.18, 420.0, dmg, "Bolt"))
		e.cd = 1.3
