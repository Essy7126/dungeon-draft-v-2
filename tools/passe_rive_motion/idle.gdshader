shader_type canvas_item;
uniform float cycle_seconds = 3.2;
float gaussian(vec2 p, vec2 center, vec2 extent) {
    vec2 q = (p - center) / extent;
    return exp(-dot(q, q));
}
void fragment() {
    vec2 size = vec2(1024.0, 1536.0);
    vec2 p = UV * size;
    float a = mod(TIME, cycle_seconds) / cycle_seconds * 6.28318530718;
    float pinned = smoothstep(290.0, 360.0, p.y)
        * (1.0 - smoothstep(1110.0, 1190.0, p.y))
        * smoothstep(345.0, 405.0, p.x)
        * (1.0 - smoothstep(635.0, 690.0, p.x));
    vec2 displacement = vec2(0.0);
    displacement.y = -5.0 * sin(a) * gaussian(p, vec2(515.0, 520.0), vec2(150.0, 240.0));
    displacement.x = 5.0 * (sin(a + 0.8) - sin(0.8)) * gaussian(p, vec2(590.0, 960.0), vec2(105.0, 220.0));
    displacement.y += 1.3 * (sin(a + 0.8) - sin(0.8)) * gaussian(p, vec2(505.0, 790.0), vec2(75.0, 180.0));
    COLOR = texture(TEXTURE, (p - displacement * pinned) / size);
}
