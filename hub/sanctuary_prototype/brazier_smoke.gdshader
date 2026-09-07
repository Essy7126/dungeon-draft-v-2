shader_type canvas_item;
render_mode unshaded;

uniform vec4 smoke_color : source_color = vec4(0.76, 0.72, 0.61, 0.23);
uniform float speed : hint_range(0.0, 2.0) = 0.32;
uniform float phase = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

void fragment() {
	float t = TIME * speed + phase;
	float height = 1.0 - UV.y;
	float sway = sin(height * 8.0 - t * 1.8) * 0.1 * height;
	float width = mix(0.045, 0.3, height);
	float envelope = 1.0 - smoothstep(width * 0.4, width, abs(UV.x - 0.5 - sway));
	float n = noise(vec2(UV.x * 7.0 + sin(t), UV.y * 9.0 + t * 2.5));
	n = n * 0.65 + noise(vec2(UV.x * 13.0, UV.y * 18.0 + t * 3.0)) * 0.35;
	float density = smoothstep(0.32, 0.78, n);
	float fade = smoothstep(0.0, 0.12, height) * (1.0 - smoothstep(0.45, 1.0, height));
	COLOR = vec4(smoke_color.rgb, smoke_color.a * envelope * density * fade);
}
