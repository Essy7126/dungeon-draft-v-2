shader_type canvas_item;

void fragment() {
	vec4 portrait = texture(TEXTURE, UV);
	// Presentation mask only: keep the original painted asset intact.
	float edge = length((UV - vec2(0.5)) * vec2(2.0, 2.0));
	portrait.a *= 1.0 - smoothstep(0.91, 1.0, edge);
	COLOR = portrait;
}
