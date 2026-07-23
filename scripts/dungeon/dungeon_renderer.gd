extends Control

const TILE_WALL: int = 1
const TILE_BLOCKED: int = 6

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

func get_wall_cell_at_strip(strip: int) -> Vector2i:
	if strip < 0 or strip >= _wall_zbuf.size(): return Vector2i(-1, -1)
	var perp: float = _wall_zbuf[strip]
	if perp >= fog_distance: return Vector2i(-1, -1)
	# Recast to get cell position
	var fov: float = deg_to_rad(90.0)
	var num_strips: int = _wall_zbuf.size()
	var angle: float = player_angle - fov * 0.5 + (strip / float(num_strips)) * fov
	var result: Dictionary = _cast_ray(cam_x, cam_y, angle)
	return Vector2i(result.get("mx", -1), result.get("my", -1))

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
			var is_wall: bool = map_data[y][x] == TILE_WALL or map_data[y][x] == TILE_BLOCKED
			var fh: float = height_data[y][x] if y < height_data.size() and x < height_data[y].size() else 0.0
			_map_img.set_pixel(x, y, Color(1.0 if is_wall else 0.0, (fh + 2.0) / 4.0, 0, 1))
	_map_tex = ImageTexture.create_from_image(_map_img)
	if _floor_mat:
		_floor_mat.set_shader_parameter("map_tex", _map_tex)
		_floor_mat.set_shader_parameter("map_w", _map_w)
		_floor_mat.set_shader_parameter("map_h", _map_h)

func _update_floor_shader():
	if not _floor_mat: return
	_floor_mat.set_shader_parameter("cam_pos", Vector2(cam_x, cam_y))
	_floor_mat.set_shader_parameter("cam_angle", player_angle)
	_floor_mat.set_shader_parameter("view_size", Vector2(_view_w, _view_h))
	_floor_mat.set_shader_parameter("fog_dist", fog_distance)
	_floor_mat.set_shader_parameter("fog_fade", fog_fade)
	_floor_mat.set_shader_parameter("fog_color", fog_color)

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
			if map_data[my][mx] == TILE_WALL or map_data[my][mx] == TILE_BLOCKED: hit = true; break
		_wall_zbuf[i] = (side_x - ddx if s == 0 else side_y - ddy) if hit else 999.0

func _draw():
	pass

func draw_walls(ci: CanvasItem):
	if not ci: return
	var half_h: float = _view_h / 2.0
	var num_strips: int = int(float(_view_w) / _strip_w)
	if _wall_zbuf.size() != num_strips: _wall_zbuf.resize(num_strips)
	var fov: float = deg_to_rad(90.0)
	for i in range(num_strips):
		var ray_angle: float = player_angle - fov * 0.5 + (i / float(num_strips)) * fov
		var result: Dictionary = _cast_ray(cam_x, cam_y, ray_angle)
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
		var cell_tex := _cell_tex(mx, my, true)
		if cell_tex:
			var wall_x: float = result.get("wall_x", 0.0)
			var tex_w: float = cell_tex.get_width(); var tex_h: float = cell_tex.get_height()
			var tex_xx: int = int(wall_x * tex_w)
			if (result.side == 0 and result.get("rdx", 0.0) > 0) or (result.side == 1 and result.get("rdy", 0.0) < 0):
				tex_xx = int(tex_w) - tex_xx - 1
			var shade: float = clamp(1.0 - perp * 0.04, 0.3, 1.0)
			if result.side == 1: shade *= 0.7
			var has_alpha := _texture_has_alpha(cell_tex)
			var wcol: Color = Color(shade, shade, shade, 0.5 if has_alpha else 1.0)
			wcol = wcol.lerp(fog_color, fbl)
			ci.draw_texture_rect_region(cell_tex, Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h), Rect2(tex_xx, 0, 1, tex_h), wcol)
		else:
			var c: Color = Color(0.4, 0.4, 0.5)
			if result.side == 0: c = Color(0.3, 0.3, 0.4)
			var shade: float = clamp(1.0 - perp * 0.04, 0.2, 1.0)
			shade = lerp(shade, 0.0, fbl); c *= shade
			ci.draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h), c)
		
		var dkey := "%d,%d" % [result.get("mx", -1), result.get("my", -1)]
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
				ci.draw_texture_rect(tex, Rect2(dx, dy, ds, ds), false, dcol)

