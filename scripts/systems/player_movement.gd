extends Node
class_name PlayerMovement

enum Dir { NORTH, EAST, SOUTH, WEST }
const DIR_ANGLES: Dictionary = { Dir.NORTH: -PI / 2.0, Dir.EAST: 0.0, Dir.SOUTH: PI / 2.0, Dir.WEST: PI }
const DIR_VECTORS: Dictionary = {
	Dir.NORTH: Vector2i(0, -1),
	Dir.EAST:  Vector2i(1, 0),
	Dir.SOUTH: Vector2i(0, 1),
	Dir.WEST:  Vector2i(-1, 0),
}

const BODY_RADIUS: float = 0.05

var walk_speed: float = 1.5
var run_speed: float = 2.5
var move_step_dist: float = 0.15

var map_manager: MapManager
var audio_system: AudioSystem
var _get_dir_active: Callable
var _get_inv_open: Callable
var _is_entity_blocking: Callable
var _refresh_cb: Callable
var _shake_cb: Callable

var player_x: float = 10.0
var player_y: float = 3.0
var player_dir: int = Dir.SOUTH
var current_angle: float = PI / 2.0

var is_animating := false

var turn_step_deg: float = 8.0
var turn_step_interval: float = 0.05
var _key_turn: int = 0
var _edge_turn: int = 0
var _turn_step_acc: float = 0.0
var _move_step_acc: float = 0.0

var _prev_move_key: Dictionary = {}
var _move_key_edge: bool = false
var _move_keys: Array = [KEY_W, KEY_UP, KEY_S, KEY_DOWN, KEY_Q, KEY_E]
var _steps_since_foot: int = 0
var footstep_every: int = 5

var bob_offset: float = 0.0
var bob_amp: float = 1.0
var bob_freq: float = 1.0
var _bob_phase: float = 0.0
var _bob_active: bool = false

signal moved()

func setup(mm: MapManager, aud: AudioSystem, get_dir_active: Callable, get_inv_open: Callable, refresh_cb: Callable, shake_cb: Callable, move_dur: float, turn_dur: float, is_entity_blocking: Callable = Callable()):
	map_manager = mm
	audio_system = aud
	_get_dir_active = get_dir_active
	_get_inv_open = get_inv_open
	_refresh_cb = refresh_cb
	_shake_cb = shake_cb
	_is_entity_blocking = is_entity_blocking

func _cell_solid(ix: int, iy: int) -> bool:
	if not map_manager.is_walkable(ix, iy):
		return true
	if _is_entity_blocking and _is_entity_blocking.is_valid() and _is_entity_blocking.call(ix, iy):
		return true
	return false

func _collides_center(cx: float, cy: float) -> bool:
	var r: float = BODY_RADIUS
	var x0: int = int(floor(cx - r))
	var x1: int = int(floor(cx + r))
	var y0: int = int(floor(cy - r))
	var y1: int = int(floor(cy + r))
	for ix in range(x0, x1 + 1):
		for iy in range(y0, y1 + 1):
			if _cell_solid(ix, iy):
				var cxp: float = clampf(cx, float(ix), float(ix + 1))
				var cyp: float = clampf(cy, float(iy), float(iy + 1))
				var dx: float = cx - cxp
				var dy: float = cy - cyp
				if dx * dx + dy * dy < r * r:
					return true
	return false

func _clamp_to_bounds():
	var w: int = map_manager.get_width()
	var h: int = map_manager.get_height()
	player_x = clampf(player_x, 0.0, float(w - 1))
	player_y = clampf(player_y, 0.0, float(h - 1))

func _track_move_keys() -> void:
	_move_key_edge = false
	for k in _move_keys:
		var pressed: bool = Input.is_key_pressed(k)
		if pressed and not _prev_move_key.get(k, false):
			_move_key_edge = true
		_prev_move_key[k] = pressed

