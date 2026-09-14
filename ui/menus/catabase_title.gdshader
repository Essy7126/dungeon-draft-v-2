shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1600.0, 900.0);
uniform vec2 pointer_offset = vec2(0.0);
uniform float elapsed = 0.0;
uniform float fire_strength : hint_range(0.0, 1.5) = 1.0;
uniform float fog_strength : hint_range(0.0, 1.5) = 1.0;
uniform float wind_strength : hint_range(0.0, 1.5) = 1.0;
uniform float rock_fog_strength : hint_range(0.0, 1.5) = 1.0;
// Allows the visual review to isolate local movement from camera movement.
uniform float camera_strength : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = noise(p) * 0.57;
	p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + 7.3;
	value += noise(p) * 0.28;
	value += noise(p * 2.03 + 4.8) * 0.15;
	return value;
}

float ellipse(vec2 uv, vec2 center, vec2 radius) {
	vec2 p = (uv - center) / radius;
	return exp(-dot(p, p) * 2.0);
}

// All positions are anchored in painting UVs, so flames stay attached when
// the camera moves or the viewport crops the painting. p.y rises from the bowl.
vec3 brazier(vec2 uv, vec2 base, vec2 size, float seed) {
	vec2 p = (uv - base) / size;
	p.y = -p.y;
	if (abs(p.x) > 2.5 || p.y < -0.12 || p.y > 2.7) {
		return vec3(0.0);
	}
	float t = elapsed * (1.45 + seed * 0.035) + seed * 3.7;
	float rise = fbm(vec2(p.x * 3.5, p.y * 3.0 - t * 2.7));
	float curl = noise(vec2(p.y * 3.8 - t * 1.8, seed)) - 0.5;
	float sway = sin(p.y * 4.3 - t * 2.5) * 0.10 + curl * 0.38;
	float x = p.x + sway * p.y;
	float height = 0.93 + noise(vec2(t * 1.4, seed)) * 0.40;
	float taper = max(0.0, 1.0 - p.y / height);
	float width = 0.10 + taper * 0.58;
	float body = 1.0 - smoothstep(width * 0.4, width, abs(x) + (rise - 0.5) * 0.50);
	body *= smoothstep(-0.035, 0.08, p.y);
	body *= 1.0 - smoothstep(height * 0.42, height + (rise - 0.5) * 0.45, p.y);
	float core = body * (1.0 - smoothstep(0.05, 0.60, abs(x))) * (1.0 - smoothstep(0.05, 0.65, p.y));
	vec3 fire = mix(vec3(0.95, 0.16, 0.015), vec3(1.0, 0.65, 0.13), body);
	fire = mix(fire, vec3(1.0, 0.91, 0.58), core);
	vec3 emission = fire * body * (0.48 + rise * 0.45);
	// Sparse drifting sparks have independent lifetimes; no screen-space rain.
	for (int i = 0; i < 4; i++) {
		float id = float(i) + seed * 7.0;
		float life = fract(t * (0.19 + hash(vec2(id, 2.0)) * 0.10) + hash(vec2(id, 4.0)));
		float spark_y = 0.25 + life * 2.20;
		float spark_x = (hash(vec2(id, 5.0)) - 0.5) * 0.85 + sin(life * 5.0 + id) * life * 0.32;
		vec2 d = (p - vec2(spark_x, spark_y)) / vec2(0.023, 0.038);
		float spark = exp(-dot(d, d) * 2.0) * sin(life * 3.14159);
		emission += vec3(1.0, 0.49, 0.11) * spark * 0.85;
	}
	return emission;
}

vec2 heat_flow(vec2 uv, vec2 base, vec2 size, float seed) {
	vec2 p = (uv - base) / size;
	float plume = ellipse(p, vec2(0.0, -0.75), vec2(1.25, 1.2));
	float above_bowl = 1.0 - smoothstep(-0.06, 0.0, p.y);
	float t = elapsed * 2.4 + seed;
	vec2 turbulence = vec2(noise(p * 3.0 - vec2(0.0, t)), noise(p * 3.7 - vec2(t * 0.2, t)));
	return (turbulence - 0.5) * size * vec2(0.24, 0.13) * plume * above_bowl;
}

float fire_light(vec2 uv, vec2 source, vec2 radius, float seed) {
	float t = elapsed + seed * 8.1;
	float pulse = noise(vec2(t * 3.7, seed)) * 0.65 + noise(vec2(t * 7.3, seed + 2.0)) * 0.35;
	return ellipse(uv, source, radius) * (pulse - 0.35);
}

float mist(vec2 p, vec2 velocity, float seed) {
	vec2 advected = p + velocity * elapsed;
	vec2 curl = vec2(noise(advected * 0.65 + seed), noise(advected * 0.72 - seed));
	return fbm(advected + (curl - 0.5) * 1.9);
}

