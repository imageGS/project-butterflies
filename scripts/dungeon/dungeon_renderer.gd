extends Control

const TILE_WALL: int = 1
const TILE_BLOCKED: int = 6
const TILE_DOOR: int = 2
const TILE_LOCKED: int = 3

func _is_solid_cell(x: int, y: int) -> bool:
	if y < 0 or x < 0 or y >= map_data.size() or x >= map_data[0].size():
		return true
	var tv: int = map_data[y][x]
	return tv == TILE_WALL or tv == TILE_BLOCKED or tv == TILE_DOOR or tv == TILE_LOCKED

var cam_x: float = 1.5
var cam_y: float = 1.5
var player_angle: float = 0.0
var map_data: Array = []
var height_data: Array = []

var _view_w: int = 0
var _view_h: int = 0
var _strip_w: int = 4
var _wall_zbuf: Array[float] = []

var entities_on_map: Array = []
var _entity_lights: Array = []
var floor_ambient: float = 0.0
var _flashlight_on: bool = false
var _flashlight_range: float = 6.0
var _flashlight_intensity: float = 0.0
var _flashlight_color: Color = Color.WHITE
var flashlight_aim: float = 0.0
var flicker_enabled: bool = true
var light_cell: float = 1.0
var bob_offset: float = 0.0

var _wall_tex: Texture2D = load("res://assets/textures/wall/default.png")
var _floor_tex: Texture2D = load("res://assets/textures/floor/default.png")
var _ceiling_enabled: bool = false
var _ceiling_tex: Texture2D
var fog_distance: float = 7.0
var fog_fade: float = 2.5
var fog_color: Color = Color(0.08, 0.08, 0.08)
var wall_decors: Dictionary = {}
var _tex_cache: Dictionary = {}
var _alpha_cache: Dictionary = {}
var hovered_grid: Vector2i = Vector2i(-1, -1)
var _outline_cache: Dictionary = {}
var floor_dust: Node = null

func _cell_tex(x: int, y: int, is_wall: bool) -> Texture2D:
	var key := "%d,%d" % [x, y]
	if wall_decors.has(key):
		var cell: Dictionary = wall_decors[key]
		var tid: String = cell.get("texture", "")
		if not tid.is_empty():
			return _load_tex(tid)
	return _wall_tex if is_wall else _floor_tex

func _load_tex(tid: String) -> Texture2D:
	if _tex_cache.has(tid): return _tex_cache[tid]
	var p := "res://assets/textures/" + tid
	if not tid.ends_with(".png"): p += ".png"
	if FileAccess.file_exists(p):
		var t := load(p) as Texture2D
		if t: _tex_cache[tid] = t; return t
	if not "/" in tid:
		for folder in ["wall", "floor", "door"]:
			p = "res://assets/textures/" + folder + "/" + tid
			if not tid.ends_with(".png"): p += ".png"
			if FileAccess.file_exists(p):
				var t := load(p) as Texture2D
				if t: _tex_cache[tid] = t; return t
	return null

func _get_outline_tex(tex: Texture2D, outline_width: float = 1.5) -> Texture2D:
	var key: String = tex.resource_path
	if _outline_cache.has(key):
		return _outline_cache[key]
	var src: Image = tex.get_image()
	if not src: return tex
	src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	var dst := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rw: int = int(ceil(outline_width))
	for x in range(w):
		for y in range(h):
			var c: Color = src.get_pixel(x, y)
			if c.a <= 0.0: continue
			var edge := false
			for dx in range(-rw, rw + 1):
				for dy in range(-rw, rw + 1):
					var nx := x + dx; var ny := y + dy
					if nx < 0 or nx >= w or ny < 0 or ny >= h:
						edge = true
					else:
						var nc: Color = src.get_pixel(nx, ny)
						if nc.a <= 0.0:
							edge = true
					if edge: break
				if edge: break
			if edge:
				dst.set_pixel(x, y, Color(1, 1, 1))
	var out_tex := ImageTexture.create_from_image(dst)
	_outline_cache[key] = out_tex
	return out_tex

func get_wall_cell_at_strip(strip: int) -> Vector2i:
	if strip < 0 or strip >= _wall_zbuf.size(): return Vector2i(-1, -1)
	var perp: float = _wall_zbuf[strip]
	if perp >= fog_distance: return Vector2i(-1, -1)
	# Recast to get cell position
	var result: Dictionary = _cast_ray(cam_x, cam_y, _strip_angle(strip))
	return Vector2i(result.get("mx", -1), result.get("my", -1))

func _strip_angle(strip: int) -> float:
	var fov: float = deg_to_rad(90.0)
	var num_strips: int = _wall_zbuf.size()
	var angle: float = player_angle - fov * 0.5 + ((strip + 0.5) / float(max(num_strips, 1))) * fov
	return angle

func _strip_zbuf(strip: int) -> float:
	if strip < 0 or strip >= _wall_zbuf.size(): return INF
	return _wall_zbuf[strip]

func wall_cell_at_local(px: float, py: float) -> Vector2i:
	if _wall_zbuf.is_empty(): return Vector2i(-1, -1)
	var strip: int = clampi(int(px / max(_strip_w, 1)), 0, _wall_zbuf.size() - 1)
	var perp: float = _wall_zbuf[strip]
	if not is_finite(perp) or perp >= fog_distance: return Vector2i(-1, -1)
	var half_h: float = _view_h / 2.0 + bob_offset
	var wh: float = _view_h / perp
	var top: float = half_h - wh * 0.5
	if py < top - 4.0 or py > top + wh + 4.0:
		return Vector2i(-1, -1)
	var result: Dictionary = _cast_ray(cam_x, cam_y, _strip_angle(strip))
	var tile: Vector2i = Vector2i(result.get("mx", -1), result.get("my", -1))
	if not _is_solid_cell(tile.x, tile.y):
		return Vector2i(-1, -1)
	return tile

