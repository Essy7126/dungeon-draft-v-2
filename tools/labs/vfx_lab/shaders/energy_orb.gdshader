shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.16, 0.01, 1.0);
uniform float intensity : hint_range(0.1, 3.0) = 1.2;
uniform float time_offset = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float flow = noise(p * 7.0 + vec2(TIME * 2.3 + time_offset, -TIME * 1.4));
	float flame = sin(angle * 7.0 - TIME * 8.0 + flow * 4.0) * 0.025;
	float mask = smoothstep(0.5 + flame, 0.25, radius);
	float rim = smoothstep(0.5, 0.31, radius) - smoothstep(0.34, 0.17, radius);
	float core = smoothstep(0.26, 0.02, radius + (flow - 0.5) * 0.06);
	vec3 energy = mix(edge_color.rgb, core_color.rgb, core);
	energy *= 0.75 + flow * 0.65 + rim * 0.5;
	COLOR = vec4(energy * intensity, mask * (0.8 + core * 0.2));
}
