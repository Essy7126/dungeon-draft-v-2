shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.65, 1.0);
uniform vec4 body_color : source_color = vec4(1.0, 0.48, 0.06, 1.0);
uniform vec4 edge_color : source_color = vec4(0.82, 0.06, 0.015, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float effect_time = 0.0;
uniform float seed_value = 1.0;
uniform float turbulence : hint_range(0.0, 1.5) = 0.6;
uniform float distortion : hint_range(0.0, 0.3) = 0.12;
uniform float stretch : hint_range(0.5, 2.5) = 1.0;
uniform float tail_bias : hint_range(0.0, 0.3) = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed_value * 13.17) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	mat2 turn = mat2(vec2(0.82, -0.57), vec2(0.57, 0.82));
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p = turn * p * 2.03 + vec2(5.2, 1.7);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float flow_time = effect_time * (2.2 + turbulence * 1.8);
	vec2 warp = vec2(
		fbm(p * 5.2 + vec2(flow_time, seed_value * 0.07)),
		fbm(p * 5.2 + vec2(-seed_value * 0.05, -flow_time * 0.74))
	) - vec2(0.5);
	p += warp * distortion * (0.55 + turbulence * 0.65);
	p.x /= stretch;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float coarse = fbm(p * 7.5 + vec2(-flow_time * 0.55, flow_time * 0.92));
	float harmonic = sin(angle * 3.0 + seed_value * 0.11 + effect_time * 5.0) * 0.035;
	harmonic += sin(angle * 7.0 - seed_value * 0.07 - effect_time * 8.5) * 0.018;
	float back = smoothstep(0.18, -0.46, p.x) * tail_bias;
	float boundary = 0.39 + (coarse - 0.5) * distortion + harmonic + back;
	float mask = smoothstep(boundary + 0.055, boundary - 0.075, r);
	float inner_noise = fbm(p * 12.0 + vec2(flow_time * 1.25, -flow_time));
	float body = smoothstep(boundary * 0.92, boundary * 0.34, r + (inner_noise - 0.5) * 0.07);
	float core = smoothstep(0.23, 0.035, r + (inner_noise - 0.5) * 0.055);
	float fissure = smoothstep(0.37, 0.82, inner_noise) * body;
	vec3 color = mix(edge_color.rgb, body_color.rgb, body);
	color = mix(color, core_color.rgb, clamp(core * 0.88 + fissure * 0.28, 0.0, 1.0));
	float luminous = 0.56 + coarse * 0.52 + core * 0.72 + fissure * 0.28;
	COLOR = vec4(color * luminous * intensity, mask * opacity * (0.72 + core * 0.28));
}
