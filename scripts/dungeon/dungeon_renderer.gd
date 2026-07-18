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

	var num_strips: int = int(float(_view_w) / _strip_w)
	var half_h: float = _view_h / 2.0
	_wall_zbuf.resize(num_strips)
	_wall_zbuf.fill(INF)

	if sector_map and sector_map.sectors.size() > 0:
		_render_portals(num_strips, half_h)
	else:
		_render_dda(num_strips, half_h)

	_render_entities(num_strips, half_h)
	_draw_fog()

func _setup_view():
	_view_w = int(size.x)
	_view_h = int(size.y)
	if _view_w <= 0: _view_w = 858
	if _view_h <= 0: _view_h = 449

# ── Portal renderer ────────────────────────────────────────────

func _render_portals(num_strips: int, half_h: float):
	var px: int = int(floor(cam_x))
	var py: int = int(floor(cam_y))
	var cs: int = sector_map.cell_sector_at(px, py)
	if cs < 0:
		_draw_floor_ceiling(half_h, 0.0)
		return

	var y_lo: Array[float] = []; y_lo.resize(num_strips); y_lo.fill(0.0)
	var y_hi: Array[float] = []; y_hi.resize(num_strips); y_hi.fill(float(_view_h))

	var drawn: Array[bool] = []; drawn.resize(sector_map.sectors.size())

	var dir_x: float = cos(player_angle)
	var dir_y: float = sin(player_angle)

	var queue: Array[Dictionary] = [{"sector": cs, "x0": 0, "x1": num_strips - 1}]
	var cam_sec = sector_map.sectors[cs]

	while not queue.is_empty():
		var entry: Dictionary = queue.pop_back()
		var si: int = entry.sector
		if si < 0 or si >= sector_map.sectors.size(): continue
		if drawn[si]: continue
		drawn[si] = true

		var sec = sector_map.sectors[si]
		var x0: int = entry.x0
		var x1: int = entry.x1

		for wi in sec.walls:
			var wall = sector_map.walls[wi]
			var wx1: float = _wall_wx1(wall)
			var wy1: float = _wall_wy1(wall)
			var wx2: float = _wall_wx2(wall)
			var wy2: float = _wall_wy2(wall)

			var rx1: float = wx1 - cam_x
			var ry1: float = wy1 - cam_y
			var rx2: float = wx2 - cam_x
			var ry2: float = wy2 - cam_y

			var tx1: float = ry1 * dir_x - rx1 * dir_y
			var tz1: float = rx1 * dir_x + ry1 * dir_y
			var tx2: float = ry2 * dir_x - rx2 * dir_y
			var tz2: float = rx2 * dir_x + ry2 * dir_y

			if tz1 <= 0.1 and tz2 <= 0.1: continue

			if tz1 <= 0.1:
				var t: float = (0.1 - tz1) / (tz2 - tz1)
				tx1 = tx1 + (tx2 - tx1) * t
				tz1 = 0.1
			if tz2 <= 0.1:
				var t: float = (0.1 - tz2) / (tz1 - tz2)
				tx2 = tx2 + (tx1 - tx2) * t
				tz2 = 0.1

			var sx1: float = (tx1 / tz1) * half_h + _view_w * 0.5
			var sx2: float = (tx2 / tz2) * half_h + _view_w * 0.5

			var s1: int = clampi(int(sx1 / _strip_w), 0, num_strips - 1)
			var s2: int = clampi(int(sx2 / _strip_w), 0, num_strips - 1)

			if s1 == s2: continue

			var lo: int = min(s1, s2)
			var hi: int = max(s1, s2)

			if lo > x1 or hi < x0: continue
			lo = max(lo, x0)
			hi = min(hi, x1)

			var fh: float = sec.floor_h
			var nfh: float = sector_map.sectors[wall.portal].floor_h if wall.portal >= 0 else fh
			var nch: float = sector_map.sectors[wall.portal].ceil_h if wall.portal >= 0 else sec.ceil_h

			_draw_wall_column_range(lo, hi, tz1, tz2, fh, nfh, wall.portal >= 0, half_h, y_lo, y_hi, num_strips)

			if wall.portal >= 0:
				queue.append({"sector": wall.portal, "x0": lo, "x1": hi})

	_draw_floor_ceiling_portal(num_strips, half_h, y_lo, y_hi, cam_sec.floor_h)