func throw_target_tile_at_local(px: float, py: float, max_dist: float) -> Vector2i:
	if _wall_zbuf.is_empty(): return Vector2i(-1, -1)
	var strip: int = clampi(int(px / _strip_w), 0, _wall_zbuf.size() - 1)
	var angle: float = _strip_angle(strip)
	var dir := Vector2(cos(angle), sin(angle))
	var cx: float = cam_x; var cy: float = cam_y
	var cur_x: int = int(floor(cx)); var cur_y: int = int(floor(cy))
	var last: Vector2i = Vector2i(-1, -1)
	var travelled: float = 0.0
	while travelled <= max_dist:
		travelled += 0.25
		var gx: int = int(floor(cx + dir.x * travelled))
		var gy: int = int(floor(cy + dir.y * travelled))
		if gx != cur_x or gy != cur_y:
			if map_data.is_empty() or gx < 0 or gy < 0 or gy >= map_data.size() or gx >= map_data[0].size():
				return last if last.x >= 0 else Vector2i(cur_x, cur_y)
			if _is_solid_cell(gx, gy):
				return last if last.x >= 0 else Vector2i(cur_x, cur_y)
			cur_x = gx; cur_y = gy; last = Vector2i(gx, gy)
	return last if last.x >= 0 else Vector2i(cur_x, cur_y)

func is_entity_occluded(ve: Dictionary) -> bool:
	var scx: float = ve.get("scx", -1.0)
	if scx < 0.0: return false
	var si: int = int(scx / _strip_w)
	if si < 0 or si >= _wall_zbuf.size(): return false
	return ve.depth >= _wall_zbuf[si]

func set_floor_texture(tid: String):
	var t := _load_tex(tid)
	if t:
		_floor_tex = t
		if _floor_mat: _floor_mat.set_shader_parameter("floor_tex", _floor_tex)

func set_ceiling(tid: String):
	_ceiling_enabled = not tid.is_empty()
	if _ceiling_enabled:
		_ceiling_tex = _load_tex(tid)

func apply_tileset(ts: Resource):
	if not ts: return
	_wall_tex = ts.get("wall_tex") if ts.get("wall_tex") else _wall_tex
	_floor_tex = ts.get("floor_tex") if ts.get("floor_tex") else _floor_tex
	if _floor_mat:
		_floor_mat.set_shader_parameter("floor_tex", _floor_tex)

var _floor_ctrl: Control
var _floor_mat: ShaderMaterial
var _map_img: Image
var _map_tex: ImageTexture
var _map_w: int = 0
var _map_h: int = 0
var _wall_ctrl: Control

func _ready():
	_setup_view()
	_setup_floor()
	_setup_walls()

func _setup_view():
	_view_w = int(size.x); _view_h = int(size.y)
	if _view_w <= 0: _view_w = 858
	if _view_h <= 0: _view_h = 449

func _setup_floor():
	_floor_ctrl = ColorRect.new()
	_floor_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floor_ctrl)
	var shader: Shader = load("res://shaders/floor_shader.gdshader")
	if not shader:
		push_warning("floor_shader.gdshader not found")
		return
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = shader
	_floor_ctrl.material = _floor_mat
	_floor_mat.set_shader_parameter("floor_tex", _floor_tex)
	_floor_mat.set_shader_parameter("rail_tex", _floor_tex)
	_init_fog_tex()

func _init_fog_tex():
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.5, 0.0, 0.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_floor_mat.set_shader_parameter("fog_tex", tex)

func _setup_walls():
	_wall_ctrl = Control.new()
	_wall_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wall_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wall_ctrl.set_script(load("res://scripts/dungeon/wall_drawer.gd"))
	_wall_ctrl.renderer = self
	add_child(_wall_ctrl)

func _fill_map_tex():
	if map_data.is_empty(): return
	_map_w = map_data[0].size(); _map_h = map_data.size()
	_map_img = Image.create(_map_w, _map_h, false, Image.FORMAT_RGBA8)
	for y in _map_h:
		for x in _map_w:
			var is_wall: bool = _is_solid_cell(x, y)
			var fh: float = height_data[y][x] if y < height_data.size() and x < height_data[y].size() else 0.0
			_map_img.set_pixel(x, y, Color(1.0 if is_wall else 0.0, (fh + 2.0) / 4.0, 0, 1))
	_map_tex = ImageTexture.create_from_image(_map_img)
	_build_floor_atlas()
	if _floor_mat:
		_floor_mat.set_shader_parameter("map_tex", _map_tex)
		_floor_mat.set_shader_parameter("map_w", _map_w)
		_floor_mat.set_shader_parameter("map_h", _map_h)

const ATLAS_TILE: int = 256
const ATLAS_COLS: int = 8

var _floor_atlas_tex: Texture2D
var _floor_map_tex: ImageTexture
var _floor_atlas_hash: int = 0

func rebuild_floor_atlas():
	_build_floor_atlas()

