extends Node

# One-shot: generates c64_palette.png and saves to project.
func _ready():
	var img := Image.create(16, 1, false, Image.FORMAT_RGB8)
	var colors := [
		Color(0,0,0), Color(1,1,1), Color(0.533,0,0), Color(0.667,1,0.933),
		Color(0.8,0.267,0.8), Color(0,0.8,0.333), Color(0,0,0.667), Color(0.933,0.933,0.467),
		Color(0.867,0.467,0.2), Color(0.4,0.267,0), Color(1,0.467,0.467), Color(0.2,0.2,0.2),
		Color(0.467,0.467,0.467), Color(0.667,1,0.4), Color(0,0.533,1), Color(0.733,0.733,0.733),
	]
	for i in 16: img.set_pixel(i, 0, colors[i])
	img.save_png("res://assets/textures/c64_palette.png")
	print("Saved c64_palette.png")
	queue_free()
