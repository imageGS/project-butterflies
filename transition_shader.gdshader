shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0, 1) = 0.0;
uniform float strength = 1.5;
uniform sampler2D parallax_map : filter_nearest;

void fragment() {
	float screen_texels = float(textureSize(SCREEN_TEXTURE, 0).x);
	float offset = 1.0 - texture(parallax_map, vec2(0, SCREEN_UV.y)).y;
	float pixel_shift = floor(offset * progress * strength * screen_texels);
	float uv_shift = pixel_shift / screen_texels;

	vec2 uv = SCREEN_UV + vec2(uv_shift, 0);
	uv = clamp(uv, vec2(0), vec2(1));
	vec4 color = texture(SCREEN_TEXTURE, uv);

	COLOR = mix(color, vec4(0, 0, 0, 1), progress);
}
