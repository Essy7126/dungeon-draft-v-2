shader_type canvas_item;
render_mode unshaded;

// Material data, never color-corrected: R water, G leaves, B protected ground/props.
uniform sampler2D material_mask : filter_linear, repeat_disable;
uniform float effect_time = 0.0;
uniform float foliage_strength = 1.7;
uniform float foliage_speed = 0.85;
uniform bool lamp_enabled = false;
uniform vec2 lamp_center = vec2(0.0);
uniform vec2 lamp_radius = vec2(1.0);
varying vec2 native_position;

void vertex() {
	native_position = VERTEX;
}

void fragment() {
	vec2 size = vec2(1920.0, 1200.0);
	vec2 p = native_position;
	vec2 uv = p / size;
	vec4 original = texture(TEXTURE, uv);
	vec3 mask = texture(material_mask, uv).rgb;
	float free_surface = 1.0 - clamp(mask.b, 0.0, 1.0);
	float wet = mask.r * free_surface;
	float leaves = mask.g * free_surface;
	float t = effect_time;
	vec2 lamp_q = (p - lamp_center) / max(lamp_radius, vec2(1.0));
	if (lamp_enabled) {
		// Glass, frame and handle are rigid, even beside a water or reed mask.
		float cage_lock = 1.0 - smoothstep(2.6, 3.2, length(lamp_q));
		wet *= 1.0 - cage_lock;
		leaves *= 1.0 - cage_lock;
	}
	vec2 current = vec2(
		sin(p.y * 0.027 - t * 0.45 + sin(p.x * 0.014 + t * 0.17)) * 0.65,
		cos(p.x * 0.024 + t * 0.31) * 0.38
	);
	float wind_time = t * foliage_speed;
	vec2 wind = vec2(
		sin(wind_time * 0.83 + p.y * 0.009) * 1.45,
		cos(wind_time * 0.63 + p.x * 0.010) * 0.26
	);
	// Default leaf travel is about 2.5 native pixels; protected tile tops stay exact.
	vec2 offset = current * wet + wind * leaves * foliage_strength;
	vec2 candidate_uv = clamp(uv + offset / size, vec2(0.0), vec2(1.0));
	offset *= 1.0 - texture(material_mask, candidate_uv).b;
	vec3 painted = texture(TEXTURE, clamp(uv + offset / size, vec2(0.0), vec2(1.0))).rgb;
	float a = sin(p.x * 0.040 + sin(p.y * 0.020 + t * 0.19) * 1.8 - t * 0.32);
	float b = sin(p.y * 0.050 + sin(p.x * 0.020 - t * 0.23) * 1.2 + t * 0.41);
	float caustic = pow(max(0.0, 1.0 - abs(a + b) * 2.4), 3.0);
	painted += vec3(0.08, 0.30, 0.26) * wet * (caustic * 0.032 + sin(p.y * 0.040 - t * 0.47) * 0.011);
	if (lamp_enabled) {
		float pulse = sin(t * 2.3) * 0.55 + sin(t * 4.7) * 0.30 + sin(t * 8.1) * 0.15;
		float glass = smoothstep(0.36, 0.78, max(original.g, original.r * 0.62))
			* smoothstep(0.12, 0.45, original.r - original.b);
		float core = exp(-dot(lamp_q, lamp_q) * 1.7)
			* (1.0 - smoothstep(0.8, 1.6, length(lamp_q)));
		float window = core * glass;
		float tongue_x = lamp_q.x + sin(t * 3.4 + lamp_q.y * 3.0) * 0.05;
		float tongue = exp(-pow(tongue_x / 0.24, 2.0) - pow((lamp_q.y + 0.08) / 0.55, 2.0));
		// Light varies in the painted window; no lamp UV or silhouette displacement.
		painted += original.rgb * window * pulse * 0.20;
		painted += vec3(1.0, 0.46, 0.05) * window * tongue * (0.04 + pulse * 0.04);
		vec2 halo_radius = clamp(lamp_radius * 3.4, vec2(24.0, 32.0), vec2(64.0, 78.0));
		vec2 halo = (p - lamp_center) / halo_radius;
		float spill = exp(-dot(halo, halo) * 2.2) * (1.0 - smoothstep(0.75, 1.0, length(halo)));
		painted += vec3(1.0, 0.55, 0.16) * spill * pulse * 0.025;
	}
	COLOR = vec4(clamp(painted, vec3(0.0), vec3(1.0)), original.a);
}
