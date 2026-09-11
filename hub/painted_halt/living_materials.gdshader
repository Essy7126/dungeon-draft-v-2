shader_type canvas_item;
render_mode unshaded;

uniform sampler2D materials : filter_linear, repeat_disable;
uniform sampler2D flow_map : filter_linear, repeat_disable;
uniform bool has_flow_map = false;
uniform vec4 torch_strength[12];
uniform vec2 source_size = vec2(1672.0, 941.0);
uniform float effect_time = 0.0;
uniform float strength = 1.0;
uniform bool water_enabled = true;
uniform bool fire_enabled = true;
uniform float fire_warp_strength = 1.0;
uniform float fire_flicker_speed = 1.0;
uniform bool foliage_enabled = true;
uniform vec4 water_color : source_color = vec4(0.28, 0.85, 0.58, 1.0);
uniform int torch_count = 0;
uniform vec4 torches[12];
uniform vec2 ripple_origin = vec2(0.0);
uniform float ripple_age = -1.0;

float flicker(float time, float phase) {
	return sin(time * 7.1 + phase) * 0.48 + sin(time * 11.3 + phase * 1.3) * 0.32 + sin(time * 18.7 + phase) * 0.2;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec4 mask = texture(materials, UV);
	vec2 p = UV * source_size;
	float t = effect_time;
	vec4 flow = has_flow_map ? texture(flow_map, UV) : vec4(0.9472, 0.7236, 0.25, 1.0);
	vec2 current = (flow.rg * 2.0 - 1.0) * flow.b * 4.0;
	vec2 water_p = p - current * t * 8.0;
	float wet = water_enabled ? mask.r : 0.0;
	float fall = water_enabled ? mask.g : 0.0;
	// Color confidence suppresses incidental moss-free gray stones inside broad masks.
	wet *= smoothstep(0.02, 0.16, original.g - original.r);
	vec2 drift = vec2(sin(water_p.y * 0.054 + t * 1.2) + sin(water_p.x * 0.035 - t * 0.81), cos(water_p.x * 0.058 - t * 0.9));
	vec2 offset = drift * wet * 1.1;
	offset += vec2(sin(p.y * 0.06 - t * 6.0), sin(p.y * 0.022 - t * 3.6) * 4.0) * fall;
	if (foliage_enabled) {
		offset += vec2(sin(t * 0.83 + p.y * 0.009) * 1.7, cos(t * 0.63 + p.x * 0.01) * 0.45) * mask.b;
	}
	float fire_glow = 0.0;
	float flame = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= torch_count || !fire_enabled) { break; }
		vec2 center = torches[i].xy * source_size;
		vec2 radius = max(torches[i].zw * source_size, vec2(1.0));
		vec2 q = (p - center) / radius;
		float core = exp(-dot(q, q) * 1.7);
		float orange = smoothstep(0.04, 0.22, original.r - original.b);
		float phase = float(i) * 1.731;
		float f = flicker(t * fire_flicker_speed, phase);
		offset.x += core * orange * (sin(t * 8.0 + q.y * 2.6 + phase) * 2.8) * torch_strength[i].x * fire_warp_strength;
		offset.y += core * orange * f * 2.0 * torch_strength[i].x * fire_warp_strength;
		vec2 halo = (p - center) / vec2(94.0, 117.0);
		fire_glow += exp(-dot(halo, halo) * 1.8) * (f + torch_strength[i].z) * torch_strength[i].y;
		flame += core * orange * f * torch_strength[i].x;
	}
	vec3 painted = texture(TEXTURE, clamp(UV + offset * strength / source_size, vec2(0.0), vec2(1.0))).rgb;
	float a = sin(water_p.x * 0.052 + sin(water_p.y * 0.037 + t * 0.41) * 2.3 - t * 0.65);
	float b = sin(water_p.y * 0.066 + sin(water_p.x * 0.032 - t * 0.47) * 2.0 + t * 0.87);
	float caustic = pow(max(0.0, 1.0 - abs(a + b) * 2.0), 3.0);
	painted += water_color.rgb * wet * (caustic * 0.15 + sin(p.y * 0.07 - t * 0.72) * 0.025) * strength;
	painted += vec3(0.59, 0.98, 0.77) * fall * (sin(p.y * 0.22 - t * 7.5) * 0.07 + sin(p.x * 0.39 + t * 1.4) * 0.035) * strength;
	painted += vec3(0.27, 0.11, 0.015) * (fire_glow * 0.2 + flame * 0.42) * strength;
	if (water_enabled) {
		painted += water_color.rgb * mask.a * caustic * 0.055 * strength;
	}
	if (ripple_age >= 0.0 && ripple_age < 3.0 && water_enabled) {
		vec2 d = (UV - ripple_origin) * source_size;
		d.y *= 2.0;
		float ring = exp(-pow((length(d) - ripple_age * 53.0) / 5.0, 2.0));
		painted += water_color.rgb * ring * wet * (1.0 - ripple_age / 3.0) * 0.33 * strength;
	}
	COLOR = vec4(clamp(painted, vec3(0.0), vec3(1.0)), original.a);
}
