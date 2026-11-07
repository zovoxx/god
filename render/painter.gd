extends Node2D
## Draws a page of procedural sprites into a SubViewport once, for baking into textures.

var cells: Array = []   # [{id, rect: Rect2i, draw: Callable, scale}]

func _draw() -> void:
	for c in cells:
		var r: Rect2i = c.rect
		draw_set_transform(Vector2(r.position) + Vector2(r.size) * 0.5, 0.0, Vector2.ONE * float(c.scale))
		c.draw.call(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
