shader_type canvas_item;
render_mode unshaded;

// La Halle sous les racines: registration is in its native 1376 x 768 pixels.
// The controller supplies time so pauses and comparison captures are repeatable.
uniform float effect_time = 0.0;
uniform float effect_strength : hint_range(0.0, 1.5) = 1.0;
uniform bool water_enabled = true;
uniform bool fire_enabled = true;
uniform bool magic_enabled = true;
uniform vec2 ripple_origin = vec2(0.43023, 0.63411);
uniform float ripple_age = -1.0;

const vec2 SOURCE_SIZE = vec2(1376.0, 768.0);
varying vec4 canvas_tint;

void vertex() { canvas_tint = COLOR; }

float edge_distance(vec2 p, vec2 a, vec2 b) {
	vec2 e = b - a;
	vec2 q = p - a;
	return (e.x * q.y - e.y * q.x) / length(e);
}

float quad_distance(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	return min(min(edge_distance(p, a, b), edge_distance(p, b, c)),
		min(edge_distance(p, c, d), edge_distance(p, d, a)));
}

float capsule_distance(vec2 p, vec2 a, vec2 b, float radius) {
	vec2 e = b - a;
	return length(p - a - e * clamp(dot(p - a, e) / dot(e, e), 0.0, 1.0)) - radius;
}

float cyan_water(vec3 rgb) {
	// Cyan reflections painted onto grey masonry are much less saturated.
	return smoothstep(0.095, 0.245, min(rgb.g, rgb.b) - rgb.r);
}

float left_canal(vec2 p) {
	float a = quad_distance(p, vec2(-8.0, 462.0), vec2(151.0, 540.0),
		vec2(122.0, 583.0), vec2(-8.0, 532.0));
	float b = quad_distance(p, vec2(114.0, 523.0), vec2(266.0, 600.0),
		vec2(188.0, 625.0), vec2(109.0, 585.0));
	float mask = smoothstep(0.0, 3.0, max(a, b));
	// Three visible roots reach down into this channel. Protect their edges too.
	mask *= smoothstep(0.0, 2.0, capsule_distance(p, vec2(170.0, 510.0), vec2(159.0, 552.0), 7.0));
	mask *= smoothstep(0.0, 2.0, capsule_distance(p, vec2(184.0, 520.0), vec2(204.0, 565.0), 8.0));
	mask *= smoothstep(0.0, 2.0, capsule_distance(p, vec2(204.0, 563.0), vec2(201.0, 581.0), 4.0));
	return mask;
}

float right_canal(vec2 p) {
	float d = min(edge_distance(p, vec2(1028.0, 579.0), vec2(1069.0, 566.0)),
		edge_distance(p, vec2(1069.0, 566.0), vec2(1320.0, 654.0)));
	d = min(d, edge_distance(p, vec2(1320.0, 654.0), vec2(1265.0, 680.0)));
	d = min(d, edge_distance(p, vec2(1265.0, 680.0), vec2(1023.0, 590.0)));
	d = min(d, edge_distance(p, vec2(1023.0, 590.0), vec2(1028.0, 579.0)));
	float mask = smoothstep(0.0, 3.0, d);
	// A conservative hull excludes the foreground gear, its teeth and chains.
	float gear = edge_distance(p, vec2(1066.0, 482.0), vec2(1100.0, 446.0));
	gear = min(gear, edge_distance(p, vec2(1100.0, 446.0), vec2(1176.0, 438.0)));
	gear = min(gear, edge_distance(p, vec2(1176.0, 438.0), vec2(1220.0, 474.0)));
	gear = min(gear, edge_distance(p, vec2(1220.0, 474.0), vec2(1254.0, 555.0)));
	gear = min(gear, edge_distance(p, vec2(1254.0, 555.0), vec2(1245.0, 620.0)));
	gear = min(gear, edge_distance(p, vec2(1245.0, 620.0), vec2(1230.0, 650.0)));
	gear = min(gear, edge_distance(p, vec2(1230.0, 650.0), vec2(1185.0, 645.0)));
	gear = min(gear, edge_distance(p, vec2(1185.0, 645.0), vec2(1120.0, 617.0)));
	gear = min(gear, edge_distance(p, vec2(1120.0, 617.0), vec2(1086.0, 582.0)));
	gear = min(gear, edge_distance(p, vec2(1086.0, 582.0), vec2(1066.0, 482.0)));
	mask *= 1.0 - smoothstep(-3.0, 0.0, gear);
	mask *= smoothstep(0.0, 2.0, capsule_distance(p, vec2(1044.0, 546.0), vec2(1058.0, 587.0), 5.5));
	return mask;
}

