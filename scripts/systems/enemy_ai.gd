class_name EnemyAI
extends Node

var entities: Array
var map_data: Array
var player_x: float
var player_y: float
var is_animating: bool

var _is_walkable: Callable
var _is_blocked_fn: Callable
var _play_step: Callable
var _refresh: Callable
var _dialogue_active: Callable

func setup(
	is_walkable_fn: Callable,
	is_blocked_fn: Callable,
	play_step_fn: Callable,
	refresh_fn: Callable,
	dialogue_active_fn: Callable,
):
	_is_walkable = is_walkable_fn
	_is_blocked_fn = is_blocked_fn
	_play_step = play_step_fn
	_refresh = refresh_fn
	_dialogue_active = dialogue_active_fn

func sync_state(ent_arr: Array, map_arr: Array, px: float, py: float, animating: bool):
	entities = ent_arr
	map_data = map_arr
	player_x = px
	player_y = py
	is_animating = animating

func update(delta: float):
	if entities.is_empty() or map_data.is_empty():
		return
	for ent in entities:
		if ent.type != "enemy": continue
		if ent.get("move_progress", 1.0) < 1.0:
			_tick_anim(ent, delta)
			continue

		ent.move_timer = ent.get("move_timer", 0.0) - delta
		if ent.move_timer > 0.0: continue

		var interval: float = 0.5 if ent.get("chase_active", false) else 0.9
		ent.move_timer = interval + randf_range(-0.1, 0.1)

		var px: int = roundi(player_x)
		var py: int = roundi(player_y)
		var dist: int = abs(ent.grid_x - px) + abs(ent.grid_y - py)

		if dist <= 8 and not _is_blocked_fn.call(ent.grid_x, ent.grid_y, px, py):
			_try_detect(ent, px, py)

		if ent.get("chase_active", false):
			_chase(ent, px, py, delta)
		else:
			_patrol(ent)

func _try_detect(ent: Dictionary, px: int, py: int):
	var dx: int = px - ent.grid_x
	var dy: int = py - ent.grid_y
	var f: int = ent.facing
	var vec: Vector2i = _dir_vec(f)
	var dot: int = vec.x * dx + vec.y * dy
	var dist: int = abs(ent.grid_x - px) + abs(ent.grid_y - py)

	var max_range: int = 8
	var chase_chance: float = 0.0
	if dot > 0:
		max_range = 8; chase_chance = 1.0
	elif dot == 0:
		max_range = 6; chase_chance = 0.5
	else:
		max_range = 3
		var moving: bool = is_animating or _dialogue_active.call()
		chase_chance = 0.25 if moving else 0.0

	if dist > max_range: return

	if randf() < chase_chance and not ent.get("chase_active", false):
		ent.chase_active = true

func _patrol(ent: Dictionary):
	var f: int = ent.facing
	var vec: Vector2i = _dir_vec(f)
	var nx: int = ent.grid_x + vec.x
	var ny: int = ent.grid_y + vec.y
	if _is_walkable.call(nx, ny):
		_step_to(ent, nx, ny, f)
		return

	var dirs: Array[int] = [f, (f + 1) % 4, (f + 3) % 4, (f + 2) % 4]
	for d in dirs:
		var v: Vector2i = _dir_vec(d)
		var tx: int = ent.grid_x + v.x
		var ty: int = ent.grid_y + v.y
		if _is_walkable.call(tx, ty):
			if d == f:
				_step_to(ent, tx, ty, d)
			else:
				ent.facing = d
			return

func _chase(ent: Dictionary, px: int, py: int, delta: float):
	var dist: int = abs(ent.grid_x - px) + abs(ent.grid_y - py)
	var blocked: bool = _is_blocked_fn.call(ent.grid_x, ent.grid_y, px, py)

	if dist > 10 or blocked:
		var timer: float = ent.get("chase_lost_timer", 2.0) - delta
		ent.chase_lost_timer = timer
		if timer <= 0.0:
			ent.chase_active = false
			ent.erase("chase_lost_timer")
			return
	else:
		ent.erase("chase_lost_timer")

	var f: int = ent.facing
	var best_dir: int = f
	var best_prio: int = -1
	var dirs: Array[int] = [f, (f + 1) % 4, (f + 3) % 4, (f + 2) % 4]
	for d in dirs:
		var v: Vector2i = _dir_vec(d)
		var tx: int = ent.grid_x + v.x
		var ty: int = ent.grid_y + v.y
		if not _is_walkable.call(tx, ty): continue
		var ndx: int = abs(px - tx)
		var ndy: int = abs(py - ty)
		var prio: int = 10 - (ndx + ndy)
		if d != f: prio -= 1
		if prio > best_prio:
			best_prio = prio
			best_dir = d

	if best_dir == f:
		var v: Vector2i = _dir_vec(f)
		_step_to(ent, ent.grid_x + v.x, ent.grid_y + v.y, f)
	else:
		ent.facing = best_dir

	if ent.grid_x == px and ent.grid_y == py:
		TransitionManager.change_scene("res://scenes/battle/node.tscn")

func _step_to(ent: Dictionary, nx: int, ny: int, facing: int):
	ent._from_x = float(ent.grid_x)
	ent._from_y = float(ent.grid_y)
	ent.grid_x = nx
	ent.grid_y = ny
	ent.facing = facing
	ent.move_progress = 0.0
	if _play_step.is_valid():
		_play_step.call(ent)

func _tick_anim(ent: Dictionary, delta: float):
	ent.move_progress = min(ent.get("move_progress", 1.0) + delta * 6.0, 1.0)
	var t: float = ent.move_progress
	t = t * t * (3.0 - 2.0 * t)
	ent.anim_x = lerp(ent.get("_from_x", float(ent.grid_x)), float(ent.grid_x), t)
	ent.anim_y = lerp(ent.get("_from_y", float(ent.grid_y)), float(ent.grid_y), t)
	if ent.move_progress >= 1.0:
		ent.anim_x = float(ent.grid_x)
		ent.anim_y = float(ent.grid_y)
		ent.stuck_count = 0
	if _refresh.is_valid():
		_refresh.call()

func _dir_vec(d: int) -> Vector2i:
	match d:
		0: return Vector2i(0, -1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, 1)
		3: return Vector2i(-1, 0)
	return Vector2i(0, 1)