func _build_floor_atlas():
	if map_data.is_empty() or _floor_mat == null: return
	var h: int = map_data.hash()
	h = h * 31 + wall_decors.hash()
	if h == _floor_atlas_hash: return
	_floor_atlas_hash = h
	var tile_ids := {}
	var cell_tex := {}
	var next: int = 0
	for y in _map_h:
		for x in _map_w:
			if map_data[y][x] == TILE_WALL or map_data[y][x] == TILE_BLOCKED or map_data[y][x] == TILE_DOOR or map_data[y][x] == TILE_LOCKED:
				continue
			var tid := ""
			var rot: int = 0
			var key := "%d,%d" % [x, y]
			if wall_decors.has(key):
				var cell: Dictionary = wall_decors[key]
				tid = str(cell.get("texture", ""))
				rot = int(cell.get("rotation", 0))
			if tid.is_empty(): continue
			if _load_tex(tid) == null: continue
			var tkey := "%s|%d" % [tid, rot]
			if not tile_ids.has(tkey):
				tile_ids[tkey] = next
				next += 1
			cell_tex[key] = tile_ids[tkey]
	if next == 0:
		var empty_img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		empty_img.set_pixel(0, 0, Color(0, 0, 0, 0))
		var empty_tex := ImageTexture.create_from_image(empty_img)
		_floor_mat.set_shader_parameter("floor_map", empty_tex)
		return
	var rows := int(ceil(next / float(ATLAS_COLS)))
	var atlas := Image.create(ATLAS_COLS * ATLAS_TILE, rows * ATLAS_TILE, false, Image.FORMAT_RGBA8)
	for k in tile_ids:
		var idx: int = tile_ids[k]
		var parts: PackedStringArray = String(k).split("|")
		var tex := _load_tex(parts[0])
		var img: Image = tex.get_image()
		if not img: continue
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != ATLAS_TILE or img.get_height() != ATLAS_TILE:
			img.resize(ATLAS_TILE, ATLAS_TILE, Image.INTERPOLATE_NEAREST)
		var rot := int(parts[1])
		if rot != 0:
			img = _rotate_img(img, rot)
		var col := idx % ATLAS_COLS
		var row := idx / ATLAS_COLS
		atlas.blit_rect(img, Rect2i(0, 0, ATLAS_TILE, ATLAS_TILE), Vector2i(col * ATLAS_TILE, row * ATLAS_TILE))
	var fmap := Image.create(_map_w, _map_h, false, Image.FORMAT_RGBA8)
	for y in _map_h:
		for x in _map_w:
			var key := "%d,%d" % [x, y]
			if cell_tex.has(key):
				var idx: int = cell_tex[key]
				fmap.set_pixel(x, y, Color(float(idx % ATLAS_COLS) / ATLAS_COLS, float(idx / ATLAS_COLS) / rows, 0, 1))
			else:
				fmap.set_pixel(x, y, Color(0, 0, 0, 0))
	var atlas_tex := ImageTexture.create_from_image(atlas)
	var fmap_tex := ImageTexture.create_from_image(fmap)
	_floor_mat.set_shader_parameter("floor_atlas", atlas_tex)
	_floor_mat.set_shader_parameter("floor_map", fmap_tex)
	_floor_mat.set_shader_parameter("atlas_cols", ATLAS_COLS)
	_floor_mat.set_shader_parameter("atlas_rows", rows)

func _rotate_img(img: Image, quarter_turns: int) -> Image:
	quarter_turns = posmod(quarter_turns, 4)
	if quarter_turns == 0: return img
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out := Image.create(w, h, false, img.get_format())
	for y in range(h):
		for x in range(w):
			var src := img.get_pixel(x, y)
			match quarter_turns:
				1: out.set_pixel(h - 1 - y, x, src)
				2: out.set_pixel(w - 1 - x, h - 1 - y, src)
				3: out.set_pixel(y, w - 1 - x, src)
	return out

func _update_floor_shader():
	if not _floor_mat: return
	_floor_mat.set_shader_parameter("cam_pos", Vector2(cam_x, cam_y))
	_floor_mat.set_shader_parameter("cam_angle", player_angle)
	_floor_mat.set_shader_parameter("view_size", Vector2(_view_w, _view_h))
	_floor_mat.set_shader_parameter("view_bob", bob_offset)
	_floor_mat.set_shader_parameter("fog_dist", fog_distance)
	_floor_mat.set_shader_parameter("fog_fade", fog_fade)
	_floor_mat.set_shader_parameter("fog_color", fog_color)
	if floor_dust and floor_dust.has_method("get_fog_texture"):
		var ft = floor_dust.get_fog_texture()
		if ft:
			_floor_mat.set_shader_parameter("fog_tex", ft)
			var ga = floor_dust.get("fog_base_alpha")
			if ga != null:
				_floor_mat.set_shader_parameter("ground_fog_alpha", ga)
			var gc = floor_dust.get("fog_color")
			if gc != null:
				_floor_mat.set_shader_parameter("ground_fog_color", gc)



const LIGHT_STYLES: Dictionary = {
	fluorescent = "mmamammmmammamamaaammma",
	pulse = "abcdefghijklmnopqrstuvwxyzyxwvutsrqponmlkjihgfedcba",
	candle = "mmmmmaaaaammmmmaaaaaabcdefgabcdefg",
	strobe = "mamamamamama",
	alarm = "nmlkjihgfedcbaabcdefghijklmn",
}

func _get_light_style_mod(style_name: String, gx: int, gy: int) -> float:
	if style_name.is_empty() or not flicker_enabled: return 1.0
	var style: String = LIGHT_STYLES.get(style_name, "")
	if style.is_empty(): return 1.0
	var t: int = Time.get_ticks_msec()
	var offset: int = 0
	if style_name != "alarm":
		offset = abs(gx * 73856093 + gy * 19349663) % 100000
	var idx: int = ((t / 100) + offset) % style.length()
	var ch: int = style.unicode_at(idx) - 97
	return clampf(ch / 12.0, 0.0, 2.0)

