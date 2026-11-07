class_name Combat
extends RefCounted
## Hit pipeline, damage, kills, the Sigil and dash interactions.

static func on_dash_start(sim) -> void:
	pass

static func on_dashing(sim, dt: float) -> void:
	pass

static func on_dash_end(sim) -> void:
	pass

static func cast_sigil(sim) -> void:
	pass
