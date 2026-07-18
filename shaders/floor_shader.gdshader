shader_type canvas_item;

uniform vec2 cam_pos = vec2(1.5, 1.5);
uniform float cam_angle = 0.0;
uniform vec2 view_size = vec2(858, 449);
uniform float fog_dist = 7.0;
uniform float fog_fade = 2.5;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D map_tex;
uniform sampler2D floor_tex;
uniform sampler2D rail_tex;
uniform float map_w = 48.0;
uniform float map_h = 48.0;

void fragment() {
	float half_h = view_size.y * 0.5;
	float focal = view_size.x * 0.5;
	float eye_h = 0.5;

	vec2 px = UV * view_size;
	float sy = px.y;
	if (sy < half_h) {
		COLOR = vec4(0.0);
	} else {
		float rx = (px.x - view_size.x * 0.5) / focal;
		float ray_angle = cam_angle + atan(rx);
		float d = eye_h * focal / max(sy - half_h, 0.5);
		float wx = cam_pos.x + cos(ray_angle) * d;
		float wy = cam_pos.y + sin(ray_angle) * d;

		float gx = floor(wx);
		float gy = floor(wy);
		if (gx >= 0.0 && gy >= 0.0 && gx < map_w && gy < map_h) {
			vec2 uv = (vec2(gx, gy) + 0.5) / vec2(map_w, map_h);
			vec4 cell = texture(map_tex, uv);
			float fh = cell.g * 4.0 - 2.0;
			vec4 fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
			float fog_start = max(fog_dist - fog_fade, 0.0);
			float fog = clamp((d - fog_start) / fog_fade, 0.0, 1.0);
			COLOR = vec4(mix(fc.rgb, fog_color.rgb, fog), 1.0);
		} else {
			COLOR = vec4(0.06, 0.06, 0.07, 1.0);
		}
	}
}
