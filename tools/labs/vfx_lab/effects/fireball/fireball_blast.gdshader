shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.72, 1.0);
uniform vec4 body_color : source_color = vec4(1.0, 0.42, 0.035, 1.0);
uniform vec4 edge_color : source_color = vec4(0.76, 0.035, 0.02, 1.0);
uniform float effect_time = 0.0;
uniform float seed_value = 1.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float turbulence : hint_range(0.0, 1.5) = 0.7;
uniform float asymmetry : hint_range(0.0, 1.0) = 0.55;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(53.31, 417.17)) + seed_value * 9.73) * 43117.31);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.58;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p = p * 2.08 + vec2(3.7, 8.1);
		amplitude *= 0.48;
	}
	return value;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.y *= 1.18;
	p += vec2(-0.035 * asymmetry, 0.075 * asymmetry * progress);
	float flow = effect_time * (2.6 + turbulence * 1.7);
	vec2 warp = vec2(fbm(p * 5.5 + vec2(flow, seed_value * 0.04)),
		fbm(p * 5.5 + vec2(-flow * 0.63, -seed_value * 0.06))) - vec2(0.5);
	p += warp * (0.055 + turbulence * 0.035);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float lobes = sin(angle * 3.0 + seed_value * 0.13) * 0.075;
	lobes += sin(angle * 5.0 - seed_value * 0.09) * 0.045;
	lobes += sin(angle * 8.0 + effect_time * 4.5) * 0.022 * turbulence;
	float organic = (fbm(p * 9.0 + vec2(-flow * 0.3, flow * 0.48)) - 0.5) * 0.10 * turbulence;
	float expansion = 0.035 + (1.0 - pow(1.0 - progress, 3.0)) * 0.36;
	float boundary = expansion + lobes * progress + organic * progress;
	float mask = smoothstep(boundary + 0.045, boundary - 0.055, r);
	float hot_noise = fbm(p * 14.0 + vec2(flow * 0.9, -flow * 0.72));
	float body = smoothstep(boundary * 0.94, boundary * 0.36, r + (hot_noise - 0.5) * 0.055);
	float core = smoothstep(boundary * 0.40, boundary * 0.06, r + (hot_noise - 0.5) * 0.035);
	vec3 color = mix(edge_color.rgb, body_color.rgb, body);
	color = mix(color, core_color.rgb, core);
	float breakup = smoothstep(0.18, 0.76, hot_noise + core * 0.36);
	COLOR = vec4(color * intensity * (0.54 + body * 0.56 + core * 0.50), mask * fade * breakup);
}
