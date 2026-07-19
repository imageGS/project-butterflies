extends Control

const TILE_WALL: int = 1
const TILE_BLOCKED: int = 6

var cam_x: float = 1.5
var cam_y: float = 1.5
var player_angle: float = 0.0
var map_data: Array[Array] = []
var height_data: Array[Array] = []

var entities_on_map: Array[Dictionary] = []

var fog_distance: float = 7.0
var fog_fade: float = 2.5
var fog_color: Color = Color(0.08, 0.08, 0.08)

var _view_w: int = 0
var _view_h: int = 0
var _strip_w: int = 4
var _wall_zbuf: Array[float] = []

var _wall_tex: Texture2D = preload("res://assets/textures/wall.png")
var _rail_tex: Texture2D = preload("res://assets/textures/rails.png")
var _floor_tex: Texture2D = preload("res://assets/textures/floor.png")

var _floor_ctrl: ColorRect
var _wall_canvas: Control

var _map_img: Image
var _map_tex: ImageTexture
var _map_w: int = 0
var _map_h: int = 0
var _floor_mat: ShaderMaterial

func _ready():
	_view_w = max(1, int(size.x))
	_view_h = max(1, int(size.y))

	_floor_ctrl = ColorRect.new()
	_floor_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := load("res://shaders/floor_shader.gdshader") as Shader
	if shader:
		_floor_mat = ShaderMaterial.new()
		_floor_mat.shader = shader
		_floor_mat.set_shader_parameter("floor_tex", _floor_tex)
		_floor_mat.set_shader_parameter("rail_tex", _rail_tex)
		_floor_ctrl.material = _floor_mat
	add_child(_floor_ctrl)

	_wall_canvas = Control.new()
	_wall_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wall_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wall_canvas.set_script(preload("res://scripts/dungeon/wall_canvas.gd"))
	_wall_canvas.renderer = self
	add_child(_wall_canvas)

func _build_map_tex():
	if map_data.is_empty(): return
	_map_w = map_data[0].size()
	_map_h = map_data.size()
	_map_img = Image.create(_map_w, _map_h, false, Image.FORMAT_RGBA8)
	for y in _map_h:
		for x in _map_w:
			var is_wall: bool = map_data[y][x] == TILE_WALL or map_data[y][x] == TILE_BLOCKED
			var fh: float = height_data[y][x] if y < height_data.size() and x < height_data[y].size() else 0.0
			_map_img.set_pixel(x, y, Color(1.0 if is_wall else 0.0, (fh + 2.0) / 4.0, 0.0, 1.0))
	_map_tex = ImageTexture.create_from_image(_map_img)
	if _floor_mat:
		_floor_mat.set_shader_parameter("map_tex", _map_tex)
		_floor_mat.set_shader_parameter("map_w", _map_w)
		_floor_mat.set_shader_parameter("map_h", _map_h)

func _push_floor_uniforms():
	if not _floor_mat: return
	_floor_mat.set_shader_parameter("cam_pos", Vector2(cam_x, cam_y))
	_floor_mat.set_shader_parameter("cam_angle", player_angle)
	_floor_mat.set_shader_parameter("view_size", Vector2(_view_w, _view_h))
	_floor_mat.set_shader_parameter("fog_dist", fog_distance)
	_floor_mat.set_shader_parameter("fog_fade", fog_fade)
	_floor_mat.set_shader_parameter("fog_color", fog_color)

func update_view(cx: float, cy: float, angle: float, map: Array, entities: Array):
	cam_x = cx; cam_y = cy; player_angle = angle
	map_data = map; entities_on_map = entities
	_push_floor_uniforms()
	if _map_w != map_data[0].size() or _map_h != map_data.size() or not _map_tex:
		_build_map_tex()
	if _wall_canvas:
		_wall_canvas.queue_redraw()

func update_height(data: Array):
	height_data = data
	_build_map_tex()

# ---------------------------------------------------------------------------
# Wall renderer
# ---------------------------------------------------------------------------

func draw_ceiling(ci: CanvasItem):
	var half_h: float = _view_h * 0.5
	for y in range(int(half_h)):
		var t: float = float(y) / float(_view_h)
		var c: Color = Color(0.03, 0.03, 0.04).lerp(Color(0.0, 0.0, 0.0), t * 2.0)
		ci.draw_rect(Rect2(0, y, _view_w, 1), c)

