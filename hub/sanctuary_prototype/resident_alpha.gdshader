shader_type canvas_item;
render_mode unshaded;

uniform sampler2D silhouette_mask : filter_linear, repeat_disable;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	original.a *= texture(silhouette_mask, UV).r;
	COLOR = original;
}
