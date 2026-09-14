shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform bool silhouette = false;

float coarse_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1, 0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0, 1), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1, 1), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// COLOR already includes the sampled sprite texture in a CanvasItem fragment.
	vec4 painted = COLOR;
	float mask = UV.x * 0.35 + coarse_noise(UV * vec2(9.0, 5.0)) * 0.65;
	float threshold = mix(-0.12, 1.12, erosion);
	painted.a *= smoothstep(threshold, threshold + 0.08, mask);
	if (silhouette) {
		painted.rgb = vec3(0.72);
	}
	COLOR = painted;
}
