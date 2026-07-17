class_name MinimapControl
extends Control

var map_data: Array = []
var map_width: int = 0
var map_height: int = 0
var player_x: int = 0
var player_y: int = 0
var cell_size: int = 7
var view_tiles: int = 25

func update_map(map: Array, px: int, py: int):
	map_data = map
	if map_data.size() > 0:
		map_width = map_data[0].size()
		map_height = map_data.size()
	player_x = px
	player_y = py
	queue_redraw()

func _draw():
	if map_data.is_empty(): return
	var ox: int = player_x - view_tiles / 2
	var oy: int = player_y - view_tiles / 2
	for by in range(view_tiles):
		for bx in range(view_tiles):
			var gx: int = ox + bx
			var gy: int = oy + by
			var c: Color
			if gx == player_x and gy == player_y:
				c = Color(0.2, 0.9, 0.3, 0.9)
			elif gx >= 0 and gx < map_width and gy >= 0 and gy < map_height:
				var t: int = map_data[gy][gx]
				if t == 1:
					c = Color(0.5, 0.45, 0.4, 0.7)
				elif t == 7:
					c = Color(1, 0.85, 0.2, 0.8)
				else:
					c = Color(0.08, 0.08, 0.08, 0.4)
			else:
				c = Color(0, 0, 0, 0)
			draw_rect(Rect2(bx * cell_size, by * cell_size, cell_size - 1, cell_size - 1), c)
