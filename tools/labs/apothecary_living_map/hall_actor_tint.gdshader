shader_type canvas_item;
render_mode unshaded;

uniform float display_scale = 0.52;
uniform float warm_light : hint_range(0.0, 1.0) = 0.0;
uniform float warm_direction : hint_range(-1.0, 1.0) = 0.0;
uniform float cool_light : hint_range(0.0, 1.0) = 0.0;

varying vec2 floor_relative_position;

void vertex() {
	// Sprite vertices already include the authored foot-anchor offset. Using them
	// instead of UV also works as the animation visits different atlas regions.
	floor_relative_position = VERTEX * display_scale;
}

void fragment() {
	vec4 source = COLOR;
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 paint = mix(vec3(luminance), source.rgb, 0.94);
	// Retain the bronze, red crest and readable painted outlines in cool stone light.
	paint *= vec3(0.87, 0.94, 0.92);
	float lantern_side = clamp(0.72 + floor_relative_position.x * warm_direction / 95.0, 0.4, 1.0);
	paint += source.rgb * vec3(0.25, 0.14, 0.035) * warm_light * lantern_side;
	float water_bounce = mix(0.28, 1.0, smoothstep(-112.0, -5.0, floor_relative_position.y));
	paint += source.rgb * vec3(0.018, 0.13, 0.15) * cool_light * water_bounce;
	COLOR = vec4(clamp(paint, vec3(0.0), vec3(1.0)), source.a);
}