func draw_walls(ci: CanvasItem):
	var half_h: float = _view_h * 0.5
	var num_strips: int = int(float(_view_w) / _strip_w)
	var fov: float = deg_to_rad(90.0)
	var fov_half: float = fov * 0.5
	var fog_limit: float = fog_distance + fog_fade

	_wall_zbuf.resize(num_strips)

	for i in range(num_strips):
		var ray_angle: float = player_angle - fov_half + (i / float(num_strips)) * fov
		var dir := Vector2(cos(ray_angle), sin(ray_angle))
		var map_x: int = int(floor(cam_x))
		var map_y: int = int(floor(cam_y))
		var delta_x: float = INF if dir.x == 0 else abs(1.0 / dir.x)
		var delta_y: float = INF if dir.y == 0 else abs(1.0 / dir.y)
		var step_x: int = 1 if dir.x > 0 else -1
		var step_y: int = 1 if dir.y > 0 else -1
		var side_x: float = (map_x + 1.0 - cam_x) * delta_x if dir.x > 0 else (cam_x - map_x) * delta_x
		var side_y: float = (map_y + 1.0 - cam_y) * delta_y if dir.y > 0 else (cam_y - map_y) * delta_y
		var side: int = 0
		var steps: int = int(fog_limit) + 3

		while steps > 0:
			steps -= 1
			if side_x < side_y:
				side_x += delta_x; map_x += step_x; side = 0
			else:
				side_y += delta_y; map_y += step_y; side = 1
			if map_x < 0 or map_y < 0 or map_y >= len(map_data) or map_x >= len(map_data[0]):
				break
			if map_data[map_y][map_x] == TILE_WALL or map_data[map_y][map_x] == TILE_BLOCKED:
				break

		var perp: float = side_x - delta_x if side == 0 else side_y - delta_y
		if perp < 0.01: perp = 0.01
		_wall_zbuf[i] = perp

		# fog check — if beyond fog range, draw fog column and skip
		if perp > fog_limit:
			var fbl: float = clamp((perp - fog_distance) / fog_fade, 0.0, 1.0)
			if fbl <= 0.0: continue
			var fh: float = _view_h / perp
			var ft: float = half_h - fh * 0.5
			var fc: Color = fog_color; fc.a = fbl * 0.85
			ci.draw_rect(Rect2(i * _strip_w, ft, _strip_w + 1, fh), fc)
			continue

		var wall_h: float = _view_h / perp
		var wall_top: float = half_h - wall_h * 0.5

		# fog blend
		var fog_blend: float = 0.0
		if perp > fog_distance:
			fog_blend = clamp((perp - fog_distance) / fog_fade, 0.0, 1.0)

		if not _wall_tex:
			var c: Color = Color(0.4, 0.4, 0.5)
			if side == 0: c = Color(0.3, 0.3, 0.4)
			var shade: float = clamp(1.0 - perp * 0.04, 0.2, 1.0)
			shade = lerp(shade, 0.0, fog_blend)
			ci.draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h), c * shade)
			continue

		# textured wall
		var wall_x_frac: float
		if side == 0:
			wall_x_frac = cam_y + perp * dir.y
		else:
			wall_x_frac = cam_x + perp * dir.x
		wall_x_frac -= floor(wall_x_frac)

		var tex_w: float = _wall_tex.get_width()
		var tex_h: float = _wall_tex.get_height()
		var tex_xx: int = int(wall_x_frac * tex_w)
		if (side == 0 and dir.x > 0) or (side == 1 and dir.y < 0):
			tex_xx = int(tex_w) - tex_xx - 1

		var shade: float = clamp(1.0 - perp * 0.04, 0.3, 1.0)
		if side == 1: shade *= 0.7
		shade = lerp(shade, 0.0, fog_blend)

		ci.draw_texture_rect_region(
			_wall_tex,
			Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h),
			Rect2(tex_xx, 0, 1, tex_h),
			Color(shade, shade, shade))

