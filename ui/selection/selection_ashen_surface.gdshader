shader_type canvas_item;
render_mode unshaded;

uniform vec2 surface_size = vec2(200.0, 60.0);
uniform vec4 base_color : source_color = vec4(0.11, 0.095, 0.085, 1.0);
uniform vec4 edge_color : source_color = vec4(0.45, 0.36, 0.27, 1.0);
uniform float corner_radius = 5.0;
uniform float texture_strength = 0.04;
uniform float bevel_width = 1.0;
uniform float hover_amount = 0.0;
uniform float selection_amount = 0.0;
uniform float press_amount = 0.0;
uniform float disabled_amount = 0.0;
uniform bool is_window = false;
uniform bool is_primary = false;

varying vec4 surface_modulate;

void vertex() {
	surface_modulate = COLOR;
}

float rounded_box(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + radius;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = UV * surface_size;
	float distance = rounded_box(p - surface_size * 0.5, surface_size * 0.5 - vec2(0.75), corner_radius);
	float aa = max(fwidth(distance), 0.6);
	float mask = 1.0 - smoothstep(-aa, aa, distance);
	// Tile at a stable density so a large window never stretches the grain.
	vec3 grain_sample = texture(TEXTURE, p / 470.0).rgb;
	float grain = dot(grain_sample, vec3(0.333333));
	float relief = (grain - 0.12) * texture_strength;
	vec3 body = base_color.rgb + vec3(relief);
	float active = max(selection_amount, is_primary ? 1.0 : 0.0);
	body = mix(body, vec3(0.045, 0.15, 0.18) + vec3(relief * 0.35), active);
	body += vec3(0.025, 0.022, 0.018) * pow(1.0 - UV.y, 2.0);
	body += vec3(0.020) * hover_amount;
	body -= vec3(0.016) * press_amount;
	// One fine bronze rule, with no stacked bevel or inset seam.
	float band = smoothstep(-bevel_width - aa, -bevel_width + aa, distance);
	vec3 metal = edge_color.rgb * (0.75 + 0.12 * (1.0 - UV.y));
	metal += vec3(0.065, 0.055, 0.040) * hover_amount;
	vec3 result = mix(body, metal, band);
	result = mix(result, vec3(dot(result, vec3(0.299, 0.587, 0.114))) * 0.72, disabled_amount * 0.8);
	COLOR = vec4(max(result, vec3(0.0)), mask * base_color.a) * surface_modulate;
}
