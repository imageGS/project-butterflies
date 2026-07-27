extends ColorRect

@export var subviewport_node: SubViewport

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent):
	if not subviewport_node or not event:
		prints("[CRT]", "no subviewport")
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var new_event = event.duplicate()
		new_event.position = event.position * Vector2(subviewport_node.size) / size
		subviewport_node.push_input(new_event)
		accept_event()
