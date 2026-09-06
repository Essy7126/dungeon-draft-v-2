shader_type canvas_item;
render_mode unshaded;

uniform vec2 surface_size = vec2(200.0, 60.0);
uniform vec4 base_color : source_color = vec4(0.11, 0.095, 0.085, 1.0);
uniform vec4 edge_color : source_color = vec4(0.45, 0.36, 0.27, 1.0);
uniform float corner_radius = 5.0;
uniform float texture_strength = 0.24;
uniform float bevel_width = 3.0;
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
	vec3 body = base_color.rgb + vec3(relief * 1.04, relief, relief * 0.94);
	float top_light = pow(1.0 - UV.y, 2.0);
	body += vec3(0.024, 0.019, 0.014) * top_light;
	body += vec3(0.027, 0.021, 0.014) * hover_amount;
	body += vec3(0.036, 0.026, 0.015) * selection_amount;
	body -= vec3(0.019, 0.016, 0.012) * press_amount;
	// A restrained patinated metal band, followed by a dark inset seam.
	float band = smoothstep(-bevel_width - aa, -bevel_width + aa, distance);
	float top_edge = 1.0 - smoothstep(0.0, bevel_width + 2.0, p.y);
	float left_edge = 1.0 - smoothstep(0.0, bevel_width + 2.0, p.x);
	float lower_edge = 1.0 - smoothstep(0.0, bevel_width + 2.0, surface_size.y - p.y);
	vec3 metal = edge_color.rgb * (0.58 + grain * 1.25);
	metal += vec3(0.105, 0.086, 0.060) * (top_edge + left_edge * 0.3);
	metal -= vec3(0.075, 0.057, 0.040) * lower_edge;
	metal += edge_color.rgb * (hover_amount * 0.17 + selection_amount * 0.2);
	vec3 result = mix(body, metal, band * 0.85);
	float inner_seam = 1.0 - smoothstep(0.25, 1.3, abs(distance + bevel_width + 1.0));
	result *= 1.0 - inner_seam * 0.50;
	float lip = 1.0 - smoothstep(0.25, 1.1, abs(distance + bevel_width + 2.5));
	result += vec3(0.035, 0.028, 0.018) * lip * (1.0 - press_amount);
	if (is_window) {
		// The panel gets a second engraved hairline; the text area stays quiet.
		float rule = 1.0 - smoothstep(0.2, 0.9, abs(distance + 7.5));
		result += edge_color.rgb * rule * 0.13;
	}
	if (is_primary) {
		float sheen = pow(max(0.0, 1.0 - abs(UV.x - 0.5) * 1.7), 3.0);
		result += vec3(0.046, 0.028, 0.012) * sheen;
	}
	result = mix(result, vec3(dot(result, vec3(0.299, 0.587, 0.114))) * 0.72, disabled_amount * 0.8);
	COLOR = vec4(max(result, vec3(0.0)), mask * base_color.a) * surface_modulate;
}
