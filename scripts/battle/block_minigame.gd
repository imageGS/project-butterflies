extends Control
class_name BlockMinigame

enum State { IDLE, WINDUP, ACTIVE, SUCCESS, EARLY, LATE, MISS }
enum Phase { IDLE, COMBAT, RESULT, PAUSE }

signal block_result(result: int)
signal combo_finished(results: Array)

var _phase: int = Phase.IDLE

var current_center: Vector2
var current_radius: float = 350.0
var ring_start_radius: float = 350.0
var ring_end_radius: float = 20.0
var ring_perfect: float = 120.0
var ring_grace: float = 45.0
var ring_threshold: float = 0.35
var ring_duration: float = 0.8
var ring_elapsed: float = 0.0
var _ring_result: int = State.IDLE
var _resolved: bool = false

var _combo_queue: Array = []
var _combo_results: Array = []
var _current_index: int = 0
var _pause_timer: float = 0.0

const BLOCK_SOUNDS := [
	preload("res://audio/gore/block_1.wav"),
	preload("res://audio/gore/block_2.wav"),
	preload("res://audio/gore/block_3.wav"),
	preload("res://audio/gore/block_4.wav"),
]
var _sound_player: AudioStreamPlayer

func start_single(attack_speed: float = 1.0):
	var rings = [{duration = 0.8 / attack_speed}]
	start_combo(rings)

func start_combo(rings: Array):
	_combo_queue = rings.duplicate()
	_combo_results = []
	_current_index = 0
	_phase = Phase.COMBAT
	visible = true
	_begin_current_ring()

func _begin_current_ring():
	if _current_index >= _combo_queue.size():
		_phase = Phase.IDLE
		visible = false
		var final_results = _combo_results.duplicate()
		combo_finished.emit(final_results)
		return

	var r = _combo_queue[_current_index]
	var rel = r.get("pos", Vector2(0.5, 0.5))
	current_center = Vector2(size.x * rel.x, size.y * rel.y)
	ring_start_radius = r.get("start_radius", 350.0)
	ring_end_radius = r.get("end_radius", 20.0)
	ring_perfect = r.get("perfect", 120.0)
	ring_grace = r.get("grace", 45.0)
	ring_threshold = r.get("threshold", 0.35)
	ring_duration = r.get("duration", 0.8)
	current_radius = ring_start_radius
	ring_elapsed = 0.0
	_resolved = false
	_ring_result = State.IDLE
	_phase = Phase.COMBAT
	queue_redraw()

func _play_block_sound():
	if not _sound_player:
		_sound_player = AudioStreamPlayer.new()
		_sound_player.bus = &"Master"
		add_child(_sound_player)
	_sound_player.stream = BLOCK_SOUNDS[randi() % BLOCK_SOUNDS.size()]
	_sound_player.play()

func _input(event: InputEvent):
	if _phase != Phase.COMBAT or _resolved:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event.is_action_pressed("ui_accept"):
		pressed = true
	if pressed:
		_resolved = true
		var diff = abs(current_radius - ring_perfect)
		if diff <= ring_grace * ring_threshold:
			_ring_result = State.SUCCESS
		elif diff <= ring_grace:
			_ring_result = State.EARLY if current_radius > ring_perfect else State.LATE
		else:
			_ring_result = State.MISS
		_play_block_sound()
		block_result.emit(_ring_result)
		_combo_results.append(_ring_result)
		_phase = Phase.RESULT
		ring_elapsed = 0.0
		queue_redraw()

func _process(delta):
	match _phase:
		Phase.COMBAT:
			ring_elapsed += delta
			var t = ring_elapsed / ring_duration
			current_radius = lerpf(ring_start_radius, ring_end_radius, t)
			if not _resolved and t >= 1.0:
				_resolved = true
				_ring_result = State.MISS
				_play_block_sound()
				block_result.emit(_ring_result)
				_combo_results.append(_ring_result)
				_phase = Phase.RESULT
				ring_elapsed = 0.0
			queue_redraw()

		Phase.RESULT:
			ring_elapsed += delta
			if ring_elapsed > 0.3:
				_current_index += 1
				_phase = Phase.PAUSE
				_pause_timer = 0.0
				queue_redraw()

		Phase.PAUSE:
			_pause_timer += delta
			if _pause_timer > 0.15:
				_begin_current_ring()

func _get_ring_color(radius: float) -> Color:
	var diff = abs(radius - ring_perfect)
	if diff <= ring_grace * ring_threshold:
		return Color(0.0, 1.0, 0.3, 0.9)
	if diff <= ring_grace:
		return Color(1.0, 0.8, 0.1, 0.85)
	return Color(0.6, 0.8, 1.0, 0.7)

func draw_filled_ring(c: Vector2, inner_r: float, outer_r: float, color: Color):
	var steps = 32
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(steps + 1):
		var a = float(i) / steps * TAU
		points.append(c + Vector2(cos(a), sin(a)) * outer_r)
		colors.append(color)
	for i in range(steps, -1, -1):
		var a = float(i) / steps * TAU
		points.append(c + Vector2(cos(a), sin(a)) * inner_r)
		colors.append(color)
	if points.size() > 2:
		draw_polygon(points, colors)

func _draw():
	if _phase == Phase.IDLE:
		return
	var c = current_center
	var y_outer = ring_perfect + ring_grace
	var y_inner = ring_perfect - ring_grace
	var g_outer = ring_perfect + ring_grace * ring_threshold
	var g_inner = ring_perfect - ring_grace * ring_threshold

	draw_filled_ring(c, y_inner, y_outer, Color(1.0, 0.8, 0.1, 0.25))
	draw_filled_ring(c, g_inner, g_outer, Color(0.0, 1.0, 0.3, 0.3))
	draw_filled_ring(c, ring_end_radius, y_inner, Color(1.0, 0.2, 0.1, 0.25))

	if _phase == Phase.COMBAT:
		draw_block_ring(c, current_radius, _get_ring_color(current_radius))
	elif _phase == Phase.RESULT:
		match _ring_result:
			State.SUCCESS:
				draw_block_ring(c, current_radius, Color(0.0, 1.0, 0.3, 0.8))
				draw_circle(c, 6, Color(0.0, 1.0, 0.3, 0.9))
			State.EARLY, State.LATE:
				draw_block_ring(c, current_radius, Color(1.0, 0.6, 0.0, 0.7))
				draw_circle(c, 6, Color(1.0, 0.6, 0.0, 0.8))
			State.MISS:
				draw_block_ring(c, current_radius, Color(1.0, 0.2, 0.1, 0.6))
	elif _phase == Phase.PAUSE:
		pass

	if _current_index > 0:
		var combo_text = "%d/%d" % [_current_index, _combo_queue.size()]
		var font_size = 16
		var text_pos = Vector2(size.x * 0.5 - 15, 30)
		draw_string(ThemeDB.fallback_font, text_pos, combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.6))

func draw_block_ring(c: Vector2, radius: float, color: Color):
	var steps = max(16, int(radius * 0.5))
	var points: PackedVector2Array = []
	for i in range(steps + 1):
		var a = float(i) / steps * TAU
		points.append(c + Vector2(cos(a), sin(a)) * radius)
	if points.size() > 1:
		draw_polyline(points, color, 4, true)

	var fill_points: PackedVector2Array = []
	for i in range(steps + 1):
		var a = float(i) / steps * TAU
		fill_points.append(c + Vector2(cos(a), sin(a)) * (radius - 8))
	draw_polyline(fill_points, color * Color(1, 1, 1, 0.3), 2, true)
