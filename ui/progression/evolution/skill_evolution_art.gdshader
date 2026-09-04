shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 1.8) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float outline_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.96, 0.66, 0.18, 1.0);
uniform float sweep_progress : hint_range(-0.5, 1.5) = -0.5;
uniform float sweep_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float selected_amount : hint_range(0.0, 1.0) = 0.0;


float cleaned_alpha(vec4 texel) {
	float lightest = max(texel.r, max(texel.g, texel.b));
	float darkest = min(texel.r, min(texel.g, texel.b));
	float neutral = 1.0 - smoothstep(0.035, 0.18, lightest - darkest);
	float paper = smoothstep(0.7, 0.97, darkest) * neutral;
	return texel.a * (1.0 - paper);
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	source.a = cleaned_alpha(source);

	vec3 gray = vec3(dot(source.rgb, vec3(0.299, 0.587, 0.114)));
	vec3 color = mix(gray, source.rgb, saturation);
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness * tint.rgb;
	color *= mix(vec3(1.0), vec3(1.04, 0.99, 0.88), selected_amount);

	vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
	float around = 0.0;
	around = max(around, cleaned_alpha(texture(TEXTURE, UV + vec2(px.x, 0.0))));
	around = max(around, cleaned_alpha(texture(TEXTURE, UV - vec2(px.x, 0.0))));
	around = max(around, cleaned_alpha(texture(TEXTURE, UV + vec2(0.0, px.y))));
	around = max(around, cleaned_alpha(texture(TEXTURE, UV - vec2(0.0, px.y))));
	float rim = max(around - source.a, 0.0) * outline_intensity;

	float diagonal = UV.x * 0.72 + UV.y * 0.28;
	float sweep = smoothstep(0.11, 0.0, abs(diagonal - sweep_progress));
	color += vec3(1.0, 0.88, 0.58) * sweep * sweep_intensity * source.a;

	COLOR = vec4(mix(color, outline_color.rgb, rim), max(source.a, rim));
}
