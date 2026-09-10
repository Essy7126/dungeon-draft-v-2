shader_type canvas_item;
render_mode unshaded;

// Same controller contract as the painted halt shader; this dry map has no water.
uniform sampler2D materials : filter_linear, repeat_disable;
uniform sampler2D flow_map : filter_linear, repeat_disable;
uniform bool has_flow_map = false;
uniform vec4 torch_strength[12];
uniform vec2 source_size = vec2(1672.0, 941.0);
uniform float effect_time = 0.0;
uniform float strength = 1.0;
uniform bool water_enabled = false;
uniform bool fire_enabled = true;
uniform bool foliage_enabled = false;
uniform vec4 water_color : source_color = vec4(0.28, 0.85, 0.58, 1.0);
uniform int torch_count = 0;
uniform vec4 torches[12];
uniform vec2 ripple_origin = vec2(0.0);
uniform float ripple_age = -1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec2 p = UV * source_size;
	vec2 offset = vec2(0.0);
	float radiance = 0.0;
	float glow = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= torch_count || !fire_enabled) { break; }
		vec2 center = torches[i].xy * source_size;
		vec2 radius = max(torches[i].zw * source_size, vec2(1.0));
		vec2 q = (p - center) / radius;
		float phase = float(i) * 7.319;
		float t = effect_time;
		float slow = noise21(vec2(t * 2.1, phase)) * 2.0 - 1.0;
		float fast = noise21(vec2(t * 8.7, phase + 31.0)) * 2.0 - 1.0;
		float flicker = slow * 0.72 + fast * 0.28;
		// Move only luminous, orange flame pixels. Bronze rims and columns stay firm.
		float hot = smoothstep(0.13, 0.38, original.r - original.b);
		hot *= smoothstep(0.42, 0.77, max(original.r, original.g));
		float flame_mask = exp(-dot(q, q) * 1.8) * hot;
		flame_mask *= 1.0 - smoothstep(0.35, 0.78, q.y);
		float tongue = noise21(vec2(q.y * 2.2 - t * 4.4, phase + q.x)) * 2.0 - 1.0;
		offset += vec2(tongue * 1.9 + slow * 0.65, flicker * 1.4)
			* flame_mask * torch_strength[i].x;
		// A faint rising heat shimmer above each bowl, at sub-pixel amplitude.
		vec2 heat_q = (p - center + vec2(0.0, radius.y * 1.2)) / (radius * vec2(1.35, 1.7));
		float heat = exp(-dot(heat_q, heat_q) * 2.2);
		heat *= 1.0 - smoothstep(-0.12, 0.3, q.y);
		offset.x += heat * (noise21(vec2(p.y * 0.09 - t * 2.8, phase)) * 2.0 - 1.0)
			* 0.42 * torch_strength[i].x;
		vec2 halo = (p - center) / vec2(124.0, 98.0);
		glow += exp(-dot(halo, halo) * 1.9) * flicker * torch_strength[i].y;
		radiance += flame_mask * (0.24 + flicker * 0.76) * torch_strength[i].x;
	}
	vec3 painted = texture(TEXTURE, clamp(UV + offset * strength / source_size,
		vec2(0.0), vec2(1.0))).rgb;
	painted += vec3(0.34, 0.13, 0.026) * (radiance * 0.35 + glow * 0.13) * strength;
	COLOR = vec4(clamp(painted, vec3(0.0), vec3(1.0)), original.a);
}
