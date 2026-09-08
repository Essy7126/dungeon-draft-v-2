shader_type canvas_item;
render_mode unshaded;

// Painted reference: 03_apothicairerie_du_bassin.png, 1376 x 768.
// All masks use source pixels. Display resizing does not change registration.
// Time comes from the lab so pausing and before/after captures are deterministic.
uniform float effect_time = 0.0;
uniform float effect_strength : hint_range(0.0, 1.5) = 1.0;
uniform bool water_enabled = true;
uniform bool fire_enabled = true;
uniform bool magic_enabled = true;
// The pointer position is in the original image's normalized UV coordinates.
// Negative age disables the expanding water ring; seconds otherwise.
uniform vec2 ripple_origin = vec2(0.6076, 0.3646);
uniform float ripple_age = -1.0;

const vec2 SOURCE_SIZE = vec2(1376.0, 768.0);
varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

float inside_edge(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	vec2 relative = p - a;
	return (edge.x * relative.y - edge.y * relative.x) / length(edge);
}

float capsule_distance(vec2 p, vec2 a, vec2 b, float radius) {
	vec2 segment = b - a;
	float h = clamp(dot(p - a, segment) / dot(segment, segment), 0.0, 1.0);
	return length(p - a - segment * h) - radius;
}

float water_geometry(vec2 p) {
	// Conservative inner shoreline, inset from the painted stone rim. Its back
	// edge slopes toward the right; a simple ellipse would animate the masonry.
	float d = inside_edge(p, vec2(730.0, 253.0), vec2(741.0, 249.0));
	d = min(d, inside_edge(p, vec2(741.0, 249.0), vec2(758.0, 250.0)));
	d = min(d, inside_edge(p, vec2(758.0, 250.0), vec2(812.0, 260.0)));
	d = min(d, inside_edge(p, vec2(812.0, 260.0), vec2(866.0, 269.0)));
	d = min(d, inside_edge(p, vec2(866.0, 269.0), vec2(913.0, 281.0)));
	d = min(d, inside_edge(p, vec2(913.0, 281.0), vec2(943.0, 286.0)));
	d = min(d, inside_edge(p, vec2(943.0, 286.0), vec2(918.0, 295.0)));
	d = min(d, inside_edge(p, vec2(918.0, 295.0), vec2(876.0, 302.0)));
	d = min(d, inside_edge(p, vec2(876.0, 302.0), vec2(832.0, 301.0)));
	d = min(d, inside_edge(p, vec2(832.0, 301.0), vec2(785.0, 293.0)));
	d = min(d, inside_edge(p, vec2(785.0, 293.0), vec2(753.0, 280.0)));
	d = min(d, inside_edge(p, vec2(753.0, 280.0), vec2(735.0, 265.0)));
	d = min(d, inside_edge(p, vec2(735.0, 265.0), vec2(730.0, 253.0)));
	float mask = smoothstep(0.0, 3.0, d);
	// Foreground copper is never part of the water, including its soft outline.
	mask *= smoothstep(0.0, 2.0, capsule_distance(p, vec2(837.0, 238.0), vec2(833.0, 277.0), 8.0));
	mask *= smoothstep(0.0, 2.0, capsule_distance(p, vec2(891.0, 253.0), vec2(888.0, 287.0), 6.7));
	mask *= smoothstep(0.0, 2.0, capsule_distance(p, vec2(760.0, 238.0), vec2(763.0, 253.0), 4.0));
	return mask;
}

float cyan_pigment(vec3 pigment) {
	return smoothstep(0.035, 0.19, min(pigment.g, pigment.b) - pigment.r);
}

float candle_flicker(float t, float phase) {
	// Three incommensurate frequencies avoid identical metronomic candles.
	return 0.51 * sin(t * 6.1 + phase)
		+ 0.28 * sin(t * 9.7 + phase * 2.31)
		+ 0.21 * sin(t * 15.3 + phase * 0.73);
}

vec2 flame_displacement(vec2 p, vec2 wick, float height, float phase, float t) {
	vec2 q = (p - wick + vec2(0.0, height * 0.48)) / vec2(7.0, height * 0.72);
	float envelope = 1.0 - smoothstep(0.35, 1.0, length(q));
	float above_wick = clamp((wick.y - p.y) / height, 0.0, 1.0);
	float sway = sin(t * 4.7 + phase) + 0.32 * sin(t * 8.2 + phase * 1.7);
	// Warp the existing painted flame; never draw a second flame over it.
	return vec2(sway * 1.65 * above_wick,
		candle_flicker(t, phase) * 1.0 * above_wick) * envelope;
}

float candle_light(vec2 p, vec2 wick, vec2 radius, float phase, float t) {
	vec2 q = (p - wick) / radius;
	float halo = exp(-dot(q, q) * 2.7);
	return halo * candle_flicker(t, phase);
}

