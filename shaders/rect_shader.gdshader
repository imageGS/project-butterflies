shader_type canvas_item;

uniform vec2 cam_pos = vec2(1.5, 1.5);
uniform float cam_angle = 0.0;
uniform float cam_height = 0.0;
uniform vec2 view_size = vec2(858, 449);
uniform float fog_dist = 7.0;
uniform sampler2D map_tex : source_color, filter_nearest;
uniform sampler2D wall_tex : source_color, filter_linear;
uniform sampler2D floor_tex : source_color, filter_linear;
uniform sampler2D rail_tex : source_color, filter_linear;
uniform int map_w = 48;
uniform int map_h = 48;

void fragment() {
	float fov = radians(90.0);
	float focal = view_size.x * 0.5 / tan(fov * 0.5);
	float half_h = view_size.y * 0.5;
	float hh = half_h + cam_height * view_size.y * 0.25;
	float eye_h = 0.5;

	vec2 px = UV * view_size;
	float sx = px.x;
	float sy = px.y;

	float rx = (sx - view_size.x * 0.5) / focal;
	float ray_angle = cam_angle + atan(rx);
	vec2 rd = vec2(cos(ray_angle), sin(ray_angle));

	// DDA
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
	float perp = 0.0;
	float wall_x = 0.0;
	int mx = map.x;
	int my = map.y;
	bool hit = false;
	int steps = int(fog_dist * 3.0) + 3;

	while (steps > 0) {
		steps--;
		if (side.x < side.y) {
			side.x += delta.x;
			map.x += step.x;
			hit_side = 0;
		} else {
			side.y += delta.y;
			map.y += step.y;
			hit_side = 1;
		}
		if (map.x < 0 || map.y < 0 || map.x >= map_w || map.y >= map_h) { hit = false; break; }
		vec4 cell = texelFetch(map_tex, ivec2(map.x, map.y), 0);
		if (cell.r > 0.5) {
			hit = true;
			mx = map.x; my = map.y;
			break;
		}
	}

	float perp_dist = hit_side == 0 ? side.x - delta.x : side.y - delta.y;
	if (perp_dist < 0.0) perp_dist = 0.0;

	if (hit && perp_dist <= fog_dist * 1.5) {
		// Get floor height at the walkable cell next to the wall
		ivec2 floor_cell = ivec2(mx, my);
		if (hit_side == 0) floor_cell.x -= step.x;
		else floor_cell.y -= step.y;
		float wall_height = 0.0;
		if (floor_cell.x >= 0 && floor_cell.y >= 0 && floor_cell.x < map_w && floor_cell.y < map_h) {
			wall_height = texelFetch(map_tex, floor_cell, 0).g * 4.0 - 2.0;
		}

		float wall_unit = view_size.y / max(perp_dist, 0.01);
		float ceil_dist = 0.5 - cam_height;
		float floor_dist = cam_height - wall_height + 0.5;
		float wall_top = hh - ceil_dist * wall_unit;
		float wall_bot = hh + floor_dist * wall_unit;

		if (sy >= wall_top && sy <= wall_bot) {
			float w_x = hit_side == 0 ? cam_pos.y + perp_dist * rd.y : cam_pos.x + perp_dist * rd.x;
			w_x = fract(w_x);
			float shade = clamp(1.0 - perp_dist * 0.04, 0.3, 1.0);
			if (hit_side == 1) shade *= 0.7;
			vec4 tex = texture(wall_tex, vec2(w_x, (sy - wall_top) / (wall_bot - wall_top)));
			// Tint walls on lower floors
			if (wall_height < -0.5) tex *= vec4(1.3, 0.7, 0.4, 1.0);
			else if (wall_height < -0.1) tex *= vec4(1.1, 0.85, 0.7, 1.0);
			COLOR = tex * shade;
		} else if (sy > wall_bot) {
			float d = eye_h * focal / max(sy - hh, 0.5);
			float ang = ray_angle;
			float wx = cam_pos.x + cos(ang) * d;
			float wy = cam_pos.y + sin(ang) * d;
			ivec2 tc = ivec2(int(floor(wx)), int(floor(wy)));
			if (tc.x >= 0 && tc.y >= 0 && tc.x < map_w && tc.y < map_h) {
				vec4 cell = texelFetch(map_tex, tc, 0);
				float fh = cell.g * 4.0 - 2.0;
				vec4 fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
				float shade2 = clamp(1.0 - d / fog_dist, 0.0, 1.0);
				COLOR = fc * shade2;
			} else {
				COLOR = vec4(0.06, 0.06, 0.07, 1.0);
			}
		} else {
			float t = sy / view_size.y;
			COLOR = mix(vec4(0.03, 0.03, 0.04, 1.0), vec4(0.0, 0.0, 0.0, 1.0), t * 2.0);
		}
	} else {
		// No wall hit — floor/ceiling
		if (sy >= hh) {
			float d = eye_h * focal / max(sy - hh, 0.5);
			float ang = ray_angle;
			float wx = cam_pos.x + cos(ang) * d;
			float wy = cam_pos.y + sin(ang) * d;
			ivec2 tc = ivec2(int(floor(wx)), int(floor(wy)));
			if (tc.x >= 0 && tc.y >= 0 && tc.x < map_w && tc.y < map_h) {
				vec4 cell = texelFetch(map_tex, tc, 0);
				float fh = cell.g * 4.0 - 2.0;
				vec4 fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
				float shade2 = clamp(1.0 - d / fog_dist, 0.0, 1.0);
				COLOR = fc * shade2;
			} else {
				COLOR = vec4(0.06, 0.06, 0.07, 1.0);
			}
		} else {
			float t = sy / view_size.y;
			COLOR = mix(vec4(0.03, 0.03, 0.04, 1.0), vec4(0.0, 0.0, 0.0, 1.0), t * 2.0);
		}
	}

	// Fog
	float fx = abs(px.x - view_size.x * 0.5) / (view_size.x * 0.5);
	float fy = abs(px.y - view_size.y * 0.5) / (view_size.y * 0.5);
	float fog = smoothstep(0.5, 1.0, max(fx, fy)) * 0.6;
	COLOR = mix(COLOR, vec4(0.08, 0.08, 0.08, 1.0), fog);
}
