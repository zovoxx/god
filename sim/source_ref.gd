class_name SourceRef
extends RefCounted
## Names the source of damage when the attacker itself is gone (death blasts, mines, pools),
## so the damage log, damage numbers and death recap still say who hurt you.

var name := "Hazard"
var art := "hazard"
var kind := ""
var alive := true
var is_boss := false
var is_guardian := false
var pos := Vector2.ZERO

static func of(e) -> SourceRef:
	var s := SourceRef.new()
	if e != null:
		s.name = e.name
		s.art = e.art
		s.kind = e.kind
		s.pos = e.pos
	return s
