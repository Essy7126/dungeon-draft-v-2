shader_type canvas_item;
render_mode unshaded;
uniform float tremor_pixels = 0.0;
uniform vec2 arm_center = vec2(576.0, 391.0);
uniform vec2 arm_radius = vec2(91.0, 43.0);
uniform vec2 frame_origin = vec2(0.0);
void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE - frame_origin;
	float weight = max(0.0, 1.0-length((pixel-arm_center)/arm_radius));
	weight = weight*weight*(3.0-2.0*weight);
	COLOR = texture(TEXTURE,UV+vec2(0.35,1.0)*tremor_pixels*weight*TEXTURE_PIXEL_SIZE);
}
