class_name SimBody
extends RefCounted
## Common physical data for anything that moves in the arena.

var id := 0
var pos := Vector2.ZERO
var prev := Vector2.ZERO
var vel := Vector2.ZERO
var kvel := Vector2.ZERO   # knockback velocity (decays separately)
var radius := 15.0
var facing := 0.0
var alive := true
var flying := false
