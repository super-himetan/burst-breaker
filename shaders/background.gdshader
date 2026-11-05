shader_type canvas_item;
// Slow drifting light over dark ink. `heat` brightens it as combos climb.

uniform float heat = 0.0;
uniform float fever = 0.0;
uniform vec3 sky_a = vec3(0.30, 0.18, 0.62);
uniform vec3 sky_b = vec3(0.05, 0.42, 0.50);
uniform vec3 sky_c = vec3(0.72, 0.13, 0.42);

float blob(vec2 uv, vec2 center, float radius) {
	return smoothstep(radius, 0.0, distance(uv, center));
}

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.07;
	vec3 color = vec3(0.051, 0.039, 0.118);
	color += sky_a * blob(uv, vec2(0.25 + 0.14 * sin(t * 2.1), 0.12 + 0.07 * cos(t * 1.7)), 0.75) * 0.48;
	color += sky_b * blob(uv, vec2(0.85 + 0.10 * cos(t * 1.3), 0.58 + 0.12 * sin(t * 1.9)), 0.68) * 0.26;
	color += sky_c * blob(uv, vec2(0.30 + 0.15 * cos(t * 2.4), 0.96 + 0.05 * sin(t)), 0.72) * (0.18 + heat * 0.75);
	color += vec3(0.95, 0.42, 0.25) * blob(uv, vec2(0.5, 0.42), 0.8) * heat * 0.22;
	color = mix(color, vec3(0.95, 0.68, 0.18), fever * 0.28);
	float vignette = smoothstep(1.05, 0.35, distance(uv, vec2(0.5)));
	color *= mix(0.55, 1.0, vignette);
	// A little noise stops the soft gradients from banding.
	color += (noise(uv * 800.0) - 0.5) * 0.012;
	COLOR = vec4(color, 1.0);
}
