class_name MapManager
extends Node

const TILE_FLOOR := 0
const TILE_WALL := 1
const TILE_DOOR := 2
const TILE_LOCKED := 3
const TILE_STAIRS := 4
const TILE_SPECIAL := 5
const TILE_BLOCKED := 6
const TILE_EXIT := 7
const TILE_ITEM := 8
const TILE_RAIL := 9

var map_data: Array = []
var renderer: Control
var height_data: Array = []

func setup(renderer_node: Control):
	renderer = renderer_node

func get_data() -> Array:
	return map_data

func get_width() -> int:
	if map_data.is_empty(): return 0
	return map_data[0].size()

func get_height() -> int:
	return map_data.size()

func get_tile(x: int, y: int) -> int:
	if y < 0 or y >= map_data.size() or x < 0 or x >= map_data[0].size():
		return 1
	return map_data[y][x]

func set_tile(x: int, y: int, tile: int):
	if y < 0 or y >= map_data.size() or x < 0 or x >= map_data[0].size():
		return
	map_data[y][x] = tile

func is_door_tile(x: int, y: int) -> bool:
	if y < 0 or y >= map_data.size() or x < 0 or x >= map_data[0].size():
		return false
	var tv: int = map_data[y][x]
	return tv == TILE_DOOR or tv == TILE_LOCKED

func open_door(x: int, y: int):
	set_tile(x, y, TILE_FLOOR)
	if renderer:
		renderer.update_height(height_data)

func is_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= get_width() or y < 0 or y >= get_height():
		return false
	var tile_val: int = map_data[y][x]
	return tile_val != TILE_WALL and tile_val != TILE_BLOCKED \
		and tile_val != TILE_DOOR and tile_val != TILE_LOCKED

func is_blocked(x1: int, y1: int, x2: int, y2: int) -> bool:
	var steps: int = int(sqrt(float((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))) * 2.0) + 1
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var gx: int = int(round(lerp(float(x1), float(x2), t)))
		var gy: int = int(round(lerp(float(y1), float(y2), t)))
		if gx == x2 and gy == y2: break
		if gx >= 0 and gx < get_width() and gy >= 0 and gy < get_height():
			var tv: int = map_data[gy][gx]
			if tv == TILE_WALL or tv == TILE_BLOCKED or tv == TILE_DOOR or tv == TILE_LOCKED:
				return true
	return false

func build_height_data():
	height_data.clear()
	if map_data.is_empty(): return
	for y in map_data.size():
		var row: Array = []; row.resize(map_data[y].size()); row.fill(0.0)
		height_data.append(row)
	for y in map_data.size():
		for x in map_data[y].size():
			var tv: int = map_data[y][x]
			if tv == TILE_RAIL:
				height_data[y][x] = -1.0
			elif tv == TILE_STAIRS:
				height_data[y][x] = -0.5
	if renderer:
		renderer.height_data = height_data

func build_from_station_data(station) -> bool:
	if not station: return false
	var sd: StationData = station
	var text: String = FileAccess.get_file_as_string(sd.map_file)
	var rows: PackedStringArray = text.split("\n", false)
	map_data = []
	for y in rows.size():
		var row: Array = []; var line: String = rows[y]
		for x in line.length():
			match line[x]:
				"#": row.append(TILE_WALL)
				"E": row.append(TILE_EXIT)
				"D": row.append(TILE_DOOR)
				"L": row.append(TILE_LOCKED)
				"S": row.append(TILE_STAIRS)
				"R": row.append(TILE_RAIL)
				"I": row.append(TILE_ITEM)
				"O": row.append(TILE_WALL)
				"B": row.append(TILE_BLOCKED)
				"@", "N", "+", ".": row.append(TILE_FLOOR)
				" ": row.append(TILE_WALL)
				_: row.append(TILE_FLOOR)
		map_data.append(row)
	if renderer: renderer.fog_distance = sd.fog_distance
	if sd.outer_ring:
		for x in range(0, 48): set_tile(x, 0, TILE_RAIL); set_tile(x, 1, TILE_RAIL)
		_carve(9, 2, 11, 4, TILE_STAIRS)
		_carve(2, 2, 45, 2)
		_carve(2, 44, 45, 45)
		_carve(1, 3, 2, 43)
		_carve(45, 3, 46, 43)
		_carve_diag(6, 6, 18, 18)
		_carve_diag(40, 8, 28, 20)
		_carve_diag(10, 40, 24, 28)
		_carve(35, 22, 37, 24)
		set_tile(36, 23, TILE_ITEM); set_tile(34, 22, TILE_DOOR)
		set_tile(2, 46, TILE_ITEM)
		var spiral: Array[Vector2i] = [Vector2i(24,20),Vector2i(24,19),Vector2i(23,19),Vector2i(22,19),Vector2i(22,20),Vector2i(22,21),Vector2i(23,21),Vector2i(24,21),Vector2i(24,22),Vector2i(25,22),Vector2i(25,21),Vector2i(25,20),Vector2i(25,19),Vector2i(25,18),Vector2i(24,18),Vector2i(23,18),Vector2i(22,18),Vector2i(22,17),Vector2i(23,17),Vector2i(24,17),Vector2i(25,17),Vector2i(25,16),Vector2i(24,16),Vector2i(23,16),Vector2i(22,16),Vector2i(22,15),Vector2i(23,15),Vector2i(24,15),Vector2i(25,15),Vector2i(25,14),Vector2i(24,14),Vector2i(23,14),Vector2i(23,13),Vector2i(24,13),Vector2i(25,13),Vector2i(25,12),Vector2i(24,12),Vector2i(23,12),Vector2i(23,11),Vector2i(24,11),Vector2i(25,11),Vector2i(25,10),Vector2i(24,10),Vector2i(23,10)]
		for pt in spiral: set_tile(pt.x, pt.y, TILE_FLOOR)
		set_tile(24, 24, TILE_FLOOR); set_tile(46, 46, TILE_FLOOR)
		set_tile(19, 22, TILE_FLOOR); _carve(19, 20, 20, 21); set_tile(19, 20, TILE_ITEM)
		set_tile(3, 5, TILE_ITEM); set_tile(45, 9, TILE_ITEM); set_tile(7, 33, TILE_ITEM); set_tile(41, 37, TILE_ITEM); set_tile(15, 43, TILE_ITEM)
		set_tile(10, 1, TILE_EXIT); set_tile(2, 10, TILE_EXIT); set_tile(46, 10, TILE_EXIT)
	build_height_data()
	return true

