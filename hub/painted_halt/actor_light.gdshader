shader_type canvas_item;
render_mode unshaded;
uniform float display_scale = 0.52;
uniform float warm_light = 0.0;
uniform float warm_direction = 0.0;
uniform float cool_light = 0.0;
uniform vec4 water_tint : source_color = vec4(0.28, 0.85, 0.58, 1.0);
varying vec2 floor_position;
void vertex() { floor_position = VERTEX * display_scale; }
void fragment() {
	vec4 source = COLOR;
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 paint = mix(vec3(luminance), source.rgb, 0.91) * vec3(0.85, 0.92, 0.89);
	float side = clamp(0.72 + floor_position.x * warm_direction / 95.0, 0.4, 1.0);
	paint += source.rgb * vec3(0.28, 0.14, 0.035) * warm_light * side;
	paint += source.rgb * water_tint.rgb * 0.19 * cool_light * mix(0.28, 1.0, smoothstep(-112.0, -5.0, floor_position.y));
	COLOR = vec4(clamp(paint, vec3(0.0), vec3(1.0)), source.a);
}
