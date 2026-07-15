extends Node

enum Dir { NORTH, EAST, SOUTH, WEST }
const DIR_ANGLES := { Dir.NORTH: -PI / 2.0, Dir.EAST: 0.0, Dir.SOUTH: PI / 2.0, Dir.WEST: PI }
const DIR_NAMES := { Dir.NORTH: "N", Dir.EAST: "E", Dir.SOUTH: "S", Dir.WEST: "W" }
const DIR_VECTORS := {
	Dir.NORTH: Vector2i(0, -1), Dir.EAST: Vector2i(1, 0),
	Dir.SOUTH: Vector2i(0, 1), Dir.WEST: Vector2i(-1, 0),
}
const TILE_FLOOR := 0; const TILE_WALL := 1; const TILE_EXIT := 7

@export var move_duration: float = 0.25
@export var turn_duration: float = 0.2

var _player_x: float = 3.0; var _player_y: float = 3.0; var _player_dir: int = Dir.SOUTH
var _current_angle: float = DIR_ANGLES[Dir.SOUTH]
var _map_data: Array = []
var _entities: Array = []
var _is_animating := false; var _anim_timer := 0.0
var _anim_from_x := 3.0; var _anim_to_x := 3.0
var _anim_from_y := 3.0; var _anim_to_y := 3.0
var _anim_from_angle := 0.0; var _anim_to_angle := 0.0

@onready var _renderer: Control = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView
@onready var _label: Label = $CRT_Root/GameViewport/UI/CentralViewport/DungeonView/InfoLabel

func _ready():
	_build_map()
	_setup_entities()
	_current_angle = DIR_ANGLES[_player_dir]
	_refresh()

func _build_map():
	var w := 15; var h := 20
	_map_data = []
	for y in range(h):
		var row: Array = []; for x in range(w): row.append(TILE_WALL)
		_map_data.append(row)

	# Главный зал (убежище)
	for y in range(2, 18):
		for x in range(2, 13):
			_map_data[y][x] = TILE_FLOOR

	# Альковы по бокам
	for y in range(4, 7): _map_data[y][1] = TILE_FLOOR
	for y in range(12, 15): _map_data[y][13] = TILE_FLOOR

	# Выход
	_set_tile(7, 1, TILE_EXIT)
	# Проход к выходу
	_set_tile(7, 2, TILE_FLOOR)

func _setup_entities():
	_entities = []
	_entities.append({ "grid_x": 3, "grid_y": 5, "color": Color(0.3, 0.5, 0.7, 0.8), "type": "object", "object_type": "rest",
		"data": { "name": "кровать", "description": "Старая продавленная кровать. Но лежать можно." }})
	_entities.append({ "grid_x": 10, "grid_y": 10, "color": Color(0.4, 0.8, 0.4, 0.8), "type": "object", "object_type": "lore",
		"data": { "name": "Телевизор", "description": "Работает. Помехи, потом лицо диктора: «...станция Акио... западное крыло... проход открыт». Затем снова помехи." }})

func _set_tile(x: int, y: int, t: int) -> void:
	if y >= 0 and y < _map_data.size() and x >= 0 and x < _map_data[0].size():
		_map_data[y][x] = t

func _unhandled_input(event):
	if _is_animating: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP: _try_move_forward()
			KEY_S, KEY_DOWN: _try_move_backward()
			KEY_A, KEY_LEFT: var o = _player_dir; _player_dir = (_player_dir + 3) % 4; _start_rotate(o)
			KEY_D, KEY_RIGHT: var o = _player_dir; _player_dir = (_player_dir + 1) % 4; _start_rotate(o)
			KEY_SPACE, KEY_F: _try_interact()

func _try_move_forward():
	var v: Vector2i = DIR_VECTORS[_player_dir]; var nx: int = roundi(_player_x) + v.x; var ny: int = roundi(_player_y) + v.y
	if _is_walkable(nx, ny): _start_move(nx, ny)

func _try_move_backward():
	var v: Vector2i = DIR_VECTORS[_player_dir]; var nx: int = roundi(_player_x) - v.x; var ny: int = roundi(_player_y) - v.y
	if _is_walkable(nx, ny): _start_move(nx, ny)

func _try_interact():
	var v: Vector2i = DIR_VECTORS[_player_dir]; var fx: int = roundi(_player_x) + v.x; var fy: int = roundi(_player_y) + v.y
	for ent in _entities:
		if ent.grid_x == fx and ent.grid_y == fy:
			if ent.type == "object":
				var ot: String = ent.get("object_type", "lore")
				if ot == "rest":
					_show("Вы немного отдохнули. +3 HP, +2 Рассудок.")
					PlayerStats.heal(3); PlayerStats.restore_sanity(2)
				elif ot == "lore": _show(ent.data.description)
			return

func _is_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= _map_data[0].size() or y < 0 or y >= _map_data.size(): return false
	return _map_data[y][x] != TILE_WALL

func _start_move(tx: int, ty: int):
	_is_animating = true; _anim_timer = 0.0
	_anim_from_x = _player_x; _anim_from_y = _player_y
	_anim_to_x = float(tx); _anim_to_y = float(ty)
	_anim_from_angle = _current_angle; _anim_to_angle = _current_angle
	set_process(true)

func _start_rotate(old_dir: int):
	_is_animating = true; _anim_timer = 0.0
	_anim_from_x = _player_x; _anim_to_x = _player_x
	_anim_from_y = _player_y; _anim_to_y = _player_y
	_anim_from_angle = DIR_ANGLES[old_dir]; _anim_to_angle = DIR_ANGLES[_player_dir]
	set_process(true)

func _process(delta):
	if not _is_animating: set_process(false); return
	_anim_timer += delta
	var dur := turn_duration if _anim_from_angle != _anim_to_angle and _anim_from_x == _anim_to_x else move_duration
	var t: float = min(_anim_timer / dur, 1.0)
	t = t * t * t * (t * (6.0 * t - 15.0) + 10.0)
	_player_x = lerp(_anim_from_x, _anim_to_x, t); _player_y = lerp(_anim_from_y, _anim_to_y, t)
	_current_angle = lerp_angle(_anim_from_angle, _anim_to_angle, t)
	_refresh()
	if t >= 1.0: _is_animating = false; set_process(false); _check_tile()

func _check_tile():
	var rx := roundi(_player_x); var ry := roundi(_player_y)
	if _map_data[ry][rx] == TILE_EXIT:
		TransitionManager.change_scene("res://scenes/dungeon/test_dungeon_mechanics.tscn")

var _tip_label: Label
func _show(msg: String):
	if not _tip_label:
		_tip_label = get_node_or_null("CRT_Root/GameViewport/UI/CentralViewport/DungeonView/AwarenessLabel")
	if _tip_label:
		_tip_label.text = msg
		get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(_tip_label): _tip_label.text = "", CONNECT_ONE_SHOT)

func _refresh():
	if _renderer: _renderer.update_view(_player_x + 0.5, _player_y + 0.5, _current_angle, _map_data, _entities)
	if _label: _label.text = DIR_NAMES[_player_dir]
