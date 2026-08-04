shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float darkness : hint_range(0.0, 1.0) = 0.57;
uniform float saturation : hint_range(0.0, 1.0) = 0.38;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.62;
uniform vec3 cold_tint : source_color = vec3(0.78, 0.88, 1.0);

void fragment() {
	vec3 source = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float gray = dot(source, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(vec3(gray), source, saturation) * cold_tint;
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float vignette = smoothstep(0.34, 1.22, dot(centered, centered));
	color *= 1.0 - darkness;
	color *= 1.0 - vignette * vignette_strength;
	COLOR = vec4(color, 1.0);
}
