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
var _ready_drawn: bool = false
var _wall_zbuf: Array[float] = []

var entities_on_map: Array = []
var _wall_tex: Texture2D = load("res://assets/textures/wall.png")
var fog_distance: float = 7.0
var fog_fade: float = 2.5
var fog_color: Color = Color(0.08, 0.08, 0.08)

func _ready():
	if not _ready_drawn:
		queue_redraw()
		_ready_drawn = true

func _draw():
	if _view_w == 0 or _view_h == 0:
		_setup_view()

	var fov: float = deg_to_rad(90.0)
	var num_strips: int = int(float(_view_w) / _strip_w)
	var half_h: float = _view_h / 2.0

	var floor_h: float = sector_map.get_floor_height(int(floor(cam_x)), int(floor(cam_y))) if sector_map else 0.0
	var eye_shift: float = floor_h * _view_h * 0.08
	var hh: float = half_h + eye_shift

	_draw_floor_ceiling(hh, floor_h)
	_wall_zbuf.resize(num_strips)

	for i in range(num_strips):
		var ray_angle: float = player_angle - fov * 0.5 + (i / float(num_strips)) * fov
		var result: Dictionary = _cast_ray(cam_x, cam_y, ray_angle)
		var perp: float = result.distance
		if perp < 0.01: perp = 0.01
		_wall_zbuf[i] = perp

		if result.get("fog", false):
			var fbl: float = clamp((perp - fog_distance) / fog_fade, 0.0, 1.0)
			if fbl <= 0.0: continue
			var fh: float = _view_h / perp
			var ft: float = hh - fh * 0.5
			var fc: Color = fog_color
			fc.a = fbl * 0.85
			draw_rect(Rect2(i * _strip_w, ft, _strip_w + 1, fh), fc)
			continue

		var wall_h: float = _view_h / perp

		var hx: int = result.get("mx", int(cam_x))
		var hy: int = result.get("my", int(cam_y))
		if result.side == 0:
			hx -= result.get("sx", 0)
		else:
			hy -= result.get("sy", 0)
		var wh: float = sector_map.get_floor_height(hx, hy) if sector_map else 0.0

		var ceil_dist: float = 0.5 - wh
		var floor_dist: float = 0.5
		var wall_top: float = hh - ceil_dist * wall_h
		var wall_bot: float = hh + floor_dist * wall_h

		var wall_color: Color = Color(0.4, 0.4, 0.5)
		if wh < -0.5:
			wall_color = Color(0.55, 0.35, 0.25)
		elif wh < -0.1:
			wall_color = Color(0.45, 0.38, 0.35)

		var fbl: float = 0.0
		if perp > fog_distance - fog_fade:
			fbl = clamp((perp - (fog_distance - fog_fade)) / fog_fade, 0.0, 1.0)

		if _wall_tex:
			var wall_x: float = result.get("wall_x", 0.0)
			var tex_w: float = _wall_tex.get_width()
			var tex_h: float = _wall_tex.get_height()
			var tex_xx: int = int(wall_x * tex_w)
			if (result.side == 0 and result.get("rdx", 0.0) > 0) or (result.side == 1 and result.get("rdy", 0.0) < 0):
				tex_xx = int(tex_w) - tex_xx - 1
			var shade: float = clamp(1.0 - perp * 0.04, 0.3, 1.0)
			if result.side == 1: shade *= 0.7
			shade = lerpf(shade, 0.0, fbl)
			draw_texture_rect_region(_wall_tex, Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_bot - wall_top), Rect2(tex_xx, 0, 1, tex_h), Color(shade, shade, shade))
		else:
			var c: Color = wall_color
			if result.side == 0: c *= 0.75
			var shade: float = clamp(1.0 - perp * 0.04, 0.2, 1.0)
			shade = lerpf(shade, 0.0, fbl)
			c *= shade
			draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_bot - wall_top), c)

	_render_entities(num_strips, hh)
	_draw_fog()

func _setup_view():
	_view_w = int(size.x)
	_view_h = int(size.y)
	if _view_w <= 0: _view_w = 858
	if _view_h <= 0: _view_h = 449

