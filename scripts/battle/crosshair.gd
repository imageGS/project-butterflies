extends Control
class_name BattleCrosshair

signal fired(pos: Vector2)

var enabled: bool = false
var elapsed: float = 0.0
var center: Vector2
var aim_bounds: Rect2

var speed_x: float = 2.0
var speed_y: float = 1.3
var amp_x: float = 80.0
var amp_y: float = 60.0
var phase: float = 0.0

var _held_breath: float = 0.0
const HOLD_BREATH_TIME: float = 0.8
var _was_mouse_down: bool = false
var _was_right_down: bool = false

var max_aim_time: float = 4.0
var remaining_time: float = 4.0

func start(bounds: Rect2, pattern: Dictionary = {}):
	aim_bounds = bounds
	center = bounds.get_center()
	amp_x = pattern.get("amp_x", bounds.size.x * randf_range(0.25, 0.4))
	amp_y = pattern.get("amp_y", bounds.size.y * randf_range(0.2, 0.35))
	speed_x = pattern.get("speed_x", randf_range(1.5, 4.0))
	speed_y = pattern.get("speed_y", randf_range(1.0, 3.5))
	phase = pattern.get("phase", randf_range(0, TAU))
	max_aim_time = pattern.get("max_time", 4.0)
	elapsed = 0.0
	remaining_time = max_aim_time
	_held_breath = 0.0
	_was_mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_was_right_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	enabled = true
	queue_redraw()

func stop():
	enabled = false
	queue_redraw()

func get_crosshair_pos() -> Vector2:
	var x = center.x + sin(elapsed * speed_x) * amp_x
	var y = center.y + sin(elapsed * speed_y + phase) * amp_y
	return Vector2(x, y)

func _process(delta):
	if not enabled:
		_was_mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_was_right_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		return
	elapsed += delta
	remaining_time -= delta
	if remaining_time <= 0.0:
		enabled = false
		fired.emit(get_crosshair_pos())
		queue_redraw()
		return
	if Input.is_key_pressed(KEY_SHIFT):
		_held_breath = min(_held_breath + delta, HOLD_BREATH_TIME)
	else:
		_held_breath = max(_held_breath - delta * 2, 0.0)

	var mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_down and not _was_mouse_down:
		fired.emit(get_crosshair_pos())
	_was_mouse_down = mouse_down

	var right_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if right_down and not _was_right_down:
		fired.emit(Vector2(-1, -1))
	_was_right_down = right_down

	queue_redraw()

func is_holding_breath() -> bool:
	return _held_breath >= HOLD_BREATH_TIME

func _draw():
	if not enabled:
		return
	var pos = get_crosshair_pos()
	var r = 10
	draw_line(pos + Vector2(-r - 4, 0), pos + Vector2(-2, 0), Color(1, 1, 1, 0.7), 2)
	draw_line(pos + Vector2(2, 0), pos + Vector2(r + 4, 0), Color(1, 1, 1, 0.7), 2)
	draw_line(pos + Vector2(0, -r - 4), pos + Vector2(0, -2), Color(1, 1, 1, 0.7), 2)
	draw_line(pos + Vector2(0, 2), pos + Vector2(0, r + 4), Color(1, 1, 1, 0.7), 2)
	draw_circle(pos, 2, Color(1, 0.2, 0.1, 0.9))
	if not is_holding_breath():
		var jitter = Vector2(
			sin(elapsed * 31.7) * 2,
			cos(elapsed * 27.3) * 2,
		)
		draw_circle(pos + jitter, 1, Color(1, 1, 1, 0.3))

	var bar_w = aim_bounds.size.x * 0.8
	var bar_h = 6
	var bar_x = aim_bounds.position.x + (aim_bounds.size.x - bar_w) * 0.5
	var bar_y = aim_bounds.position.y - 20
	var t = max(0.0, remaining_time / max_aim_time)
	var fill_w = bar_w * t
	var col = Color(1, 0.3, 0.2, 0.8) if t < 0.3 else Color(1, 0.8, 0.2, 0.8) if t < 0.6 else Color(0.3, 0.8, 0.3, 0.8)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2, 0.5))
	draw_rect(Rect2(bar_x, bar_y, fill_w, bar_h), col)
