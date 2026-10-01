shader_type canvas_item;

uniform vec2 art_size = vec2(1.0);
uniform float padding = 4.0;
uniform float outline_width = 2.0;
uniform float alpha_threshold = 0.35;
uniform vec4 outline_color : source_color = vec4(0.95, 0.76, 0.35, 1.0);
uniform bool highlighted = false;

float inside_art(vec2 uv) {
	return float(all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0))));
}

void fragment() {
	// The extra transparent margin lets the contour extend beyond the artwork.
	vec2 uv = (UV * (art_size + vec2(2.0 * padding)) - vec2(padding)) / art_size;
	vec4 art = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * inside_art(uv);
	float rim = 0.0;
	if (highlighted) {
		for (int index = 0; index < 24; index++) {
			float angle = float(index) * 6.2831853 / 24.0;
			vec2 offset = vec2(cos(angle), sin(angle)) * outline_width / art_size;
			vec2 neighbor_uv = uv + offset;
			float neighbor = texture(TEXTURE, clamp(neighbor_uv, vec2(0.0), vec2(1.0))).a * inside_art(neighbor_uv);
			rim = max(rim, smoothstep(alpha_threshold - 0.08, alpha_threshold + 0.08, neighbor));
		}
		rim *= outline_color.a;
	}
	float alpha = art.a + rim * (1.0 - art.a);
	vec3 rgb = (art.rgb * art.a + outline_color.rgb * rim * (1.0 - art.a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha);
}
