class_name RippleButton
extends Button

const _shader := preload("res://shaders/ripple_button.gdshader")

var _overlay: ColorRect
var _exit_tween: Tween
var _is_mouse_over = false
var _original_brightness = {}
var _center1 = Vector2(0.5, 0.5)
var _center2 = Vector2(0.5, 0.5)

func _ready():
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.TRANSPARENT
	var sm := ShaderMaterial.new()
	sm.shader = _shader
	_overlay.material = sm
	add_child(_overlay)

	_update_overlay_size()
	sm.set("shader_parameter/time1", 1.0)
	sm.set("shader_parameter/time2", 0.0)
	pressed.connect(_on_pressed)
	mouse_exited.connect(_on_mouse_exited)
	mouse_entered.connect(_on_mouse_entered)

	var normal_style = get_theme_stylebox("normal")
	if normal_style and normal_style is StyleBoxFlat:
		sm.set("shader_parameter/corner_radius", normal_style.corner_radius_top_left / size.y * 2)
	sm.set("shader_parameter/color", Color(1, 1, 1))

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_update_overlay_size()

func _update_overlay_size():
	if not _overlay:
		return
	_overlay.set_size(size)
	_overlay.position = Vector2.ZERO
	var sm = _overlay.material as ShaderMaterial
	if sm and size.x > 0 and size.y > 0:
		sm.set("shader_parameter/size", size)

func _process(_delta):
	if size.x <= 0 or size.y <= 0:
		return
	var sm = _overlay.material as ShaderMaterial
	if not sm:
		return
	var local_mouse = (get_global_transform().affine_inverse() * get_global_mouse_position()) / size
	if _is_mouse_over:
		_center2 = local_mouse
		sm.set("shader_parameter/center2", _center2)
	sm.set("shader_parameter/center1", _center1)

func _on_pressed():
	if size.x <= 0 or size.y <= 0:
		return
	var sm = _overlay.material as ShaderMaterial
	if not sm:
		return
	_center1 = (get_global_transform().affine_inverse() * get_global_mouse_position()) / size
	create_tween().tween_method(_set_time1.bind(sm), 0.0, 1.0, 0.5)

func _set_time1(v: float, sm: ShaderMaterial):
	sm.set("shader_parameter/time1", v)

func _on_mouse_entered():
	var sm = _overlay.material as ShaderMaterial
	if not sm:
		return
	_is_mouse_over = true
	if _exit_tween:
		_exit_tween.kill()
	create_tween().tween_method(_set_glow.bind(sm), 0.0, 2.0, 0.2)
	create_tween().tween_method(_set_time2.bind(sm), 0.0, 0.35, 0.2)
	set_process(true)

func _set_glow(v: float, sm: ShaderMaterial):
	sm.set("shader_parameter/glow", v)

func _set_time2(v: float, sm: ShaderMaterial):
	sm.set("shader_parameter/time2", v)

func _on_mouse_exited():
	var sm = _overlay.material as ShaderMaterial
	if not sm:
		return
	_is_mouse_over = false
	var center = Vector2(0.5, 0.5)
	var exit_target = center + (_center2 - center).normalized() * 2.0
	_exit_tween = create_tween()
	_exit_tween.parallel().tween_method(_set_center2, _center2, exit_target, 0.3)
	_exit_tween.parallel().tween_method(_set_time2.bind(sm), 0.35, 0.0, 0.3)
	_exit_tween.parallel().tween_method(_set_glow.bind(sm), 2.0, 0.0, 0.2)
	_exit_tween.tween_callback(func():
		_center2 = Vector2(0.5, 0.5)
		set_process(false)
	)

func _set_center2(v: Vector2):
	_center2 = v