func draw_entities(ci: CanvasItem):
	var half_h: float = _view_h * 0.5
	var num_strips: int = int(float(_view_w) / _strip_w)
	var dir_x: float = cos(player_angle)
	var dir_y: float = sin(player_angle)
	var plane_x: float = -dir_y
	var plane_y: float = dir_x
	var inv_det: float = 1.0 / (plane_x * dir_y - dir_x * plane_y)

	var visible: Array[Dictionary] = []

	for ent: Dictionary in entities_on_map:
		var sx2: float = ent.grid_x + 0.5 - cam_x
		var sy2: float = ent.grid_y + 0.5 - cam_y
		var dist: float = sqrt(sx2 * sx2 + sy2 * sy2)
		if dist < 0.01: continue

		var tx: float = inv_det * (dir_y * sx2 - dir_x * sy2)
		var ty: float = inv_det * (-plane_y * sx2 + plane_x * sy2)
		if ty <= 0.01: continue

		var scx: int = int((_view_w * 0.5) * (1.0 + tx / ty))
		if scx < -_view_w or scx >= _view_w * 2: continue

		var scale_h: float = _view_h / (ty * 1.2)
		var tex: Texture2D = _get_ent_texture(ent)
		var spw: float = scale_h
		var texw: float = 1.0
		var texh: float = 1.0
		if tex:
			texw = tex.get_width()
			texh = tex.get_height()
			spw = scale_h * texw / texh

		var dx1: int = max(0, int(scx - spw * 0.5))
		var dx2: int = min(_view_w, int(scx + spw * 0.5))
		var feety: float = half_h + half_h / ty
		var spy: float = feety - scale_h

		visible.append({
			depth = ty,
			dist = dist,
			dx1 = dx1, dx2 = dx2,
			spy = spy, spw = spw, sph = scale_h,
			scx = scx,
			tex = tex, texw = texw, texh = texh,
			col = ent.get("color", Color.WHITE)
		})

	visible.sort_custom(func(a, b): return a.depth > b.depth)

	for ve in visible:
		var ss: int = int(ve.dx1 / _strip_w)
		var se: int = int((ve.dx2 + _strip_w - 1) / _strip_w)
		var fog_blend: float = clamp((ve.dist - (fog_distance - fog_fade)) / fog_fade, 0.0, 1.0)
		var fog_mod: Color = Color.WHITE.lerp(fog_color, fog_blend); fog_mod.a = 1.0

		for si in range(ss, se):
			if si >= num_strips: break
			if si >= _wall_zbuf.size(): break
			if ve.depth >= _wall_zbuf[si]: continue

			var px2: int = si * _strip_w
			if ve.tex and ve.spw > 1.0:
				var sc: float = px2 + _strip_w * 0.5
				var u: float = (sc - (ve.scx - ve.spw * 0.5)) / ve.spw
				var rx2: float = u * ve.texw
				var rw: float = max(1.0, ve.texw / ve.spw * _strip_w)
				ci.draw_texture_rect_region(
					ve.tex,
					Rect2(px2, ve.spy, _strip_w + 1, ve.sph),
					Rect2(rx2, 0, rw, ve.texh),
					fog_mod)
			else:
				ci.draw_rect(Rect2(px2, ve.spy, _strip_w + 1, ve.sph),
					ve.col.lerp(fog_color, fog_blend))

func draw_overlay(ci: CanvasItem):
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
	if ent.get("chase_active", false):
		var chase: Texture2D = texs.get("chase", null)
		if chase: return chase
	var ex: float = ent.get("anim_x", float(ent.grid_x))
	var ey: float = ent.get("anim_y", float(ent.grid_y))
	var dx: float = cam_x - (ex + 0.5)
	var dy: float = cam_y - (ey + 0.5)
	var va: float = atan2(dy, dx)
	var fi: int = ent.get("facing", 2)
	var ea: float = [-PI / 2, 0, PI / 2, PI][fi]
	var di: float = va - ea
	while di > PI: di -= TAU
	while di < -PI: di += TAU
	match posmod(int(round(di / (PI * 0.5))), 4):
		0: return texs.get("front", null)
		1: return texs.get("right", null)
		2: return texs.get("back", null)
		_: return texs.get("left", null)
