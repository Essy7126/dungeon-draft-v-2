shader_type canvas_item;
render_mode unshaded, blend_mix;

// The density painting stays in image space. Curl never displaces this mask:
// a black route or statue exclusion always contributes exactly zero smoke.
uniform sampler2D density_mask : filter_linear, repeat_disable;
uniform bool has_density_mask = false;
uniform vec4 fog_color : source_color = vec4(0.267, 0.482, 0.502, 1.0);
uniform float opacity : hint_range(0.0, 0.6) = 0.20;
uniform float effect_time = 0.0;
uniform float effect_strength = 1.0;
uniform vec2 drift = vec2(-0.0008, 0.00003);
uniform float field_scale : hint_range(0.5, 2.0) = 1.0;
uniform float curl_strength : hint_range(0.0, 2.0) = 1.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.75;
uniform float edge_fade : hint_range(0.005, 0.3) = 0.065;
uniform float seed = 17.0;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Quintic value noise and its analytic gradient share the same four samples.
// Smooth derivatives make the curled filaments cross cell edges without jerks.
vec3 noise_gradient(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	float cross_term = a - b - c + d;
	float value = a + (b - a) * u.x + (c - a) * u.y + cross_term * u.x * u.y;
	vec2 gradient = (vec2(b - a, c - a) + cross_term * u.yx) * du;
	return vec3(value, gradient);
}

float soft_noise(vec2 p) {
	return noise_gradient(p).x;
}

vec2 curl(vec2 p) {
	vec3 field = noise_gradient(p);
	return vec2(field.z, -field.y);
}

float smoke_sheet(vec2 p, float breakup) {
	// Three bounded scales add soft structure, not pixel-sized grain. A shear
	// breaks aligned grid patterns while preserving the ground-hugging shape.
	vec2 middle = vec2(p.x * 1.93 + p.y * 0.17, p.y * 1.81 - p.x * 0.09);
	float billow = soft_noise(p) * 0.57
		+ soft_noise(middle + vec2(7.1, 13.7)) * 0.28
		+ soft_noise(p * vec2(3.91, 3.37) + vec2(19.4, 3.6)) * 0.15;
	float veil = smoothstep(0.26, 0.72, billow);
	// Thin, broken density contours become the curling wisps. They fade along
	// their length instead of becoming solid lines or repeated smoke rings.
	float filament = 1.0 - smoothstep(0.025, 0.145, abs(billow - 0.53));
	float wisps = filament * smoothstep(0.18, 0.78, breakup);
	return mix(veil, veil * 0.28 + wisps * 0.72, detail_strength);
}

void fragment() {
	vec4 item_color = COLOR;
	vec2 uv = UV;
	float density;
	if (has_density_mask) {
		density = clamp(texture(density_mask, uv).r, 0.0, 1.0);
	} else {
		float sides = smoothstep(0.10, 0.30, abs(uv.x - 0.5));
		float floor_band = smoothstep(0.28, 0.60, uv.y)
			* (1.0 - smoothstep(0.90, 1.0, uv.y));
		density = sides * floor_band;
	}
	float border_distance = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float border = smoothstep(0.0, max(edge_fade, 0.005), border_distance);

	vec2 shift = drift * effect_time;
	vec2 origin = vec2(seed * 0.173, seed * 0.391);
	// Two curl scales roll and stretch the sheets sideways. Their deformation
	// evolves through the supplied advection only, including in reduced mode.
	vec2 flow_domain = (uv + shift * 0.37) * vec2(4.8, 8.1) * field_scale + origin;
	vec2 flow = curl(flow_domain);
	flow += curl(flow_domain * 1.73 + vec2(11.3, 5.9) - shift * 3.0) * 0.42;
	vec2 bent = uv + flow * vec2(0.030, 0.018) * curl_strength;
	float breakup = soft_noise(
		(uv - shift * 0.23) * vec2(8.0, 12.0) * field_scale + origin + vec2(5.1, 16.8)
	);

	// Independently advected layers reveal and conceal each other. The narrow
	// vertical scale makes modest horizontal drift readable within a few seconds.
	vec2 front = (bent + shift) * vec2(6.5, 26.0) * field_scale + origin;
	vec2 back = (uv - flow * vec2(0.016, 0.011) * curl_strength - shift * 0.61)
		* vec2(5.2, 19.0) * field_scale + origin + vec2(17.1, 8.4);
	float front_smoke = smoke_sheet(front, breakup);
	float back_smoke = smoke_sheet(back, 1.0 - breakup * 0.70);
	// Transmittance blending keeps overlapping wisps soft and bounded. There is
	// no constant veil: every clear gap can return to the untouched painting.
	float body = 1.0 - (1.0 - front_smoke * 0.94) * (1.0 - back_smoke * 0.78);
	float alpha = opacity * effect_strength * density * border * body;
	vec3 tint = fog_color.rgb * mix(0.82, 1.07, front_smoke * 0.65 + breakup * 0.35);
	COLOR = vec4(tint, clamp(alpha, 0.0, 0.6)) * item_color;
}
