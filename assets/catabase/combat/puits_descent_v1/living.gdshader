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
    // Authored outer clefts only. The floor, bones, bucket and masonry never warp.
    bool cleft = (p.x < 300.0 && p.y > 440.0 && p.y < 650.0)
        || (p.x > 1400.0 && p.y > 520.0 && p.y < 830.0)
        || (p.x > 920.0 && p.x < 1400.0 && p.y > 810.0 && p.y < 905.0)
        || (p.x > 550.0 && p.x < 630.0 && p.y > 150.0 && p.y < 190.0);
    float hot = smoothstep(0.15, 0.45, source.r - max(source.g, source.b));
    float lava = cleft ? hot : 0.0;
    vec2 drift = vec2(sin(p.y * 0.045 - t * 0.65), cos(p.x * 0.037 - t * 0.4));
    vec3 painted = texture(TEXTURE, clamp(uv + drift * lava * 0.65 / size, vec2(0.0), vec2(1.0))).rgb;
    float pulse = 0.5 + 0.5 * sin(p.x * 0.025 + p.y * 0.041 - t * 1.1);
    painted += vec3(0.14, 0.044, 0.003) * lava * pulse;
    // Luminance flicker at painted lantern and torches, never on their frames.
    for (int i = 0; i < 4; i++) {
        vec2 center = vec2(380.0, 211.0);
        if (i == 1) { center = vec2(1213.0, 138.0); }
        if (i == 2) { center = vec2(1324.0, 126.0); }
        if (i == 3) { center = vec2(1416.0, 203.0); }
        vec2 q = (p - center) / vec2(12.0, 20.0);
        float light = exp(-dot(q,q) * 1.6) * hot;
        painted += vec3(0.26, 0.12, 0.014) * light * (0.6 + 0.4 * sin(t * 2.1 + float(i)));
    }
    COLOR = vec4(clamp(painted, vec3(0.0), vec3(1.0)), source.a);
}
