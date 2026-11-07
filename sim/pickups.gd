class_name Pickups
extends RefCounted
## Pickup spawning and collection. On room clear everything flies to the player.

static func spawn(sim, kind: String, pos: Vector2, value: float, data: Dictionary = {}) -> SimPickup:
	var pk := SimPickup.new()
	pk.id = sim.new_id()
	pk.kind = kind
	pk.pos = pos
	pk.prev = pos
	pk.value = value
	pk.data = data
	pk.radius = 10.0
	var a = sim.rng.randf() * TAU
	pk.vel = Geom.dir(a) * sim.rng.randf_range(80, 220)
	sim.pickups.append(pk)
	return pk

static func drop_gold(sim, pos: Vector2, amount: int) -> void:
	var coins := clampi(int(ceil(amount / 3.0)), 1, 8)
	var left := amount
	for i in coins:
		var v := int(ceil(float(left) / float(coins - i)))
		left -= v
		spawn(sim, "gold", pos, v)

static func magnet_all(sim) -> void:
	for pk in sim.pickups:
		pk.magnet = true

static func update_all(sim, dt: float) -> void:
	var p: SimPlayer = sim.player
	var RC: Dictionary = sim.F.room_clear
	var keep: Array = []
	for pk in sim.pickups:
		pk.prev = pk.pos
		pk.t += dt
		var to = p.pos - pk.pos
		var d = to.length()
		var pull_r := 70.0 if pk.kind != "reward" else 0.0
		if pk.kind == "orb":
			pull_r = 110.0
		if pk.magnet or d < pull_r:
			var spd := minf(float(RC.magnet_speed) + pk.t * float(RC.magnet_accel), 2400.0)
			pk.vel = pk.vel.lerp(to.normalized() * spd, clampf(dt * 10.0, 0.0, 1.0))
		else:
			pk.vel *= exp(-6.0 * dt)
		var step_len: float = pk.vel.length() * dt
		if pk.magnet and step_len >= d:
			pk.pos = p.pos
		else:
			pk.pos += pk.vel * dt
		sim.collide_arena(pk, pk.radius)
		if (d < p.radius + pk.radius + 4.0 or (pk.magnet and step_len >= d)) and pk.t > 0.15 and p.state != SimPlayer.St.DEAD:
			collect(sim, pk)
			continue
		keep.append(pk)
	sim.pickups = keep

static func collect(sim, pk: SimPickup) -> void:
	match pk.kind:
		"gold":
			if sim.run != null:
				sim.run.add_gold(int(pk.value))
		"ember":
			if sim.run != null:
				sim.run.embers += int(pk.value)
		"orb":
			Combat.heal_player(sim, pk.value, "orb")
		"reward":
			if sim.flow != null:
				sim.flow.on_reward_collected(pk)
	sim.fire(&"pickup_collected", {"kind": pk.kind, "value": pk.value, "pos": pk.pos})