func set_edge_turn(dir: int):
	var was: int = _effective_turn()
	_edge_turn = signi(dir)
	if _effective_turn() != was:
		_turn_step_acc = 0.0

func start_continuous_turn(dir: int):
	set_edge_turn(dir)

func stop_continuous_turn():
	set_edge_turn(0)

func set_key_turn(dir: int):
	var was: int = _effective_turn()
	_key_turn = dir
	if _effective_turn() != was:
		_turn_step_acc = 0.0

func is_continuous_turning() -> bool:
	return (_key_turn != 0) or (_edge_turn != 0)

func _effective_turn() -> int:
	return _key_turn if _key_turn != 0 else _edge_turn

func process_continuous_turn(delta: float) -> bool:
	var t: int = _effective_turn()
	if t == 0:
		return false
	_turn_step_acc += delta
	if _turn_step_acc < turn_step_interval:
		return true
	_turn_step_acc -= turn_step_interval
	current_angle = wrapf(current_angle + float(t) * deg_to_rad(turn_step_deg), -PI, PI)
	player_dir = _nearest_cardinal_dir(current_angle)
	return true

func _nearest_cardinal_dir(angle: float) -> int:
	var c: float = cos(angle)
	var s: float = sin(angle)
	if absf(c) >= absf(s):
		return Dir.EAST if c >= 0.0 else Dir.WEST
	return Dir.SOUTH if s >= 0.0 else Dir.NORTH

func _update_position(delta: float) -> bool:
	_track_move_keys()
	if _get_dir_active.call() or _get_inv_open.call():
		_bob_active = false
		return false
	var fwd: Vector2 = Vector2(cos(current_angle), sin(current_angle))
	var right: Vector2 = Vector2(fwd.y, -fwd.x)
	var wish := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		wish += fwd
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		wish -= fwd
	if Input.is_key_pressed(KEY_Q):
		wish += right
	if Input.is_key_pressed(KEY_E):
		wish -= right
	if wish.length_squared() < 0.000001:
		_move_step_acc = 0.0
		_bob_active = false
		return false
	wish = wish.normalized()
	var speed: float = run_speed if (Input.is_key_pressed(KEY_SHIFT)) else walk_speed
	_bob_active = true
	_bob_phase += delta * bob_freq * TAU * (speed / walk_speed)
	if _move_key_edge:
		_move_step_acc = maxf(_move_step_acc, move_step_dist)
	_move_step_acc += speed * delta
	var moved: bool = false
	while _move_step_acc >= move_step_dist:
		_move_step_acc -= move_step_dist
		if not _apply_step(wish * move_step_dist):
			_move_step_acc = 0.0
			_bob_active = false
			break
		moved = true
		_steps_since_foot += 1
		if audio_system and _steps_since_foot >= footstep_every:
			_steps_since_foot = 0
			audio_system.play_footstep()
	return moved

func _apply_step(disp: Vector2) -> bool:
	var before: Vector2 = Vector2(player_x, player_y)
	var tx: float = player_x + disp.x
	if not _collides_center(tx + 0.5, player_y + 0.5):
		player_x = tx
	var ty: float = player_y + disp.y
	if not _collides_center(player_x + 0.5, ty + 0.5):
		player_y = ty
	_clamp_to_bounds()
	return player_x != before.x or player_y != before.y

func _update_bob(delta: float) -> void:
	if _bob_active:
		var target: float = sin(_bob_phase) * bob_amp
		bob_offset = lerpf(bob_offset, target, clampf(delta * 20.0, 0.0, 1.0))
	else:
		bob_offset = lerpf(bob_offset, 0.0, clampf(delta * 10.0, 0.0, 1.0))

func process_free(delta: float) -> bool:
	var left: bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right: bool = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	set_key_turn((0 if left == right else (-1 if left else 1)))
	var moved: bool = _update_position(delta)
	var turned: bool = process_continuous_turn(delta)
	_update_bob(delta)
	return moved or turned