func build_test_level():
	var ascii_rows: Array[String] = [
		"################################################",
		"#E....#.........#.......#.....#........#........#",
		"#.###.#.#######.#.#####.#.###.#.######.#.######.#",
		"#.#.#...#.....#...#...#...#.#...#....#...#....#..#",
		"#.#.#####.###.#####.#.#####.#####.#.#####.##.#.#.#",
		"#.#.......#.#.....#.#.....#.....#.#.....#..#.#.#.#",
		"#.#######.#.#####.#.#####.#####.#.#####.#.##.#.#.#",
		"#.......#.#.....#.#.....#.....#.#.....#.#..#.#.#.#",
		"#.#####.#.#####.#.#####.#####.#.#####.#.##.#.#.#.#",
		"#.#...#.#.#...#.#.....#.....#.#.....#.#..#.#...#.#",
		"#.#.#.#.#.#.#.#.#####.#####.#.#####.#.##.#.#####.#",
		"#.#.#.#...#.#.#.....#.....#.#.....#.#..#.#.....#.#",
		"#.#.#.#####.#.#####.#####.#.#####.#.##.#.#####.#.#",
		"#.#.#.....#.#.....#.....#.#.....#.#..#...#...#.#.#",
		"#.#.#####.#.#####.#####.#.#####.#.##.#####.#.#.#.#",
		"#...#...#.#.....#.....#.#.....#.#..#.....#.#.#...#",
		"#####.#.#.#####.#####.#.#####.#.##.#####.#.#.###.#",
		"#...#.#.#.....#.....#.#.....#.#..#.....#.#.#.#...#",
		"#.#.#.#.#####.#####.#.#####.#.##.#####.#.#.#.#.###",
		"#.#.#.#.....#.....#.#.....#.#..#.....#.#.#.#.#...#",
		"#.#.#.#####.#####.#.#####.#.##.#####.#.#.#.#.###.#",
		"#.#.#.....#.....#.#.....#.#..#.....#...#.#.#...#.#",
		"#.#.#####.#####.#.#####.#.##.#####L#####.#.###.#.#",
		"#.#.....#.....#.#.....#.#..#.....#.....#.#...#.#.#",
		"#.#####.#####.#.#####.#.##.#####.#####.#.###.#.#.#",
		"#.....#.....#.#.....#.#..#.....#.....#.#...#.#.#.#",
		"#.###.#####.#.#####.#.##.#####.#####.#.###.#.#.#.#",
		"#.#.#.....#.#.....#.#..#.....#.....#.#...#...#.#.#",
		"#.#.#####.#.#####.#.##.#####.#####.#.###.#####.#.#",
		"#.#.....#...#...#.#..#.....#.....#...#...#.....#.#",
		"#.#####.#####.#.#.#.#####.#####.#####.#.#.#####.#",
		"#.....#.....#.#.#.#.....#.....#.....#.#.#.....#.#",
		"#.###.#####.#.#.#.#####.#####.#####.#.#.#####.#.#",
		"#.#.#.....#.#...#.....#.....#.....#.#...#...#...#",
		"#.#.#####.#.#########.#####.#####.#.#####.#.#####",
		"#.#.#.....#...........#.....#.....#...#...#.#.....#",
		"#.#####.###########.#####.#####.###.#.#.#.#####.#",
		"#.....#...........#.....#.....#...#.#.#.#.....#.#",
		"#####.###########.#####.#####.#.#.#.#.#.#####.#.#",
		"#...#...........#.....#.....#.#.#.#.#.#.....#.#.#",
		"#.#.###########.#####.#####.#.#.#.#.#.#####.#.#.#",
		"#.#...........#.....#.....#.#...#.#.#.....#.#.#.#",
		"#.###########.#####.#####.#.#####.#.#####.#.#.#.#",
		"#...........#.....#.....#...#...#.#.....#.#.#...#",
		"###########.#####.#####.#####.#.#.#####.#.#.###.#",
		"#.........#.....#.....#.....#.#.#.....#.#.#...#.#",
		"#.#######.#####.#####.#####.#.#.#####.#.#.###.#X#",
		"################################################",
	]
	map_data = []
	for y in ascii_rows.size():
		var row: Array = []
		var line: String = ascii_rows[y]
		for x in line.length():
			var ch: String = line[x]
			match ch:
				"#": row.append(TILE_WALL)
				".": row.append(TILE_FLOOR)
				"+": row.append(TILE_FLOOR)
				"T": row.append(TILE_FLOOR)
				"O": row.append(TILE_WALL)
				"D": row.append(TILE_DOOR)
				"L": row.append(TILE_LOCKED)
				"K": row.append(TILE_FLOOR)
				"S": row.append(TILE_STAIRS)
				" ": row.append(TILE_WALL)
				"▓": row.append(TILE_FLOOR)
				"E": row.append(TILE_EXIT)
				"X": row.append(TILE_FLOOR)
				"I": row.append(TILE_ITEM)
				"@": row.append(TILE_FLOOR)
				_: row.append(TILE_WALL)
		map_data.append(row)
	_carve(2, 1, 45, 2)
	_carve(2, 44, 45, 45)
	_carve(1, 3, 2, 43)
	_carve(45, 3, 46, 43)
	_carve_diag(6, 6, 18, 18)
	_carve_diag(40, 8, 28, 20)
	_carve_diag(10, 40, 24, 28)
	_carve(35, 22, 37, 24)
	set_tile(36, 23, TILE_ITEM)
	set_tile(34, 22, TILE_DOOR)
	set_tile(2, 46, TILE_ITEM)
	var spiral: Array[Vector2i] = [
		Vector2i(24, 20), Vector2i(24, 19), Vector2i(23, 19), Vector2i(22, 19),
		Vector2i(22, 20), Vector2i(22, 21), Vector2i(23, 21), Vector2i(24, 21),
		Vector2i(24, 22), Vector2i(25, 22), Vector2i(25, 21), Vector2i(25, 20),
		Vector2i(25, 19), Vector2i(25, 18), Vector2i(24, 18), Vector2i(23, 18),
		Vector2i(22, 18), Vector2i(22, 17), Vector2i(23, 17), Vector2i(24, 17),
		Vector2i(25, 17), Vector2i(25, 16), Vector2i(24, 16), Vector2i(23, 16),
		Vector2i(22, 16), Vector2i(22, 15), Vector2i(23, 15), Vector2i(24, 15),
		Vector2i(25, 15), Vector2i(25, 14), Vector2i(24, 14), Vector2i(23, 14),
		Vector2i(23, 13), Vector2i(24, 13), Vector2i(25, 13), Vector2i(25, 12),
		Vector2i(24, 12), Vector2i(23, 12), Vector2i(23, 11), Vector2i(24, 11),
		Vector2i(25, 11), Vector2i(25, 10), Vector2i(24, 10), Vector2i(23, 10),
	]
	for pt in spiral:
		set_tile(pt.x, pt.y, TILE_FLOOR)
	set_tile(24, 24, TILE_FLOOR)
	set_tile(46, 46, TILE_FLOOR)
	set_tile(19, 22, TILE_FLOOR)
	_carve(19, 20, 20, 21)
	set_tile(19, 20, TILE_ITEM)
	set_tile(3, 5, TILE_ITEM)
	set_tile(45, 9, TILE_ITEM)
	set_tile(7, 33, TILE_ITEM)
	set_tile(41, 37, TILE_ITEM)
	set_tile(15, 43, TILE_ITEM)
	set_tile(10, 1, TILE_EXIT)
	set_tile(2, 10, TILE_EXIT)
	set_tile(46, 10, TILE_EXIT)
	build_height_data()

func _carve_diag(x1: int, y1: int, x2: int, y2: int, tile: int = TILE_FLOOR):
	var steps: int = max(abs(x2 - x1), abs(y2 - y1))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps) if steps > 0 else 1.0
		var gx: int = int(round(lerp(float(x1), float(x2), t)))
		var gy: int = int(round(lerp(float(y1), float(y2), t)))
		set_tile(gx, gy, tile)

func _carve(x1: int, y1: int, x2: int, y2: int, tile: int = TILE_FLOOR):
	for y in range(min(y1, y2), max(y1, y2) + 1):
		for x in range(min(x1, x2), max(x1, x2) + 1):
			set_tile(x, y, tile)