float cloth_region(vec2 uv) {
	float left = smoothstep(0.540, 0.548, uv.x) * (1.0 - smoothstep(0.577, 0.588, uv.x));
	left *= 1.0 - smoothstep(0.413, 0.432, uv.y);
	float right = smoothstep(0.880, 0.896, uv.x) * (1.0 - smoothstep(0.360, 0.378, uv.y));
	return max(left, right);
}

float cloth_color(vec3 color) {
	// Select oxblood fabric; warm stone and bronze have much more green.
	return smoothstep(0.035, 0.095, color.r - color.g * 1.55)
		* smoothstep(0.015, 0.070, color.r - color.b * 1.20);
}

vec2 cloth_flow(vec2 uv) {
	if (uv.x > 0.85) {
		// Follow the curved inner hem. Fade displacement to zero BEFORE the edge:
		// no exposed background plate exists behind this painted banner.
		float hem = 0.887 + 0.040 * uv.y + 0.83 * uv.y * uv.y;
		float fabric = smoothstep(hem + 0.013, hem + 0.029, uv.x);
		fabric *= 1.0 - smoothstep(0.34, 0.375, uv.y);
		float hanging = smoothstep(0.0, 0.19, uv.y);
		float along_fold = uv.y + (uv.x - 0.89) * 0.45;
		float phase = along_fold * 15.0 - elapsed * 0.85;
		float wave = sin(phase) + 0.16 * sin(phase * 1.7 + 0.8);
		// The whole cloth, including gold embroidery, shares one smooth field.
		return vec2(wave * 0.0011, sin(phase + 0.6) * 0.0007)
			* fabric * hanging * wind_strength;
	}
	float right = step(0.75, uv.x);
	float free_end = smoothstep(0.005, 0.38, uv.y);
	float phase = uv.y * 23.0 - elapsed * 1.15 + right * 2.4;
	float breeze = 0.78 + 0.22 * sin(elapsed * 0.31);
	// The header stays pinned. Two travelling waves bend the hanging folds.
	float wave = sin(phase) + 0.28 * sin(phase * 1.83 + uv.x * 31.0);
	return vec2(wave * 0.0018, sin(phase + 0.9) * 0.0006)
		* free_end * breeze * wind_strength * cloth_region(uv);
}

float rock_mist(vec2 uv, vec3 painting) {
	// Mist already painted between the near-left rocks provides occlusion.
	// Dark stone is excluded, so the rock silhouettes never wobble or wash out.
	float luminance = dot(painting, vec3(0.2126, 0.7152, 0.0722));
	float mist_color = smoothstep(0.105, 0.245, luminance);
	mist_color *= smoothstep(0.018, 0.075, min(painting.g, painting.b) - painting.r);
	// A conservative depth boundary keeps even blue-lit foreground boulders
	// in front of the fog. Color alone cannot distinguish them from the mist.
	float foreground_ridge = 0.568 + uv.x * 0.73;
	mist_color *= 1.0 - smoothstep(foreground_ridge - 0.014, foreground_ridge, uv.y);
	float pockets = ellipse(uv, vec2(0.125, 0.59), vec2(0.235, 0.21));
	pockets += ellipse(uv, vec2(0.25, 0.733), vec2(0.13, 0.10));
	vec2 p = uv * vec2(10.0, 15.0) + vec2(-0.075, 0.115) * elapsed;
	vec2 curl = vec2(fbm(p * 0.53 + 21.0), fbm(p * 0.61 - 7.0)) - 0.5;
	float volume = fbm(p + curl * 2.4);
	float wisps = fbm(p * vec2(1.4, 2.1) + curl * 3.0);
	float density = smoothstep(0.30, 0.72, volume) * 0.46;
	density += smoothstep(0.43, 0.74, wisps) * 0.25;
	return 1.0 - exp(-density * min(pockets, 1.0) * mist_color * fog_strength * rock_fog_strength);
}

float ground_mist(vec2 uv) {
	// Stable advection carries the shapes across the paving, with slower billows
	// beneath finer ribbons. No opacity pulsation or distortion of the stone.
	vec2 p = uv * vec2(6.0, 23.0) - vec2(elapsed * 0.070, -elapsed * 0.016);
	vec2 bend = vec2(fbm(p * 0.47 + 8.0), fbm(p * 0.39 - 12.0)) - 0.5;
	float body = fbm(p + bend * 2.8);
	float ribbon = fbm(p * vec2(1.45, 1.8) + bend * 3.5 + vec2(9.0, elapsed * 0.022));
	float billow = smoothstep(0.28, 0.75, body);
	float filament = smoothstep(0.40, 0.73, ribbon) * smoothstep(0.26, 0.58, body);
	float mask = ellipse(uv, vec2(0.60, 0.925), vec2(0.52, 0.145));
	mask *= smoothstep(0.20, 0.43, uv.x);
	float low_layer = mist(uv * vec2(8.0, 30.0), vec2(-0.10, 0.014), 43.0);
	float low_mask = ellipse(uv, vec2(0.72, 1.00), vec2(0.40, 0.082));
	float density = (billow * 0.32 + filament * 0.34) * mask;
	density += smoothstep(0.34, 0.76, low_layer) * low_mask * 0.28;
	return 1.0 - exp(-density * fog_strength);
}