func _light_cell_pos(w: float) -> float:
	var cell: float = max(light_cell, 0.05)
	return floor(w / cell) * cell + cell * 0.5

func _get_light_at(wx: float, wy: float) -> Color:
	var lr: float = floor_ambient
	var lg: float = floor_ambient
	var lb: float = floor_ambient
	var cx2: float = _light_cell_pos(wx)
	var cy2: float = _light_cell_pos(wy)
	for ls in _entity_lights:
		var dx: float = cx2 - (ls.grid_x + 0.5)
		var dy: float = cy2 - (ls.grid_y + 0.5)
		var h: float = ls.get("height", 0.0)
		var dist: float = sqrt(dx * dx + dy * dy + h * h)
		if dist >= ls.world_radius: continue
		var falloff: float = 1.0 - smoothstep(0.0, ls.world_radius, dist)
		var smod: float = _get_light_style_mod(ls.get("style", ""), ls.grid_x, ls.grid_y)
		var strength: float = falloff * ls.intensity * smod
		lr += ls.color.r * strength
		lg += ls.color.g * strength
		lb += ls.color.b * strength
	return Color(clampf(lr, 0.0, 1.0), clampf(lg, 0.0, 1.0), clampf(lb, 0.0, 1.0))

func _get_flashlight_at(wx: float, wy: float, ray_angle: float) -> Color:
	if not _flashlight_on: return Color.BLACK
	var dx: float = _light_cell_pos(wx) - cam_x
	var dy: float = _light_cell_pos(wy) - cam_y
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist > _flashlight_range: return Color.BLACK
	var angle_diff: float = abs(ray_angle - (player_angle + flashlight_aim))
	if angle_diff > PI: angle_diff = TAU - angle_diff
	var beam: float = 1.0 - smoothstep(0.35, 0.70, angle_diff)
	if beam <= 0.0: return Color.BLACK
	var dist_falloff: float = 1.0 - smoothstep(0.0, _flashlight_range, dist)
	var strength: float = beam * dist_falloff * _flashlight_intensity
	return _flashlight_color * strength

func _update_floor_lighting(ambient: float, light_sources: Array, flash_x: float = 0.0, flash_y: float = 0.0, flash_intensity: float = 0.0, flash_radius: float = 0.0, flash_color: Color = Color(1, 1, 1), flash_aim: float = 0.0):
	floor_ambient = ambient
	if not _floor_mat: return
	_floor_mat.set_shader_parameter("ambient_light", ambient)
	_floor_mat.set_shader_parameter("light_cell", light_cell)
	_floor_mat.set_shader_parameter("view_bob", bob_offset)
	var total: int = mini(light_sources.size(), 16)
	_floor_mat.set_shader_parameter("light_count", total)
	var pos_arr := PackedVector2Array()
	var rad_arr := PackedFloat32Array()
	var int_arr := PackedFloat32Array()
	var col_arr := PackedVector3Array()
	var hgt_arr := PackedFloat32Array()
	pos_arr.resize(16)
	rad_arr.resize(16)
	int_arr.resize(16)
	col_arr.resize(16)
	hgt_arr.resize(16)
	for i in total:
		var ls: Dictionary = light_sources[i]
		pos_arr[i] = Vector2(ls.grid_x + 0.5, ls.grid_y + 0.5)
		rad_arr[i] = ls.world_radius
		var smod: float = _get_light_style_mod(ls.get("style", ""), ls.grid_x, ls.grid_y)
		int_arr[i] = ls.intensity * smod
		var c: Color = ls.color
		col_arr[i] = Vector3(c.r, c.g, c.b)
		hgt_arr[i] = ls.get("height", 0.0)
	for i in range(total, 16):
		pos_arr[i] = Vector2(0, 0)
		rad_arr[i] = 0.0
		int_arr[i] = 0.0
		col_arr[i] = Vector3(0, 0, 0)
		hgt_arr[i] = 0.0
	_floor_mat.set_shader_parameter("light_pos", pos_arr)
	_floor_mat.set_shader_parameter("light_rad", rad_arr)
	_floor_mat.set_shader_parameter("light_int", int_arr)
	_floor_mat.set_shader_parameter("light_col", col_arr)
	_floor_mat.set_shader_parameter("light_height", hgt_arr)
	var flash_on: bool = flash_intensity > 0.0
	_floor_mat.set_shader_parameter("flashlight_on", flash_on)
	if flash_on:
		_floor_mat.set_shader_parameter("flashlight_pos", Vector2(flash_x + 0.5, flash_y + 0.5))
		_floor_mat.set_shader_parameter("flashlight_rad", flash_radius)
		_floor_mat.set_shader_parameter("flashlight_int", flash_intensity)
		_floor_mat.set_shader_parameter("flashlight_col", Vector3(flash_color.r, flash_color.g, flash_color.b))
	_floor_mat.set_shader_parameter("flashlight_aim", flash_aim)
	_flashlight_on = flash_on
	_flashlight_range = flash_radius
	_flashlight_intensity = flash_intensity
	_flashlight_color = flash_color

func _texture_has_alpha(tex: Texture2D) -> bool:
	if not tex: return false
	var rid := tex.get_rid().get_id()
	if _alpha_cache.has(rid): return _alpha_cache[rid]
	var img := tex.get_image()
	if not img or img.is_empty():
		_alpha_cache[rid] = false; return false
	for x in img.get_width():
		if img.get_pixel(x, 0).a < 0.99:
			_alpha_cache[rid] = true; return true
	_alpha_cache[rid] = false; return false

func _get_decal_tex(id: String) -> Texture2D:
	return _load_tex("decal/" + id)

