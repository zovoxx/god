class_name HpChip
extends RefCounted
## Displayed-HP model for the HP bar: lost HP turns into a white "chip" segment that holds
## for `chip_delay` seconds and then drains; heals fill a green segment up to the new value.
## Pure logic so it can be unit-tested headless.

var shown := 0.0        # solid HP drawn
var chip := 0.0         # top of the white chip segment (>= shown)
var heal_to := 0.0      # green heal target (>= shown)
var hold := 0.0
var delay := 0.5
var drain := 1.6        # fraction of max per second
var fill := 1.2

func _init(hp: float = 0.0, chip_delay: float = 0.5, drain_speed: float = 1.6, heal_speed: float = 1.2) -> void:
	shown = hp
	chip = hp
	heal_to = hp
	delay = chip_delay
	drain = drain_speed
	fill = heal_speed

func update(dt: float, hp: float, max_hp: float) -> void:
	if hp < shown:
		# took damage: the solid bar drops instantly, the chip stays and starts its hold
		chip = maxf(chip, shown)
		shown = hp
		heal_to = hp
		hold = delay
	elif hp > heal_to:
		heal_to = hp
	if hold > 0.0:
		hold -= dt
	elif chip > shown:
		chip = maxf(shown, chip - drain * max_hp * dt)
	if heal_to > shown:
		shown = minf(heal_to, shown + fill * max_hp * dt)
	if chip < shown:
		chip = shown
