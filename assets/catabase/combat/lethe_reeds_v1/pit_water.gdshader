shader_type canvas_item;

// Platform draws flat pit floors and walls as separate, uniformly colored
// primitives. Only the floor color receives water shading; walls keep COLOR.
uniform float effect_time = 0.0;
uniform sampler2D water_texture : source_color, filter_linear, repeat_disable;
uniform vec4 water_patch_uv = vec4(0.0, 0.0, 1.0, 1.0); // source rectangle: xy origin, zw size
uniform vec3 pit_floor_srgb;
uniform vec3 pit_floor_linear;
uniform vec2 native_axis_x = vec2(1.0, 0.0);
uniform vec2 native_axis_y = vec2(0.0, 1.0);
uniform vec2 native_origin = vec2(0.0);
varying vec2 native_position;
varying float water_surface;

// Keep the painted scale except near a reflection fold, where the derivative
// eases to zero instead of making a sharp mirrored seam.
float soft_fold(float value) {
	float edge = 0.08;
	if (value < edge) {
		return value * value * (2.0 * edge - value) / (edge * edge);
	}
	if (value > 1.0 - edge) {
		float distance_to_end = 1.0 - value;
		return 1.0 - distance_to_end * distance_to_end * (2.0 * edge - distance_to_end) / (edge * edge);
	}
	return value;
}

vec2 mirrored_patch(vec2 position) {
	vec2 reflected = 1.0 - abs(mod(position, 2.0) - 1.0);
	return vec2(soft_fold(reflected.x), soft_fold(reflected.y));
}

void vertex() {
	native_position = native_origin + VERTEX.x * native_axis_x + VERTEX.y * native_axis_y;
	float distance_to_floor = min(distance(COLOR.rgb, pit_floor_srgb), distance(COLOR.rgb, pit_floor_linear));
	water_surface = 1.0 - step(0.002, distance_to_floor);
}

void fragment() {
	if (water_surface > 0.5) {
		vec2 p = native_position;
		float t = effect_time;
		vec2 distortion = vec2(
			sin(p.y * 0.027 - t * 0.45 + sin(p.x * 0.014 + t * 0.17)) * 0.8,
			cos(p.x * 0.024 + t * 0.31) * 0.6
		);
		vec2 native_patch_size = max(water_patch_uv.zw * vec2(1920.0, 1200.0), vec2(1.0));
		vec2 repeated = mirrored_patch((p + distortion) / native_patch_size);
		vec2 half_texel = 0.5 / vec2(textureSize(water_texture, 0));
		vec2 sample_uv = water_patch_uv.xy + half_texel
			+ repeated * max(water_patch_uv.zw - 2.0 * half_texel, vec2(0.0));
		// Preserve the original painted ripples; a small palette mix adds depth.
		vec3 painted = mix(texture(water_texture, sample_uv).rgb, COLOR.rgb, 0.14);
		float a = sin(p.x * 0.040 + sin(p.y * 0.020 + t * 0.19) * 1.8 - t * 0.32);
		float b = sin(p.y * 0.050 + sin(p.x * 0.020 - t * 0.23) * 1.2 + t * 0.41);
		float caustic = pow(max(0.0, 1.0 - abs(a + b) * 2.4), 3.0);
		float ripple = sin(p.y * 0.040 - t * 0.47);
		vec3 light = vec3(0.09, 0.22, 0.18) * (caustic * 0.055 + ripple * 0.010);
		COLOR = vec4(clamp(painted + light, vec3(0.0), vec3(1.0)), COLOR.a);
	}
}