void fragment() {
	vec2 image_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float cover = max(viewport_size.x / image_size.x, viewport_size.y / image_size.y);
	vec2 crop = viewport_size / (image_size * cover);
	vec2 drift = vec2(sin(elapsed * 0.075), cos(elapsed * 0.055) - 1.0) * 0.004;
	vec2 uv = (UV - 0.5) * crop / 1.035 + 0.5 + (drift + pointer_offset * 0.004) * camera_strength;
	vec2 left_fire = vec2(0.607, 0.532);
	vec2 right_fire = vec2(0.896, 0.518);
	vec2 left_size = vec2(0.014, 0.050);
	vec2 right_size = vec2(0.022, 0.079);
	vec2 heat = heat_flow(uv, left_fire, left_size, 1.0) + heat_flow(uv, right_fire, right_size, 4.0);
	vec2 sample_uv = uv + heat * fire_strength;
	vec3 scene = texture(TEXTURE, sample_uv).rgb;
	vec3 painting = scene;
	vec2 cloth_offset = cloth_flow(uv);
	vec3 moving_cloth = texture(TEXTURE, sample_uv + cloth_offset).rgb;
	// Union of the original and displaced fabric also lets its silhouette move.
	float cloth_mask = max(cloth_color(scene), cloth_color(moving_cloth)) * cloth_region(uv);
	// At right the UV field itself supplies the geometric mask. Selecting by
	// red would leave gold symbols behind and shear the embroidery at its edges.
	cloth_mask = mix(cloth_mask, 1.0, step(0.85, uv.x));
	scene = mix(scene, moving_cloth, cloth_mask);
	float fold_light = sin(uv.y * 23.0 - elapsed * 1.15 + step(0.75, uv.x) * 2.4);
	scene *= 1.0 + fold_light * cloth_mask * smoothstep(0.01, 0.35, uv.y) * 0.025 * wind_strength * (1.0 - step(0.85, uv.x));
	// Warm bounce light is irregular and local, never a whole-image exposure pulse.
	float light = fire_light(uv, left_fire, vec2(0.072, 0.14), 1.0);
	light += fire_light(uv, right_fire, vec2(0.10, 0.19), 4.0);
	scene += scene * vec3(0.60, 0.31, 0.08) * light * fire_strength;
	vec3 fire = brazier(uv, left_fire, left_size, 1.0);
	fire += brazier(uv, right_fire, right_size, 4.0);
	fire += brazier(uv, vec2(0.346, 0.771), vec2(0.008, 0.025), 7.0);
	fire += brazier(uv, vec2(0.403, 0.775), vec2(0.006, 0.020), 11.0);
	fire += brazier(uv, vec2(0.463, 0.764), vec2(0.008, 0.027), 16.0);
	// Screen-like emission retains painted detail instead of clipping to white.
	scene += fire * max(vec3(0.0), vec3(1.0) - scene * 0.75) * fire_strength;
	// Distant vertical wisps remain in the valley; foreground mist travels laterally.
	float far_field = mist(uv * vec2(12.0, 7.0), vec2(0.025, 0.11), 3.0);
	float far_mask = ellipse(uv, vec2(0.425, 0.53), vec2(0.16, 0.42));
	float far_density = smoothstep(0.29, 0.76, far_field) * far_mask * 0.29;
	scene = mix(scene, vec3(0.24, 0.53, 0.54), far_density * fog_strength);
	float middle_field = mist(uv * vec2(7.0, 15.0), vec2(-0.12, 0.024), 13.0);
	float middle_mask = ellipse(uv, vec2(0.46, 0.72), vec2(0.25, 0.19));
	float middle_density = smoothstep(0.32, 0.78, middle_field) * middle_mask * 0.42;
	scene = mix(scene, vec3(0.30, 0.49, 0.48), middle_density * fog_strength);
	float near_density = ground_mist(uv);
	float warm_mist = ellipse(uv, vec2(0.84, 0.84), vec2(0.24, 0.24));
	vec3 near_color = mix(vec3(0.25, 0.43, 0.44), vec3(0.47, 0.43, 0.32), warm_mist * 0.65);
	scene = mix(scene, near_color, near_density);
	float rock_density = rock_mist(uv, painting);
	scene = mix(scene, vec3(0.22, 0.46, 0.47), rock_density);
	float vignette = smoothstep(0.30, 0.84, length((UV - 0.5) * vec2(0.95, 0.8)));
	scene *= 1.0 - vignette * 0.45;
	scene *= 1.0 - (1.0 - smoothstep(0.1, 0.45, UV.x)) * 0.18;
	COLOR = vec4(scene, 1.0);
}
