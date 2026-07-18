extends Control

var renderer: Control

func _draw():
	if not renderer:
		return
	var r = renderer as CanvasItem
	var half_h: float = size.y * 0.5
	var num_strips: int = int(size.x / 4.0)

	# ceiling
	var view_h: int = int(size.y); var view_w: int = int(size.x)
	for y in range(int(half_h)):
		var t: float = float(y) / float(view_h)
		var c: Color = Color(0.03, 0.03, 0.04).lerp(Color(0.0, 0.0, 0.0), t * 2.0)
		draw_rect(Rect2(0, y, view_w, 1), c)

	renderer.draw_walls(self)
	renderer.draw_entities(self)
	renderer.draw_fog_overlay(self)
