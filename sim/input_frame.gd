class_name InputFrame
extends RefCounted
## One fixed-step worth of player intent. Built from devices by the presentation layer,
## or synthesised by the headless bot. The simulation never reads Input directly.

enum Aim { AUTO, MOUSE, STICK }

var move := Vector2.ZERO          # -1..1 per axis, length <= 1
var aim := Vector2.ZERO           # stick direction (length 0 = none)
var aim_point := Vector2.ZERO     # world point (mouse cursor)
var aim_source := Aim.AUTO
var attack_p := false
var attack_h := false
var special_p := false
var special_h := false
var dash_p := false
var cast_p := false

func clear_edges() -> void:
	attack_p = false
	special_p = false
	dash_p = false
	cast_p = false
