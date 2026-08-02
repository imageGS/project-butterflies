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
uniform sampler2D floor_atlas;
uniform sampler2D floor_map;
uniform float atlas_cols = 8.0;
uniform float atlas_rows = 1.0;
uniform float map_w = 48.0;
uniform float map_h = 48.0;

uniform sampler2D fog_tex;
uniform float ground_fog_alpha = 0.25;
uniform vec4 ground_fog_color : source_color = vec4(0.4, 0.4, 0.43, 1.0);

const int MAX_LIGHTS = 16;
uniform int light_count = 0;
uniform vec2 light_pos[MAX_LIGHTS];
uniform float light_rad[MAX_LIGHTS];
uniform float light_int[MAX_LIGHTS];
uniform vec3 light_col[MAX_LIGHTS];
uniform float ambient_light = 0.05;
uniform float light_height[MAX_LIGHTS];

uniform bool flashlight_on = false;
uniform vec2 flashlight_pos = vec2(0.0);
uniform float flashlight_rad = 0.0;
uniform float flashlight_int = 0.0;
uniform vec3 flashlight_col = vec3(1.0);
uniform float flashlight_aim = 0.0;

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
			vec4 fc;
			vec4 fmap = texture(floor_map, uv);
			if (fmap.a > 0.5) {
				vec2 at_uv = round(fmap.rg * vec2(atlas_cols, atlas_rows)) / vec2(atlas_cols, atlas_rows) + fract(vec2(wx, wy)) / vec2(atlas_cols, atlas_rows);
				fc = texture(floor_atlas, at_uv);
			} else {
				fc = fh < -0.5 ? texture(rail_tex, fract(vec2(wx, wy))) : texture(floor_tex, fract(vec2(wx, wy)));
			}

			vec3 entity_light = vec3(ambient_light);
			for (int i = 0; i < MAX_LIGHTS; i++) {
				if (i >= light_count) break;
				vec2 delta = vec2(wx, wy) - light_pos[i];
				float dist = sqrt(delta.x * delta.x + delta.y * delta.y + light_height[i] * light_height[i]);
				if (dist >= light_rad[i]) continue;
				float falloff = 1.0 - smoothstep(0.0, light_rad[i], dist);
				entity_light += falloff * light_int[i] * light_col[i];
			}
			entity_light = clamp(entity_light, 0.0, 1.0);

			vec3 flash_light = vec3(0.0);
			if (flashlight_on) {
				float fdist = distance(vec2(wx, wy), flashlight_pos);
				if (fdist < flashlight_rad) {
					float dx = wx - flashlight_pos.x;
					float dy = wy - flashlight_pos.y;
					float angle_to = atan(dy, dx);
					float angle_diff = abs(angle_to - (cam_angle + flashlight_aim));
					if (angle_diff > 3.14159) angle_diff = 6.28318 - angle_diff;
					float beam = 1.0 - smoothstep(0.35, 0.70, angle_diff);
					if (beam > 0.0) {
						float ffalloff = 1.0 - smoothstep(0.0, flashlight_rad, fdist);
						flash_light = ffalloff * beam * flashlight_int * flashlight_col;
					}
				}
			}

			vec3 total_light = clamp(entity_light + flash_light, 0.0, 1.0);
			fc.rgb *= total_light;

			float fog_start = max(fog_dist - fog_fade, 0.0);
			float fog = clamp((d - fog_start) / fog_fade, 0.0, 1.0);
			float gf = texture(fog_tex, vec2(wx, wy) / vec2(map_w, map_h)).r;
			vec2 ts = vec2(1.0 / map_w, 1.0 / map_h);
			float wn = texture(map_tex, uv + vec2(-ts.x, 0.0)).r;
			wn += texture(map_tex, uv + vec2(ts.x, 0.0)).r;
			wn += texture(map_tex, uv + vec2(0.0, -ts.y)).r;
			wn += texture(map_tex, uv + vec2(0.0, ts.y)).r;
			gf = min(gf + wn * 0.06, 1.0);
			gf *= ground_fog_alpha * (0.5 + fog * 0.5);
			float n1 = sin(wx * 2.5 + wy * 1.7 + TIME * 0.5) * 0.5;
			float n2 = cos(wx * 1.3 - wy * 2.1 + TIME * 0.3) * 0.3;
			gf *= clamp(1.0 + n1 + n2, 0.3, 1.7);
			vec3 ground_fogged = mix(fc.rgb, ground_fog_color.rgb, gf);
			COLOR = vec4(mix(ground_fogged, fog_color.rgb, fog), 1.0);
		} else {
			COLOR = vec4(0.06, 0.06, 0.07, 1.0);
		}
	}
}
