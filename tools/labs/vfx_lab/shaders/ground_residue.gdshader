shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 hot_color : source_color = vec4(1.0, 0.22, 0.015, 0.8);
uniform vec4 cold_color : source_color = vec4(0.12, 0.015, 0.01, 0.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.0, 289.0))) * 45758.5453);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 2.0);
	float r = length(p);
	float n = hash(floor(UV * 18.0)) * 0.22;
	float veins = abs(sin(atan(p.y, p.x) * 7.0 + r * 28.0 + n * 5.0));
	float ember = smoothstep(0.72, 0.96, veins) * smoothstep(0.52, 0.12, r);
	float mask = smoothstep(0.52 + n * 0.08, 0.32, r);
	vec4 color = mix(cold_color, hot_color, ember);
	color.a = (mask * 0.24 + ember * 0.55) * fade;
	COLOR = color;
}
