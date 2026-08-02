shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float light_glow : hint_range(0.0, 1.0) = 0.15;

// Entity light positions (projected to screen) — kept for glow
uniform int light_count = 0;
uniform vec2 light_positions[48];
uniform float light_radii[48];
uniform vec3 light_colors[48];
uniform float light_intensities[48];
uniform float softness : hint_range(0.0, 1.0) = 0.30;

// Flashlight for glow
uniform bool flashlight_on = false;
uniform vec2 flashlight_screen_pos = vec2(0.0);
uniform float flashlight_screen_rad = 0.0;
uniform float flashlight_intensity_val = 0.0;
uniform vec3 flashlight_color_val = vec3(1.0);

void fragment() {
	vec2 frag = FRAGCOORD.xy;
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	vec3 glow = vec3(0.0);

	// Entity lights — glow only
	for (int i = 0; i < 48; i++) {
		if (i >= light_count) break;
		float r = max(light_radii[i], 1.0);
		float d = distance(frag, light_positions[i]);
		float falloff = 1.0 - smoothstep(r * softness, r, d);
		if (falloff <= 0.0) continue;
		glow += light_colors[i] * falloff * light_intensities[i];
	}

	// Flashlight — glow only
	if (flashlight_on) {
		float fd = distance(frag, flashlight_screen_pos);
		float ffalloff = 1.0 - smoothstep(flashlight_screen_rad * softness, flashlight_screen_rad, fd);
		if (ffalloff > 0.0) {
			glow += flashlight_color_val * ffalloff * flashlight_intensity_val;
		}
	}

	vec3 outc = scene + glow * light_glow;
	COLOR = vec4(outc, 1.0);
}
