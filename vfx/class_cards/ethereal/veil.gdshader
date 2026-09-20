shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform int family = 0;
uniform float progress = 0.0;
uniform float flow_time = 0.0;
uniform float opacity = 1.0;
uniform float seed_value = 0.0;
uniform float layer = 0.0;
uniform bool holding = false;
uniform vec4 body_color : source_color = vec4(0.60, 0.78, 0.75, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.80, 1.0);

float band(float d, float width) { return exp(-d * d / (width * width)); }
float noise_at(vec2 p) { return texture(flow_noise, p).r; }
float wrap_angle(float a) { return atan(sin(a), cos(a)); }

void fragment() {
    float u = progress;
    float t = flow_time;
    float birth = smoothstep(0.0, 0.10, u);
    float fade = birth * (1.0 - smoothstep(0.33, 1.0, u)) * opacity;
    vec2 p = vec2((UV.x - 0.5) * 2.0, (0.84 - UV.y) * 2.0);
    vec2 npos = p * vec2(0.53, 0.44) + vec2(seed_value * 0.013, -t * 0.19);
    float n = noise_at(npos);
    float detail = noise_at(npos * 2.3 + n * 0.2);
    vec2 q = p + (vec2(n, detail) - 0.5) * 0.048;
    float radius = length(vec2(q.x, (q.y - 0.48) * 0.94));
    float angle = atan(q.y - 0.48, q.x);
    float ground_r = length(vec2(q.x, q.y * 2.8));
    float field = 0.0;
    float core = 0.0;
    float veil = 0.0;
    // Curved weapon traces: three different silhouettes and temporal sweeps.
    if (family <= 2) {
        vec2 c = vec2(q.x, q.y - 0.47);
        float turn = family == 1 ? -0.12 : -0.6;
        c = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn))) * c;
        if (family == 1) {
            float tip = -0.53 + (1.0 - pow(1.0 - u, 3.0)) * 1.03;
            field = band(c.y + sin(c.x * 4.0 - t * 7.0) * 0.026, 0.024 + n * 0.032);
            field *= smoothstep(-0.65, -0.4, c.x) * (1.0 - smoothstep(tip - 0.16, tip, c.x));
            core = field * band(c.y, 0.015);
        } else {
            float curve = c.y - c.x * c.x * (family == 2 ? 1.25 : 0.70);
            field = band(curve, 0.027 + detail * 0.065) * (1.0 - smoothstep(0.35, 0.68, abs(c.x)));
            field *= smoothstep(-0.8, -0.4, c.x + u * 1.9);
            core = band(curve, 0.013) * field;
            if (family == 2) field += band(c.y + c.x * c.x * 0.9 + 0.15, 0.04) * (1.0 - smoothstep(0.32, 0.6, abs(c.x))) * 0.5;
        }
        veil = field * (0.20 + detail * 0.45);
    } else if (family == 3) { // Mark: an eye of light above the target.
        vec2 c = q - vec2(0.0, 1.30);
        float eye = length(c * vec2(1.0, 2.0));
        field = band(eye - 0.22, 0.025 + n * 0.025);
        core = band(c.x, 0.018) * band(c.y, 0.13);
        veil = band(eye, 0.32) * 0.08;
    } else if (family == 4) { // Bleed: narrow falling crimson threads.
        for (int i = 0; i < 3; i++) {
            float k = float(i) - 1.0;
            float h = q.y + u * 0.5;
            float x = k * 0.16 + sin(h * 6.0 + k + t * 2.5) * 0.055;
            field += band(q.x - x, 0.015 + n * 0.021) * smoothstep(0.0, 0.16, h) * (1.0 - smoothstep(0.50, 0.9, h));
        }
        core = field * detail * 0.3;
    } else if (family == 5) { // Guard: translucent membrane with flowing rim.
        float dome = length(vec2(q.x * 1.30, (q.y - 0.61) * 0.94));
        float rim = band(dome - 0.62, 0.028 + n * 0.055);
        field = rim * (0.45 + detail * 0.65);
        core = rim * pow(max(0.0, sin(angle * 2.0 + t * 3.0)), 8.0) * 0.6;
        veil = (1.0 - smoothstep(0.48, 0.62, dome)) * (0.025 + detail * 0.085);
    } else if (family == 6 || family == 9 || family == 10) { // Gust, push / pull.
        float r = family == 10 ? 0.58 * (1.0 - u) + 0.06 : 0.12 + u * 0.66;
        float a = atan(q.y * 2.8, q.x);
        field = band(ground_r - r + sin(a * 3.0 + t * 4.0) * 0.022, 0.034 + n * 0.03);
        field *= 0.25 + pow(0.5 + 0.5 * sin(a * 2.0 - t * 5.0), 2.0);
        veil = band(ground_r - r + 0.07, 0.11) * detail * 0.17;
        core = field * 0.24;
    } else if (family == 7 || family == 11 || family == 20) { // Shadow / draining or poisoned mist.
        float a = angle + t * (family == 7 ? 2.0 : -1.0);
        float spiral = sin(a * 2.0 + radius * 12.0 + n * 2.0);
        field = pow(max(0.0, spiral), 5.0) * band(radius - 0.3, 0.16) * (0.3 + detail);
        veil = band(radius, 0.46) * detail * 0.13;
        core = field * 0.12;
    } else if (family == 8) { // Root: low crossing currents binding the ankles.
        float h = q.y;
        float curl = q.x - sin(h * 18.0 - t * 2.0) * 0.25;
        field = band(curl, 0.025 + n * 0.027) + band(q.x + sin(h * 16.0 + t * 1.5) * 0.25, 0.03) * 0.7;
        field *= smoothstep(-0.04, 0.04, h) * (1.0 - smoothstep(0.28, 0.58, h));
        core = field * 0.28;
    } else if (family == 12) { // Ice: branching frost currents and cold vapor.
        float h = q.y;
        for (int i = 0; i < 3; i++) {
            float k = float(i) - 1.0;
            float curve = k * h * 0.40 + sin(h * 9.0 + k + t) * h * 0.04;
            field += band(q.x - curve, 0.014 + n * 0.021) * (1.0 - smoothstep(0.44, 0.95 - abs(k) * 0.2, h));
        }
        field *= smoothstep(-0.03, 0.09, h);
        veil = band(q.x, 0.31) * band(h - 0.28, 0.31) * detail * 0.30;
        core = field * 0.30;
    } else if (family == 14) { // Lightning: branching angular discharge, local.
        float h = q.y;
        float zig = abs(fract(h * 4.2 + floor(t * 13.0) * 0.13) - 0.5) * 0.18;
        float path = q.x - zig + 0.08;
        field = band(path, 0.023) + band(path, 0.075) * 0.17;
        field += band(path + max(0.0, h - 0.35) * 0.55, 0.016) * 0.45;
        field *= smoothstep(-0.02, 0.05, h) * (1.0 - smoothstep(0.8, 1.2, h));
        core = field * 0.8;
    } else if (family == 15) { // Disruption: fractured eccentric arcs.
        float arc = band(radius - 0.25 - u * 0.15, 0.03 + n * 0.02);
        field = arc * smoothstep(-0.25, 0.4, sin(angle * 3.0 + t * 4.0 + n));
        field += band(radius - 0.48 + u * 0.16, 0.018) * max(0.0, sin(angle * 4.0 - t * 2.0)) * 0.4;
        core = field * 0.25;
    } else if (family == 16) { // Stasis: suspended hourglass and a quiet envelope.
        float h = q.y - 0.49;
        float waist = 0.045 + abs(h) * 0.55;
        field = band(abs(q.x) - waist, 0.023 + n * 0.013) * (1.0 - smoothstep(0.28, 0.46, abs(h)));
        veil = band(q.x, 0.31) * band(h, 0.48) * detail * 0.11;
        core = field * 0.22 + band(q.x, 0.026) * band(h, 0.065) * 0.38;
    } else if (family == 17) { // Heal: ascending jade currents and a few leaves.
        float h = q.y;
        float center = sin(h * 5.8 - t * 2.1) * (0.16 + h * 0.10);
        field = band(q.x - center, 0.043 + n * 0.028) + band(q.x + center * 0.8 + 0.1, 0.06) * 0.35;
        field *= smoothstep(-0.04, 0.06, h) * (1.0 - smoothstep(0.62, 1.18, h));
        for (int i = 0; i < 5; i++) {
            float k = float(i);
            float ly = fract(k * 0.217 + t * 0.28) * 0.95;
            vec2 l = q - vec2(sin(ly * 6.0 - t * 2.0 + k * 0.25) * 0.26, ly);
            l = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * l;
            field += band(length(l * vec2(1.0, 2.8)), 0.037) * 0.7;
        }
        veil = field * detail * 0.3;
        core = field * 0.2;
    } else if (family == 18) { // Summon: a portal opens from the announced tile.
        float a = atan(q.y * 2.8, q.x);
        field = band(ground_r - 0.32 - sin(u * 3.14) * 0.14, 0.03 + n * 0.03) * (0.4 + 0.6 * pow(sin(a * 2.0 - t * 2.0), 2.0));
        field += band(q.x - sin(q.y * 8.0 - t * 4.0) * 0.16, 0.048) * band(q.y - 0.38, 0.33) * 0.42;
        veil = band(ground_r, 0.45) * detail * 0.1;
        core = field * 0.35;
    } else if (family == 19) { // Water: droplets and soft ripples at the feet.
        field = band(ground_r - 0.31 - sin(t * 1.5) * 0.06, 0.026) * 0.65;
        for (int i = 0; i < 4; i++) {
            float k = float(i);
            vec2 d = q - vec2(sin(k * 2.4) * 0.27, fract(k * 0.27 - t * 0.28) * 0.8);
            field += exp(-dot(d * vec2(50.0, 21.0), d * vec2(50.0, 21.0))) * 0.6;
        }
        core = field * 0.28;
    }
    float dissolve = smoothstep(0.13 + u * 0.25, 0.7, detail + 0.2);
    vec3 light = body_color.rgb * (field * 0.54 + veil) + core_color.rgb * core * 0.40;
    light *= fade * dissolve * (holding ? 1.25 : 1.0);
    float edge = smoothstep(0.0, 0.035, UV.x) * (1.0 - smoothstep(0.965, 1.0, UV.x));
    edge *= smoothstep(0.0, 0.035, UV.y) * (1.0 - smoothstep(0.965, 1.0, UV.y));
    float front = smoothstep(0.58, 0.69, UV.y);
    COLOR = vec4(light * edge * (layer > 0.5 ? front : 1.0 - front), 1.0);
}
