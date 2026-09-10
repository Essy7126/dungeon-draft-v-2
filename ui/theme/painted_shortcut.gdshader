shader_type canvas_item;

// Reveal the painted silhouette at display time, without changing the source art.
varying vec4 icon_modulate;

void vertex() {
	icon_modulate = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 backdrop = (
		texture(TEXTURE, vec2(0.015, 0.015)).rgb
		+ texture(TEXTURE, vec2(0.985, 0.015)).rgb
		+ texture(TEXTURE, vec2(0.015, 0.985)).rgb
		+ texture(TEXTURE, vec2(0.985, 0.985)).rgb
	) * 0.25;
	float coverage = smoothstep(0.065, 0.15, distance(source.rgb, backdrop));
	COLOR = vec4(source.rgb, source.a * coverage) * icon_modulate;
}
