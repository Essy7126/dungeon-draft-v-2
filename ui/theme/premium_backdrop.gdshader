shader_type canvas_item;

uniform vec4 center_color : source_color = vec4(0.075, 0.055, 0.055, 1.0);
uniform vec4 edge_color : source_color = vec4(0.008, 0.007, 0.012, 1.0);
uniform vec4 accent_color : source_color = vec4(0.34, 0.20, 0.08, 1.0);
uniform float grain_strength : hint_range(0.0, 0.12) = 0.025;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = dot(centered, centered);
	float vignette = smoothstep(0.08, 1.32, radius);
	float top_glow = exp(-length((UV - vec2(0.5, 0.04)) * vec2(1.7, 1.0)) * 5.0);
	vec3 color = mix(center_color.rgb, edge_color.rgb, vignette);
	color += accent_color.rgb * top_glow * 0.18;
	float grain = hash(floor(UV * vec2(960.0, 540.0))) - 0.5;
	color += grain * grain_strength;
	COLOR = vec4(color, 1.0);
}
