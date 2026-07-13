extends Node

@export var transition_duration: float = 1.0

var _overlay: CanvasLayer
var _rect: ColorRect
var _transitioning: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ensure_overlay():
	if _overlay:
		return

	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	add_child(_overlay)

	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.anchors_preset = Control.PRESET_FULL_RECT
	_rect.color = Color(0, 0, 0, 0)
	_overlay.add_child(_rect)

	_overlay.hide()

func change_scene(path: String, p_duration: float = -1.0):
	if _transitioning:
		return
	_transitioning = true

	_ensure_overlay()

	var dur = p_duration if p_duration >= 0 else transition_duration

	_overlay.show()
	_rect.color = Color(0, 0, 0, 0)
	await get_tree().process_frame

	var tween = create_tween()
	tween.tween_property(_rect, "color", Color(0, 0, 0, 1), dur * 0.5).set_ease(Tween.EASE_IN)
	await tween.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	tween = create_tween()
	tween.tween_property(_rect, "color", Color(0, 0, 0, 0), dur * 0.5).set_ease(Tween.EASE_OUT)
	await tween.finished

	_overlay.hide()
	_transitioning = false
