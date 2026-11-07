class_name SimHazard
extends RefCounted
## Area effects on the floor: the Sigil blast, starfall, fissures, fire/slag fields, vents...
## team 0 = player (hurts enemies), team 1 = enemy (hurts the player).
## Enemy floor hazards pulse twice (warn) before they become active.

enum Shape { CIRCLE, LINE, RING }

var id := 0
var name := "Hazard"
var art := "hazard"
var team := 0
var shape := Shape.CIRCLE
var pos := Vector2.ZERO
var radius := 40.0
var inner := 0.0
var angle := 0.0
var length := 0.0
var width := 0.0
var kind := "blast"         # blast | rain | field | vent
var delay := 0.0            # time before the first hit
var warn := 0.0             # enemy hazards: pulse-warning time before active
var t := 0.0
var life := 1.0
var tick := 0.0             # repeat interval (0 = single hit)
var tick_t := 0.0
var hits_left := 1
var dmg := 0.0
var power := 0.4
var knock := 0.8
var slot := "cast"
var root := 0.0
var color := Color.WHITE
var owner = null
var attack_name := ""
var element := ""
var data := {}
var alive := true
var hit_ids := {}           # for single-hit-per-target hazards

func active() -> bool:
	return t >= warn + delay

func contains(p: Vector2, r: float) -> bool:
	match shape:
		Shape.LINE:
			return Geom.in_line(p, r, pos, angle, length, width)
		Shape.RING:
			return Geom.in_ring(p, r, pos, inner, radius)
	return Geom.in_circle(p, r, pos, radius)
