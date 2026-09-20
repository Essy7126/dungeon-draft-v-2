shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float age = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}
float noise2(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
        mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += noise2(p) * a;
        p = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * p * 2.03 + 7.3;
        a *= 0.5;
    }
    return v;
}
void fragment() {
    vec2 p = vec2((UV.x - 0.5) * 2.0, (0.84 - UV.y) * 2.0);
    float t = max(age - 0.35, 0.0);
    float h = p.y - t * 0.32;
    vec2 q = vec2(p.x * 3.7, p.y * 3.1 - age * 1.45);
    float n = fbm(q);
    float detail = fbm(q * 2.3 + n * 3.0);
    float bend = sin(h * 5.0 - age * 3.0) * h * 0.25 + h * 0.22;
    float x = p.x - bend + (n - 0.5) * 0.38;
    float mask = exp(-pow(x / (0.13 + t * 0.07), 2.0));
    mask *= smoothstep(0.02, 0.22, h) * (1.0 - smoothstep(0.45, 1.3, h));
    float veil = pow(max(0.0, 1.0 - abs(detail * 2.0 - 1.0)), 4.0);
    float fade = smoothstep(0.32, 0.65, age) * (1.0 - smoothstep(0.75, 1.85, age));
    float edge = smoothstep(0.0, 0.055, UV.y) * (1.0 - smoothstep(0.94, 1.0, UV.y));
    vec3 color = mix(vec3(0.15, 0.18, 0.18), vec3(0.46, 0.37, 0.29), detail);
    COLOR = vec4(color, mask * veil * fade * edge * 0.21);
}
