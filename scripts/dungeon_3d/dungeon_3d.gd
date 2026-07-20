extends Node3D

# =============================================================================
# 3D Dungeon main controller — loads map, builds world, spawns player.
# =============================================================================

@export var station_data: StationData

const TILE_WALL := 1
const TILE_BLOCKED := 6

var _map_data: Array = []
var _height_data: Array = []

@onready var _player: CharacterBody3D = $Player
@onready var _world: Node3D = $World

func _ready():
	_load_map()
	_build_world()
	_place_player()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _load_map():
	if not station_data:
		station_data = StationData.new()
		station_data.map_file = "res://resources/stations/maps/test_polygon.txt"
	
	if station_data.map_file and FileAccess.file_exists(station_data.map_file):
		_parse_map(station_data.map_file)
	else:
		_build_fallback()
	
	_build_height_data()

func _parse_map(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if not f: return
	var lines: Array = []
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.length() > 0: lines.append(line)
	var h: int = lines.size()
	var w: int = lines[0].length() if h > 0 else 0
	for line in lines:
		var row: Array = []
		for ch in line:
			match ch:
				"#", "!", "$": row.append(TILE_WALL)
				"+", "E", "i", "d", "t", ".", "@", "N": row.append(0)
				"I": row.append(8)
				"B": row.append(TILE_BLOCKED)
				"D": row.append(2)
				"L": row.append(3)
				"S": row.append(4)
				"R": row.append(9)
				" ": row.append(TILE_WALL)
				_: row.append(0)
		_map_data.append(row)

func _build_height_data():
	var h: int = _map_data.size()
	var w: int = _map_data[0].size() if h > 0 else 0
	_height_data = []
	for _y in h:
		var row: Array = []; row.resize(w); row.fill(0.0)
		_height_data.append(row)

func _build_fallback():
	_map_data = []; _height_data = []
	for _y in 15:
		var row: Array = []; row.resize(15); row.fill(0)
		_map_data.append(row)
	for _y in 15:
		var row: Array = []; row.resize(15); row.fill(0.0)
		_height_data.append(row)
	for x in 15:
		_map_data[0][x] = TILE_WALL; _map_data[14][x] = TILE_WALL
	for y in 15:
		_map_data[y][0] = TILE_WALL; _map_data[y][14] = TILE_WALL

func _build_world():
	if not _world: return
	var gen := WorldGenerator.new()
	gen.name = "GeneratedGeometry"
	_world.add_child(gen)
	gen.owner = _world
	gen.build_from_map(_map_data, _height_data)

func _place_player():
	if not _player: return
	var h: int = _map_data.size()
	var w: int = _map_data[0].size() if h > 0 else 0
	
	var spawn_x: int = w / 2
	var spawn_z: int = h / 2
	if station_data:
		spawn_x = station_data.spawn.x
		spawn_z = station_data.spawn.y
	
	spawn_x = clampi(spawn_x, 1, w - 2)
	spawn_z = clampi(spawn_z, 1, h - 2)
	
	while _map_data[spawn_z][spawn_x] in [TILE_WALL, TILE_BLOCKED]:
		spawn_x += 1
		if spawn_x >= w - 1:
			spawn_x = 1; spawn_z += 1
	
	_player.position = Vector3(float(spawn_x) + 0.5, 0.9, float(spawn_z) + 0.5)
	var dir: int = station_data.spawn_dir if station_data else 1
	var angles: Array = [0.0, PI * 0.5, PI, -PI * 0.5]
	_player.rotation.y = angles[dir] if dir >= 0 and dir < 4 else 0.0