float front_canal(vec2 p) {
	float a = quad_distance(p, vec2(424.0, 755.0), vec2(483.0, 747.0),
		vec2(578.0, 779.0), vec2(444.0, 790.0));
	float b = quad_distance(p, vec2(532.0, 763.0), vec2(780.0, 763.0),
		vec2(801.0, 790.0), vec2(532.0, 790.0));
	float c = quad_distance(p, vec2(778.0, 764.0), vec2(832.0, 747.0),
		vec2(869.0, 790.0), vec2(778.0, 790.0));
	float d = quad_distance(p, vec2(846.0, 754.0), vec2(882.0, 743.0),
		vec2(925.0, 783.0), vec2(867.0, 786.0));
	return smoothstep(0.0, 2.5, max(max(a, b), max(c, d)));
}

float fountain_pool(vec2 p) {
	float d = edge_distance(p, vec2(576.0, 470.0), vec2(607.0, 455.0));
	d = min(d, edge_distance(p, vec2(607.0, 455.0), vec2(653.0, 455.0)));
	d = min(d, edge_distance(p, vec2(653.0, 455.0), vec2(690.0, 472.0)));
	d = min(d, edge_distance(p, vec2(690.0, 472.0), vec2(690.0, 487.0)));
	d = min(d, edge_distance(p, vec2(690.0, 487.0), vec2(666.0, 499.0)));
	d = min(d, edge_distance(p, vec2(666.0, 499.0), vec2(617.0, 502.0)));
	d = min(d, edge_distance(p, vec2(617.0, 502.0), vec2(578.0, 490.0)));
	d = min(d, edge_distance(p, vec2(578.0, 490.0), vec2(576.0, 470.0)));
	float pedestal = edge_distance(p, vec2(607.0, 439.0), vec2(655.0, 440.0));
	pedestal = min(pedestal, edge_distance(p, vec2(655.0, 440.0), vec2(655.0, 483.0)));
	pedestal = min(pedestal, edge_distance(p, vec2(655.0, 483.0), vec2(634.0, 497.0)));
	pedestal = min(pedestal, edge_distance(p, vec2(634.0, 497.0), vec2(608.0, 487.0)));
	pedestal = min(pedestal, edge_distance(p, vec2(608.0, 487.0), vec2(607.0, 439.0)));
	return smoothstep(0.0, 2.2, d) * (1.0 - smoothstep(-1.5, 0.0, pedestal));
}

float fountain_jets(vec2 p) {
	float top = capsule_distance(p, vec2(632.4, 427.5), vec2(634.5, 440.0), 3.0);
	float left = capsule_distance(p, vec2(567.7, 476.0), vec2(566.4, 488.0), 1.6);
	float right = capsule_distance(p, vec2(686.4, 477.0), vec2(687.0, 488.0), 1.4);
	return 1.0 - smoothstep(-0.7, 0.8, min(top, min(left, right)));
}

float water_geometry(vec2 p) {
	return max(max(left_canal(p), right_canal(p)), max(front_canal(p), fountain_pool(p)));
}

float flicker(float t, float phase) {
	return 0.48 * sin(t * 5.3 + phase) + 0.32 * sin(t * 8.9 + phase * 2.3)
		+ 0.20 * sin(t * 13.7 + phase * 0.7);
}

vec2 lantern_light(vec2 p, vec2 center, vec2 radius, float phase, float t) {
	vec2 core_uv = (p - center) / vec2(10.0, 13.0);
	vec2 halo_uv = (p - center) / radius;
	float intensity = flicker(t, phase);
	return vec2(exp(-dot(core_uv, core_uv) * 2.0),
		exp(-dot(halo_uv, halo_uv) * 2.5)) * intensity;
}

