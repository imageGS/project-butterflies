extends Node

@export var transition_duration: float = 1.5

var _overlay: CanvasLayer
var _rect: ColorRect
var _material: ShaderMaterial
var _transitioning: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ensure_overlay():
	if _overlay:
		return

	var shader := preload("res://shaders/noise_transition.gdshader") as Shader
	if not shader:
		push_error("Transition shader not found")
		return

	_material = ShaderMaterial.new()
	_material.shader = shader

	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	add_child(_overlay)

	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_rect)

func _update_rect_size():
	if not _rect:
		return
	var vs := get_viewport().get_visible_rect().size
	_rect.set_size(vs)
	_rect.position = Vector2.ZERO

func change_scene(path: String, p_duration: float = -1.0):
	if _transitioning:
		return
	_transitioning = true

	_ensure_overlay()
	if not _material:
		get_tree().change_scene_to_file(path)
		_transitioning = false
		return

	_update_rect_size()

	var dur: float = p_duration if p_duration >= 0.0 else transition_duration
	var half: float = dur * 0.5

	_material.set_shader_parameter("seed", randf())
	_material.set_shader_parameter("progress", 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_progress, 0.0, 0.5, half)
	await tween.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	_update_rect_size()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_progress, 0.5, 1.0, half)
	await tween.finished

	_transitioning = false

func _set_progress(value: float):
	if _material:
		_material.set_shader_parameter("progress", value)
