class_name HitInfo
extends RefCounted
## Everything the hit pipeline needs to know about one hit.

var dmg := 0.0
var slot := "attack"        # attack | special | dash | cast | status | other
var power := 0.3            # 0..1, drives hit-stop, shake, particles, stagger
var knock := 1.0
var dir := Vector2.RIGHT
var src := Vector2.ZERO
var crit_bonus := 0.0
var can_crit := true
var force_crit := false
var armor_break := 1.0
var is_dot := false
var element := ""           # patron id for status-coloured numbers
var tag := ""               # tip, backstab, finisher, slam, jolt, burst...
var no_infuse := false
var no_hitstop := false
var stagger := 1.0
var source_id := 0          # projectile/hazard id (merging numbers)

static func make(dmg_v: float, slot_v: String, power_v: float, dir_v: Vector2, src_v: Vector2) -> HitInfo:
	var h := HitInfo.new()
	h.dmg = dmg_v
	h.slot = slot_v
	h.power = power_v
	h.dir = dir_v.normalized() if dir_v != Vector2.ZERO else Vector2.RIGHT
	h.src = src_v
	return h
