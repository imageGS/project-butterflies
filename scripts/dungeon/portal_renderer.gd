class_name PortalRenderer
extends RefCounted

var _sector_map: SectorMap
var _view_w: int; var _view_h: int; var _strip_w: int

func _init(sm: SectorMap, vw: int, vh: int, sw: int):
	_sector_map = sm; _view_w = vw; _view_h = vh; _strip_w = sw

func render(draw_func: Callable, cam_x: float, cam_y: float, cam_angle: float, player_sector: int):
	var half_h: float = float(_view_h) / 2.0
	var num_strips: int = int(float(_view_w) / float(_strip_w))

	var y_lo: Array[float] = []; y_lo.resize(num_strips); y_lo.fill(0.0)
	var y_hi: Array[float] = []; y_hi.resize(num_strips); y_hi.fill(float(_view_h))
	var sect_drawn: Array[bool] = []; sect_drawn.resize(_sector_map.sectors.size())

	var fov: float = deg_to_rad(90.0)

	# Camera direction vectors
	var dir_x: float = cos(cam_angle)
	var dir_y: float = sin(cam_angle)
	var plane_x: float = -dir_y * tan(fov * 0.5)  # not used in this simplified version

	# Queue for portal traversal
	var queue: Array[Dictionary] = [{ "sector": player_sector, "x0": 0, "x1": num_strips - 1 }]

	while not queue.is_empty():
		var entry: Dictionary = queue.pop_back()
		var si: int = entry.sector
		if si < 0 or si >= _sector_map.sectors.size(): continue
		if sect_drawn[si]: continue
		sect_drawn[si] = true

		var sec := _sector_map.sectors[si]
		for wi in sec.walls:
			var wall := _sector_map.walls[wi]

			# Convert wall coords to camera space
			var wx1: float = float(wall.x1) + 0.5 - cam_x
			var wy1: float = float(wall.y1) + 0.5 - cam_y
			var wx2: float = float(wall.x2) + 0.5 - cam_x
			var wy2: float = float(wall.y2) + 0.5 - cam_y

			# Rotate to camera space
			var tx1: float = wy1 * dir_x - wx1 * dir_y
			var tz1: float = wx1 * dir_x + wy1 * dir_y
			var tx2: float = wy2 * dir_x - wx2 * dir_y
			var tz2: float = wx2 * dir_x + wy2 * dir_y

			if tz1 <= 0.1 and tz2 <= 0.1: continue

			# Clip near plane
			if tz1 <= 0.1:
				var t: float = (0.1 - tz1) / (tz2 - tz1)
				tx1 = tx1 + (tx2 - tx1) * t
				tz1 = 0.1
			if tz2 <= 0.1:
				var t: float = (0.1 - tz2) / (tz1 - tz2)
				tx2 = tx2 + (tx1 - tx2) * t
				tz2 = 0.1

			# Project to screen
			var sx1: float = (tx1 / tz1) * float(_view_h) * 0.5 + float(_view_w) * 0.5
			var sx2: float = (tx2 / tz2) * float(_view_h) * 0.5 + float(_view_w) * 0.5

			var strip1: int = clampi(int(sx1 / _strip_w), 0, num_strips - 1)
			var strip2: int = clampi(int(sx2 / _strip_w), 0, num_strips - 1)

			if strip1 == strip2: continue

			var lo := min(strip1, strip2)
			var hi := max(strip1, strip2)

			# Check against portal bounds
			if lo > entry.x1 or hi < entry.x0: continue
			lo = max(lo, entry.x0); hi = min(hi, entry.x1)

			# Get heights
			var fh: float = sec.floor_h
			var ch: float = sec.ceil_h
			var nfh: float = _sector_map.sectors[wall.portal].floor_h if wall.portal >= 0 else fh
			var nch: float = _sector_map.sectors[wall.portal].ceil_h if wall.portal >= 0 else ch

			for i in range(lo, hi + 1):
				var t: float = float(i - lo) / float(hi - lo) if hi != lo else 0.5
				# Perpendicular distance approx
				var perp: float = lerp(tz1, tz2, t)

				var wall_h: float = float(_view_h) / max(perp, 0.1)
				var wall_top: float = half_h - wall_h * 0.5
				var wall_bot: float = half_h + wall_h * 0.5

				# Height step
				var step: float = 0.0
				if wall.portal >= 0:
					step = (fh - nfh) * float(_view_h) * 0.2

				if abs(step) > 2.0:
					if step > 0:
						var mid: float = wall_bot - abs(step)
						callv(draw_func, [i, wall_top, mid, wall.portal >= 0, Color(0.4, 0.4, 0.5), perp])
						callv(draw_func, [i, mid, wall_bot, wall.portal >= 0, Color(0.1, 0.07, 0.04), perp])
					else:
						var mid: float = wall_top + abs(step)
						callv(draw_func, [i, wall_top, mid, wall.portal >= 0, Color(0.08, 0.05, 0.03), perp])
						callv(draw_func, [i, mid, wall_bot, wall.portal >= 0, Color(0.4, 0.4, 0.5), perp])
				else:
					callv(draw_func, [i, wall_top, wall_bot, wall.portal >= 0, Color(0.4, 0.4, 0.5), perp])

				y_lo[i] = max(y_lo[i], wall_bot)
				y_hi[i] = min(y_hi[i], wall_top)

			if wall.portal >= 0:
				queue.append({ "sector": wall.portal, "x0": lo, "x1": hi })

	# Fill floor/ceiling gaps
	for i in range(num_strips):
		for y in range(0, int(y_hi[i])):
			var t: float = float(y) / float(_view_h)
			var c: Color = Color(0.03, 0.03, 0.04).lerp(Color(0, 0, 0), t * 2)
			draw_func.call(i, y, y + 1, false, c, 999.0)
		for y in range(int(y_lo[i]), int(_view_h)):
			var t: float = float(y) / float(_view_h)
			var c: Color = Color(0.06, 0.05, 0.04).lerp(Color(0, 0, 0), (t - 0.5) * 2)
			draw_func.call(i, y, y + 1, false, c, 999.0)
