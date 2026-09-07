shader_type canvas_item;
render_mode unshaded;

// Apply only to an explicit water polygon sampling the original painted image.
// Its UVs are the original image coordinates, so stone borders stay unchanged.
uniform vec2 image_size = vec2(1536.0, 1024.0);
uniform float displacement_pixels : hint_range(0.0, 3.0) = 0.75;
uniform float shimmer_strength : hint_range(0.0, 0.2) = 0.04;
uniform float speed : hint_range(0.0, 2.0) = 0.35;

void fragment() {
	float t = TIME * speed;
	vec2 p = UV * image_size;
	vec2 drift = vec2(
		sin(p.y * 0.052 + t) + 0.35 * sin(p.x * 0.037 - t * 0.65),
		cos(p.x * 0.046 + t * 0.8) * 0.45
	) * displacement_pixels / image_size;
	vec4 painted = texture(TEXTURE, UV + drift);
	float ripple = sin(p.x * 0.082 + p.y * 0.14 + t * 1.1);
	float glint = pow(max(ripple, 0.0), 14.0);
	float broad = 0.5 + 0.5 * sin(p.x * 0.021 - p.y * 0.034 - t * 0.7);
	painted.rgb += vec3(0.56, 0.91, 0.84) * glint * broad * shimmer_strength;
	COLOR = painted;
}
