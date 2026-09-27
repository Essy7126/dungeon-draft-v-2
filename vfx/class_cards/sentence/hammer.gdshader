shader_type canvas_item;
render_mode unshaded;
uniform float contact_light = 0.0;
uniform float withdrawal = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 pose_uv = fract(UV * vec2(8.0, 6.0));
	float cut = sin(pose_uv.y * 105.0 + pose_uv.x * 22.0) * .08 + pose_uv.y;
	c.a *= smoothstep(withdrawal - .08, withdrawal + .035, cut);
	// Light the warm bevels without washing out the ink, handle or enamel.
	float warm_metal = smoothstep(.025, .17, c.r - c.b);
	float bevel = smoothstep(.18, .55, dot(c.rgb, vec3(.2126, .7152, .0722)));
	c.rgb = mix(c.rgb, vec3(1.0, .91, .69), contact_light * warm_metal * bevel);
	COLOR = c;
}
