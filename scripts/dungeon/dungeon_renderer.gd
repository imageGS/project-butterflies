extends Control

const TILE_WALL: int = 1
const TILE_BLOCKED: int = 6

var cam_x: float = 1.5
var cam_y: float = 1.5
var player_angle: float = 0.0
var map_data: Array = []
var sector_map: SectorMap

var _view_w: int = 0
var _view_h: int = 0
var _strip_w: int = 4
var _wall_zbuf: Array[float] = []

var entities_on_map: Array = []
var _wall_tex: Texture2D = load("res://assets/textures/wall.png")
var _floor_tex: Texture2D = load("res://assets/textures/floor.png")
var _rail_tex: Texture2D = load("res://assets/textures/rails.png")
var fog_distance: float = 7.0

var _shader_rect: ColorRect
var _shader_mat: ShaderMaterial
var _map_img: Image
var _map_tex: ImageTexture
var _map_w: int = 0
var _map_h: int = 0
var _entity_ctrl: Control

func _ready():
	_setup_view()
	_setup_shader()
	_setup_entity_layer()
	_fill_map_tex()

func _setup_view():
	_view_w = int(size.x)
	_view_h = int(size.y)
	if _view_w <= 0: _view_w = 858
	if _view_h <= 0: _view_h = 449

func _setup_shader():
	_shader_rect = ColorRect.new()
	_shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shader_rect)
	var shader := load("res://shaders/rect_shader.gdshader") as Shader
	if not shader: return
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	_shader_rect.material = _shader_mat
	_shader_mat.set_shader_parameter("wall_tex", _wall_tex)
	_shader_mat.set_shader_parameter("floor_tex", _floor_tex)
	_shader_mat.set_shader_parameter("rail_tex", _rail_tex)

func _setup_entity_layer():
	_entity_ctrl = Control.new()
	_entity_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_entity_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_entity_ctrl)

func _fill_map_tex():
	if map_data.is_empty(): return
	_map_w = map_data[0].size()
	_map_h = map_data.size()
	_map_img = Image.create(_map_w, _map_h, false, Image.FORMAT_RGBA8)
	for y in _map_h:
		for x in _map_w:
			var is_wall: bool = map_data[y][x] == TILE_WALL or map_data[y][x] == TILE_BLOCKED
			var fh: float = sector_map.get_floor_height(x, y) if sector_map else 0.0
			_map_img.set_pixel(x, y, Color(1.0 if is_wall else 0.0, (fh + 2.0) / 4.0, 0, 1))
	_map_tex = ImageTexture.create_from_image(_map_img)
	if _shader_mat:
		_shader_mat.set_shader_parameter("map_tex", _map_tex)
		_shader_mat.set_shader_parameter("map_w", _map_w)
		_shader_mat.set_shader_parameter("map_h", _map_h)

func _update_shader():
	if not _shader_mat: return
	_shader_mat.set_shader_parameter("cam_pos", Vector2(cam_x, cam_y))
	_shader_mat.set_shader_parameter("cam_angle", player_angle)
	_shader_mat.set_shader_parameter("view_size", Vector2(_view_w, _view_h))
	_shader_mat.set_shader_parameter("fog_dist", fog_distance)

func _fill_zbuf():
	var fov: float = deg_to_rad(90.0)
	var num_strips: int = int(float(_view_w) / _strip_w)
	_wall_zbuf.resize(num_strips)
	if map_data.is_empty(): return
	for i in range(num_strips):
		var angle: float = player_angle - fov * 0.5 + (i / float(num_strips)) * fov
		var rx: float = cos(angle); var ry: float = sin(angle)
		var mx: int = int(floor(cam_x)); var my: int = int(floor(cam_y))
		var ddx: float = INF if rx == 0 else abs(1.0 / rx)
		var ddy: float = INF if ry == 0 else abs(1.0 / ry)
		var sx: int = 1 if rx > 0 else -1; var sy: int = 1 if ry > 0 else -1
		var sx_: float = (mx + 1.0 - cam_x) * ddx if rx > 0 else (cam_x - mx) * ddx
		var sy_: float = (my + 1.0 - cam_y) * ddy if ry > 0 else (cam_y - my) * ddy
		var side: int = 0; var steps: int = int(fog_distance * 3.0) + 3; var hit := false
		while steps > 0:
			steps -= 1
			if sx_ < sy_: sx_ += ddx; mx += sx; side = 0
			else: sy_ += ddy; my += sy; side = 1
			if mx < 0 or my < 0 or my >= len(map_data) or mx >= len(map_data[0]): break
			if map_data[my][mx] == TILE_WALL or map_data[my][mx] == TILE_BLOCKED: hit = true; break
		_wall_zbuf[i] = (sx_ - ddx if side == 0 else sy_ - ddy) if hit else 999.0

func _draw():
	pass

