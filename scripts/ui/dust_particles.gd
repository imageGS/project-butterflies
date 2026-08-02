extends Node
class_name FloorDust

@export var specks_per_tile: int = 8
@export var speck_size: float = 0.5
@export var puff_duration: float = 0.6
@export var puff_spread: float = 12.0
@export var base_alpha: float = 0.5
@export var color: Color = Color(0.7, 0.65, 0.6)

@export var fog_base_alpha: float = 0.2
@export var fog_recovery_rate: float = 0.25
@export var fog_radius: int = 2
@export var fog_color: Color = Color(0.471, 0.471, 0.5, 1.0)

var _tile_specks: Dictionary = {}
var _puffing_specks: Array = []
var _map_min_x: int = 0
var _map_max_x: int = 0
var _map_min_y: int = 0
var _map_max_y: int = 0

var _fog_density: Array = []
var _fog_img: Image
var _fog_texture: ImageTexture
var _fog_dirty: bool = false

func generate_for_map(map_data: Array):
	_tile_specks.clear()
	_puffing_specks.clear()
	_map_min_x = 999999; _map_max_x = -999999
	_map_min_y = 999999; _map_max_y = -999999
	for y in map_data.size():
		var row = map_data[y]
		for x in row.size():
			if row[x] != 0: continue
			if x < _map_min_x: _map_min_x = x
			if x > _map_max_x: _map_max_x = x
			if y < _map_min_y: _map_min_y = y
			if y > _map_max_y: _map_max_y = y
			var key := "%d,%d" % [x, y]
			var specks: Array = []
			for i in specks_per_tile:
				specks.append({
					"ox": randf_range(0.15, 0.85),
					"oy": randf_range(0.15, 0.85),
					"sz": speck_size * randf_range(0.6, 1.4),
					"alpha": base_alpha * randf_range(0.5, 1.0),
					"state": "active",
				})
			_tile_specks[key] = specks

func puff_tile(tx: int, ty: int):
	var key := "%d,%d" % [tx, ty]
	var specks: Array = _tile_specks.get(key, [])
	if specks.is_empty(): return
	for s in specks:
		if s.state == "gone": continue
		s.state = "puffing"
		s.puff_timer = 0.0
		s.puff_dir_x = randf_range(-1.0, 1.0)
		s.puff_dir_y = randf_range(-1.0, 1.0)
		var dlen := sqrt(s.puff_dir_x * s.puff_dir_x + s.puff_dir_y * s.puff_dir_y)
		if dlen < 0.01:
			s.puff_dir_x = 1.0; s.puff_dir_y = 0.0
		else:
			s.puff_dir_x /= dlen; s.puff_dir_y /= dlen
	_puffing_specks.append({"tx": tx, "ty": ty, "specks": specks})

func generate_fog_map(map_data: Array):
	_fog_density.clear()
	_fog_density.resize(map_data.size())
	var w: int = map_data[0].size() if map_data.size() > 0 else 1
	var h: int = map_data.size()
	for y in h:
		_fog_density[y] = []
		_fog_density[y].resize(w)
		for x in w:
			_fog_density[y][x] = 1.0 if map_data[y][x] == 0 else 0.0
	_fog_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_fog_texture = ImageTexture.create_from_image(_fog_img)
	_sync_fog_texture()

func displace_fog(tx: int, ty: int):
	if _fog_density.is_empty(): return
	var h: int = _fog_density.size()
	var w: int = _fog_density[0].size() if h > 0 else 0
	if w == 0: return
	for dy in range(-fog_radius - 1, fog_radius + 2):
		for dx in range(-fog_radius - 1, fog_radius + 2):
			var nx := tx + dx
			var ny := ty + dy
			if nx < 0 or ny < 0 or ny >= h or nx >= w: continue
			if _fog_density[ny][nx] <= 0.0: continue
			var dist := sqrt(float(dx * dx + dy * dy))
			if dist < 0.5:
				_fog_density[ny][nx] = 0.0
				_fog_dirty = true
			elif dist <= fog_radius:
				var clear_dist: float = max(dist - 0.5, 0.0)
				var fade: float = clear_dist / (fog_radius + 1.0)
				var new_val: float = lerp(0.0, _fog_density[ny][nx], fade)
				if abs(new_val - _fog_density[ny][nx]) > 0.001:
					_fog_density[ny][nx] = new_val
					_fog_dirty = true
			elif dist <= fog_radius + 1.0:
				_fog_density[ny][nx] = min(_fog_density[ny][nx] + 0.15, 1.0)
				_fog_dirty = true

func get_fog_texture() -> ImageTexture:
	return _fog_texture

func get_fog_density_at(tx: int, ty: int) -> float:
	if _fog_density.is_empty(): return 0.0
	if ty < 0 or ty >= _fog_density.size(): return 0.0
	if tx < 0 or tx >= _fog_density[ty].size(): return 0.0
	return _fog_density[ty][tx]

func _sync_fog_texture():
	if not _fog_img or _fog_density.is_empty(): return
	for y in _fog_density.size():
		var row = _fog_density[y]
		for x in row.size():
			_fog_img.set_pixel(x, y, Color(row[x], 0.0, 0.0, 1.0))
	_fog_texture.update(_fog_img)
	_fog_dirty = false

func _process(delta):
	var done: Array = []
	for entry in _puffing_specks:
		var any_active := false
		for s in entry.specks:
			if s.state != "puffing": continue
			s.puff_timer += delta
			if s.puff_timer >= puff_duration:
				s.state = "gone"
			else:
				any_active = true
		if not any_active:
			done.append(entry)
	for d in done:
		_puffing_specks.erase(d)

	if _fog_density.is_empty(): return
	for y in _fog_density.size():
		var row = _fog_density[y]
		for x in row.size():
			if row[x] < 1.0:
				var new_val: float = min(row[x] + fog_recovery_rate * delta, 1.0)
				if abs(new_val - row[x]) > 0.001:
					row[x] = new_val
					_fog_dirty = true
	if _fog_dirty:
		_sync_fog_texture()

func get_all_specks_for_tile(tx: int, ty: int) -> Array:
	var key := "%d,%d" % [tx, ty]
	return _tile_specks.get(key, [])

func has_dust_at(tx: int, ty: int) -> bool:
	var specks: Array = _tile_specks.get("%d,%d" % [tx, ty], [])
	for s in specks:
		if s.state != "gone":
			return true
	return false

func has_active_dust_at(tx: int, ty: int) -> bool:
	var specks: Array = _tile_specks.get("%d,%d" % [tx, ty], [])
	for s in specks:
		if s.state == "active":
			return true
	return false

func get_specks_in_range(cx: float, cy: float, range: float) -> Array:
	var result: Array = []
	if _tile_specks.is_empty(): return result
	var sx: int = max(_map_min_x, int(floor(cx - range)))
	var ex: int = min(_map_max_x, int(ceil(cx + range)))
	var sy: int = max(_map_min_y, int(floor(cy - range)))
	var ey: int = min(_map_max_y, int(ceil(cy + range)))
	for y in range(sy, ey + 1):
		for x in range(sx, ex + 1):
			var specks: Array = _tile_specks.get("%d,%d" % [x, y], [])
			for s in specks:
				if s.state == "gone": continue
				result.append({"tile_x": x, "tile_y": y, "speck": s})
	return result
