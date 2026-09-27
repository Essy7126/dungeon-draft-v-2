shader_type canvas_item;
// An etched aureole behind the live hero. Static, low contrast, no gameplay information.
void fragment() {
	vec2 p = (UV - vec2(0.5, 0.46)) * vec2(1.0, 1.1);
	float radius = length(p);
	float glow = exp(-radius * radius * 9.0);
	vec3 base = mix(vec3(0.085, 0.065, 0.05), vec3(0.23, 0.18, 0.13), glow);
	float rings = (1.0 - smoothstep(0.001, 0.004, abs(radius - 0.39))) * 0.5;
	rings += (1.0 - smoothstep(0.001, 0.003, abs(radius - 0.42))) * 0.25;
	float rays = pow(abs(cos(atan(p.y, p.x) * 16.0)), 22.0);
	rings += rays * smoothstep(0.36, 0.38, radius) * (1.0 - smoothstep(0.41, 0.43, radius)) * 0.4;
	COLOR = vec4(mix(base, vec3(0.67, 0.54, 0.32), rings), 1.0);
}
