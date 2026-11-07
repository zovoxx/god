class_name SimPickup
extends SimBody
## Gold coins, Embers, HP orbs (cyan = pickup/heal) and the room reward orb.

var kind := "gold"          # gold | ember | orb | reward
var value := 1.0
var t := 0.0
var magnet := false
var data := {}
