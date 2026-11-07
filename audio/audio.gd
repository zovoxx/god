extends Node
## Sound: procedural SFX (rendered in a background thread at startup) with optional overrides
## from res://audio/<id>.ogg|wav, a voice pool with ±8 % pitch variation, voice limits and a
## minimum retrigger time; layered music per depth (explore / combat / streak / boss) that fades
## with the action, a room-clear stinger, and a muffled low-HP state with a heartbeat.

const LAYERS := 4

var enabled := true
var _sfx := {}
var _mutex := Mutex.new()
var _pool: Array = []
var _pool_i := 0
var _last := {}
var _music_players: Array = []
var _music_cache := {}          # depth -> [streams]
var _music_pending := {}
var _music_depth := -1
var _want_depth := -1
var _layer_target := [1.0, 0.0, 0.0, 0.0]
var _layer_vol := [0.0, 0.0, 0.0, 0.0]
var _music_on := true
var _low_hp := false
var _beat_t := 0.0
var _lp: AudioEffectLowPassFilter
var _music_bus := -1
var _override_cache := {}

func _init() -> void:
	enabled = DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().find("--bot") < 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	if not enabled:
		return
	var voices := int(Cfg.F.audio.max_voices)
	for i in voices:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in LAYERS:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.volume_db = -80.0
		add_child(mp)
		_music_players.append(mp)
	WorkerThreadPool.add_task(_render_all_sfx)

func _setup_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")
	_music_bus = AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(_music_bus) == 0:
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = float(Cfg.F.audio.low_hp_cutoff)
		AudioServer.add_bus_effect(_music_bus, _lp)
		AudioServer.set_bus_effect_enabled(_music_bus, 0, false)

func _render_all_sfx() -> void:
	for id in Synth.sfx_recipes().keys():
		var w := Synth.render_sfx(id)
		_mutex.lock()
		if not _sfx.has(id):
			_sfx[id] = w
		_mutex.unlock()

func apply_volumes(s: Dictionary) -> void:
	_set_bus("Master", float(s.get("master", 0.8)))
	_set_bus("Music", float(s.get("music", 0.5)))
	_set_bus("SFX", float(s.get("sfx", 0.9)))

func _set_bus(name: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, lin)))
	AudioServer.set_bus_mute(i, lin <= 0.001)

func _override(id: String) -> AudioStream:
	if _override_cache.has(id):
		return _override_cache[id]
	var s: AudioStream = null
	for ext in ["ogg", "wav"]:
		var p := "res://audio/%s.%s" % [id, ext]
		if ResourceLoader.exists(p):
			s = load(p)
			break
		if FileAccess.file_exists(p):
			if ext == "ogg":
				s = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(p))
			else:
				s = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(p))
			break
	_override_cache[id] = s
	return s

func stream_for(id: String) -> AudioStream:
	var o := _override(id)
	if o != null:
		return o
	_mutex.lock()
	var s = _sfx.get(id)
	_mutex.unlock()
	if s == null:
		s = Synth.render_sfx(id)
		_mutex.lock()
		_sfx[id] = s
		_mutex.unlock()
	return s

## plays a sound with random pitch spread, voice stealing and a minimum retrigger time
func play(id: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not enabled or _pool.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -1.0)) < float(Cfg.F.audio.retrigger):
		return
	_last[id] = now
	var s := stream_for(id)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for i in _pool.size():
		var c: AudioStreamPlayer = _pool[(_pool_i + i) % _pool.size()]
		if not c.playing:
			p = c
			_pool_i = (_pool_i + i + 1) % _pool.size()
			break
	if p == null:
		p = _pool[_pool_i]
		_pool_i = (_pool_i + 1) % _pool.size()
	var v: float = Cfg.F.audio.pitch_variation
	p.stream = s
	p.pitch_scale = clampf(pitch * randf_range(1.0 - v, 1.0 + v), 0.3, 3.0)
	p.volume_db = vol_db
	p.play()

# ───────── music ─────────

func music_state(state: String) -> void:
	if not enabled:
		return
	match state:
		"title", "wick":
			_music_on = true
			set_depth(4)
			_layer_target = [1.0, 0.0, 0.0, 0.0]
		"explore":
			_music_on = true
			_layer_target = [1.0, 0.0, 0.0, 0.0]
		"death":
			_layer_target = [0.35, 0.0, 0.0, 0.0]
		"off":
			_music_on = false

## depth index 0..3 for the four depths, 4 = the Wick theme
func set_depth(d: int) -> void:
	if not enabled:
		return
	_want_depth = d
	if _music_cache.has(d):
		_start_music(d)
	elif not _music_pending.has(d):
		_music_pending[d] = true
		WorkerThreadPool.add_task(func():
			var streams: Array = []
			for l in LAYERS:
				streams.append(Synth.render_music(d, l))
			_mutex.lock()
			_music_cache[d] = streams
			_mutex.unlock())

func _start_music(d: int) -> void:
	if _music_depth == d:
		return
	_music_depth = d
	var streams: Array = _music_cache[d]
	for i in LAYERS:
		var mp: AudioStreamPlayer = _music_players[i]
		mp.stream = streams[i]
		mp.volume_db = -80.0
		_layer_vol[i] = 0.0
		mp.play()

func set_intensity(combat: bool, streak: bool, boss: bool) -> void:
	_layer_target = [1.0, 1.0 if combat or boss else 0.0, 1.0 if streak else 0.0, 1.0 if boss else 0.0]

func stinger() -> void:
	play("stinger", 1.0, -4.0)

func set_low_hp(on: bool) -> void:
	_low_hp = on and enabled
	if _music_bus >= 0 and AudioServer.get_bus_effect_count(_music_bus) > 0:
		AudioServer.set_bus_effect_enabled(_music_bus, 0, _low_hp)

func _process(delta: float) -> void:
	if not enabled:
		return
	if _want_depth >= 0 and _music_depth != _want_depth:
		_mutex.lock()
		var ready := _music_cache.has(_want_depth)
		_mutex.unlock()
		if ready:
			_start_music(_want_depth)
	var fade: float = Cfg.F.audio.music_fade
	for i in _music_players.size():
		var target: float = _layer_target[i] if _music_on else 0.0
		_layer_vol[i] = move_toward(_layer_vol[i], target, delta / maxf(0.05, fade))
		var mp: AudioStreamPlayer = _music_players[i]
		mp.volume_db = linear_to_db(maxf(0.0001, _layer_vol[i] * (0.8 if i > 0 else 1.0)))
	if _low_hp:
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = 60.0 / float(Cfg.F.low_hp.heartbeat_bpm)
			play("heartbeat", 1.0, -2.0)
