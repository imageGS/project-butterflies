shader_type canvas_item;

uniform vec2 cam_pos = vec2(1.5, 1.5);
uniform float cam_angle = 0.0;
uniform vec2 view_size = vec2(858, 449);
uniform float fog_dist = 7.0;
uniform sampler2D map_tex : source_color, filter_nearest;
uniform sampler2D floor_tex : source_color, filter_linear;
uniform sampler2D rail_tex : source_color, filter_linear;
uniform int map_w = 48;
uniform int map_h = 48;

void fragment() {
	float half_h = view_size.y * 0.5;
	float focal = view_size.x * 0.5;
	float eye_h = 0.5;

	vec2 px = UV * view_size;
	float sy = px.y;
	if (sy < half_h) { COLOR = vec4(0.0); return; }

	float rx = (px.x - view_size.x * 0.5) / focal;
	float ray_angle = cam_angle + atan(rx);
	float d = eye_h * focal / max(sy - half_h, 0.5);
	float wx = cam_pos.x + cos(ray_angle) * d;
	float wy = cam_pos.y + sin(ray_angle) * d;

	ivec2 tc = ivec2(int(floor(wx)), int(floor(wy)));
	if (tc.x >= 0 && tc.y >= 0 && tc.x < map_w && tc.y < map_h) {
		vec4 cell = texelFetch(map_tex, tc, 0);
		float fh = cell.g * 4.0 - 2.0;
		vec4 fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
		float shade = clamp(1.0 - d / fog_dist, 0.0, 1.0);
		COLOR = fc * shade;
	} else {
		COLOR = vec4(0.06, 0.06, 0.07, 1.0);
	}
}