func _draw_wall_column_range(lo: int, hi: int, tz1: float, tz2: float, fh: float, nfh: float, is_portal: bool, half_h: float, y_lo: Array[float], y_hi: Array[float], num_strips: int):
	for i in range(lo, hi + 1):
		var t: float = float(i - lo) / float(hi - lo) if hi != lo else 0.5
		var perp: float = lerpf(tz1, tz2, t)
		if perp < 0.1: perp = 0.1
		_wall_zbuf[i] = minf(_wall_zbuf[i], perp)

		var wall_h: float = float(_view_h) / perp
		var wall_top: float = half_h - wall_h * 0.5
		var wall_bot: float = half_h + wall_h * 0.5
		wall_bot -= fh * wall_h

		var shade: float = clamp(1.0 - perp * 0.04, 0.3, 1.0)

		if is_portal and abs(nfh - fh) > 0.01:
			var step: float = (fh - nfh) * wall_h
			if step > 2.0:
				var mid: float = wall_bot - step
				draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, mid - wall_top), Color(0.4, 0.4, 0.5) * shade)
				draw_rect(Rect2(i * _strip_w, mid, _strip_w + 1, wall_bot - mid), Color(0.1, 0.07, 0.04) * shade)
				y_lo[i] = maxf(y_lo[i], wall_bot)
				y_hi[i] = minf(y_hi[i], wall_top)
			elif step < -2.0:
				var mid: float = wall_top - step
				draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, mid - wall_top), Color(0.08, 0.05, 0.03) * shade)
				draw_rect(Rect2(i * _strip_w, mid, _strip_w + 1, wall_bot - mid), Color(0.4, 0.4, 0.5) * shade)
				y_lo[i] = maxf(y_lo[i], wall_bot)
				y_hi[i] = minf(y_hi[i], wall_top)
			else:
				draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_bot - wall_top), Color(0.4, 0.4, 0.5) * shade)
				y_lo[i] = maxf(y_lo[i], wall_bot)
				y_hi[i] = minf(y_hi[i], wall_top)
		else:
			draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_bot - wall_top), Color(0.4, 0.4, 0.5) * shade)
			y_lo[i] = maxf(y_lo[i], wall_bot)
			y_hi[i] = minf(y_hi[i], wall_top)

func _wall_wx1(wall: SectorMap.SWall) -> float:
	if wall.x2 != wall.x1:
		return float(wall.x1 + wall.x2) * 0.5
	return float(wall.x1)

func _wall_wy1(wall: SectorMap.SWall) -> float:
	if wall.x2 != wall.x1:
		return float(wall.y1)
	return float(wall.y1 + wall.y2) * 0.5

func _wall_wx2(wall: SectorMap.SWall) -> float:
	if wall.x2 != wall.x1:
		return float(wall.x1 + wall.x2) * 0.5
	return float(wall.x1) + 1.0

func _wall_wy2(wall: SectorMap.SWall) -> float:
	if wall.x2 != wall.x1:
		return float(wall.y1) + 1.0
	return float(wall.y1 + wall.y2) * 0.5

func _draw_floor_ceiling_portal(num_strips: int, half_h: float, y_lo: Array[float], y_hi: Array[float], floor_h: float):
	var fc: Color = Color(0.06, 0.05, 0.04)
	if floor_h < -0.5:
		fc = Color(0.12, 0.07, 0.04)
	elif floor_h < -0.1:
		fc = Color(0.09, 0.06, 0.04)

	for i in range(num_strips):
		var sx: int = i * _strip_w
		for y in range(0, int(y_hi[i])):
			var t: float = float(y) / float(_view_h)
			var c: Color = Color(0.03, 0.03, 0.04).lerp(Color(0, 0, 0), t * 2)
			draw_rect(Rect2(sx, y, _strip_w + 1, 1), c)
		for y in range(int(y_lo[i]), _view_h):
			var t: float = float(y) / float(_view_h)
			var c: Color = fc.lerp(Color(0, 0, 0), (t - 0.5) * 2)
			draw_rect(Rect2(sx, y, _strip_w + 1, 1), c)

# ── DDA fallback renderer ──────────────────────────────────────

func _render_dda(num_strips: int, half_h: float):
	var fov: float = deg_to_rad(90.0)
	var floor_h: float = sector_map.get_floor_height(int(floor(cam_x)), int(floor(cam_y))) if sector_map else 0.0
	_draw_floor_ceiling(half_h, floor_h)

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
			var ft: float = half_h - fh * 0.5
			var fc: Color = fog_color
			fc.a = fbl * 0.85
			draw_rect(Rect2(i * _strip_w, ft, _strip_w + 1, fh), fc)
			continue

		var wall_h: float = _view_h / perp
		var wall_top: float = half_h - wall_h * 0.5

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
			draw_texture_rect_region(_wall_tex, Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h), Rect2(tex_xx, 0, 1, tex_h), Color(shade, shade, shade))
		else:
			var c: Color = Color(0.4, 0.4, 0.5)
			if result.side == 0: c = Color(0.3, 0.3, 0.4)
			var shade: float = clamp(1.0 - perp * 0.04, 0.2, 1.0)
			shade = lerpf(shade, 0.0, fbl)
			c *= shade
			draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h), c)

func _draw_floor_ceiling(hh: float, floor_h_override: float = 0.0):
	var floor_color: Color = Color(0.06, 0.05, 0.04)
	if floor_h_override < -0.5:
		floor_color = Color(0.12, 0.07, 0.04)
	elif floor_h_override < -0.1:
		floor_color = Color(0.09, 0.06, 0.04)

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
	return { "hit": true, "distance": perp, "fog": false, "side": side, "wall_x": wall_x, "rdx": dir.x, "rdy": dir.y }

# ── Entities ───────────────────────────────────────────────────

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

# ── Public API ─────────────────────────────────────────────────

func update_view(cx: float, cy: float, angle: float, map: Array, entities: Array):
	cam_x = cx
	cam_y = cy
	player_angle = angle
	map_data = map
	entities_on_map = entities
	queue_redraw()

func update_height(data: Array):
	pass
