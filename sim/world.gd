class_name World
extends RefCounted
## Per-step update of everything in the arena except the player's own controller.

static func update(sim, dt: float) -> void:
	Enemies.update_all(sim, dt)
	Projectiles.update_all(sim, dt)
	Hazards.update_all(sim, dt)
	Tele.update_all(sim, dt)
	Pickups.update_all(sim, dt)
	Combat.streak_tick(sim, dt)
	Combat.overdrive_tick(sim, dt)
	BoonFx.tick(sim, dt)
	if sim.weapon != null:
		sim.weapon.passive_tick(sim, sim.player, dt)
	Enemies.cleanup(sim)
