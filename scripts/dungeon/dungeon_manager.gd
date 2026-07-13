extends Node

@export_group("Scene References")
@export var renderer: Control
@export var hud_label: Label
@export var direction_label: Label

enum Dir { NORTH, EAST, SOUTH, WEST }
const DIR_ANGLES: Dictionary = { Dir.NORTH: -PI / 2.0, Dir.EAST: 0.0, Dir.SOUTH: PI / 2.0, Dir.WEST: PI }
const DIR_NAMES: Dictionary = { Dir.NORTH: "N", Dir.EAST: "E", Dir.SOUTH: "S", Dir.WEST: "W" }
const DIR_VECTORS: Dictionary = {
	Dir.NORTH: Vector2i(0, -1),
	Dir.EAST:  Vector2i(1, 0),
	Dir.SOUTH: Vector2i(0, 1),
	Dir.WEST:  Vector2i(-1, 0),
}

const TILE_FLOOR := 0
const TILE_WALL := 1

var _player_x: int = 1
var _player_y: int = 1
var _player_dir: int = Dir.SOUTH
var _map_data: Array[Array] = []
var _entities: Array[Dictionary] = []

func _ready():
	_build_map()
	_setup_entities()
	_refresh_renderer()

func _build_map():
	_build_test_level()

func _build_test_level():
	_map_data = []
	_map_data.append([1, 1, 1, 1, 1, 1, 1, 1] as Array[int])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1] as Array[int])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1] as Array[int])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1] as Array[int])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1] as Array[int])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1] as Array[int])
	_map_data.append([1, 0, 0, 0, 0, 0, 0, 1] as Array[int])
	_map_data.append([1, 1, 1, 1, 1, 1, 1, 1] as Array[int])

func _setup_entities():
	_entities = []
	_entities.append({ "grid_x": 3, "grid_y": 3, "color": Color(0.8, 0.2, 0.2), "type": "enemy" } as Dictionary)
	_entities.append({ "grid_x": 5, "grid_y": 5, "color": Color(0.2, 0.6, 0.2), "type": "npc" } as Dictionary)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP:
				_move_forward()
			KEY_S, KEY_DOWN:
				_move_backward()
			KEY_A, KEY_LEFT:
				_player_dir = (_player_dir + 3) % 4
				_refresh_renderer()
			KEY_D, KEY_RIGHT:
				_player_dir = (_player_dir + 1) % 4
				_refresh_renderer()
			KEY_SPACE, KEY_E:
				_interact()

func _move_forward():
	var vec: Vector2i = DIR_VECTORS[_player_dir]
	var nx: int = _player_x + vec.x
	var ny: int = _player_y + vec.y
	if _is_walkable(nx, ny):
		_player_x = nx
		_player_y = ny
		_check_entity()
		_refresh_renderer()

func _move_backward():
	var vec: Vector2i = DIR_VECTORS[_player_dir]
	var nx: int = _player_x - vec.x
	var ny: int = _player_y - vec.y
	if _is_walkable(nx, ny):
		_player_x = nx
		_player_y = ny
		_check_entity()
		_refresh_renderer()

func _is_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= len(_map_data[0]) or y < 0 or y >= len(_map_data):
		return false
	return _map_data[y][x] == TILE_FLOOR

func _check_entity():
	for ent: Dictionary in _entities:
		if ent.grid_x == _player_x and ent.grid_y == _player_y:
			print("Stepped on: ", ent.type)
			if ent.type == "enemy":
				_start_battle()
			elif ent.type == "npc":
				_start_dialogue(ent)

func _start_battle():
	TransitionManager.change_scene("res://node.tscn")

func _start_dialogue(_ent: Dictionary):
	if hud_label:
		hud_label.text = "[NPC] Hello, wanderer..."

func _interact():
	var vec: Vector2i = DIR_VECTORS[_player_dir]
	var fx: int = _player_x + vec.x
	var fy: int = _player_y + vec.y
	for ent: Dictionary in _entities:
		if ent.grid_x == fx and ent.grid_y == fy:
			if ent.type == "enemy":
				_start_battle()
			elif ent.type == "npc":
				_start_dialogue(ent)
			return
	if hud_label:
		hud_label.text = "Nothing to interact with."

func _refresh_renderer():
	if renderer:
		var angle: float = DIR_ANGLES[_player_dir]
		renderer.update_view(_player_x, _player_y, angle, _map_data, _entities)
	if direction_label:
		direction_label.text = DIR_NAMES[_player_dir]
	if hud_label:
		var vec: Vector2i = DIR_VECTORS[_player_dir]
		var fx: int = _player_x + vec.x
		var fy: int = _player_y + vec.y
		var tile: int = _map_data[fy][fx] if _in_bounds(fx, fy) else TILE_WALL
		var info: String = "Wall" if tile == TILE_WALL else "Floor"
		for ent: Dictionary in _entities:
			if ent.grid_x == fx and ent.grid_y == fy:
				info = ent.type.capitalize()
		hud_label.text = info

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < len(_map_data[0]) and y >= 0 and y < len(_map_data)
