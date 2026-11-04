shader_type canvas_item;
// Splits the colors outward from the center for a moment on big hits.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount = 0.0;

void fragment() {
	vec2 offset = (SCREEN_UV - vec2(0.5)) * amount;
	float r = texture(screen_texture, SCREEN_UV + offset).r;
	float g = texture(screen_texture, SCREEN_UV).g;
	float b = texture(screen_texture, SCREEN_UV - offset).b;
	COLOR = vec4(r, g, b, 1.0);
}