func _fill_zbuf():
	var fov: float = deg_to_rad(90.0)
	var num_strips: int = int(float(_view_w) / _strip_w)
	_wall_zbuf.resize(num_strips)
	if map_data.is_empty(): return
	for i in range(num_strips):
		var angle: float = player_angle - fov * 0.5 + (i / float(num_strips)) * fov
		var rx: float = cos(angle); var ry: float = sin(angle)
		var mx: int = int(floor(cam_x)); var my: int = int(floor(cam_y))
		var ddx: float = INF if rx == 0 else abs(1.0 / rx); var ddy: float = INF if ry == 0 else abs(1.0 / ry)
		var step_x: int = 1 if rx > 0 else -1; var step_y: int = 1 if ry > 0 else -1
		var side_x: float = (mx + 1.0 - cam_x) * ddx if rx > 0 else (cam_x - mx) * ddx
		var side_y: float = (my + 1.0 - cam_y) * ddy if ry > 0 else (cam_y - my) * ddy
		var s: int = 0; var steps: int = int(fog_distance * 3.0) + 3; var hit := false
		while steps > 0:
			steps -= 1
			if side_x < side_y: side_x += ddx; mx += step_x; s = 0
			else: side_y += ddy; my += step_y; s = 1
			if mx < 0 or my < 0 or my >= len(map_data) or mx >= len(map_data[0]): break
			if _is_solid_cell(mx, my): hit = true; break
		_wall_zbuf[i] = (side_x - ddx if s == 0 else side_y - ddy) if hit else 999.0

func _draw():
	pass

func draw_walls(ci: CanvasItem):
	if not ci: return
	var half_h: float = _view_h / 2.0 + bob_offset
	var num_strips: int = int(float(_view_w) / _strip_w)
	if _wall_zbuf.size() != num_strips: _wall_zbuf.resize(num_strips)
	var fov: float = deg_to_rad(90.0)
	for i in range(num_strips):
		var ray_angle: float = player_angle - fov * 0.5 + (i / float(num_strips)) * fov
		var result: Dictionary = _cast_ray_skip_alpha(cam_x, cam_y, ray_angle, true)
		var perp: float = result.distance
		if perp < 0.01: perp = 0.01
		_wall_zbuf[i] = perp
		var fbl: float = 0.0
		if result.get("fog", false):
			fbl = clamp((perp - fog_distance) / fog_fade, 0.0, 1.0)
			if fbl <= 0.0: continue
			var fh: float = _view_h / perp; var ft: float = half_h - fh * 0.5
			var fc: Color = fog_color; fc.a = fbl * 0.85
			ci.draw_rect(Rect2(i * _strip_w, ft, _strip_w + 1, fh), fc)
			continue
		var wall_h: float = _view_h / perp
		var wall_top: float = half_h - wall_h * 0.5
		if perp > fog_distance - fog_fade:
			fbl = clamp((perp - (fog_distance - fog_fade)) / fog_fade, 0.0, 1.0)
		var mx: int = result.get("mx", -1); var my: int = result.get("my", -1)
		var wall_light := _get_light_at(mx + 0.5, my + 0.5)
		wall_light += _get_flashlight_at(mx + 0.5, my + 0.5, ray_angle)
		wall_light.r = clampf(wall_light.r, 0.0, 1.0)
		wall_light.g = clampf(wall_light.g, 0.0, 1.0)
		wall_light.b = clampf(wall_light.b, 0.0, 1.0)
		var cell_tex := _cell_tex(mx, my, true)
		if cell_tex:
			var wall_x: float = result.get("wall_x", 0.0)
			var tex_w: float = cell_tex.get_width(); var tex_h: float = cell_tex.get_height()
			var tex_xx: int = int(wall_x * tex_w)
			if (result.side == 0 and result.get("rdx", 0.0) > 0) or (result.side == 1 and result.get("rdy", 0.0) < 0):
				tex_xx = int(tex_w) - tex_xx - 1
			var shade: float = clamp(1.0 - perp * 0.04, 0.3, 1.0)
			if result.side == 1: shade *= 0.7
			var wcol: Color = Color(shade, shade, shade, 1.0)
			wcol = wcol.lerp(fog_color, fbl)
			wcol *= wall_light
			ci.draw_texture_rect_region(cell_tex, Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h), Rect2(tex_xx, 0, 1, tex_h), wcol)
			
			# Draw alpha wall overlays (window frames, glass)  
			for ah in result.get("alpha_hits", []):
				var atex: Texture2D = ah.get("tex", null)
				if not atex: continue
				var adist: float = ah.get("dist", perp)
				if adist < 0.01: adist = 0.01
				var awall_h: float = _view_h / adist
				var awall_top: float = half_h - awall_h * 0.5
				var awx: float = ah.get("wall_x", 0.0)
				var atex_w: float = atex.get_width(); var atex_h: float = atex.get_height()
				var atex_xx: int = int(awx * atex_w)
				if (ah.side == 0 and result.get("rdx", 0.0) > 0) or (ah.side == 1 and result.get("rdy", 0.0) < 0):
					atex_xx = int(atex_w) - atex_xx - 1
				ci.draw_texture_rect_region(atex, Rect2(i * _strip_w, awall_top, _strip_w + 1, awall_h), Rect2(atex_xx, 0, 1, atex_h), Color(1, 1, 1, 1).lerp(fog_color, fbl) * wall_light)
		else:
			var c: Color = Color(0.4, 0.4, 0.5)
			if result.side == 0: c = Color(0.3, 0.3, 0.4)
			var shade: float = clamp(1.0 - perp * 0.04, 0.2, 1.0)
			shade = lerp(shade, 0.0, fbl); c *= shade
			c *= wall_light
			ci.draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h), c)
		
		var dkey := "%d,%d" % [mx, my]
		if wall_decors.has(dkey):
			var raw: Variant = wall_decors[dkey]
			if not raw is Array: continue
			var decals: Array = raw
			for dec in decals:
				var did: String = dec.get("id", "")
				if did.is_empty(): continue
				var tex := _get_decal_tex(did)
				if not tex: continue
				var d_offset: float = dec.get("offset", 0.5)
				var d_height: float = dec.get("height", 0.2)
				var d_scale: float = dec.get("scale", 1.0)
				var wx: float = result.get("wall_x", 0.0)
				var dx: float = i * _strip_w + (wx - d_offset) * _strip_w * 2.0
				if dx < -100 or dx > _view_w + 100: continue
				var ds: float = wall_h * d_scale * 0.8
				var dy: float = wall_top + wall_h * (1.0 - d_height) - ds * 0.5
				var dcol: Color = Color(1, 1, 1, 1)
				dcol = dcol.lerp(fog_color, fbl)
				dcol *= wall_light
				ci.draw_texture_rect(tex, Rect2(dx, dy, ds, ds), false, dcol)

