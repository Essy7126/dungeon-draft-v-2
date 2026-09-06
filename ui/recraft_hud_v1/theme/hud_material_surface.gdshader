shader_type canvas_item;
render_mode unshaded;

uniform sampler2D material_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform bool has_texture = false;
uniform vec2 surface_size = vec2(1444.0, 140.0);
uniform vec4 module_0 = vec4(0.0, 0.0, 486.0, 140.0);
uniform vec4 module_1 = vec4(504.0, 0.0, 552.0, 140.0);
uniform vec4 module_2 = vec4(1072.0, 0.0, 372.0, 140.0);
uniform vec4 surface_color : source_color = vec4(0.055, 0.052, 0.065, 0.98);
uniform vec4 metal_color : source_color = vec4(0.63, 0.44, 0.24, 1.0);
uniform vec4 metal_light : source_color = vec4(0.94, 0.79, 0.50, 1.0);
uniform float texture_strength : hint_range(0.0, 1.0) = 0.55;
uniform float tile_size = 256.0;
uniform float rim_width = 3.0;
uniform float bevel_cut = 13.0;
varying vec4 surface_modulate;

void vertex() {
	surface_modulate = COLOR;
}

float cut_box(vec2 p, vec2 extent, float cut) {
	vec2 q = abs(p - extent * 0.5) - extent * 0.5;
	return max(max(q.x, q.y), (q.x + q.y + cut) * 0.70710678);
}

vec4 shade_module(vec2 pixel, vec4 region) {
	if (region.z <= 0.0 || region.w <= 0.0) {
		return vec4(0.0);
	}
	vec2 p = pixel - region.xy;
	float d = cut_box(p - vec2(1.0), region.zw - vec2(2.0), bevel_cut);
	float alpha = 1.0 - smoothstep(-0.7, 0.7, d);
	float depth = clamp(p.y / region.w, 0.0, 1.0);
	vec3 grain = has_texture ? texture(material_texture, pixel / tile_size).rgb : surface_color.rgb;
	vec3 base = mix(surface_color.rgb, grain, texture_strength);
	base *= mix(1.32, 0.70, depth);
	// All highlights are bounded and static: no screen sampling or per-frame noise.
	float rim = 1.0 - smoothstep(rim_width - 0.6, rim_width + 0.6, -d);
	vec3 metal = mix(metal_light.rgb, metal_color.rgb * 0.50, depth);
	float inner_line = 1.0 - smoothstep(0.25, 1.0, abs(d + rim_width + 3.0));
	base = mix(base, metal_color.rgb * 0.70, inner_line * 0.52);
	base = mix(base, metal, rim);
	float inset_shadow = 1.0 - smoothstep(rim_width + 1.0, rim_width + 5.0, -d);
	base *= 1.0 - inset_shadow * (1.0 - rim) * 0.34;
	return vec4(base, alpha * surface_color.a);
}

void fragment() {
	vec2 pixel = UV * surface_size;
	vec4 a = shade_module(pixel, module_0);
	vec4 b = shade_module(pixel, module_1);
	vec4 c = shade_module(pixel, module_2);
	vec4 result = a;
	result = mix(result, b, b.a);
	result = mix(result, c, c.a);
	result.a = max(a.a, max(b.a, c.a));
	COLOR = result * surface_modulate;
}
