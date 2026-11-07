extends Node2D
## A canvas layer whose drawing is delegated to a callable (redrawn every frame).

var drawer: Callable

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if drawer.is_valid():
		drawer.call(self)
