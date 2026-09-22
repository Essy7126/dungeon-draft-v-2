shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform int motif = 0; // directed steel / clinging embers / ankle frost
uniform float progress = 0.0;
uniform float flow_time = 0.0;
uniform float opacity = 1.0;
uniform float seed_value = 0.0;
uniform float layer = 0.0;
uniform bool holding = false;
uniform vec2 direction = vec2(1.0, 0.0);

float band(float d, float w) { return exp(-d * d / (w * w)); }
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 v = b - a;
    return length(p - a - v * clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0));
}
void fragment() {
    float u = progress;
    float t = flow_time;
    float n = texture(flow_noise, UV * 1.3 + vec2(seed_value * .03, -t * .23)).r;
    float fine = texture(flow_noise, UV * 3.1 + vec2(t * .04, -t * .31)).r;
    float body = 0.0;
    float core = 0.0;
    float mist = 0.0;
    vec3 dark = vec3(.12, .31, .36);
    vec3 light = vec3(.73, .96, 1.0);
    float envelope = holding ? smoothstep(0.0, .22, t) : (1.0 - smoothstep(.18, 1.0, u));
    if (motif == 0) {
        vec2 p = (UV - vec2(.5, .60)) * 2.0;
        vec2 q = vec2(dot(p, direction), dot(p, vec2(-direction.y, direction.x)));
        float tip = .24 + u * .42;
        float along = smoothstep(-.60, -.31, q.x) * (1.0 - smoothstep(tip - .08, tip, q.x));
        float taper = max(.004, .040 * (1.0 - abs(q.x + .05) / .7));
        body = band(q.y, taper * 2.6) * along * .52;
        core = band(q.y, taper * .38) * along;
        // Three uneven fragments diverge from the actual direction of impact.
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            vec2 a = vec2(.02 + u * .16, 0.0);
            vec2 b = vec2(.25 + k * .11 + u * .15, (k - 1.1) * (.17 + u * .23));
            float d = segment(q, a, b);
            body += band(d, .010) * .65 * (1.0 - u);
        }
        mist = band(q.y + sin(q.x * 6.0 - u * 4.0) * .08, .052) * along * n * .18;
        core += band(length(q), .10) * (1.0 - smoothstep(0.0, .24, u));
        envelope *= layer < .5 ? .36 : 1.0;
    } else {
        vec2 p = vec2((UV.x - .5) * 2.0, (.84 - UV.y) * 2.0);
        if (motif == 1) {
            dark = vec3(.68, .20, .065);
            light = vec3(1.0, .80, .40);
            // Separate tongues cling to the lower silhouette; empty center keeps the actor readable.
            for (int i = 0; i < 5; i++) {
                float k = float(i);
                float h = .70 + .16 * sin(k * 3.7 + seed_value);
                float x = (k - 2.0) * .12 + sin(p.y * 7.0 - t * 2.1 + k * 2.2) * (.035 + p.y * .10);
                float w = max(.008, (.095 + n * .05) * (1.0 - p.y / h));
                float mask = smoothstep(-.04, .08, p.y) * (1.0 - smoothstep(h * .35, h, p.y));
                body += band(p.x - x, w) * mask * (.38 + fine * .45);
                core += band(p.x - x, w * .23) * mask * fine * .32;
                float rise = fract(t * (.23 + k * .025) + k * .231);
                vec2 ember = vec2((k - 2.0) * .15 + sin(rise * 6.0 + k) * .065, rise * .85);
                core += band(length(p - ember), .008 + .003 * sin(k)) * sin(rise * 3.14159) * .6;
            }
            if (!holding) {
                float r = length((p - vec2(0.0, .22)) * vec2(1.0, 1.4));
                body += band(r - u * .38, .09) * fine * (1.0 - smoothstep(.08, .55, u));
                core += band(r, .15) * (1.0 - smoothstep(0.0, .25, u));
            }
            mist = band(p.x, .31) * band(p.y - .25, .28) * n * .18;
        } else {
            dark = vec3(.10, .32, .46);
            light = vec3(.66, .91, 1.0);
            float curl = .065 + sin(p.x * 9.0 - t * 1.5) * .045 + n * .045;
            body = band(p.y - curl, .035) * (1.0 - smoothstep(.15, .48, abs(p.x))) * (.4 + fine);
            core = band(p.y - curl, .006) * body * .48;
            mist = band(p.y - .13, .13) * band(p.x, .36) * fine * .55;
            for (int i = 0; i < 4; i++) {
                float k = float(i);
                vec2 a = vec2((k - 1.5) * .16, .05);
                vec2 b = a + vec2(.04 * sin(k * 3.0), .1 + .04 * cos(k * 2.0));
                core += band(segment(p, a, b), .010) * .4;
            }
        }
        envelope *= layer < .5 ? .52 : .86;
    }
    float edge = smoothstep(0.0, .06, UV.x) * (1.0 - smoothstep(.94, 1.0, UV.x));
    float alpha = clamp(body + core + mist, 0.0, .90) * envelope * opacity * edge;
    vec3 color = mix(dark, light, clamp(core / max(.01, body + mist) + body * .40, 0.0, 1.0));
    COLOR = vec4(color, alpha);
}
