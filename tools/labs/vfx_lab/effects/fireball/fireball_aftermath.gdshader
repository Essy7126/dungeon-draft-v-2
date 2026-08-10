shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 ember_color : source_color = vec4(1.0, 0.25, 0.025, 0.82);
uniform vec4 coal_color : source_color = vec4(0.12, 0.018, 0.012, 0.0);
uniform float effect_time = 0.0;
uniform float seed_value = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(71.7, 219.3)) + seed_value * 5.31) * 45817.17);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.85);
	float angle = atan(p.y, p.x);
	float r = length(p);
	float coarse = noise(UV * vec2(11.0, 8.0) + vec2(seed_value * 0.03));
	float fine = noise(UV * vec2(31.0, 19.0) + vec2(-seed_value * 0.05, effect_time * 0.08));
	float boundary = 0.43 + sin(angle * 3.0 + seed_value * 0.11) * 0.055 + (coarse - 0.5) * 0.12;
	float mask = smoothstep(boundary + 0.035, boundary - 0.045, r);
	float cracks = smoothstep(0.73, 0.93, abs(sin(angle * 4.0 + r * 31.0 + coarse * 5.0)));
	float islands = smoothstep(0.57, 0.83, fine + coarse * 0.34) * mask;
	vec4 color = mix(coal_color, ember_color, max(cracks * 0.56, islands));
	color.a = (mask * 0.19 + islands * 0.50 + cracks * mask * 0.24) * fade;
	COLOR = color;
}
