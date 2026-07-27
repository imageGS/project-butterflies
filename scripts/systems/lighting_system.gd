extends Node
class_name LightingSystem

var light_mat: ShaderMaterial
var _viewport: Node
var flashlight_on: bool = true

func setup(parent_viewport: Node):
	_viewport = parent_viewport
	var shader := load("res://shaders/light_fog.gdshader") as Shader
	if not shader: return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("occlusion_enabled", false)
	light_mat = mat

	var cr := ColorRect.new()
	cr.name = "LightOverlay"
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.material = mat
	parent_viewport.add_child(cr)
	parent_viewport.move_child(cr, parent_viewport.get_child_count() - 1)

func apply_light_settings(ambient: float, dither: float, pixel_size: float, glow: float, softness: float, curve: float):
	if not light_mat: return
	light_mat.set_shader_parameter("ambient", ambient)
	light_mat.set_shader_parameter("dither_levels", dither)
	light_mat.set_shader_parameter("dither_pixel_size", pixel_size)
	light_mat.set_shader_parameter("light_glow", glow)
	light_mat.set_shader_parameter("softness", softness)
	light_mat.set_shader_parameter("light_curve", curve)

func _world_to_screen(wx: float, wy: float, cam_x: float, cam_y: float, cam_angle: float, view_w: int, view_h: int, height: float = 0.0) -> Vector2:
	var dir_x := cos(cam_angle)
	var dir_y := sin(cam_angle)
	var plane_x := -dir_y
	var plane_y := dir_x
	var inv_det := 1.0 / max(plane_x * dir_y - dir_x * plane_y, 0.0001)
	var sx := wx - cam_x
	var sy := wy - cam_y
	var tx := inv_det * (dir_y * sx - dir_x * sy)
	var ty := inv_det * (-plane_y * sx + plane_x * sy)
	if ty <= 0.01:
		return Vector2(-1, -1)
	var scx := int((view_w / 2.0) * (1.0 + tx / ty))
	var feety := view_h / 2.0 + view_h / (2.0 * ty)
	var half_h := view_h / 2.0
	var y := feety - height * half_h / ty
	return Vector2(scx, y)

func update_lighting(
	ambient: float, dither: float, pixel_size: float, glow: float, softness: float, curve: float,
	flashlight_radius: float, flashlight_intensity: float, flashlight_color: Color,
	cam_x: float, cam_y: float, cam_angle: float, entities: Array
):
	if not light_mat: return
	apply_light_settings(ambient, dither, pixel_size, glow, softness, curve)

	var vp_size := _viewport.get_visible_rect().size
	var view_w := int(vp_size.x)
	var view_h := int(vp_size.y)
	if view_w <= 0 or view_h <= 0: return

	var pos_arr := PackedVector2Array()
	var rad_arr := PackedFloat32Array()
	var col_arr := PackedVector3Array()
	var int_arr := PackedFloat32Array()
	var flicker_time := Time.get_ticks_msec() / 1000.0

	if flashlight_on:
		pos_arr.append(Vector2(view_w * 0.5, view_h * 0.5))
		rad_arr.append(flashlight_radius)
		col_arr.append(Vector3(flashlight_color.r, flashlight_color.g, flashlight_color.b))
		int_arr.append(flashlight_intensity)

	for ent in entities:
		var ls = ent.get("light_source", null)
		if not ls: continue
		var wx := ent.grid_x + 0.5
		var wy := ent.grid_y + 0.5
		var lh := ls.get("height", 0.0)
		var sp := _world_to_screen(wx, wy, cam_x, cam_y, cam_angle, view_w, view_h, lh)
		if sp.x < 0: continue

		var flicker := ls.get("flicker", 0.0)
		var flick := 1.0
		if flicker > 0.0:
			flick = 1.0 + sin(flicker_time * 13.37 + pos_arr.size() * 7.77) * flicker * 0.5

		var radius := ls.get("radius", 150.0) * flick
		var intensity := ls.get("intensity", 0.6) * flick
		var col: Color = ls.get("color", Color(1.0, 0.6, 0.3))

		pos_arr.append(sp)
		rad_arr.append(radius)
		col_arr.append(Vector3(col.r, col.g, col.b))
		int_arr.append(intensity)

	var count := pos_arr.size()
	light_mat.set_shader_parameter("light_count", count)
	if count > 0:
		light_mat.set_shader_parameter("light_positions", pos_arr)
		light_mat.set_shader_parameter("light_radii", rad_arr)
		light_mat.set_shader_parameter("light_colors", col_arr)
		light_mat.set_shader_parameter("light_intensities", int_arr)
