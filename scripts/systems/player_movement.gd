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

var map_manager: MapManager
var audio_system: AudioSystem
var _get_dir_active: Callable
var _get_inv_open: Callable
var _refresh_cb: Callable
var _shake_cb: Callable

var player_x: float = 10.0
var player_y: float = 3.0
var player_dir: int = Dir.SOUTH
var current_angle: float = PI / 2.0

var is_animating := false
var anim_timer := 0.0
var anim_from_x := 1.0
var anim_to_x := 1.0
var anim_from_y := 1.0
var anim_to_y := 1.0
var anim_from_angle := 0.0
var anim_to_angle := 0.0
var held_cooldown: float = 0.0

var move_duration: float = 0.25
var turn_duration: float = 0.2

signal moved()

func setup(mm: MapManager, aud: AudioSystem, get_dir_active: Callable, get_inv_open: Callable, refresh_cb: Callable, shake_cb: Callable, move_dur: float, turn_dur: float):
	map_manager = mm
	audio_system = aud
	_get_dir_active = get_dir_active
	_get_inv_open = get_inv_open
	_refresh_cb = refresh_cb
	_shake_cb = shake_cb
	move_duration = move_dur
	turn_duration = turn_dur

func try_move_forward():
	var vec: Vector2i = DIR_VECTORS[player_dir]
	var nx: int = roundi(player_x) + vec.x
	var ny: int = roundi(player_y) + vec.y
	if map_manager.is_walkable(nx, ny):
		start_move(nx, ny)

func try_move_backward():
	var vec: Vector2i = DIR_VECTORS[player_dir]
	var nx: int = roundi(player_x) - vec.x
	var ny: int = roundi(player_y) - vec.y
	if map_manager.is_walkable(nx, ny):
		start_move(nx, ny)

func try_strafe_left():
	var vec: Vector2i = DIR_VECTORS[(player_dir + 3) % 4]
	var nx: int = roundi(player_x) + vec.x
	var ny: int = roundi(player_y) + vec.y
	if map_manager.is_walkable(nx, ny):
		start_move(nx, ny)

func try_strafe_right():
	var vec: Vector2i = DIR_VECTORS[(player_dir + 1) % 4]
	var nx: int = roundi(player_x) + vec.x
	var ny: int = roundi(player_y) + vec.y
	if map_manager.is_walkable(nx, ny):
		start_move(nx, ny)

func start_move(tx: int, ty: int):
	is_animating = true
	anim_timer = 0.0
	anim_from_x = player_x
	anim_from_y = player_y
	anim_to_x = float(tx)
	anim_to_y = float(ty)
	anim_from_angle = current_angle
	anim_to_angle = current_angle
	audio_system.play_footstep()
	_shake_cb.call()

func start_rotate(old_dir: int):
	is_animating = true
	anim_timer = 0.0
	anim_from_x = player_x
	anim_to_x = player_x
	anim_from_y = player_y
	anim_to_y = player_y
	anim_from_angle = DIR_ANGLES[old_dir]
	anim_to_angle = DIR_ANGLES[player_dir]
	_shake_cb.call()

func update_animation(delta: float) -> float:
	if not is_animating:
		return -1.0
	anim_timer += delta
	var dur: float = turn_duration if anim_from_angle != anim_to_angle and anim_from_x == anim_to_x else move_duration
	var t: float = min(anim_timer / dur, 1.0)
	t = t * t * t * (t * (6.0 * t - 15.0) + 10.0)
	player_x = lerp(anim_from_x, anim_to_x, t)
	player_y = lerp(anim_from_y, anim_to_y, t)
	current_angle = lerp_angle(anim_from_angle, anim_to_angle, t)
	if t >= 1.0:
		is_animating = false
		moved.emit()
	return t

func process_held_input(delta: float):
	held_cooldown -= delta
	if held_cooldown > 0.0 or _get_dir_active.call() or _get_inv_open.call(): return
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		try_move_forward(); held_cooldown = 0.15
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		try_move_backward(); held_cooldown = 0.15
	elif Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		var old = player_dir; player_dir = (player_dir + 3) % 4; start_rotate(old); held_cooldown = 0.10
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		var old = player_dir; player_dir = (player_dir + 1) % 4; start_rotate(old); held_cooldown = 0.10
	elif Input.is_key_pressed(KEY_Q):
		try_strafe_left(); held_cooldown = 0.15
	elif Input.is_key_pressed(KEY_E):
		try_strafe_right(); held_cooldown = 0.15
	elif Input.is_key_pressed(KEY_R):
		var old = player_dir; player_dir = (player_dir + 2) % 4; start_rotate(old); held_cooldown = 0.10
