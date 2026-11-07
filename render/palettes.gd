class_name Palettes
extends RefCounted
## Per-depth floor palettes. Floors stay desaturated and cool/neutral so that red/orange
## (danger) and white/gold (player) always read on top of them.

const DEPTHS := [
	{"name": "The Ashen Gardens", "floor": "#262420", "floor2": "#2e2b25", "line": "#3a362d", "accent": "#7fae6a", "wall": "#141210", "wall_top": "#3b3a2a", "pillar": "#4a4636", "bg": "#0d0c0a", "fog": "#9ac08a"},
	{"name": "The Drowned Archive", "floor": "#16212b", "floor2": "#1b2833", "line": "#24384a", "accent": "#5ec8e0", "wall": "#0a1118", "wall_top": "#2a3e52", "pillar": "#3a4c64", "bg": "#070b10", "fog": "#6ad0ff"},
	{"name": "The Clockwork Foundry", "floor": "#22201f", "floor2": "#2a2725", "line": "#3a3532", "accent": "#d0b070", "wall": "#121010", "wall_top": "#4a423a", "pillar": "#5a524a", "bg": "#0b0a09", "fog": "#e0c890"},
	{"name": "The Starless Crown", "floor": "#15111f", "floor2": "#1b1628", "line": "#2a2340", "accent": "#c0a8ff", "wall": "#08060e", "wall_top": "#3a3058", "pillar": "#4a4070", "bg": "#05040a", "fog": "#d8c8ff"},
	{"name": "The Wick", "floor": "#221a16", "floor2": "#2a201a", "line": "#3a2c22", "accent": "#ffc94a", "wall": "#100c0a", "wall_top": "#4a3a2a", "pillar": "#5a4632", "bg": "#0a0706", "fog": "#ffd27a"},
]

static func get_depth(i: int) -> Dictionary:
	var d: Dictionary = DEPTHS[clampi(i, 0, DEPTHS.size() - 1)]
	var out := {}
	for k in d.keys():
		out[k] = Color.html(d[k]) if String(d[k]).begins_with("#") else d[k]
	return out