func _cast_ray(ox: float, oy: float, angle: float) -> Dictionary:
	return _cast_ray_skip_alpha(ox, oy, angle, false)

func _cast_ray_skip_alpha(ox: float, oy: float, angle: float, skip_alpha: bool) -> Dictionary:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var map_x: int = int(floor(ox)); var map_y: int = int(floor(oy))
	var delta_x: float = INF if dir.x == 0 else abs(1.0 / dir.x); var delta_y: float = INF if dir.y == 0 else abs(1.0 / dir.y)
	var step_x: int = 1 if dir.x > 0 else -1; var step_y: int = 1 if dir.y > 0 else -1
	var side_x: float = (map_x + 1.0 - ox) * delta_x if dir.x > 0 else (ox - map_x) * delta_x
	var side_y: float = (map_y + 1.0 - oy) * delta_y if dir.y > 0 else (oy - map_y) * delta_y
	var side: int = 0; var steps: int = int(fog_distance * 3.0) + 3
	var alpha_hits: Array = []
	while steps > 0:
		steps -= 1
		if side_x < side_y: side_x += delta_x; map_x += step_x; side = 0
		else: side_y += delta_y; map_y += step_y; side = 1
		if map_data.is_empty() or map_x < 0 or map_y < 0 or map_y >= len(map_data) or map_x >= len(map_data[0]): break
		if _is_solid_cell(map_x, map_y):
			if skip_alpha:
				var tex: Texture2D = _cell_tex(map_x, map_y, true)
				if tex and _texture_has_alpha(tex):
					var sp: float = side_x - delta_x if side == 0 else side_y - delta_y
					var wx: float = oy + sp * dir.y if side == 0 else ox + sp * dir.x
					wx -= floor(wx)
					var tx_c: int = int(wx * tex.get_width())
					if (side == 0 and dir.x > 0) or (side == 1 and dir.y < 0): tx_c = tex.get_width() - tx_c - 1
					if _tex_alpha_at(tex, tx_c) < 0.5:
						alpha_hits.append({"side":side,"wall_x":wx,"mx":map_x,"my":map_y,"tex":tex,"dist":sp})
						continue
			break
	var perp: float = side_x - delta_x if side == 0 else side_y - delta_y
	if perp < 0.0: perp = 0.0
	if perp > fog_distance * 1.5: return {"hit":false,"distance":fog_distance*1.5,"fog":true,"alpha_hits":alpha_hits}
	var wall_x: float = oy + perp * dir.y if side == 0 else ox + perp * dir.x
	wall_x -= floor(wall_x)
	return {"hit":true,"distance":perp,"fog":false,"side":side,"wall_x":wall_x,"rdx":dir.x,"rdy":dir.y,"mx":map_x,"my":map_y,"alpha_hits":alpha_hits}

func _tex_alpha_at(tex: Texture2D, col: int) -> float:
	var rid := tex.get_rid().get_id()
	var key := "%d_%d" % [rid, col]
	if _alpha_cache.has(key): return _alpha_cache[key]
	var img := tex.get_image()
	if not img or img.is_empty(): return 1.0
	var cx: int = clamp(col, 0, img.get_width() - 1)
	var a: float = img.get_pixel(cx, img.get_height() / 2).a
	_alpha_cache[key] = a
	return a

var _visible_entities: Array = []

func get_visible_entities() -> Array:
	return _visible_entities

