shader_type canvas_item;
render_mode unshaded, blend_add;

// A time-sampled flow field: the drawing evolves instead of scaling a fixed sprite.
uniform float age = 0.0;
uniform float seed_value = 3.7;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
        mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
    for (int i = 0; i < 5; i++) {
        v += a * noise2(p);
        p = rot * p * 2.07 + 17.31;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    float t = max(age - 0.09, 0.0);
    vec2 p = vec2((UV.x - 0.5) * 2.0, (0.84 - UV.y) * 2.0);
    float birth = smoothstep(0.0, 0.13, t);
    float dying = 1.0 - smoothstep(0.38, 1.38, t);
    float height = 0.14 + 1.14 * (1.0 - exp(-t * 11.0));
    float lift = max(t - 0.64, 0.0) * 0.37;
    vec2 q = p;
    q.y -= lift;
    vec2 flow = vec2(q.x * 3.1, q.y * 2.2 - t * 1.9);
    float n = fbm(flow + seed_value);
    float n2 = fbm(flow * 1.55 + vec2(5.7, -t * 0.6));
    float h = max(q.y, 0.0);
    float bend = sin(h * 4.9 - t * 2.4) * h * 0.30 + h * 0.2;
    float warp = (n - 0.5) * (0.045 + h * 0.09);
    float x = q.x - bend + warp;
    float envelope = smoothstep(-0.035, 0.035, q.y)
        * (1.0 - smoothstep(height * 0.63, height, h + (n - 0.45) * 0.3));
    float width = max(0.018, 0.265 * (1.0 - h / max(height, 0.1)));
    float density = exp(-pow(x / (width * (0.65 + n * 1.2)), 2.0));
    // Separate tongues fork off with different curves, thicknesses and lifetimes.
    float side = x + 0.14 + sin(h * 7.3 + t * 2.0) * h * 0.22;
    density += exp(-pow(side / (width * 0.46 + 0.003), 2.0)) * 0.62;
    side = x - 0.14 - sin(h * 5.1 - t * 2.6) * h * 0.24;
    density += exp(-pow(side / (width * 0.55 + 0.003), 2.0)) * 0.58;
    // Folded, broken sheets of energy. Fine ridges survive inside transparent vapor.
    float sheets = fbm(vec2(x * 4.2 + n2 * 1.2, h * 2.0 - t * 2.4));
    float folds = pow(1.0 - abs(sin(x * 18.0 + sheets * 5.0 + h * 4.0)), 1.8);
    float erosion = smoothstep(0.21 + (1.0 - dying) * 0.43, 0.76, n2 + density * 0.21);
    float body = density * envelope * erosion * dying * birth;
    float filaments = body * (0.68 + folds * 0.40);
    float hot = exp(-dot(vec2(x * 9.0, (q.y - 0.10) * 7.0), vec2(x * 9.0, (q.y - 0.10) * 7.0)));
    hot *= (0.45 + folds * 0.4) * birth * (1.0 - smoothstep(0.21, 0.62, t));
    vec3 red = vec3(0.82, 0.14, 0.038);
    vec3 amber = vec3(1.0, 0.32, 0.065);
    vec3 ivory = vec3(1.0, 0.68, 0.32);
    vec3 col = mix(red, amber, clamp(filaments * 1.7, 0.0, 1.0));
    col = mix(col, ivory, clamp(filaments * 0.40 + hot * 0.4, 0.0, 1.0));
    vec3 light = col * filaments * 0.78 + ivory * hot * 0.38;
    // Soft local halo and a flattened pool of reflected light at the ground.
    float halo = exp(-dot(vec2(x * 3.7, (q.y - 0.22) * 3.0), vec2(x * 3.7, (q.y - 0.22) * 3.0)));
    light += vec3(0.7, 0.13, 0.017) * halo * birth * dying * 0.10;
    float ground = exp(-dot(vec2(p.x * 4.3, p.y * 25.0), vec2(p.x * 4.3, p.y * 25.0)));
    light += vec3(1.0, 0.38, 0.09) * ground * birth * exp(-t * 3.6) * 0.65;
    // Deterministic sparks follow curved trajectories; no particle simulation to reset.
    for (int i = 0; i < 9; i++) {
        float id = float(i);
        float r = hash21(vec2(id + seed_value, 11.7));
        float a = t - r * 0.17;
        float life = smoothstep(0.0, 0.07, a) * (1.0 - smoothstep(0.35, 1.0, a));
        float sx = (r - 0.5) * a * 1.2 + sin(a * 4.0 + id) * a * 0.1;
        float sy = a * (0.5 + hash21(vec2(id, 32.1)) * 0.85) - a * a * 0.32;
        vec2 d = p - vec2(sx, sy);
        float spark = exp(-dot(d * vec2(230.0, 100.0), d * vec2(230.0, 100.0)));
        float glow = exp(-dot(d * 60.0, d * 60.0));
        light += (ivory * spark * 0.9 + amber * glow * 0.07) * life;
    }
    float border = smoothstep(0.0, 0.045, UV.x) * (1.0 - smoothstep(0.955, 1.0, UV.x));
    border *= smoothstep(0.0, 0.045, UV.y) * (1.0 - smoothstep(0.955, 1.0, UV.y));
    COLOR = vec4(light * border, age > 0.0 && age < 1.8 ? 1.0 : 0.0);
}
