shader_type canvas_item;
render_mode unshaded;
uniform float effect_time = 0.0;
uniform vec2 torch_base_a = vec2(183.0, 190.0);
uniform vec2 torch_base_b = vec2(403.0, 153.0);
varying vec2 native_position;
void vertex() { native_position = VERTEX; }

float fire(vec2 point, vec2 base) {
    vec2 d = point - base;
    float width = 1.0 - smoothstep(11.0, 20.0, abs(d.x));
    float bottom = 1.0 - smoothstep(-3.0, 0.0, d.y);
    float top = smoothstep(-54.0, -40.0, d.y);
    return width * bottom * top;
}
void fragment() {
    vec2 size = vec2(1920.0, 1200.0);
    vec2 p = native_position / size;
    vec3 original = texture(TEXTURE, p).rgb;
    float first = fire(native_position, torch_base_a);
    float second = fire(native_position, torch_base_b);
    float source_fire = smoothstep(0.36, 0.64, original.r - original.b)
        * smoothstep(0.58, 0.88, original.r);
    float mask = max(first, second) * source_fire;
    float base_y = first > second ? torch_base_a.y : torch_base_b.y;
    float tip = clamp((base_y - native_position.y) / 43.0, 0.0, 1.0);
    float seed = first > second ? 0.7 : 2.9;
    // A pinned base and subpixel lateral curls; never deform the bronze bowl,
    // the wall, or the turquoise mineral/steam details in the painting.
    float curl = sin(native_position.y * 0.19 + effect_time * 3.1 + seed)
        + 0.32 * sin(native_position.y * 0.31 + effect_time * 4.8 + seed);
    vec2 offset = vec2(curl * 1.15 * tip * mask, 0.0);
    vec3 painted = texture(TEXTURE, p + offset / size).rgb;
    float pulse = sin(effect_time * 3.7 + seed) * 0.018
        + sin(effect_time * 6.1 + seed * 2.0) * 0.012;
    painted *= 1.0 + pulse * mask;
    // Modulate the warm lighting already painted into the masonry, instead
    // of adding an orange disc over the drawing.
    vec2 a = (native_position - torch_base_a) / vec2(105.0, 115.0);
    vec2 b = (native_position - torch_base_b) / vec2(105.0, 115.0);
    float warm = smoothstep(0.06, 0.26, original.r - original.b);
    float illumination = exp(-dot(a,a)*2.5) * sin(effect_time * 3.7 + 0.7)
        + exp(-dot(b,b)*2.5) * sin(effect_time * 3.7 + 2.9);
    painted *= 1.0 + illumination * warm * 0.025 * (1.0-mask);
    COLOR = vec4(painted, 1.0);
}