func _draw_entities():
	if not _entity_ctrl: return
	if _entity_ctrl.draw.is_connected(_on_entity_draw):
		_entity_ctrl.draw.disconnect(_on_entity_draw)
	_entity_ctrl.draw.connect(_on_entity_draw, CONNECT_ONE_SHOT)
	_entity_ctrl.queue_redraw()

func _on_entity_draw():
	var ci: RID = _entity_ctrl.get_canvas_item()
	if ci == RID(): return

	var dir_x: float = cos(player_angle); var dir_y: float = sin(player_angle)
	var plane_x: float = -dir_y; var plane_y: float = dir_x
	var inv_det: float = 1.0 / (plane_x * dir_y - dir_x * plane_y)
	var half_h: float = _view_h / 2.0; var num_strips: int = int(float(_view_w) / _strip_w)

	var visible_entities: Array[Dictionary] = []
	for ent: Dictionary in entities_on_map:
		var sx2: float = ent.grid_x + 0.5 - cam_x; var sy2: float = ent.grid_y + 0.5 - cam_y
		var dist: float = sqrt(sx2 * sx2 + sy2 * sy2)
		if dist < 0.01: continue
		var tx: float = inv_det * (dir_y * sx2 - dir_x * sy2); var ty: float = inv_det * (-plane_y * sx2 + plane_x * sy2)
		if ty <= 0.01: continue
		var scx: int = int((_view_w / 2.0) * (1.0 + tx / ty))
		if scx < -_view_w or scx >= _view_w * 2: continue
		var scale_h: float = _view_h / (ty * 1.2)
		var tex: Texture2D = _get_ent_texture(ent)
		var spw: float = scale_h; var texw: float = 1.0; var texh: float = 1.0
		if tex: texw = tex.get_width(); texh = tex.get_height(); spw = scale_h * texw / texh
		var dx1: int = max(0, int(scx - spw * 0.5)); var dx2: int = min(_view_w, int(scx + spw * 0.5))
		var feety: float = half_h + half_h / ty; var spy: float = feety - scale_h
		visible_entities.append({"depth":ty,"dx1":dx1,"dx2":dx2,"spy":spy,"spw":spw,"sph":scale_h,"scx":scx,"tex":tex,"texw":texw,"texh":texh,"col":ent.get("color",Color.WHITE)})

	visible_entities.sort_custom(func(a:Dictionary,b:Dictionary): return a.depth > b.depth)

	for ve in visible_entities:
		var ss: int = ve.dx1 / _strip_w; var se: int = (ve.dx2 + _strip_w - 1) / _strip_w
		for si in range(ss, se):
			if si >= num_strips: break
			if ve.depth >= _wall_zbuf[si]: continue
			var px2: int = si * _strip_w
			if ve.tex and ve.spw > 1.0:
				var sc: float = px2 + _strip_w * 0.5; var u: float = (sc - (ve.scx - ve.spw * 0.5)) / ve.spw
				var rx2: float = u * ve.texw; var rw: float = max(1.0, ve.texw / ve.spw * _strip_w)
				RenderingServer.canvas_item_add_texture_rect_region(ci, Rect2(px2, ve.spy, _strip_w+1, ve.sph), ve.tex, Rect2(rx2, 0, rw, ve.texh), Color.WHITE)
			else:
				RenderingServer.canvas_item_add_rect(ci, Rect2(px2, ve.spy, _strip_w+1, ve.sph), ve.col)

func _get_ent_texture(ent: Dictionary) -> Texture2D:
	var texs: Dictionary = ent.get("textures", {})
	if texs.is_empty(): return ent.get("texture", null)
	if ent.get("chase_active", false): var chase: Texture2D = texs.get("chase",null); if chase: return chase
	var ex: float = ent.get("anim_x", float(ent.grid_x)); var ey: float = ent.get("anim_y", float(ent.grid_y))
	var dx: float = cam_x - (ex + 0.5); var dy: float = cam_y - (ey + 0.5); var va: float = atan2(dy, dx)
	var fi: int = ent.get("facing", 2); var ea: float = [-PI/2,0,PI/2,PI][fi]; var di: float = va - ea
	while di > PI: di -= TAU; while di < -PI: di += TAU
	match posmod(int(round(di/(PI*0.5))),4):
		0: return texs.get("front",null); 1: return texs.get("right",null)
		2: return texs.get("back",null); _: return texs.get("left",null)

func update_view(cx: float, cy: float, angle: float, map: Array, entities: Array):
	cam_x = cx; cam_y = cy; player_angle = angle
	map_data = map; entities_on_map = entities
	_update_shader(); _update_map_if_needed(); _fill_zbuf(); _draw_entities()

func _update_map_if_needed():
	if map_data.is_empty(): return
	var w: int = map_data[0].size(); var h: int = map_data.size()
	if w != _map_w or h != _map_h or not _map_tex: _fill_map_tex()

func update_height(data: Array):
	pass
