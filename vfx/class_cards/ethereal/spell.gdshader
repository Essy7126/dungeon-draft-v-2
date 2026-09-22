shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform int motif = 0;
uniform float variant = 0.0;
uniform float progress = 0.0;
uniform float flow_time = 0.0;
uniform float opacity = 1.0;
uniform float seed_value = 0.0;
uniform float layer = 0.0;
uniform bool holding = false;
uniform vec2 direction = vec2(1.0, 0.0);
uniform vec3 body_color : source_color = vec3(.3, .65, .72);
uniform vec3 core_color : source_color = vec3(.85, 1.0, 1.0);
uniform float release = 0.0;
uniform float travel_phase = 0.0;
uniform float power = 0.0;

float band(float d, float w) { return exp(-d * d / max(.00001, w * w)); }
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 v = b - a;
    return length(p - a - v * clamp(dot(p - a, v) / max(.00001, dot(v, v)), 0.0, 1.0));
}
vec2 rotate(vec2 p, float a) { return vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a)); }

void fragment() {
    float u = progress;
    float t = flow_time;
    vec2 p = (UV - vec2(.5, .56)) * 2.0;
    p /= 1.0 + power * .16;
    p *= 1.0 + release * .24;
    vec2 q = vec2(dot(p, direction), dot(p, vec2(-direction.y, direction.x)));
    float n = texture(flow_noise, UV * 2.2 + vec2(seed_value * .03, -t * .17)).r;
    float f = texture(flow_noise, UV * 4.1 + vec2(t * .07, -t * .25)).r;
    float body = 0.0;
    float core = 0.0;
    float mist = 0.0;
    float v = variant;
    float envelope = holding ? smoothstep(0.0, .18, t) : (1.0 - smoothstep(.22, 1.0, u));
    float drive = holding ? .35 + sin(t * 1.2) * .025 : u;

    if (motif == 0) { // Cuts: full crescents with a luminous leading edge and porous wake.
        int count = (int(v) == 3 || int(v) == 7) ? 2 : 1;
        for (int i = 0; i < 2; i++) {
            if (i >= count) { break; }
            float side = i == 0 ? 1.0 : -1.0;
            float angle = -.50 + mod(v, 3.0) * .38 + float(i) * 1.5;
            vec2 a = rotate(p, angle) * vec2(1.0, side);
            float sweep = a.y - (.42 * a.x * a.x - .17 + drive * .24);
            float span = 1.0 - smoothstep(.35, .88, abs(a.x));
            float wake = smoothstep(-.28, -.03, sweep) * (1.0 - smoothstep(.0, .055, sweep));
            body += wake * span * (.65 + f * .45);
            core += band(sweep, .025) * span;
            mist += band(sweep + .14, .15) * span * n * .42;
        }
    } else if (motif == 1) { // Lances/fans: clear taper, rear barbs, directional impact.
        int count = int(v) == 10 ? 5 : (int(v) == 7 ? 3 : 1);
        for (int i = 0; i < 5; i++) {
            if (i >= count) { break; }
            float offset = (float(i) - float(count - 1) * .5) * .22;
            vec2 a = rotate(q, offset);
            float end = .28 + drive * .45;
            float span = smoothstep(-.87, -.55, a.x) * (1.0 - smoothstep(end - .12, end, a.x));
            float width = (.07 + mod(v, 3.0) * .018) * max(.15, 1.0 - (a.x + .7) / 1.5);
            body += band(a.y, width) * span * .85;
            core += band(a.y, .017) * span;
            for (int j = 0; j < 2; j++) {
                float k = float(j) * 2.0 - 1.0;
                float barb = segment(a, vec2(-.2, 0), vec2(-.46, k * (.13 + mod(v, 4.0) * .04)));
                body += band(barb, .027) * .60;
            }
            mist += band(a.y, .15) * span * n * .30;
        }
        core += band(length(q - vec2(.1, 0)), .12) * (1.0 - smoothstep(.04, .25, u));
    } else if (motif == 2) { // Mark: suspended open prongs, never a target-covering disk.
        vec2 a = p - vec2(0, -.43);
        float spread = holding ? .22 : .38 - drive * .20;
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            if (i == 2 && mod(v, 3.0) == 1.0) { break; }
            vec2 b = rotate(a, k * 2.0944 + v * .21);
            float d = segment(b, vec2(spread, -.08), vec2(spread + .12, .0));
            d = min(d, segment(b, vec2(spread + .12, 0), vec2(spread, .08)));
            body += band(d, .058) * .65;
            core += band(d, .018) * .85;
        }
        core += band(length(a), .041) * (.65 + .2 * sin(t * 2.0));
        mist = band(length(a), .18) * n * .24;
    } else if (motif == 3) { // Bleeding: attached wounds plus descending drops, not poison smoke.
        for (int i = 0; i < 4; i++) {
            float k = float(i);
            float x = (k - 1.5) * .16;
            float descent = holding ? fract(t * .30 + k * .21) : drive;
            float y = -.12 + descent * .55;
            float d = segment(p, vec2(x, y - .24), vec2(x + sin(k * 2.0) * .09, y));
            body += band(d, .047) * (.55 + n * .5);
            core += band(d, .013) * .55;
            core += band(length(p - vec2(x, y)), .025) * .7;
        }
    } else if (motif == 4) { // Guard: curved translucent panels around an empty central silhouette.
        int count = int(v) == 5 ? 4 : (int(v) == 1 || int(v) == 2 ? 3 : 2);
        for (int i = 0; i < 4; i++) {
            if (i >= count) { break; }
            float k = float(i);
            float angle = -1.0 + k * 2.0 / float(max(1, count - 1));
            float x = sin(angle) * .56;
            float y = cos(angle) * .13;
            vec2 a = p - vec2(x, y);
            float rim = a.x - sin(a.y * 3.0 + angle) * .075;
            float height = (1.0 - smoothstep(.35, .57, abs(a.y))) * smoothstep(-.58, -.40, a.y);
            body += band(rim, .095) * height * (.55 + n * .30);
            core += band(rim - .055, .018) * height * .75;
            mist += band(rim + .06, .18) * height * f * .15;
        }
    } else if (motif == 5) { // Foot-level streamers. Arrival folds inward; departure opens outward.
        vec2 a = p - vec2(0, .40);
        a = vec2(dot(a, direction), dot(a, vec2(-direction.y, direction.x)));
        float travel = travel_phase > .5 ? 1.0 - drive : drive;
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float curl = a.y - sin(a.x * 3.5 + k * 1.7 - travel * 2.0) * .12 - (k - 1.0) * .08;
            float span = (1.0 - smoothstep(.2, .82, abs(a.x + travel * .18))) * (1.0 - drive * .4);
            body += band(curl, .065) * span * (.4 + n * .45);
            core += band(curl, .016) * span * .6;
        }
    } else if (motif == 6) { // PM loss lives at the ankles; net adds crossing strands.
        vec2 a = p - vec2(0, .38);
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float d = a.y - sin(a.x * 4.0 + k * 2.1 + t * .45) * .10 - (k - 1.0) * .08;
            float span = 1.0 - smoothstep(.22, .49, abs(a.x));
            body += band(d, .042) * span * .65;
            core += band(d, .012) * span * .65;
        }
        if (mod(v, 5.0) >= 3.0) {
            for (int i = 0; i < 4; i++) {
                float k = float(i);
                float d = segment(a, vec2(-.35 + k * .20, -.24), vec2(-.12 + k * .14, .19));
                body += band(d, .030) * .55;
                core += band(d, .010) * .7;
            }
        }
    } else if (motif == 7 || motif == 8) { // Opposed vectors: divergence for push, convergence for pull.
        bool pull = motif == 8;
        vec2 a = pull ? -q : q;
        float travel = pull ? 1.0 - drive : drive;
        for (int i = 0; i < 3; i++) {
            float side = float(i) - 1.0;
            float bend = side * (.13 + (.45 + a.x) * .28) + sin(a.x * 5.0 - t * 3.0 + v) * .07;
            float span = smoothstep(-.65, -.35, a.x) * (1.0 - smoothstep(.35 + travel * .3, .85, a.x));
            float d = a.y - bend;
            body += band(d, .065) * span * (.6 + f * .35);
            core += band(d, .020) * span * .85;
            if (pull && int(v) == 5) {
                float links = pow(.5 + .5 * sin(a.x * 35.0 + t * 5.0), 3.0);
                core += band(d, .055) * links * span * .7;
            }
        }
    } else if (motif == 9 || motif == 14) { // Weakness falls from shoulders; PA disruption stays above them.
        bool ap = motif == 14;
        vec2 a = p - vec2(0, ap ? -.38 : -.08);
        for (int i = 0; i < 5; i++) {
            float k = float(i);
            float side = mod(k, 2.0) * 2.0 - 1.0;
            float fall = holding ? fract(t * .16 + k * .17) : drive;
            vec2 center = vec2(side * (.19 + k * .045), (ap ? -.10 : fall * .37) + sin(k * 2.0) * .10);
            vec2 b = rotate(a - center, side * (.5 + fall * .4));
            float d = segment(b, vec2(-.10, 0), vec2(.10, 0));
            body += band(d, ap ? .043 : .066) * .60;
            core += band(d, .016) * .75;
        }
        mist = band(length(a * vec2(1.0, 1.4)), .39) * n * .28;
    } else if (motif == 10) { // Ice shards: filled tapered prisms, not thin snowflake outlines.
        for (int i = 0; i < 7; i++) {
            float k = float(i);
            float angle = -.85 + k * .28 + mod(v, 2.0) * .10;
            vec2 a = rotate(p - vec2(0, .30), angle);
            float height = .38 + .27 * (.5 + .5 * sin(k * 3.0 + v));
            float tip = -height * (.6 + drive * .4);
            float shape = max(.008, .080 * (1.0 - abs(a.y - tip * .48) / max(.01, -tip * .6)));
            float span = smoothstep(tip - .02, tip + .08, a.y) * (1.0 - smoothstep(.01, .1, a.y));
            body += band(a.x, shape) * span * .80;
            core += band(a.x + shape * .35, .014) * span * .85;
        }
        mist = band(p.y - .27, .16) * band(p.x, .48) * n * .40;
    } else if (motif == 11 || motif == 16) { // Fire plumes / open crown: broad porous tongues, pointed tips.
        bool crown = motif == 16;
        for (int i = 0; i < 5; i++) {
            float k = float(i);
            float x = (k - 2.0) * (crown ? .25 : .17);
            float base = crown ? .22 - abs(k - 2.0) * .05 : .25;
            float y = base - p.y;
            float h = .58 + .16 * sin(k * 2.1 + v);
            float curl = x + sin(y * 7.0 - t * 3.0 + k * 2.0) * (.025 + y * .10);
            float taper = max(.012, (.13 + n * .05) * (1.0 - y / h));
            float span = smoothstep(-.10, .06, y) * (1.0 - smoothstep(h * .5, h, y));
            body += band(p.x - curl, taper) * span * (.5 + f * .6);
            core += band(p.x - curl, taper * .24) * span * .8;
        }
        mist = band(p.y - .15, .27) * band(p.x, .60) * n * .30;
    } else if (motif == 12) { // Lightning: persistent contact flash + short staggered fork afterimages.
        int branches = int(v) == 1 ? 3 : 2;
        for (int i = 0; i < 3; i++) {
            if (i >= branches) { break; }
            float k = float(i);
            vec2 a = rotate(p, (k - 1.0) * .62);
            float fork = 0.0;
            for (int j = 0; j < 5; j++) {
                float z = float(j);
                vec2 start = vec2(sin(z * 4.7 + k) * .18, -.76 + z * .28);
                vec2 end = vec2(sin((z + 1.0) * 4.7 + k) * .18, -.48 + z * .28);
                fork = max(fork, band(segment(a, start, end), .025));
                body += band(segment(a, start, end), .078) * .42;
            }
            core += fork * (1.0 - smoothstep(.12 + k * .06, .75, u));
        }
    } else if (motif == 13) { // Shadow: two broad inward curls with light only on their edges.
        for (int i = 0; i < 2; i++) {
            float side = float(i) * 2.0 - 1.0;
            vec2 a = p * vec2(side, 1.0);
            float curve = a.x - (.19 + sin(a.y * 5.0 + drive * 2.0 + v) * .18);
            float span = 1.0 - smoothstep(.25, .66, abs(a.y));
            body += band(curve, .12) * span * (.5 + n * .6);
            core += band(curve - .07, .022) * span * .7;
        }
    } else { // Stasis: two opposing fans suspend grains, no spinning damage aura.
        for (int i = 0; i < 2; i++) {
            float side = float(i) * 2.0 - 1.0;
            vec2 a = p * vec2(1.0, side);
            float rim = a.y - .40 + a.x * a.x * .7;
            float span = 1.0 - smoothstep(.30, .56, abs(a.x));
            body += band(rim, .085) * span * .6;
            core += band(rim, .018) * span * .8;
        }
        for (int i = 0; i < 6; i++) {
            float k = float(i);
            vec2 center = vec2(sin(k * 2.4) * .14, -.27 + k * .1 + sin(t * .7 + k) * .012);
            core += band(length(p - center), .023) * .85;
        }
        mist = band(length(p * vec2(1.5, 1.0)), .5) * n * .18;
    }

    float edge = smoothstep(0.0, .035, UV.x) * (1.0 - smoothstep(.965, 1.0, UV.x));
    edge *= smoothstep(0.0, .035, UV.y) * (1.0 - smoothstep(.965, 1.0, UV.y));
    float front = smoothstep(-.05, .12, p.y);
    if (motif == 0 || motif == 1 || motif == 2 || motif == 7 || motif == 8 || motif == 14) { front = .9; }
    float plane = layer > .5 ? front : 1.0 - front;
    // Major casts carry a fuller body and short fragments; holds retain the quiet material.
    if (power > .5) {
        for (int i = 0; i < 8; i++) {
            float k = float(i);
            float a = k * 2.39996 + seed_value;
            vec2 center = vec2(cos(a), sin(a)*.70) * (.18 + u*.70);
            core += band(segment(p-center, vec2(0), vec2(cos(a),sin(a))*.06), .017) * (1.0-smoothstep(.25,.75,u));
        }
    }
    float density = body * (.80 + power * .40) + core * .92 + mist;
    float alpha = clamp(density, 0.0, .94) * envelope * opacity * edge * plane;
    vec3 shaded = body_color * (.65 + power * .12);
    vec3 color = mix(shaded, core_color, clamp(core / max(.04, body + core) + body * .22, 0.0, 1.0));
    COLOR = vec4(color, alpha);
}
