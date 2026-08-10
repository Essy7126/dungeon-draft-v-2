shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 shield_color : source_color = vec4(0.22, 0.76, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.48;
uniform float pulse : hint_range(0.0, 2.0) = 0.0;
uniform float intensity : hint_range(0.1, 3.0) = 1.0;

float hex_line(vec2 uv) {
	vec2 p = uv * vec2(9.0, 7.0);
	vec2 q = vec2(p.x * 1.1547, p.y + floor(p.x) * 0.5);
	vec2 f = abs(fract(q) - 0.5);
	return smoothstep(0.48, 0.41, max(f.x * 0.866 + f.y * 0.5, f.y));
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.x *= 1.15;
	float r = length(p / vec2(0.9, 1.0));
	float shell = smoothstep(0.5, 0.46, r) - smoothstep(0.45, 0.38, r);
	float inside = smoothstep(0.5, 0.25, r);
	float scan = 0.5 + 0.5 * sin((UV.y + TIME * 0.55) * 42.0);
	float ripple = exp(-abs(r - (0.12 + pulse * 0.34)) * 35.0) * step(0.001, pulse);
	float cells = hex_line(UV) * inside;
	float alpha = (shell * 0.95 + cells * 0.12 + scan * inside * 0.045 + ripple * 0.8) * opacity;
	vec3 color = shield_color.rgb * (0.65 + shell * 0.9 + ripple * 1.4) * intensity;
	COLOR = vec4(color, alpha);
}
