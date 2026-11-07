extends Node
## Loads the balance (tuning.tres), feel (game_feel.tres) and content (boons.tres) resources
## and exposes them to both simulation and presentation. Also holds the accessibility
## multipliers chosen in Settings (shake/hitstop/flash/numbers scale, colour-blind palette).

var T: Tuning
var F: GameFeel
var B: Resource  # BoonData (patrons/boons/duos), loaded when present

# accessibility / feel multipliers (written by App from settings)
var shake_mul := 1.0
var hitstop_mul := 1.0
var flash_mul := 1.0
var numbers_mul := 1.0
var numbers_on := true
var reduce_flashing := false
var colorblind := false

var _colors := {}

func _init() -> void:
	reload()

func reload() -> void:
	T = load("res://data/tuning.tres")
	F = load("res://data/game_feel.tres")
	if ResourceLoader.exists("res://data/boons.tres"):
		B = load("res://data/boons.tres")
	_rebuild_colors()

func set_colorblind(on: bool) -> void:
	colorblind = on
	_rebuild_colors()

func _rebuild_colors() -> void:
	_colors.clear()
	var src: Dictionary = F.colors_cb if colorblind else F.colors
	for k in F.colors.keys():
		var hex: String = src.get(k, F.colors[k])
		_colors[k] = Color.html(hex)

func col(name: String) -> Color:
	return _colors.get(name, Color.MAGENTA)
