shader_type canvas_item;
render_mode unshaded;

// Explicit time lets the scene freeze every effect at the same instant.
uniform float effect_time = 0.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 1.0;
uniform float phase = 0.0;
uniform vec4 vapor_color : source_color = vec4(0.67, 0.95, 0.88, 0.11);

float vapor_hash(vec2 position) {
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453);
}

float vapor_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 part = fract(position);
	vec2 blend = part * part * (3.0 - 2.0 * part);
	return mix(
		mix(vapor_hash(cell), vapor_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(vapor_hash(cell + vec2(0.0, 1.0)), vapor_hash(cell + vec2(1.0)), blend.x),
		blend.y
	);
}

void fragment() {
	float t = effect_time * 0.23 + phase;
	float height = 1.0 - UV.y;
	float sway = sin(height * 5.8 - t * 1.3) * (0.025 + height * 0.105);
	float width = mix(0.09, 0.37, height);
	float envelope = 1.0 - smoothstep(width * 0.15, width, abs(UV.x - 0.5 - sway));
	float broad_noise = vapor_noise(vec2(UV.x * 6.0, UV.y * 5.0 + t));
	float detail_noise = vapor_noise(vec2(UV.x * 12.0 - t * 0.24, UV.y * 10.0 + t * 1.4));
	float density = smoothstep(0.25, 0.8, broad_noise * 0.75 + detail_noise * 0.25);
	// Both ends are transparent; no rectangular seam at the painted waterline.
	float fade = smoothstep(0.0, 0.11, height) * (1.0 - smoothstep(0.22, 0.95, height));
	COLOR = vec4(vapor_color.rgb, vapor_color.a * envelope * density * fade * effect_strength);
}
