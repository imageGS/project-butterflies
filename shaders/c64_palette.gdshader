shader_type canvas_item;

uniform float exposure = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D palette_tex : repeat_disable, filter_nearest;

uniform float dither_strength = 0.5;
uniform bool use_dither = true;
uniform bool use_palette = true;
float get_bayer(ivec2 p) {
	int x = p.x % 4; int y = p.y % 4;
	float m[16] = { 0.0,8.0,2.0,10.0, 12.0,4.0,14.0,6.0, 3.0,11.0,1.0,9.0, 15.0,7.0,13.0,5.0 };
	return m[y*4+x] / 16.0;
}

vec3 posterize(vec3 c, int lv) { return floor(c * float(lv)) / float(lv); }

void fragment() {
	vec3 color = texture(screen_tex, SCREEN_UV).rgb * exposure;
	ivec2 pc = ivec2(FRAGCOORD.xy);

	if (use_dither && dither_strength > 0.0) {
		float t = (get_bayer(pc) - 0.5) * 2.0 * dither_strength / 16.0;
		color = clamp(color + vec3(t), 0.0, 1.0);
	}

	if (use_palette) {
		float best = 999.0; vec3 closest = vec3(0.0);
		for (int i = 0; i < 16; i++) {
			float u = (float(i) + 0.5) / 16.0;
			vec3 pc2 = texture(palette_tex, vec2(u, 0.5)).rgb;
			float d = distance(color, pc2);
			if (d < best) { best = d; closest = pc2; }
		}
		color = closest;
	}

	COLOR = vec4(color, 1.0);
}
