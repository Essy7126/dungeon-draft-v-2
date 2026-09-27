shader_type canvas_item;
render_mode unshaded;
uniform vec3 teal_gain = vec3(1.0);
uniform vec3 cape_gain = vec3(1.0);
uniform vec3 leather_gain = vec3(1.0);
uniform vec3 gold_gain = vec3(1.0);
uniform vec3 ivory_gain = vec3(1.0);
uniform vec3 teal_center = vec3(0.10, 0.22, 0.26);
uniform vec3 cape_center = vec3(0.46, 0.56, 0.50);
uniform vec3 leather_center = vec3(0.15, 0.15, 0.16);
uniform vec3 gold_center = vec3(0.53, 0.43, 0.25);
uniform vec3 ivory_center = vec3(0.88, 0.85, 0.75);
uniform float display_scale = 0.44;
uniform float warm_light = 0.0;
uniform float warm_direction = 0.0;
uniform float cool_light = 0.0;
uniform vec4 water_tint : source_color = vec4(0.28, 0.85, 0.58, 1.0);
varying vec2 floor_position;
varying vec4 vertex_tint;

void vertex() {
	floor_position = VERTEX * display_scale;
	vertex_tint = COLOR;
}

float material_weight(vec3 c, vec3 center) {
	float peak = max(c.r, max(c.g, c.b));
	float center_peak = max(center.r, max(center.g, center.b));
	vec3 chroma = c / max(peak, 0.025) - center / max(center_peak, 0.025);
	float value = (peak - center_peak) / (0.06 + center_peak * 0.22);
	return exp(-0.5 * (dot(chroma, chroma) / 0.0144 + value * value));
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 c = source.rgb;
	// Smooth material membership avoids stippled threshold edges in painted cloth.
	// Centers and gains are fixed for the entire atlas, never re-estimated per frame.
	float wt = material_weight(c, teal_center);
	float wc = material_weight(c, cape_center);
	float wl = material_weight(c, leather_center);
	float wg = material_weight(c, gold_center);
	float wi = material_weight(c, ivory_center);
	vec3 gain = (vec3(0.025) + wt * teal_gain + wc * cape_gain + wl * leather_gain + wg * gold_gain + wi * ivory_gain) / (0.025 + wt + wc + wl + wg + wi);
	c *= gain;
	// Environmental light is a restrained addition to a shared neutral albedo.
	float side = clamp(0.72 + floor_position.x * warm_direction / 95.0, 0.4, 1.0);
	c += c * vec3(0.08, 0.035, 0.008) * warm_light * side;
	c += c * water_tint.rgb * 0.045 * cool_light;
	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), source.a) * vertex_tint;
}