void fragment() {
	vec2 p = UV * SOURCE_SIZE;
	float t = effect_time;
	float strength = clamp(effect_strength, 0.0, 1.5);
	vec4 original = texture(TEXTURE, UV);
	vec2 displacement = vec2(0.0);
	float water = 0.0;
	float water_light = 0.0;
	float jets = 0.0;
	vec2 lamp_light = vec2(0.0);
	float orb_light = 0.0;
	float orb_halo = 0.0;

	if (water_enabled && strength > 0.0) {
		float pigment = cyan_water(original.rgb);
		float pool = fountain_pool(p);
		water = max(max(left_canal(p), right_canal(p)), max(front_canal(p), pool)) * pigment;
		// Diagonal current follows the lateral channels; the foreground runs right.
		vec2 direction = p.y > 730.0 ? vec2(1.0, 0.0) : vec2(0.92, 0.39);
		float along = dot(p, direction);
		float across = dot(p, vec2(-direction.y, direction.x));
		float flow = along * 0.10 - t * 2.25;
		vec2 drift = direction * sin(flow + sin(across * 0.074) * 1.4) * 1.10
			+ vec2(-direction.y, direction.x) * sin(across * 0.13 + t * 1.0) * 0.37;
		float caustic = pow(max(sin(flow + sin(across * 0.10 - t * 0.36) * 1.9), 0.0), 9.0)
			* (0.4 + 0.6 * pow(max(cos(across * 0.12 + t * 0.43), 0.0), 2.0));
		water_light = caustic * 0.083 + sin(flow * 0.39) * 0.018;
		vec2 from_center = (p - vec2(633.0, 480.0)) * vec2(1.0, 2.0);
		float radial = length(from_center);
		float fountain_wave = sin(radial * 0.38 - t * 3.4);
		drift = mix(drift, from_center / max(radial, 1.0) / vec2(1.0, 2.0)
			* fountain_wave * 1.05, pool);
		water_light = mix(water_light, pow(max(fountain_wave, 0.0), 10.0) * 0.075
			+ sin(radial * 0.12 - t * 1.6) * 0.021, pool);
		if (ripple_age >= 0.0 && ripple_age < 5.0) {
			vec2 delta = (p - ripple_origin * SOURCE_SIZE) * vec2(1.0, 2.2);
			float distance_from_touch = length(delta);
			float front = distance_from_touch - ripple_age * 42.0;
			float fade = smoothstep(0.0, 0.10, ripple_age) * (1.0 - smoothstep(1.3, 4.5, ripple_age));
			float ring = exp(-pow(front / 3.1, 2.0)) * fade;
			water_light += ring * 0.14;
			drift += delta / max(distance_from_touch, 1.0) / vec2(1.0, 2.2)
				* sin(front * 0.47) * exp(-abs(front) * 0.07) * fade * 1.5;
		}
		vec2 candidate = drift * water * strength;
		displacement += candidate * water_geometry(p + candidate);
		jets = fountain_jets(p) * pigment;
		displacement += vec2(sin(p.y * 0.33 - t * 6.0) * 0.37, sin(t * 4.5) * 0.42)
			* jets * strength;
	}

	if (fire_enabled && strength > 0.0) {
		// Only glass light and nearby painted surfaces flicker. Housings stay still.
		lamp_light = lantern_light(p, vec2(342.0, 360.0), vec2(65.0, 69.0), 0.4, t)
			+ lantern_light(p, vec2(578.0, 273.0), vec2(62.0, 65.0), 1.7, t)
			+ lantern_light(p, vec2(625.0, 232.0), vec2(55.0, 63.0), 3.8, t)
			+ lantern_light(p, vec2(835.0, 243.0), vec2(45.0, 61.0), 5.2, t)
			+ lantern_light(p, vec2(893.0, 277.0), vec2(56.0, 63.0), 2.7, t)
			+ lantern_light(p, vec2(1056.0, 344.0), vec2(55.0, 63.0), 4.8, t);
	}

	if (magic_enabled && strength > 0.0) {
		vec2 q = p - vec2(962.0, 327.0);
		float orb = 1.0 - smoothstep(12.2, 15.0, length(q));
		float breathe = sin(t * 1.43 + 0.6);
		float swirl = sin(length(q) * 0.52 - t * 1.7 + atan(q.y, q.x) * 2.0);
		orb_light = orb * (breathe * 0.066 + pow(max(swirl, 0.0), 7.0) * 0.072);
		orb_halo = exp(-dot(q / vec2(38.0, 33.0), q / vec2(38.0, 33.0)) * 2.7) * breathe;
		displacement += vec2(-q.y, q.x) * sin(t * 0.9) * orb * strength * 0.036;
	}

	vec2 inset = vec2(0.5) / SOURCE_SIZE;
	vec4 painted = texture(TEXTURE, clamp(UV + displacement / SOURCE_SIZE, inset, vec2(1.0) - inset));
	painted.rgb += vec3(0.25, 0.93, 0.86) * water_light * water * strength;
	painted.rgb += vec3(0.20, 0.90, 0.84) * sin(p.y * 0.72 - t * 7.0) * jets * strength * 0.060;
	painted.rgb *= vec3(1.0) + vec3(0.18, 0.11, 0.037) * lamp_light.y * strength;
	painted.rgb += vec3(1.0, 0.70, 0.24) * lamp_light.x * strength * 0.10;
	painted.rgb += vec3(0.19, 0.70, 1.0) * (orb_light + orb_halo * 0.018) * strength;
	COLOR = vec4(clamp(painted.rgb, vec3(0.0), vec3(1.0)), original.a) * canvas_tint;
}
