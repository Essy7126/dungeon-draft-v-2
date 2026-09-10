shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1600.0, 900.0);
uniform vec2 pointer_offset = vec2(0.0);
uniform float elapsed = 0.0;
uniform float fire_strength : hint_range(0.0, 1.5) = 1.0;
uniform float fog_strength : hint_range(0.0, 1.5) = 1.0;

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

void fragment() {
	vec2 image_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float cover = max(viewport_size.x / image_size.x, viewport_size.y / image_size.y);
	vec2 crop = viewport_size / (image_size * cover);
	vec2 drift = vec2(sin(elapsed * 0.075), cos(elapsed * 0.055) - 1.0) * 0.004;
	vec2 uv = (UV - 0.5) * crop / 1.035 + 0.5 + drift + pointer_offset * 0.004;
	vec2 left_fire = vec2(0.607, 0.532);
	vec2 right_fire = vec2(0.896, 0.518);
	vec2 left_size = vec2(0.014, 0.050);
	vec2 right_size = vec2(0.022, 0.079);
	vec2 heat = heat_flow(uv, left_fire, left_size, 1.0) + heat_flow(uv, right_fire, right_size, 4.0);
	vec3 scene = texture(TEXTURE, uv + heat * fire_strength).rgb;
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
	float near_field = mist(uv * vec2(5.0, 19.0), vec2(0.16, -0.028), 29.0);
	float near_mask = ellipse(uv, vec2(0.59, 0.90), vec2(0.44, 0.10));
	// Keep the left menu area and the darkest foreground framing clear.
	near_mask *= smoothstep(0.12, 0.42, uv.x) * (1.0 - smoothstep(0.96, 1.0, uv.y));
	float near_density = smoothstep(0.27, 0.76, near_field) * near_mask * 0.50;
	vec3 near_color = mix(vec3(0.22, 0.36, 0.38), vec3(0.45, 0.37, 0.26), smoothstep(0.48, 0.88, uv.x));
	scene = mix(scene, near_color, near_density * fog_strength);
	float vignette = smoothstep(0.30, 0.84, length((UV - 0.5) * vec2(0.95, 0.8)));
	scene *= 1.0 - vignette * 0.45;
	scene *= 1.0 - (1.0 - smoothstep(0.1, 0.45, UV.x)) * 0.18;
	COLOR = vec4(scene, 1.0);
}
