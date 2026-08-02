shader_type canvas_item;

uniform float speed = 1.5;
uniform float height_limit = 0.5;
uniform float bar_height = 0.03;
uniform float color_speed = 1.0;
uniform float alpha = 1.0;
uniform float follow_strength = 0.7;
uniform float fade_strength = 2.0;
uniform bool use_rgb = false;
uniform vec4 color1 : source_color = vec4(0.0588, 0.0588, 0.1059, 1.0);
uniform vec4 color2 : source_color = vec4(0.3373, 0.3529, 0.4588, 1.0);
uniform vec4 color3 : source_color = vec4(0.7765, 0.7176, 0.7451, 1.0);
uniform vec4 color4 : source_color = vec4(0.9804, 0.9843, 0.9647, 1.0);


float random(float x) {
	return fract(sin(x * 12345.678) * 98765.4321);
}

void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y / bar_height);
	float base_offset = random(row) * 2.0;
	float neighbor_offset = random(row + 1.0) * 2.0;
	float offset = mix(base_offset, neighbor_offset, follow_strength);
	float global_wave = sin(TIME * speed);
	float local_wave = sin(TIME * speed + offset) * 0.3;
	float wave = (global_wave + local_wave) * 0.5 + 0.5;
	wave *= height_limit;
	float mask = step(uv.y, wave);
	float fade = clamp((wave - uv.y) * fade_strength, 0.0, 1.0);

	vec3 final_color;
	if (use_rgb) {
		float r = sin(TIME * color_speed + row * 0.2) * 0.5 + 0.5;
		float g = sin(TIME * color_speed + row * 0.2 + 2.0) * 0.5 + 0.5;
		float b = sin(TIME * color_speed + row * 0.2 + 4.0) * 0.5 + 0.5;
		final_color = vec3(r, g, b);
	} else {
		float t = fract(TIME * color_speed + row * 0.1) * 4.0;
		float segment = floor(t);
		float local_t = t - segment;
		vec3 c_a, c_b;
		if (segment < 1.0) {
			c_a = color1.rgb; c_b = color2.rgb;
		} else if (segment < 2.0) {
			c_a = color2.rgb; c_b = color3.rgb;
		} else if (segment < 3.0) {
			c_a = color3.rgb; c_b = color4.rgb;
		} else {
			c_a = color4.rgb; c_b = color1.rgb;
		}
		final_color = mix(c_a, c_b, local_t);
	}

	COLOR = vec4(final_color, fade * mask * alpha);
}