func _draw_floor_ceiling(hh: float, floor_h_override: float = 0.0):
	var floor_color: Color = Color(0.05, 0.05, 0.06)
	if floor_h_override < -0.5:
		floor_color = Color(0.14, 0.08, 0.04)
	elif floor_h_override < -0.1:
		floor_color = Color(0.09, 0.06, 0.05)

	for y in range(_view_h):
		var t: float = float(y) / float(_view_h)
		if y < hh:
			var c: Color = Color(0.03, 0.03, 0.04).lerp(Color(0.0, 0.0, 0.0), t * 2.0)
			draw_rect(Rect2(0, y, _view_w, 1), c)
		else:
			var c: Color = floor_color.lerp(Color(0.0, 0.0, 0.0), (t - 0.5) * 2.0)
			draw_rect(Rect2(0, y, _view_w, 1), c)

func _cast_ray(ox: float, oy: float, angle: float) -> Dictionary:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var map_x: int = int(floor(ox))
	var map_y: int = int(floor(oy))
	var delta_x: float = INF if dir.x == 0 else abs(1.0 / dir.x)
	var delta_y: float = INF if dir.y == 0 else abs(1.0 / dir.y)
	var step_x: int = 1 if dir.x > 0 else -1
	var step_y: int = 1 if dir.y > 0 else -1
	var side_x: float = (map_x + 1.0 - ox) * delta_x if dir.x > 0 else (ox - map_x) * delta_x
	var side_y: float = (map_y + 1.0 - oy) * delta_y if dir.y > 0 else (oy - map_y) * delta_y
	var side: int = 0
	var steps: int = int(fog_distance * 3.0) + 3
	while steps > 0:
		steps -= 1
		if side_x < side_y:
			side_x += delta_x
			map_x += step_x
			side = 0
		else:
			side_y += delta_y
			map_y += step_y
			side = 1
		if map_data.is_empty() or map_x < 0 or map_y < 0 or map_y >= len(map_data) or map_x >= len(map_data[0]):
			break
		var cell: int = map_data[map_y][map_x]
		if cell == TILE_WALL or cell == TILE_BLOCKED:
			break
	var perp: float = side_x - delta_x if side == 0 else side_y - delta_y
	if perp < 0.0: perp = 0.0
	if perp > fog_distance * 1.5:
		return { "hit": false, "distance": fog_distance * 1.5, "fog": true }
	var wall_x: float = oy + perp * dir.y if side == 0 else ox + perp * dir.x
	wall_x -= floor(wall_x)
	return { "hit": true, "distance": perp, "fog": false, "side": side, "wall_x": wall_x, "rdx": dir.x, "rdy": dir.y, "mx": map_x, "my": map_y, "sx": step_x, "sy": step_y }

