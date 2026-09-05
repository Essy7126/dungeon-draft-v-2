shader_type canvas_item;
render_mode unshaded;

// Water polygon only: the painted shore/land clips it before any combat layer.
uniform float motion_amount : hint_range(0.0, 1.0) = 0.35;
uniform float mist_breath : hint_range(0.0, 0.04) = 0.012;
varying vec4 water_tint;
void vertex() { water_tint = COLOR; }
void fragment() {
    vec2 drift = vec2(sin(UV.y * 16.0 + TIME * 0.12), cos(UV.x * 13.0 - TIME * 0.09))
        * vec2(0.0004, 0.00025) * motion_amount;
    vec4 painted = texture(TEXTURE, UV + drift);
    float broad = 0.5 + 0.5 * sin(UV.x * 8.0 + UV.y * 5.0 + TIME * 0.11);
    painted.rgb += vec3(0.55, 0.66, 0.7) * broad * mist_breath;
    COLOR = painted * water_tint;
}
