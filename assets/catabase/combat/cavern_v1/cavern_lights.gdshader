shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float effect_time = 0.0;
uniform vec2 torch_base_a = vec2(183.0, 190.0);
uniform vec2 torch_base_b = vec2(403.0, 153.0);

vec3 ember(vec2 pixel, vec2 origin, float seed) {
    vec2 d = pixel - origin;
    vec3 light = vec3(0.0);
    if (abs(d.x) < 22.0 && d.y < -5.0 && d.y > -83.0) {
        for (int i=0; i<2; i++) {
            float phase = fract(effect_time * 0.14 + float(i) * 0.5 + seed);
            vec2 pos = vec2(sin(phase * 3.0 + seed * 10.0) * phase * 12.0, -phase * 80.0);
            vec2 q = (d-pos) / vec2(0.75, 1.1);
            float fade = sin(phase * 3.14159);
            light += vec3(0.8, 0.38, 0.07) * exp(-dot(q,q) * 2.0) * fade * 0.30;
        }
    }
    return light;
}
void fragment() {
    vec2 p = UV * vec2(1920.0,1200.0);
    COLOR = vec4(ember(p, torch_base_a - vec2(0.0,17.0), 0.17) + ember(p, torch_base_b - vec2(0.0,16.0), 0.63), 1.0);
}