void fragment() {
	vec2 p = UV * SOURCE_SIZE;
	float t = effect_time;
	float strength = clamp(effect_strength, 0.0, 1.5);
	vec4 original = texture(TEXTURE, UV);
	vec2 displacement = vec2(0.0);
	float water = 0.0;
	float ring = 0.0;
	float water_glint = 0.0;
	float fire_light = 0.0;
	float magic = 0.0;
	float potion_glint = 0.0;

	if (water_enabled && strength > 0.0) {
		water = water_geometry(p) * cyan_pigment(original.rgb);
		vec2 drift = vec2(
			sin(p.y * 0.20 + t * 1.05) + 0.40 * sin(p.x * 0.086 - t * 0.73),
			0.38 * cos(p.x * 0.092 + t * 0.91)
		);
		if (ripple_age >= 0.0 && ripple_age < 5.0) {
			vec2 from_touch = (p - ripple_origin * SOURCE_SIZE) * vec2(1.0, 3.2);
			float distance_from_touch = length(from_touch);
			float wavefront = distance_from_touch - ripple_age * 40.0;
			float fade = (1.0 - smoothstep(1.0, 4.5, ripple_age))
				* smoothstep(0.0, 0.12, ripple_age);
			ring = exp(-pow(wavefront / 3.0, 2.0)) * fade;
			float wake = sin(wavefront * 0.52) * exp(-abs(wavefront) * 0.07) * fade;
			drift += (from_touch / max(distance_from_touch, 1.0)) / vec2(1.0, 3.2) * wake * 1.7;
		}
		vec2 candidate = drift * water * strength * 1.05;
		// Both ends must be in water, preventing displaced pipes/stone fringes.
		displacement += candidate * water_geometry(p + candidate);
		float waves = sin(p.x * 0.126 + p.y * 0.32 + t * 1.23
			+ sin(p.x * 0.04 - t * 0.53) * 1.6);
		float crossings = 0.5 + 0.5 * sin(p.x * 0.071 - p.y * 0.19 - t * 0.84);
		water_glint = pow(max(waves, 0.0), 9.0) * crossings * 0.058;
		water_glint += sin(p.x * 0.025 + p.y * 0.07 - t * 0.7) * 0.014;
	}

	if (fire_enabled && strength > 0.0) {
		// Wick positions in source pixels, with independently phased flames.
		displacement += strength * (
			flame_displacement(p, vec2(267.0, 363.0), 19.0, 0.2, t)
			+ flame_displacement(p, vec2(625.0, 225.0), 16.0, 1.7, t)
			+ flame_displacement(p, vec2(654.0, 214.0), 20.0, 3.9, t)
			+ flame_displacement(p, vec2(640.0, 252.0), 13.0, 5.3, t)
			+ flame_displacement(p, vec2(465.0, 636.0), 23.0, 2.4, t)
			+ flame_displacement(p, vec2(993.0, 607.0), 24.0, 4.8, t)
		);
		fire_light = candle_light(p, vec2(267.0, 361.0), vec2(61.0, 66.0), 0.2, t)
			+ candle_light(p, vec2(625.0, 224.0), vec2(49.0, 46.0), 1.7, t)
			+ candle_light(p, vec2(654.0, 213.0), vec2(52.0, 48.0), 3.9, t)
			+ candle_light(p, vec2(640.0, 250.0), vec2(29.0, 32.0), 5.3, t)
			+ candle_light(p, vec2(465.0, 633.0), vec2(67.0, 66.0), 2.4, t)
			+ candle_light(p, vec2(993.0, 605.0), vec2(69.0, 66.0), 4.8, t);
	}

	if (magic_enabled && strength > 0.0) {
		vec2 bottle = (p - vec2(415.0, 382.0)) / vec2(16.0, 12.5);
		magic = (1.0 - smoothstep(0.65, 1.0, length(bottle))) * cyan_pigment(original.rgb);
		float breath = 0.5 + 0.5 * sin(t * 1.55 + 0.7);
		vec2 bubble_center = vec2(414.0 + sin(t * 0.9) * 3.0, 390.0 - mod(t * 3.5, 18.0));
		float bubble = exp(-dot(p - bubble_center, p - bubble_center) * 0.65);
		potion_glint = (breath - 0.5) * 0.095 + bubble * 0.13;
		displacement += vec2(sin(p.y * 0.42 + t), cos(p.x * 0.4 - t) * 0.3)
			* magic * strength * 0.42;
	}

	vec4 painted = texture(TEXTURE, UV + displacement / SOURCE_SIZE);
	painted.rgb += vec3(0.35, 0.95, 0.83) * (water_glint + ring * 0.12) * water * strength;
	painted.rgb *= vec3(1.0) + vec3(0.19, 0.115, 0.043) * fire_light * strength;
	painted.rgb += vec3(0.22, 0.93, 0.91) * potion_glint * magic * strength;
	COLOR = vec4(clamp(painted.rgb, vec3(0.0), vec3(1.0)), original.a) * canvas_tint;
}
