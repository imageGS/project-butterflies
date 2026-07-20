class_name PlayerLight
extends LightComponent

func _ready():
	radius = 300.0
	intensity = 1.2
	color = Color(1.0, 0.95, 0.8)

func _process(_delta):
	var vp := get_viewport()
	if vp:
		position = vp.get_visible_rect().size * 0.5
