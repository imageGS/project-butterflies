extends Control

var renderer: Control

func _draw():
	if not renderer:
		return
	renderer.draw_ceiling(self)
	renderer.draw_walls(self)
	renderer.draw_entities(self)
	renderer.draw_overlay(self)
