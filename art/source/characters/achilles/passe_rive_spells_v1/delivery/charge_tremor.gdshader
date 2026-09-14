shader_type canvas_item;
render_mode unshaded;

// The displacement fades to zero around the drawing arm; bow hand and feet remain fixed.
uniform float tremor_pixels = 0.0;
uniform vec2 arm_center = vec2(155.0, 391.0);
uniform vec2 arm_radius = vec2(91.0, 43.0);

void fragment() {
	vec2 frame_pixel = mod(UV / TEXTURE_PIXEL_SIZE, vec2(768.0));
	float weight = max(0.0, 1.0 - length((frame_pixel - arm_center) / arm_radius));
	weight = weight * weight * (3.0 - 2.0 * weight);
	vec2 shift = vec2(0.35, 1.0) * tremor_pixels * weight;
	COLOR = texture(TEXTURE, UV + shift * TEXTURE_PIXEL_SIZE);
}