func _render_entities(num_strips: int, half_h: float):
	var dir_x: float = cos(player_angle)
	var dir_y: float = sin(player_angle)
	var plane_x: float = -dir_y
	var plane_y: float = dir_x
	var inv_det: float = 1.0 / (plane_x * dir_y - dir_x * plane_y)

	var visible_entities: Array[Dictionary] = []
	for ent: Dictionary in entities_on_map:
		var sprite_x: float = ent.grid_x + 0.5 - cam_x
		var sprite_y: float = ent.grid_y + 0.5 - cam_y
		var dist: float = sqrt(sprite_x * sprite_x + sprite_y * sprite_y)
		if dist < 0.01: continue

		var transform_x: float = inv_det * (dir_y * sprite_x - dir_x * sprite_y)
		var transform_y: float = inv_det * (-plane_y * sprite_x + plane_x * sprite_y)
		if transform_y <= 0.01: continue

		var screen_x: int = int((_view_w / 2.0) * (1.0 + transform_x / transform_y))
		if screen_x < -_view_w or screen_x >= _view_w * 2: continue

		var scale_h: float = _view_h / (transform_y * 1.2)
		var tex: Texture2D = _get_ent_texture(ent)
		var spr_w: float = scale_h
		var tex_w: float = 1.0
		var tex_h: float = 1.0
		if tex:
			tex_w = tex.get_width()
			tex_h = tex.get_height()
			spr_w = scale_h * tex_w / tex_h

		var draw_x1: int = max(0, int(screen_x - spr_w * 0.5))
		var draw_x2: int = min(_view_w, int(screen_x + spr_w * 0.5))
		var feet_y: float = half_h + half_h / transform_y
		var spr_y: float = feet_y - scale_h

		visible_entities.append({
			"depth": transform_y,
			"draw_x1": draw_x1,
			"draw_x2": draw_x2,
			"spr_y": spr_y,
			"spr_w": spr_w,
			"spr_h": scale_h,
			"screen_x": screen_x,
			"tex": tex,
			"tex_w": tex_w,
			"tex_h": tex_h,
			"color": ent.get("color", Color.WHITE),
		})

	visible_entities.sort_custom(func(a, b): return a.depth > b.depth)

	for ve in visible_entities:
		var stripe_start: int = ve.draw_x1 / _strip_w
		var stripe_end: int = (ve.draw_x2 + _strip_w - 1) / _strip_w
		for si in range(stripe_start, stripe_end):
			if si >= num_strips: break
			if ve.depth >= _wall_zbuf[si]:
				continue
			var sx: int = si * _strip_w
			if ve.tex and ve.spr_w > 1.0:
				var stripe_center: float = sx + _strip_w * 0.5
				var u: float = (stripe_center - (ve.screen_x - ve.spr_w * 0.5)) / ve.spr_w
				var reg_x: float = u * ve.tex_w
				var reg_w: float = max(1.0, ve.tex_w / ve.spr_w * _strip_w)
				var reg: Rect2 = Rect2(reg_x, 0, reg_w, ve.tex_h)
				draw_texture_rect_region(ve.tex, Rect2(sx, ve.spr_y, _strip_w + 1, ve.spr_h), reg, Color.WHITE)
			else:
				draw_rect(Rect2(sx, ve.spr_y, _strip_w + 1, ve.spr_h), ve.color)

func _draw_fog():
	var depth: float = _view_w * 0.35
	for x in range(int(depth)):
		var a: float = clamp(1.0 - float(x) / depth, 0.0, 1.0) * 0.7
		if a <= 0.0: break
		draw_rect(Rect2(x, 0, 1, _view_h), Color(0, 0, 0, a))
		draw_rect(Rect2(_view_w - x - 1, 0, 1, _view_h), Color(0, 0, 0, a))
	for y in range(int(depth * 0.5)):
		var a: float = clamp(1.0 - float(y) / (depth * 0.5), 0.0, 1.0) * 0.7
		if a <= 0.0: break
		draw_rect(Rect2(0, y, _view_w, 1), Color(0, 0, 0, a))
		draw_rect(Rect2(0, _view_h - y - 1, _view_w, 1), Color(0, 0, 0, a))

func _get_ent_texture(ent: Dictionary) -> Texture2D:
	var texs: Dictionary = ent.get("textures", {})
	if texs.is_empty():
		return ent.get("texture", null)

	if ent.get("chase_active", false):
		var chase: Texture2D = texs.get("chase", null)
		if chase: return chase

	var ex: float = ent.get("anim_x", float(ent.grid_x))
	var ey: float = ent.get("anim_y", float(ent.grid_y))
	var dx: float = cam_x - (ex + 0.5)
	var dy: float = cam_y - (ey + 0.5)
	var view_angle: float = atan2(dy, dx)

	var facing: int = ent.get("facing", 2)
	var enemy_angle: float = [-PI / 2.0, 0.0, PI / 2.0, PI][facing]
	var diff: float = view_angle - enemy_angle
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU

	var sector: int = posmod(int(round(diff / (PI * 0.5))), 4)
	match sector:
		0: return texs.get("front", null)
		1: return texs.get("right", null)
		2: return texs.get("back", null)
		_: return texs.get("left", null)

func update_view(cx: float, cy: float, angle: float, map: Array, entities: Array):
	cam_x = cx
	cam_y = cy
	player_angle = angle
	map_data = map
	entities_on_map = entities
	queue_redraw()

func update_height(data: Array):
	pass
