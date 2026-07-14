shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.45;
uniform float softness : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float alpha = smoothstep(radius - softness, radius + softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
