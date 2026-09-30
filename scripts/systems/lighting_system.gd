extends Node
class_name LightingSystem

var light_mat: ShaderMaterial
var _viewport: Node
var flashlight_on: bool = true
var flashlight_radius: float = 300.0

var _view_w: int = 0
var _view_h: int = 0
var _offset_x: float = 0.0
var _offset_y: float = 0.0
var light_levels: float = 8.0
var light_cell: float = 1.0
var light_cell_px: float = 0.0

func setup(parent_viewport: Node, renderer: Control = null):
	_viewport = parent_viewport
	if renderer:
		var rrect := renderer.get_global_rect()
		_view_w = int(rrect.size.x)
		_view_h = int(rrect.size.y)
		_offset_x = rrect.position.x
		_offset_y = rrect.position.y
	var shader := load("res://shaders/light_fog.gdshader") as Shader
	if not shader: return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	light_mat = mat

	var cr := ColorRect.new()
	cr.name = "LightOverlay"
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.material = mat
	parent_viewport.add_child(cr)
	parent_viewport.move_child(cr, parent_viewport.get_child_count() - 1)

func _project_point(wx: float, wy: float, cam_x: float, cam_y: float, cam_angle: float, view_w: int, view_h: int, height: float = 0.0) -> Dictionary:
	var dir_x := cos(cam_angle)
	var dir_y := sin(cam_angle)
	var plane_x := -dir_y
	var plane_y := dir_x
	var inv_det: float = 1.0 / (plane_x * dir_y - dir_x * plane_y)
	var sx: float = wx - cam_x
	var sy: float = wy - cam_y
	var tx: float = inv_det * (dir_y * sx - dir_x * sy)
	var ty: float = inv_det * (-plane_y * sx + plane_x * sy)
	if ty <= 0.01:
		return {"valid": false}
	var scx: int = int((view_w / 2.0) * (1.0 + tx / ty))
	var feety: float = view_h / 2.0 + view_h / (2.0 * ty)
	var half_h: float = view_h / 2.0
	var y: float = feety - height * half_h / ty
	return {"valid": true, "x": float(scx), "y": y, "depth": ty}

func update_lighting(
	glow: float, softness: float,
	flashlight_radius: float, flashlight_intensity: float, flashlight_color: Color,
	cam_x: float = 0.0, cam_y: float = 0.0, cam_angle: float = 0.0, entity_lights: Array = [], flashlight_aim: float = 0.0
):
	if not light_mat: return
	light_mat.set_shader_parameter("light_glow", glow)
	light_mat.set_shader_parameter("softness", softness)
	light_mat.set_shader_parameter("light_cell_px", light_cell_px)

	var view_w: int = _view_w
	var view_h: int = _view_h
	if view_w <= 0 or view_h <= 0:
		var vp_size: Vector2 = _viewport.get_visible_rect().size
		view_w = int(vp_size.x)
		view_h = int(vp_size.y)
		if view_w <= 0 or view_h <= 0: return

	var pos_arr := PackedVector2Array()
	var rad_arr := PackedFloat32Array()
	var col_arr := PackedVector3Array()
	var int_arr := PackedFloat32Array()

	var added: int = 0
	for ls in entity_lights:
		if added >= 47: break
		var lx: float = ls.get("grid_x", 0) + 0.5
		var ly: float = ls.get("grid_y", 0) + 0.5
		var lh: float = ls.get("height", 0.2)
		var p: Dictionary = _project_point(lx, ly, cam_x, cam_y, cam_angle, view_w, view_h, lh)
		if not p.valid: continue
		var world_radius: float = ls.world_radius
		var screen_radius: float = world_radius * float(view_h) / (2.0 * max(p.depth, 0.1))
		screen_radius = clamp(screen_radius, 4.0, float(view_h) * 0.5)
		pos_arr.append(Vector2(p.x, p.y))
		rad_arr.append(screen_radius)
		col_arr.append(Vector3(ls.color.r, ls.color.g, ls.color.b))
		int_arr.append(ls.get("intensity", 0.5))
		added += 1

	var count: int = pos_arr.size()
	light_mat.set_shader_parameter("light_count", count)
	if count > 0:
		light_mat.set_shader_parameter("light_positions", pos_arr)
		light_mat.set_shader_parameter("light_radii", rad_arr)
		light_mat.set_shader_parameter("light_colors", col_arr)
		light_mat.set_shader_parameter("light_intensities", int_arr)

	self.flashlight_radius = flashlight_radius
	light_mat.set_shader_parameter("flashlight_on", flashlight_on)
	if flashlight_on:
		var sx: float = view_w * 0.5 + _offset_x + tan(flashlight_aim) * view_w * 0.5
		var sy: float = view_h * 0.5 + _offset_y
		light_mat.set_shader_parameter("flashlight_screen_pos", Vector2(sx, sy))
		light_mat.set_shader_parameter("flashlight_screen_rad", flashlight_radius)
		light_mat.set_shader_parameter("flashlight_intensity_val", flashlight_intensity)
		light_mat.set_shader_parameter("flashlight_color_val", Vector3(flashlight_color.r, flashlight_color.g, flashlight_color.b))
