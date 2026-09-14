shader_type canvas_item;
render_mode unshaded;
uniform float effect_time = 0.0;
varying vec2 native_position;
void vertex() { native_position = VERTEX; }
void fragment() {
    vec2 size = vec2(1920.0, 1200.0);
    vec2 uv = native_position / size;
    vec2 p = uv * vec2(1586.0, 992.0);
    vec4 source = texture(TEXTURE, uv);
    float t = effect_time;
    // Traced source and outer-rill regions. Never warp the tactical reserve.
    bool spring = (p.x > 1150.0 && p.x < 1260.0 && p.y > 100.0 && p.y < 280.0)
        || (p.x > 1300.0 && p.x < 1425.0 && p.y > 110.0 && p.y < 340.0);
    bool rill = (p.x > 1410.0 && p.y > 435.0 && p.y < 700.0)
        || (p.y > 800.0 && p.y < 955.0)
        || (p.x < 325.0 && p.y > 630.0 && p.y < 740.0)
        || (p.x > 1240.0 && p.y > 700.0 && p.y < 805.0);
    float hot = smoothstep(0.15, 0.45, source.r - max(source.g, source.b));
    float lava = (spring || rill) ? hot : 0.0;
    vec2 drift = vec2(sin(p.y * 0.045 - t * 0.65), cos(p.x * 0.037 - t * 0.4));
    if (spring) { drift = vec2(sin(p.y * 0.06 - t * 0.8) * 0.5, sin(p.y * 0.09 - t * 1.1)); }
    vec3 painted = texture(TEXTURE, clamp(uv + drift * lava * 0.65 / size, vec2(0.0), vec2(1.0))).rgb;
    float pulse = 0.5 + 0.5 * sin(p.x * 0.025 + p.y * 0.041 - t * 1.1);
    painted += vec3(0.14, 0.044, 0.003) * lava * pulse;
    for (int i = 0; i < 4; i++) {
        vec2 center = vec2(155.0, 182.0);
        if (i == 1) { center = vec2(239.0, 120.0); }
        if (i == 2) { center = vec2(335.0, 137.0); }
        if (i == 3) { center = vec2(949.0, 66.0); }
        vec2 q = (p - center) / vec2(12.0, 20.0);
        float light = exp(-dot(q,q) * 1.6) * hot;
        painted += vec3(0.26, 0.12, 0.014) * light * (0.6 + 0.4 * sin(t * 2.1 + float(i)));
    }
    COLOR = vec4(clamp(painted, vec3(0.0), vec3(1.0)), source.a);
}