func _project_entities():
	_visible_entities.clear()
	if entities_on_map.is_empty(): return
	var half_h: float = _view_h / 2.0 + bob_offset
	var dir_x: float = cos(player_angle); var dir_y: float = sin(player_angle)
	var plane_x: float = -dir_y; var plane_y: float = dir_x
	var inv_det: float = 1.0 / (plane_x * dir_y - dir_x * plane_y)
	for ent: Dictionary in entities_on_map:
		var sx2: float = ent.grid_x + 0.5 - cam_x + ent.get("visual_offset_x", 0.0); var sy2: float = ent.grid_y + 0.5 - cam_y + ent.get("visual_offset_y", 0.0)
		var dist: float = sqrt(sx2 * sx2 + sy2 * sy2)
		if dist < 0.01: continue
		var tx: float = inv_det * (dir_y * sx2 - dir_x * sy2); var ty: float = inv_det * (-plane_y * sx2 + plane_x * sy2)
		if ty <= 0.01: continue
		var scx: int = int((_view_w / 2.0) * (1.0 + tx / ty))
		if scx < -_view_w or scx >= _view_w * 2: continue
		var scale_h: float = _view_h / (ty * 1.2)
		var is_floor: bool = ent.get("object_type", "") == "floor_decal"
		if is_floor:
			scale_h *= ent.get("size", 0.15)
		elif ent.has("size"):
			scale_h *= ent.get("size", 1.0)
		var tex: Texture2D = _get_ent_texture(ent)
		var spw: float = scale_h; var texw: float = 1.0; var texh: float = 1.0
		if tex: texw = tex.get_width(); texh = tex.get_height(); spw = scale_h * texw / texh
		var dx1: int = max(0, int(scx - spw * 0.5)); var dx2: int = min(_view_w, int(scx + spw * 0.5))
		var feety: float = half_h + half_h / ty
		var spy: float = feety - (scale_h * 0.5 if is_floor else scale_h)
		var ceiling_lift: float = ent.get("ceiling_lift", 0.0)
		if ceiling_lift > 0.0:
			var wall_h_px: float = 2.0 * half_h / ty
			spy -= wall_h_px * ceiling_lift
		var floating: bool = ent.get("data", {}).get("floating", false)
		if floating and not is_floor:
			var proximity: float = clamp(2.0 - dist, 0.0, 2.0) / 2.0
			if proximity > 0.01:
				var lift: float = proximity * 120.0
				var bob: float = sin(Time.get_ticks_msec() * 0.004) * 12.0 * proximity
				spy -= lift + bob
		_visible_entities.append({"ent":ent,"depth":ty,"dist":dist,"dx1":dx1,"dx2":dx2,"spy":spy,"spw":spw,"sph":scale_h,"scx":scx,"tex":tex,"texw":texw,"texh":texh,"col":ent.get("color",Color.WHITE)})
	var sorter: Callable = func(a: Dictionary, b: Dictionary): return a.depth > b.depth
	_visible_entities.sort_custom(sorter)
	if _visible_entities.size() > 0:
		pass

func draw_entities(ci: CanvasItem):
	if not ci: return
	var num_strips: int = int(float(_view_w) / _strip_w)
	for ve in _visible_entities:
		var ss: int = int(ve.dx1 / _strip_w); var se: int = int((ve.dx2 + _strip_w - 1) / _strip_w)
		var fog_blend: float = clamp((ve.dist - (fog_distance - fog_fade)) / fog_fade, 0.0, 1.0)
		var fog_mod: Color = Color.WHITE.lerp(fog_color, fog_blend); fog_mod.a = 1.0
		var ent: Dictionary = ve.get("ent", {})
		var ent_ex: float = ent.get("grid_x", -1) + 0.5
		var ent_ey: float = ent.get("grid_y", -1) + 0.5
		if ent_ex >= 0.0 and ent_ey >= 0.0:
			var ent_light := _get_light_at(ent_ex, ent_ey)
			var ent_angle: float = atan2(ent_ey - cam_y, ent_ex - cam_x)
			ent_light += _get_flashlight_at(ent_ex, ent_ey, ent_angle)
			ent_light.r = clampf(ent_light.r, 0.0, 1.0)
			ent_light.g = clampf(ent_light.g, 0.0, 1.0)
			ent_light.b = clampf(ent_light.b, 0.0, 1.0)
			fog_mod *= ent_light

		for si in range(ss, se):
			if si >= num_strips: break
			if ve.depth >= _wall_zbuf[si]: continue
			var px2: int = si * _strip_w
			if ve.tex and ve.spw > 1.0:
				var sc: float = px2 + _strip_w * 0.5; var u: float = (sc - (ve.scx - ve.spw * 0.5)) / ve.spw
				var rx2: float = u * ve.texw; var rw: float = max(1.0, ve.texw / ve.spw * _strip_w)
				ci.draw_texture_rect_region(ve.tex, Rect2(px2, ve.spy, _strip_w+1, ve.sph), Rect2(rx2, 0, rw, ve.texh), fog_mod)
			else:
				ci.draw_rect(Rect2(px2, ve.spy, _strip_w+1, ve.sph), ve.col.lerp(fog_color, fog_blend))
	
	# Hover highlight — contour outline via alpha edge detection
	if hovered_grid.x >= 0:
		for ve in _visible_entities:
			var ent: Dictionary = ve.get("ent", {})
			if ent.get("grid_x", -1) == hovered_grid.x and ent.get("grid_y", -1) == hovered_grid.y:
				var tex: Texture2D = ve.get("tex", null)
				if tex:
					var otex := _get_outline_tex(tex)
					ci.draw_texture_rect_region(otex,
						Rect2(ve.scx - ve.spw * 0.5, ve.spy, ve.spw, ve.sph),
						Rect2(0, 0, ve.texw, ve.texh),
						Color(1, 1, 1, 0.9))
				else:
					var hx: float = ve.get("dx1", 0.0)
					var hy: float = ve.get("spy", 0.0)
					var hw: float = ve.get("dx2", hx) - hx
					var hh: float = ve.get("sph", 0.0)
					ci.draw_rect(Rect2(hx - 2, hy - 2, hw + 4, hh + 4), Color(1, 1, 1, 0.9), false, 2.0)
				break

