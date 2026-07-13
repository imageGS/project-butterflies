shader_type canvas_item;

uniform float progress : hint_range(0, 1) = 0;
uniform float cell_size = 8.0;
uniform float seed = 0.0;

float _hash(vec2 p) {
	p += seed;
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = floor(UV * 400.0 / cell_size) * cell_size / 400.0;
	float n = _hash(uv);
	float strength = 1.0 - abs(progress - 0.5) * 2.0;
	float alpha = smoothstep(n * 1.05, n * 1.05 + 0.05, strength);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