func _cast_ray(ox: float, oy: float, angle: float) -> Dictionary:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var map_x: int = int(floor(ox)); var map_y: int = int(floor(oy))
	var delta_x: float = INF if dir.x == 0 else abs(1.0 / dir.x); var delta_y: float = INF if dir.y == 0 else abs(1.0 / dir.y)
	var step_x: int = 1 if dir.x > 0 else -1; var step_y: int = 1 if dir.y > 0 else -1
	var side_x: float = (map_x + 1.0 - ox) * delta_x if dir.x > 0 else (ox - map_x) * delta_x
	var side_y: float = (map_y + 1.0 - oy) * delta_y if dir.y > 0 else (oy - map_y) * delta_y
	var side: int = 0; var steps: int = int(fog_distance * 3.0) + 3
	while steps > 0:
		steps -= 1
		if side_x < side_y: side_x += delta_x; map_x += step_x; side = 0
		else: side_y += delta_y; map_y += step_y; side = 1
		if map_data.is_empty() or map_x < 0 or map_y < 0 or map_y >= len(map_data) or map_x >= len(map_data[0]): break
		if map_data[map_y][map_x] == TILE_WALL or map_data[map_y][map_x] == TILE_BLOCKED: break
	var perp: float = side_x - delta_x if side == 0 else side_y - delta_y
	if perp < 0.0: perp = 0.0
	if perp > fog_distance * 1.5: return {"hit":false,"distance":fog_distance*1.5,"fog":true}
	var wall_x: float = oy + perp * dir.y if side == 0 else ox + perp * dir.x
	wall_x -= floor(wall_x)
	return {"hit":true,"distance":perp,"fog":false,"side":side,"wall_x":wall_x,"rdx":dir.x,"rdy":dir.y,"mx":map_x,"my":map_y}

var _visible_entities: Array = []

func get_visible_entities() -> Array:
	return _visible_entities

func draw_entities(ci: CanvasItem):
	if not ci: return
	var half_h: float = _view_h / 2.0
	var num_strips: int = int(float(_view_w) / _strip_w)
	var dir_x: float = cos(player_angle); var dir_y: float = sin(player_angle)
	var plane_x: float = -dir_y; var plane_y: float = dir_x
	var inv_det: float = 1.0 / (plane_x * dir_y - dir_x * plane_y)

	var visible_positions: Array = []
	for ent: Dictionary in entities_on_map:
		var sx2: float = ent.grid_x + 0.5 - cam_x; var sy2: float = ent.grid_y + 0.5 - cam_y
		var dist: float = sqrt(sx2 * sx2 + sy2 * sy2)
		if dist < 0.01: continue
		var tx: float = inv_det * (dir_y * sx2 - dir_x * sy2); var ty: float = inv_det * (-plane_y * sx2 + plane_x * sy2)
		if ty <= 0.01: continue
		var scx: int = int((_view_w / 2.0) * (1.0 + tx / ty))
		if scx < -_view_w or scx >= _view_w * 2: continue
		var scale_h: float = _view_h / (ty * 1.2)
		var is_floor: bool = ent.get("object_type", "") == "floor_decal"
		if is_floor:
			var sz: float = ent.get("size", 0.15)
			scale_h *= sz
		var tex: Texture2D = _get_ent_texture(ent)
		var spw: float = scale_h; var texw: float = 1.0; var texh: float = 1.0
		if tex: texw = tex.get_width(); texh = tex.get_height(); spw = scale_h * texw / texh
		var dx1: int = max(0, int(scx - spw * 0.5)); var dx2: int = min(_view_w, int(scx + spw * 0.5))
		var feety: float = half_h + half_h / ty
		var spy: float = feety - (scale_h * 0.5 if is_floor else scale_h)
		visible_positions.append({"ent":ent,"depth":ty,"dist":dist,"dx1":dx1,"dx2":dx2,"spy":spy,"spw":spw,"sph":scale_h,"scx":scx,"tex":tex,"texw":texw,"texh":texh,"col":ent.get("color",Color.WHITE)})

	var sorter: Callable = func(a: Dictionary, b: Dictionary): return a.depth > b.depth
	visible_positions.sort_custom(sorter)
	_visible_entities = visible_positions

	for ve in visible_positions:
		var ss: int = int(ve.dx1 / _strip_w); var se: int = int((ve.dx2 + _strip_w - 1) / _strip_w)
		var fog_blend: float = clamp((ve.dist - (fog_distance - fog_fade)) / fog_fade, 0.0, 1.0)
		var fog_mod: Color = Color.WHITE.lerp(fog_color, fog_blend); fog_mod.a = 1.0
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

func _get_ent_texture(ent: Dictionary) -> Texture2D:
	var texs: Dictionary = ent.get("textures", {})
	if texs.is_empty(): return ent.get("texture", null)
	if ent.get("chase_active", false): var chase: Texture2D = texs.get("chase",null); if chase: return chase
	var ex: float = ent.get("anim_x", float(ent.grid_x)); var ey: float = ent.get("anim_y", float(ent.grid_y))
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
	_fill_zbuf()
	if _wall_ctrl:
		_wall_ctrl.queue_redraw()

func update_height(data: Array):
	height_data = data
	_fill_map_tex()
