extends Node
## Central asset map. Every sprite is requested by id (e.g. "cinderling", "w_pike",
## "boss_regent"). Procedural sprites are registered by the art modules in render/art/ and
## baked into textures at startup. A PNG dropped at res://sprites/<id>.png replaces the
## procedural sprite (it is scaled to the same on-screen size).

const BAKE_SCALE := 2.0
const PAGE := 2048
const PAD := 6

signal baked

var is_baked := false
var _defs := {}       # id -> {size: Vector2, draw: Callable}
var _tex := {}        # id -> Texture2D
var _fallback: Texture2D
var _flash_shader: Shader

func _init() -> void:
	for mod in [ArtChars, ArtFx, ArtEnemies1, ArtEnemies2, ArtEnemies3, ArtEnemies4, ArtBosses, ArtIcons, ArtPatrons]:
		mod.register(self)
	_flash_shader = load("res://render/hitflash.gdshader")

## registers a procedural sprite. `size` is its world-unit bounding box.
func reg(id: String, size: Vector2, draw: Callable) -> void:
	_defs[id] = {"size": size, "draw": draw}

func has_sprite(id: String) -> bool:
	return _defs.has(id) or _override_path(id) != ""

func ids() -> Array:
	return _defs.keys()

func size_of(id: String) -> Vector2:
	if _defs.has(id):
		return _defs[id].size
	return Vector2(32, 32)

## the texture for an id; procedural textures are baked at BAKE_SCALE, so draw them at
## `draw_scale(id)` to get world size
func tex(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	var path := _override_path(id)
	if path != "":
		var t := _load_png(path)
		if t != null:
			_tex[id] = t
			return t
	return fallback()

func draw_scale(id: String) -> float:
	var s := size_of(id)
	if _override_path(id) != "":
		var t := tex(id)
		return s.y / maxf(1.0, float(t.get_height()))
	if _tex.has(id):
		return 1.0 / BAKE_SCALE
	return s.y / 32.0

var _override_cache := {}

func _override_path(id: String) -> String:
	if _override_cache.has(id):
		return _override_cache[id]
	var p := "res://sprites/%s.png" % id
	var found := p if (ResourceLoader.exists(p) or FileAccess.file_exists(p)) else ""
	_override_cache[id] = found
	return found

func _load_png(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			return r
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

func fallback() -> Texture2D:
	if _fallback == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(15.0 - d, 0.0, 1.0)))
		_fallback = ImageTexture.create_from_image(img)
	return _fallback

func flash_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _flash_shader
	return m

## Bakes every registered sprite (call once at startup; a no-op when headless).
func bake() -> void:
	if is_baked:
		return
	if DisplayServer.get_name() == "headless":
		is_baked = true
		baked.emit()
		return
	var pages: Array = [[]]
	var x := 0
	var y := 0
	var row_h := 0
	var ids_sorted := _defs.keys()
	ids_sorted.sort_custom(func(a, b): return _defs[a].size.y > _defs[b].size.y)
	for id in ids_sorted:
		if _override_path(id) != "":
			continue
		var s: Vector2 = _defs[id].size * BAKE_SCALE
		var w := int(ceil(s.x)) + PAD * 2
		var h := int(ceil(s.y)) + PAD * 2
		if x + w > PAGE:
			x = 0
			y += row_h
			row_h = 0
		if y + h > PAGE:
			pages.append([])
			x = 0
			y = 0
			row_h = 0
		pages[-1].append({"id": id, "rect": Rect2i(x + PAD, y + PAD, w - PAD * 2, h - PAD * 2), "draw": _defs[id].draw, "scale": BAKE_SCALE})
		x += w
		row_h = maxi(row_h, h)
	for cells in pages:
		if cells.is_empty():
			continue
		var vp := SubViewport.new()
		vp.size = Vector2i(PAGE, PAGE)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := Node2D.new()
		painter.set_script(load("res://render/painter.gd"))
		painter.cells = cells
		vp.add_child(painter)
		add_child(vp)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		for c in cells:
			var sub := img.get_region(c.rect)
			_tex[c.id] = ImageTexture.create_from_image(sub)
		vp.queue_free()
	is_baked = true
	baked.emit()

## saves every baked sprite to a folder (handy as a starting point for custom art)
func dump(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for id in _tex.keys():
		var t: Texture2D = _tex[id]
		t.get_image().save_png(dir.path_join(id + ".png"))
