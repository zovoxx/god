extends SceneTree
## Captures screenshots of key screens. Works under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s tools/screenshots.gd -- [--out=dir] [--only=name]
## Logic lives in tools/shots_impl.gd (loaded at runtime so autoload-dependent classes compile).

var impl

func _initialize() -> void:
	impl = load("res://tools/shots_impl.gd").new()
	impl.tree = self
	impl.start()

func _process(delta: float) -> bool:
	return impl.tick(delta)
