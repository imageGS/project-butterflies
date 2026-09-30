extends Control

var _texture_rect: TextureRect
var _cache: Dictionary = {}
var _frames: Array[Texture2D] = []
var _fps: float = 12.0
var _current_frame: int = 0
var _timer: float = 0.0
var _playing: bool = false
var _on_done: Callable
var _loop: bool = false
var _loop_count: int = 0
var _max_loops: int = 1
var _reverse: bool = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_texture_rect = get_node_or_null("HandSprite") as TextureRect
	if not _texture_rect:
		_texture_rect = TextureRect.new()
		_texture_rect.name = "HandSprite"
		_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_texture_rect)
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func play(folder: String, fps: float = 12.0, on_done: Callable = Callable(), loop: bool = false, max_loops: int = 1, reverse: bool = false):
	_frames = _get_frames(folder)
	if _frames.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_fps = fps
	_current_frame = 0
	_timer = 0.0
	_on_done = on_done
	_loop = loop
	_max_loops = max_loops
	_loop_count = 0
	_reverse = reverse
	_playing = true
	visible = true
	_texture_rect.texture = _frames[0]

func stop():
	_playing = false
	visible = false
	_texture_rect.texture = null
	_frames = []

func is_playing() -> bool:
	return _playing

func _process(delta: float):
	if not _playing or _frames.is_empty():
		return
	_timer += delta
	if _reverse:
		var raw: int = _frames.size() - 1 - int(_timer * _fps)
		if raw < 0:
			if _loop:
				_loop_count += 1
				if _loop_count >= _max_loops:
					_finish()
					return
				_timer = 0.0
				_current_frame = _frames.size() - 1
			else:
				_finish()
				return
		_current_frame = clampi(raw, 0, _frames.size() - 1)
	else:
		var frame_idx: int = int(_timer * _fps)
		if frame_idx >= _frames.size():
			if _loop:
				_loop_count += 1
				if _loop_count >= _max_loops:
					_finish()
					return
				_timer = 0.0
				_current_frame = 0
			else:
				_finish()
				return
		_current_frame = clampi(frame_idx, 0, _frames.size() - 1)
	_texture_rect.texture = _frames[_current_frame]

func _finish():
	_playing = false
	visible = false
	_texture_rect.texture = null
	var cb: Callable = _on_done
	_frames = []
	if cb.is_valid():
		cb.call()

func _get_frames(folder: String) -> Array[Texture2D]:
	if _cache.has(folder):
		return _cache[folder]
	var frames: Array[Texture2D] = []
	var dir := DirAccess.open(folder)
	if not dir:
		return frames
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	var pngs: Array[String] = []
	while fname != "":
		if fname.ends_with(".png"):
			pngs.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	pngs.sort()
	for p in pngs:
		var tex := load(folder + "/" + p) as Texture2D
		if tex:
			frames.append(tex)
	_cache[folder] = frames
	return frames
