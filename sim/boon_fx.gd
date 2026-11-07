class_name BoonFx
extends RefCounted
## Unique boon mechanics hooked into the combat pipeline (filled in phase 6).

static func on_hit(sim, e: SimEnemy, h: HitInfo, dealt: float, crit: bool, first_hit: bool) -> void:
	pass
static func on_kill(sim, e: SimEnemy, h: HitInfo) -> void:
	pass
static func on_freeze(sim, e: SimEnemy) -> void:
	pass
static func on_bleed_burst(sim, e: SimEnemy, stacks: float) -> void:
	pass
static func on_jolt(sim, struck: Dictionary) -> void:
	pass
static func on_slam(sim, e: SimEnemy) -> void:
	pass
static func on_player_hurt(sim, source, dmg: float) -> void:
	pass
static func on_dash_start(sim) -> void:
	pass
static func on_dash_through(sim, e: SimEnemy) -> void:
	pass
static func on_dash_end(sim) -> void:
	pass
static func on_cast(sim, at: Vector2, hz: SimHazard) -> void:
	pass
static func tick(sim, dt: float) -> void:
	pass
