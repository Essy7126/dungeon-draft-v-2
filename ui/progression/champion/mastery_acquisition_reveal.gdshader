shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float activation : hint_range(0.0, 1.0) = 0.0;
uniform vec4 accent : source_color = vec4(0.70, 0.85, 0.62, 1.0);
uniform vec2 surface_size = vec2(226.0, 80.0);

void fragment() {
	vec2 pixel = UV * surface_size;
	vec2 to_edge = min(pixel, surface_size - pixel);
	float edge = 1.0 - smoothstep(0.8, 3.0, min(to_edge.x, to_edge.y));
	float envelope = smoothstep(0.0, 0.13, progress) * (1.0 - smoothstep(0.56, 1.0, progress));
	float position = mix(-0.22, 1.35, progress);
	float sweep = exp(-pow((UV.x + UV.y * 0.16 - position) / 0.085, 2.0));
	float alpha = activation * envelope * (edge * 0.52 + sweep * 0.14);
	COLOR = vec4(accent.rgb, alpha);
}
