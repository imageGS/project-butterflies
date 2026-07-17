class_name SectorMap
extends RefCounted

class SWall:
	var x1: int; var y1: int; var x2: int; var y2: int
	var portal: int  # -1 = solid, 0+ = neighbor sector index

class SSector:
	var floor_h: float; var ceil_h: float
	var walls: Array[int] = []
	var color: Color

var sectors: Array[SSector] = []
var walls: Array[SWall] = []
var cell_sector: Array = []  # [y][x] -> sector index

func get_floor_height(x: int, y: int) -> float:
	if y < 0 or y >= cell_sector.size(): return 0.0
	if x < 0 or x >= cell_sector[y].size(): return 0.0
	var si: int = cell_sector[y][x]
	if si < 0 or si >= sectors.size(): return 0.0
	return sectors[si].floor_h

func build_from_grid(map_data: Array, height_data: Array):
	sectors.clear(); walls.clear()
	var w: int = map_data[0].size()
	var h: int = map_data.size()
	var visited: Array = []; for y in range(h): visited.append([]); visited[y].resize(w)

	# Flood-fill sectors
	for y in range(h):
		for x in range(w):
			if _is_walkable(map_data, x, y) and not visited[y][x]:
				var sec := SSector.new()
				sec.floor_h = _height_at(height_data, x, y)
				sec.ceil_h = 0.0
				sec.color = Color(randf() * 0.3, randf() * 0.3, randf() * 0.3, 0.3)
				_flood(map_data, visited, x, y, sec, w, h)
				sectors.append(sec)

	cell_sector = visited  # save for lookup

	# Build walls for each sector
	for si in sectors.size():
		var sec := sectors[si]
		_find_walls(map_data, visited, sec, si, w, h, height_data)

func _is_walkable(map_data: Array, x: int, y: int) -> bool:
	if x < 0 or y < 0 or y >= map_data.size(): return false
	if x >= map_data[y].size(): return false
	var t: int = map_data[y][x]
	return t != 1 and t != 6  # not WALL, not BLOCKED

func _height_at(hd: Array, x: int, y: int) -> float:
	if hd.is_empty(): return 0.0
	if y < 0 or y >= hd.size(): return 0.0
	if x < 0 or x >= hd[y].size(): return 0.0
	return hd[y][x]

func _flood(map_data: Array, visited: Array, x: int, y: int, sec: SSector, w: int, h: int):
	var queue: Array[Vector2i] = [Vector2i(x, y)]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		if visited[p.y][p.x]: continue
		visited[p.y][p.x] = sectors.size()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nx: int = p.x + d.x; var ny: int = p.y + d.y
			if nx >= 0 and ny >= 0 and nx < w and ny < h:
				if _is_walkable(map_data, nx, ny) and not visited[ny][nx]:
					queue.append(Vector2i(nx, ny))

func _find_walls(map_data: Array, visited: Array, sec: SSector, si: int, w: int, h: int, hd: Array):
	var edges: Dictionary = {}
	for y in range(h):
		for x in range(w):
			if visited[y][x] != si: continue
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nx := x + d.x; var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
				if not _is_walkable(map_data, nx, ny) or (visited[ny][nx] != si and _height_at(hd, nx, ny) != sec.floor_h):
					var key := "%d,%d-%d,%d" % [x, y, nx, ny]
					var rkey := "%d,%d-%d,%d" % [nx, ny, x, y]
					if not edges.has(rkey):
						edges[key] = true

	var processed: Dictionary = {}
	for key in edges.keys():
		var parts: PackedStringArray = key.split(",")
		var ax: int = int(parts[0]); var ay: int = int(parts[1])
		var bx: int = int(parts[2]); var by: int = int(parts[3])

		var portal: int = -1
		var px: int = bx; var py: int = by
		if px >= 0 and py >= 0 and px < w and py < h and _is_walkable(map_data, px, py):
			var ns := visited[py][px] if visited[py][px] is int else -1
			if ns >= 0 and ns != si:
				portal = ns

		# Try to merge with adjacent wall
		var merged := false
		for wi in sec.walls:
			var ww := walls[wi]
			if (ww.x2 == ax and ww.y2 == ay and ww.portal == portal):
				ww.x2 = bx; ww.y2 = by
				merged = true
				break

		if not merged:
			var wall := SWall.new()
			wall.x1 = ax; wall.y1 = ay; wall.x2 = bx; wall.y2 = by
			wall.portal = portal
			sec.walls.append(walls.size())
			walls.append(wall)