func draw_fog_overlay(ci: CanvasItem):
	if not ci: return
	var depth: float = _view_w * 0.35
	for x in range(int(depth)):
		var a: float = clamp(1.0 - float(x) / depth, 0.0, 1.0) * 0.5
		if a <= 0.0: break
		ci.draw_rect(Rect2(x, 0, 1, _view_h), Color(0, 0, 0, a))
		ci.draw_rect(Rect2(_view_w - x - 1, 0, 1, _view_h), Color(0, 0, 0, a))
	for y in range(int(depth * 0.5)):
		var a: float = clamp(1.0 - float(y) / (depth * 0.5), 0.0, 1.0) * 0.5
		if a <= 0.0: break
		ci.draw_rect(Rect2(0, y, _view_w, 1), Color(0, 0, 0, a))
		ci.draw_rect(Rect2(0, _view_h - y - 1, _view_w, 1), Color(0, 0, 0, a))

func draw_floor_dust(ci: CanvasItem):
	if not ci or not floor_dust: return
	if not floor_dust.has_method("get_specks_in_range"): return
	var num_strips: int = _wall_zbuf.size()
	if num_strips <= 0: return
	var specks: Array = floor_dust.get_specks_in_range(cam_x, cam_y, fog_distance)
	if specks.is_empty(): return
	var half_h: float = _view_h * 0.5 + bob_offset
	var dir_x: float = cos(player_angle)
	var dir_y: float = sin(player_angle)
	var plane_x: float = -dir_y
	var plane_y: float = dir_x
	var inv_det: float = 1.0 / (plane_x * dir_y - dir_x * plane_y)
	var dust_color: Color = Color(0.7, 0.65, 0.6)
	var puff_spread: float = 12.0
	var puff_dur: float = 0.6
	var c_val = floor_dust.get("color")
	if c_val != null: dust_color = c_val
	var s_val = floor_dust.get("puff_spread")
	if s_val != null: puff_spread = s_val
	var d_val = floor_dust.get("puff_duration")
	if d_val != null: puff_dur = d_val
	for entry in specks:
		var s: Dictionary = entry.speck
		var wx: float = float(entry.tile_x) + s.ox
		var wy: float = float(entry.tile_y) + s.oy
		var puff_prog: float = 0.0
		if s.state == "puffing":
			puff_prog = s.puff_timer / puff_dur
			wx += s.puff_dir_x * puff_prog * puff_spread
			wy += s.puff_dir_y * puff_prog * puff_spread
		var sx: float = wx - cam_x
		var sy: float = wy - cam_y
		var tx: float = inv_det * (dir_y * sx - dir_x * sy)
		var ty: float = inv_det * (-plane_y * sx + plane_x * sy)
		if ty <= 0.02: continue
		var scx: int = int(_view_w * 0.5 * (1.0 + tx / ty))
		if scx < -_strip_w or scx >= _view_w + _strip_w: continue
		var si: int = clampi(int(scx / _strip_w), 0, num_strips - 1)
		if ty >= _wall_zbuf[si]: continue
		var fog_blend: float = clamp((ty - (fog_distance - fog_fade)) / fog_fade, 0.0, 1.0)
		if fog_blend >= 1.0: continue
		var scale_h: float = _view_h / (ty * 1.2) * (s.sz / 50.0)
		if scale_h < 0.3: continue
		var feety: float = half_h + half_h / ty
		var spy: float = feety - scale_h * 0.5
		var speck_a: float = s.alpha
		if puff_prog > 0.0:
			speck_a *= 1.0 - puff_prog
		var c: Color = dust_color
		c = c.lerp(fog_color, fog_blend)
		c.a = clamp(speck_a * (1.0 - fog_blend), 0.0, 1.0)
		if c.a <= 0.01: continue
		ci.draw_rect(Rect2(scx - scale_h * 0.5, spy, max(scale_h, 0.5), max(scale_h, 0.5)), c)

func _get_ent_texture(ent: Dictionary) -> Texture2D:
	var texs: Dictionary = ent.get("textures", {})
	if texs.is_empty(): return ent.get("texture", null)
	if ent.get("chase_active", false): var chase: Texture2D = texs.get("chase",null); if chase: return chase
	var ex: float = ent.get("anim_x", float(ent.grid_x)) + ent.get("visual_offset_x", 0.0)
	var ey: float = ent.get("anim_y", float(ent.grid_y)) + ent.get("visual_offset_y", 0.0)
	var dx: float = cam_x - (ex + 0.5); var dy: float = cam_y - (ey + 0.5); var va: float = atan2(dy, dx)
	var fi: int = ent.get("facing", 2); var ea: float = [-PI/2,0,PI/2,PI][fi]; var di: float = va - ea
	while di > PI: di -= TAU; while di < -PI: di += TAU
	match posmod(int(round(di / (PI * 0.5))), 4):
		0: return texs.get("front", null)
		1: return texs.get("right", null)
		2: return texs.get("back", null)
		_: return texs.get("left", null)

func update_view(cx: float, cy: float, angle: float, map: Array, entities: Array):
	cam_x = cx; cam_y = cy; player_angle = angle
	map_data = map; entities_on_map = entities
	if map_data.is_empty(): return
	_update_floor_shader()
	if _map_w != map_data[0].size() or _map_h != map_data.size() or not _map_tex:
		_fill_map_tex()
	_project_entities()
	_fill_zbuf()
	if _wall_ctrl:
		_wall_ctrl.queue_redraw()

func queue_redraw_walls():
	if _wall_ctrl: _wall_ctrl.queue_redraw()

func precache_outlines(entities: Array):
	for ent in entities:
		var tex: Texture2D
		var texs: Dictionary = ent.get("textures", {})
		if not texs.is_empty():
			for t in texs.values():
				if t is Texture2D: _get_outline_tex(t)
		else:
			tex = ent.get("texture", null)
			if tex: _get_outline_tex(tex)

func update_height(data: Array):
	height_data = data
	_fill_map_tex()
