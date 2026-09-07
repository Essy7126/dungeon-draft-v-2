shader_type canvas_item;
render_mode unshaded;

// This material belongs only to the water polygon, beneath the clipped Land.
uniform float motion_amount : hint_range(0.0, 1.0) = 0.45;
uniform float surface_breath : hint_range(0.0, 0.04) = 0.009;
varying vec4 water_tint;

void vertex() {
    water_tint = COLOR;
}

void fragment() {
    vec2 drift = vec2(
        sin(UV.y * 12.0 + TIME * 0.1),
        cos(UV.x * 9.0 - TIME * 0.07)
    ) * vec2(0.0006, 0.0003) * motion_amount;
    vec4 painted = texture(TEXTURE, UV + drift);
    float broad = 0.5 + 0.5 * sin(UV.x * 6.0 + UV.y * 4.0 + TIME * 0.08);
    painted.rgb += vec3(0.55, 0.63, 0.42) * broad * surface_breath;
    COLOR = painted * water_tint;
}
