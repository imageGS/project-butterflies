extends Node
class_name LightingSystem

var light_mat: ShaderMaterial
var player_light_node: Node2D
var flashlight_on: bool = true

func setup(parent_viewport: Node):
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

	var pl: Node2D = load("res://scripts/player_light.gd").new() as Node2D
	pl.name = "PlayerLight"
	player_light_node = pl
	parent_viewport.add_child(pl)

func apply_light_settings(ambient: float, dither: float, pixel_size: float, glow: float, softness: float, curve: float):
	if not light_mat: return
	light_mat.set_shader_parameter("ambient", ambient)
	light_mat.set_shader_parameter("dither_levels", dither)
	light_mat.set_shader_parameter("dither_pixel_size", pixel_size)
	light_mat.set_shader_parameter("light_glow", glow)
	light_mat.set_shader_parameter("softness", softness)
	light_mat.set_shader_parameter("light_curve", curve)

func apply_player_light(radius: float, intensity: float, color: Color):
	if not player_light_node: return
	player_light_node.radius = radius
	player_light_node.intensity = intensity
	player_light_node.color = color

func update_lighting(ambient: float, dither: float, pixel_size: float, glow: float, softness: float, curve: float, radius: float, intensity: float, color: Color):
	apply_light_settings(ambient, dither, pixel_size, glow, softness, curve)
	apply_player_light(radius, intensity if flashlight_on else 0.01, color)
	if not light_mat or not player_light_node: return
	var pos_arr := PackedVector2Array([Vector2(576, 324)])
	var rad_arr := PackedFloat32Array([radius])
	var col_arr := PackedVector3Array([Vector3(color.r, color.g, color.b)])
	var int_arr := PackedFloat32Array([intensity if flashlight_on else 0.01])
	light_mat.set_shader_parameter("light_count", 1)
	light_mat.set_shader_parameter("light_positions", pos_arr)
	light_mat.set_shader_parameter("light_radii", rad_arr)
	light_mat.set_shader_parameter("light_colors", col_arr)
	light_mat.set_shader_parameter("light_intensities", int_arr)
	light_mat.set_shader_parameter("obstructor_count", 0)
	light_mat.set_shader_parameter("occlusion_enabled", false)
