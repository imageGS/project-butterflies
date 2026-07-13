extends Control

const TILE_WALL: int = 1

var player_grid_x: int = 1
var player_grid_y: int = 1
var player_angle: float = 0.0
var map_data: Array = []

var _view_w: int = 0
var _view_h: int = 0
var _strip_w: int = 4
var _ready_drawn: bool = false

var entities_on_map: Array = []

func _ready():
	if not _ready_drawn:
		queue_redraw()
		_ready_drawn = true

func _draw():
	if _view_w == 0 or _view_h == 0:
		_setup_view()

	var fov: float = deg_to_rad(90.0)
	var num_strips: int = _view_w / _strip_w
	var half_h: float = _view_h / 2.0

	var px: float = player_grid_x + 0.5
	var py: float = player_grid_y + 0.5

	_draw_floor_ceiling()

	for i in range(num_strips):
		var ray_angle: float = player_angle - fov * 0.5 + (i / float(num_strips)) * fov
		var result: Dictionary = _cast_ray(px, py, ray_angle)
		if result.hit:
			var perp: float = result.distance
			if perp < 0.01: perp = 0.01
			var wall_h: float = _view_h / perp
			var wall_top: float = half_h - wall_h * 0.5
			var c: Color = Color(0.4, 0.4, 0.5)
			if result.side == 0:
				c = Color(0.3, 0.3, 0.4)
			var shade: float = clamp(1.0 - perp * 0.04, 0.2, 1.0)
			c *= shade
			draw_rect(Rect2(i * _strip_w, wall_top, _strip_w + 1, wall_h), c)

	for ent: Dictionary in entities_on_map:
		var ent_dir: Vector2 = Vector2(ent.grid_x + 0.5 - px, ent.grid_y + 0.5 - py).normalized()
		var view_dir: Vector2 = Vector2(cos(player_angle), sin(player_angle))
		var dot: float = view_dir.dot(ent_dir)
		if dot > 0.7:
			var cross: float = view_dir.cross(ent_dir)
			var angle: float = atan2(cross, dot)
			if abs(angle) <= fov * 0.5:
				var screen_x: int = int((angle / fov + 0.5) * _view_w)
				var dist: float = Vector2(ent.grid_x + 0.5 - px, ent.grid_y + 0.5 - py).length()
				if dist < 0.01: dist = 0.01
				var scale_h: float = _view_h / (dist * 1.5)
				var y: float = half_h - scale_h * 0.5
				draw_rect(Rect2(screen_x - 12, y, 24, scale_h), ent.color)

func _setup_view():
	_view_w = int(size.x)
	_view_h = int(size.y)
	if _view_w <= 0: _view_w = 858
	if _view_h <= 0: _view_h = 449

func _draw_floor_ceiling():
	var half_h: float = _view_h / 2.0
	for y in range(_view_h):
		var t: float = float(y) / _view_h
		if y < half_h:
			var c: Color = Color(0.05, 0.05, 0.06).lerp(Color(0.0, 0.0, 0.0), t * 2.0)
			draw_rect(Rect2(0, y, _view_w, 1), c)
		else:
			var c: Color = Color(0.1, 0.08, 0.05).lerp(Color(0.0, 0.0, 0.0), (t - 0.5) * 2.0)
			draw_rect(Rect2(0, y, _view_w, 1), c)

func _cast_ray(ox: float, oy: float, angle: float) -> Dictionary:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var map_x: int = int(floor(ox))
	var map_y: int = int(floor(oy))
	var delta_x: float = INF if dir.x == 0 else abs(1.0 / dir.x)
	var delta_y: float = INF if dir.y == 0 else abs(1.0 / dir.y)
	var step_x: int = 1 if dir.x > 0 else -1
	var step_y: int = 1 if dir.y > 0 else -1
	var side_x: float = (map_x + 1.0 - ox) * delta_x if dir.x > 0 else (ox - map_x) * delta_x
	var side_y: float = (map_y + 1.0 - oy) * delta_y if dir.y > 0 else (oy - map_y) * delta_y
	var side: int = 0
	var hit: bool = false
	var steps: int = 24
	while steps > 0:
		steps -= 1
		if side_x < side_y:
			side_x += delta_x
			map_x += step_x
			side = 0
		else:
			side_y += delta_y
			map_y += step_y
			side = 1
		if map_x < 0 or map_x >= len(map_data[0]) or map_y < 0 or map_y >= len(map_data):
			hit = true
			break
		if map_data[map_y][map_x] == TILE_WALL:
			hit = true
			break
	var perp: float = side_x - delta_x if side == 0 else side_y - delta_y
	if perp < 0.0: perp = 0.0
	return { "hit": hit, "distance": perp, "side": side, "mx": map_x, "my": map_y }

func update_view(px: int, py: int, angle: float, map: Array, entities: Array):
	player_grid_x = px
	player_grid_y = py
	player_angle = angle
	map_data = map
	entities_on_map = entities
	queue_redraw()
