shader_type canvas_item;
render_mode unshaded;

const int MAX_LIGHTS = 48;
const int MAX_OBSTRUCTORS = 24;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

uniform int light_count = 0;
uniform vec2 light_positions[MAX_LIGHTS];
uniform float light_radii[MAX_LIGHTS];
uniform vec3 light_colors[MAX_LIGHTS];
uniform float light_intensities[MAX_LIGHTS];
uniform int obstructor_count = 0;
uniform vec2 obstructor_positions[MAX_OBSTRUCTORS];
uniform float obstructor_radii[MAX_OBSTRUCTORS];

uniform float ambient : hint_range(0.0, 1.0) = 0.05;
uniform vec3 darkness_color : source_color = vec3(0.02, 0.02, 0.06);
uniform float dither_levels : hint_range(1.0, 16.0) = 6.0;
uniform float softness : hint_range(0.0, 1.0) = 0.30;
uniform float light_curve : hint_range(0.3, 3.0) = 1.6;
uniform float dither_pixel_size : hint_range(1.0, 6.0) = 2.0;
uniform float light_glow : hint_range(0.0, 1.0) = 0.15;
uniform bool occlusion_enabled = true;

float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer4(a); }

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return distance(p, a + ab * t);
}

float visibility(vec2 frag, vec2 lpos) {
	if (!occlusion_enabled) { return 1.0; }
	for (int i = 0; i < MAX_OBSTRUCTORS; i++) {
		if (i >= obstructor_count) break;
		if (distance(frag, obstructor_positions[i]) < obstructor_radii[i]) continue;
		if (seg_dist(obstructor_positions[i], frag, lpos) < obstructor_radii[i]) return 0.0;
	}
	return 1.0;
}

void fragment() {
	vec2 frag = FRAGCOORD.xy;
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	float lit = ambient;
	vec3 glow = vec3(0.0);

	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) break;
		float r = max(light_radii[i], 1.0);
		float d = distance(frag, light_positions[i]);
		float falloff = 1.0 - smoothstep(r * softness, r, d);
		if (falloff <= 0.0) continue;
		falloff *= visibility(frag, light_positions[i]);
		float contrib = falloff * light_intensities[i];
		lit += contrib;
		glow += light_colors[i] * contrib;
	}

	lit = clamp(lit, 0.0, 1.0);
	lit = pow(lit, light_curve);
	vec2 dcoord = floor(FRAGCOORD.xy / max(dither_pixel_size, 1.0));
	float bayer = bayer8(dcoord);
	float banded = clamp(floor(lit * dither_levels + bayer) / dither_levels, 0.0, 1.0);
	vec3 outc = mix(darkness_color, scene, banded);
	outc += glow * banded * light_glow;
	COLOR = vec4(outc, 1.0);
}
