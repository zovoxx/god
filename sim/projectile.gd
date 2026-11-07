class_name SimProj
extends SimBody
## A projectile. team 0 = player (never red), team 1 = enemy (always red/orange).

enum Kind { STRAIGHT, LOB, HALO, ORBIT, HOMING, WAVE, SEED }

var team := 0
var kind := Kind.STRAIGHT
var dmg := 0.0
var power := 0.3
var knock := 0.6
var pierce := 0
var life := 1.0
var max_life := 1.0
var slot := "special"
var art := ""
var color := Color.WHITE
var hits := {}
var owner = null
var data := {}
var rot := 0.0
var crit_bonus := 0.0
var attack_name := ""
var element := ""
var reflectable := true
var hit_walls := true
var size := 1.0
