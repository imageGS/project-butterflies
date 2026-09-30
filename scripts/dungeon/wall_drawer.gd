extends Control

var renderer: Control

func _draw():
	if not renderer: return
	var half_h: float = size.y * 0.5 + float(renderer.get("bob_offset"))
	var view_h: int = int(size.y); var view_w: int = int(size.x)
	
	if renderer.get("_ceiling_enabled") and renderer.get("_ceiling_tex"):
		_draw_ceiling_tex(view_w, view_h, half_h)
	else:
		for y in range(int(half_h)):
			var t: float = float(y) / float(view_h)
			var c: Color = Color(0.03, 0.03, 0.04).lerp(Color(0.0, 0.0, 0.0), t * 2.0)
			draw_rect(Rect2(0, y, view_w, 1), c)
	
	renderer.draw_walls(self)
	renderer.draw_entities(self)
	renderer.draw_floor_dust(self)
	renderer.draw_fog_overlay(self)

func _draw_ceiling_tex(vw: int, vh: int, hh: float):
	var tex: Texture2D = renderer.get("_ceiling_tex")
	if not tex: return
	var tw: float = tex.get_width(); var th: float = tex.get_height()
	for y in range(int(hh)):
		var dist: float = float(hh - y) / max(hh, 1.0)
		var scale: float = dist * 2.0
		var src_y: float = (1.0 - dist) * th
		var src_h: float = max(1.0, 2.0 * th / (hh - y + 1))
		var sy: int = int(src_y) % int(th)
		var shade: float = clamp(dist, 0.2, 1.0)
		draw_texture_rect_region(tex, Rect2(0, y, vw, 1), Rect2(0, sy, tw, max(1, int(src_h))), Color(shade, shade, shade))
