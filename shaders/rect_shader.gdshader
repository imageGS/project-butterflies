shader_type canvas_item;

uniform vec2 cam_pos = vec2(1.5, 1.5);
uniform float cam_angle = 0.0;
uniform vec2 view_size = vec2(858, 449);
uniform float fog_dist = 7.0;
uniform sampler2D map_tex : source_color, filter_nearest;
uniform sampler2D wall_tex : source_color, filter_linear;
uniform sampler2D floor_tex : source_color, filter_linear;
uniform sampler2D rail_tex : source_color, filter_linear;
uniform int map_w = 48;
uniform int map_h = 48;

void fragment() {
	float focal = view_size.x * 0.5;
	float half_h = view_size.y * 0.5;
	float eye_h = 0.5;

	vec2 px = UV * view_size;
	float sx = px.x;
	float sy = px.y;

	float rx = (sx - view_size.x * 0.5) / focal;
	float ray_angle = cam_angle + atan(rx);
	vec2 rd = vec2(cos(ray_angle), sin(ray_angle));

	ivec2 map = ivec2(floor(cam_pos));
	vec2 delta = vec2(
		rd.x == 0.0 ? 1e10 : abs(1.0 / rd.x),
		rd.y == 0.0 ? 1e10 : abs(1.0 / rd.y)
	);
	ivec2 step = ivec2(rd.x > 0.0 ? 1 : -1, rd.y > 0.0 ? 1 : -1);
	vec2 side = vec2(
		rd.x > 0.0 ? (float(map.x) + 1.0 - cam_pos.x) * delta.x : (cam_pos.x - float(map.x)) * delta.x,
		rd.y > 0.0 ? (float(map.y) + 1.0 - cam_pos.y) * delta.y : (cam_pos.y - float(map.y)) * delta.y
	);

	int hit_side = 0;
	bool hit = false;
	int steps = int(fog_dist * 3.0) + 3;

	while (steps > 0) {
		steps--;
		if (side.x < side.y) {
			side.x += delta.x; map.x += step.x; hit_side = 0;
		} else {
			side.y += delta.y; map.y += step.y; hit_side = 1;
		}
		if (map.x < 0 || map.y < 0 || map.x >= map_w || map.y >= map_h) { hit = false; break; }
		vec4 cell = texelFetch(map_tex, ivec2(map.x, map.y), 0);
		if (cell.r > 0.5) { hit = true; break; }
	}

	float perp_dist = hit_side == 0 ? side.x - delta.x : side.y - delta.y;
	if (perp_dist < 0.0) perp_dist = 0.0;

	if (hit && perp_dist <= fog_dist * 1.5) {
		float wall_unit = view_size.y / max(perp_dist, 0.01);
		float wall_top = half_h - wall_unit * 0.5;
		float wall_bot = half_h + wall_unit * 0.5;

		if (sy >= wall_top && sy <= wall_bot) {
			float w_x = hit_side == 0 ? cam_pos.y + perp_dist * rd.y : cam_pos.x + perp_dist * rd.x;
			w_x = fract(w_x);
			if ((hit_side == 0 && rd.x > 0.0) || (hit_side == 1 && rd.y < 0.0)) {
				w_x = 1.0 - w_x;
			}
			float shade = clamp(1.0 - perp_dist * 0.04, 0.3, 1.0);
			if (hit_side == 1) shade *= 0.7;
			if (perp_dist > fog_dist - 2.5) {
				float fbl = clamp((perp_dist - (fog_dist - 2.5)) / 2.5, 0.0, 1.0);
				shade = mix(shade, 0.0, fbl);
			}
			vec4 tex = texture(wall_tex, vec2(w_x, (sy - wall_top) / (wall_bot - wall_top)));
			COLOR = tex * shade;
		} else if (sy > wall_bot) {
			float d = eye_h * focal / max(sy - half_h, 0.5);
			float ang = ray_angle;
			float wx = cam_pos.x + cos(ang) * d;
			float wy = cam_pos.y + sin(ang) * d;
			ivec2 tc = ivec2(int(floor(wx)), int(floor(wy)));
			if (tc.x >= 0 && tc.y >= 0 && tc.x < map_w && tc.y < map_h) {
				vec4 cell = texelFetch(map_tex, tc, 0);
				float fh = cell.g * 4.0 - 2.0;
				vec4 fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
				float s2 = clamp(1.0 - d / fog_dist, 0.0, 1.0);
				COLOR = fc * s2;
			} else {
				COLOR = vec4(0.06, 0.06, 0.07, 1.0);
			}
		} else {
			float d = (1.0 - (0.5)) * focal / max(half_h - sy, 0.5);
			float ang = ray_angle;
			float wx = cam_pos.x + cos(ang) * d;
			float wy = cam_pos.y + sin(ang) * d;
			ivec2 tc = ivec2(int(floor(wx)), int(floor(wy)));
			if (tc.x >= 0 && tc.y >= 0 && tc.x < map_w && tc.y < map_h) {
				vec4 cell = texelFetch(map_tex, tc, 0);
				float fh = cell.g * 4.0 - 2.0;
				vec4 fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
				float s2 = clamp(1.0 - d / (fog_dist * 0.7), 0.0, 1.0);
				COLOR = fc * s2;
			} else {
				float t = sy / view_size.y;
				COLOR = mix(vec4(0.03, 0.03, 0.04, 1.0), vec4(0.0, 0.0, 0.0, 1.0), t * 2.0);
			}
		}
	} else {
		if (sy >= half_h) {
			float d = eye_h * focal / max(sy - half_h, 0.5);
			float ang = ray_angle;
			float wx = cam_pos.x + cos(ang) * d;
			float wy = cam_pos.y + sin(ang) * d;
			ivec2 tc = ivec2(int(floor(wx)), int(floor(wy)));
			if (tc.x >= 0 && tc.y >= 0 && tc.x < map_w && tc.y < map_h) {
				vec4 cell = texelFetch(map_tex, tc, 0);
				float fh = cell.g * 4.0 - 2.0;
				vec4 fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
				float s2 = clamp(1.0 - d / fog_dist, 0.0, 1.0);
				COLOR = fc * s2;
			} else {
				COLOR = vec4(0.06, 0.06, 0.07, 1.0);
			}
		} else {
			float d = (1.0 - (0.5)) * focal / max(half_h - sy, 0.5);
			float ang = ray_angle;
			float wx = cam_pos.x + cos(ang) * d;
			float wy = cam_pos.y + sin(ang) * d;
			ivec2 tc = ivec2(int(floor(wx)), int(floor(wy)));
			if (tc.x >= 0 && tc.y >= 0 && tc.x < map_w && tc.y < map_h) {
				vec4 cell = texelFetch(map_tex, tc, 0);
				float fh = cell.g * 4.0 - 2.0;
				vec4 fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
				float s2 = clamp(1.0 - d / (fog_dist * 0.7), 0.0, 1.0);
				COLOR = fc * s2;
			} else {
				float t = sy / view_size.y;
				COLOR = mix(vec4(0.03, 0.03, 0.04, 1.0), vec4(0.0, 0.0, 0.0, 1.0), t * 2.0);
			}
		}
	}

	float fx = abs(px.x - view_size.x * 0.5) / (view_size.x * 0.5);
	float fy = abs(px.y - view_size.y * 0.5) / (view_size.y * 0.5);
	float fog = smoothstep(0.5, 1.0, max(fx, fy)) * 0.6;
	COLOR = mix(COLOR, vec4(0.08, 0.08, 0.08, 1.0), fog);
}
