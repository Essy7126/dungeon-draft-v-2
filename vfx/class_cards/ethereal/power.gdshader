shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform int shape = 0;
uniform float progress = 0.0;
uniform float flow_time = 0.0;
uniform float opacity = 1.0;
uniform float seed_value = 0.0;
uniform float layer = 0.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform vec3 body_color : source_color = vec3(.65, .3, .5);
uniform vec3 core_color : source_color = vec3(1.0, .94, .82);

float band(float d, float w) { return exp(-d * d / (w * w)); }
float fill(float d) { return 1.0 - smoothstep(-.004, .012, d); }
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 v = b - a;
    return length(p - a - v * clamp(dot(p - a, v) / max(.00001, dot(v, v)), 0.0, 1.0));
}
vec2 rot(vec2 p, float a) { return vec2(p.x*cos(a)-p.y*sin(a), p.x*sin(a)+p.y*cos(a)); }
float box(vec2 p, vec2 half_size) { vec2 q = abs(p) - half_size; return length(max(q, vec2(0))) + min(max(q.x, q.y), 0.0); }
float wedge(vec2 p, float tip, float base, float half_width) {
    return max(max(tip - p.y, p.y - base), abs(p.x) - half_width * clamp((p.y - tip) / (base - tip), 0.0, 1.0));
}

void fragment() {
    float u = progress;
    float growth = 1.0 - pow(1.0 - clamp(u / .15, 0.0, 1.0), 3.0);
    vec2 p = (UV - vec2(.5, .55)) * 2.0;
    p /= .58 + growth * .42;
    float n = texture(flow_noise, UV * 2.0 + vec2(seed_value * .07, -flow_time * .12)).r;
    float fine = texture(flow_noise, UV * 5.0 + vec2(flow_time * .06, seed_value)).r;
    vec2 q = vec2(dot(p, direction), dot(p, vec2(-direction.y, direction.x)));
    float body = 0.0;
    float core = 0.0;
    float dust = 0.0;
    float front = .78;
    float tail = 1.0 - smoothstep(.32, 1.0, u);
    float dissolve = 1.0 - smoothstep(.50 + n * .35, .75 + n * .25, u);
    float contact = (1.0 - smoothstep(.015, .12, u));

    if (shape == 0) { // Reaper: wide crescent blades with an asymmetrical hollow wake.
        for (int i = 0; i < 2; i++) {
            float k = float(i);
            float swing = smoothstep(0.0,.42,u);
            vec2 a = rot(p - vec2(0, -.07), -.85 + k * 1.68 + swing * (i == 0 ? 1.50 : -.95));
            a.y *= i == 0 ? 1.0 : -1.0;
            float outer = length(a * vec2(1.0, 1.20)) - .72;
            float inner = length((a - vec2(.09, -.17)) * vec2(1.0, 1.18)) - .62;
            float blade = max(max(outer, -inner), -a.y - .16);
            body += fill(blade) * (.78 + n * .28);
            core += band(blade, .017) * .92;
            dust += band(outer + .08, .13) * smoothstep(-.1, .32, a.y) * n * .20;
        }
    } else if (shape == 1) { // Bastion: solid, crenellated spectral wall panels, hollow center.
        for (int i = 0; i < 3; i++) {
            float k = float(i) - 1.0;
            float scatter = smoothstep(.40,.95,u);
            vec2 a = p - vec2(k * (.43+scatter*.12), abs(k) * .18 + (1.0-growth) * .5 - scatter*.15);
            float lock = 1.0 - pow(1.0-clamp((u-abs(k)*.025)/.14,0.0,1.0),3.0);
            a.y += (1.0-lock)*.72;
            float panel = box(a - vec2(0, -.05), vec2(.185, .52));
            float notch = box(a - vec2(0, -.55), vec2(.063, .10));
            panel = max(panel, -notch);
            body += fill(panel) * (.65 + n * .24) * lock;
            core += band(panel, .013) * .82;
            // Faceted center ridge, no opaque plate painted over the actor.
            core += band(a.x, .019) * fill(panel) * .5;
            body += fill(panel) * step(0.0, a.x) * .22;
        }
        front = smoothstep(.12, .40, p.y) * .65;
    } else if (shape == 2) { // Judgement: descending ram of bronze, contact shards, no push arrow.
        vec2 a = rot(p - vec2(0, -.12 - (1.0-growth) * .28), -.28);
        float head = max(box(a, vec2(.28, .38)), abs(a.x) + abs(a.y * .64) - .43);
        float haft = box(a - vec2(0, -.50), vec2(.065, .20));
        float hammer = min(head, haft);
        body = fill(hammer) * (.85 + n * .25);
        core = band(hammer, .018) + band(a.x + .12, .024) * fill(head) * .65;
        body += fill(head) * step(0.0, a.x) * .32;
    } else if (shape == 3 || shape == 4) { // Broad arrowheads and translucent feathered wakes.
        int count = shape == 3 ? 5 : 1;
        for (int i = 0; i < 5; i++) {
            if (i >= count) { break; }
            float k = float(i) - float(count-1) * .5;
            vec2 a = rot(q, k * .26);
            a.x += .14 - growth * .18 - smoothstep(.15,.85,u)*.35;
            vec2 b = vec2(a.y, -a.x);
            float head = wedge(b, -.72, -.16, shape == 3 ? .10 : .22);
            float notch = wedge(b, -.40, -.10, shape == 3 ? .052 : .12);
            head = max(head, -notch);
            float shaft = box(a - vec2(-.20, 0), vec2(.39, .024));
            body += fill(min(head, shaft)) * .92;
            core += band(head, .012) * .8 + band(a.y, .010) * fill(shaft);
            float wake = max(abs(a.y) - (.74-a.x) * .10, max(-.80-a.x, a.x-.16));
            body += fill(wake) * (.30 + n * .28);
            if (shape == 4) {
                for (int j = 0; j < 3; j++) {
                    float bx = -.15 - float(j) * .18;
                    float barb = min(segment(a, vec2(bx+.15, 0), vec2(bx, -.17)), segment(a, vec2(bx+.15, 0), vec2(bx, .17)));
                    body += band(barb, .045) * .7;
                    core += band(barb, .012);
                }
            }
        }
    } else if (shape == 5) { // Broken hourglass: real glass silhouette, sand and a fractured rim.
        vec2 a = p - vec2(0, -.23);
        float height = .55;
        float width = .045 + abs(a.y) * .60;
        float glass = max(abs(a.x) - width, abs(a.y) - height);
        float rim = min(box(a - vec2(0, -height), vec2(.39, .045)), box(a - vec2(.025, height), vec2(.39, .045)));
        body = fill(glass) * (.25 + n * .32) + fill(rim) * .82;
        core = band(glass, .014) * .78 + band(rim, .014) * .9;
        float sand = max(abs(a.x) - (.31 - abs(a.y-.39) * .95), abs(a.y-.39) - .12);
        body += fill(sand) * .75;
        core += band(a.x, .012) * (1.0 - smoothstep(.28, .40, abs(a.y))) * (.4 + fine * .6);
        for (int i = 0; i < 7; i++) {
            float k = float(i);
            vec2 grain = vec2(sin(k*2.1)*.035, -.30+k*.08);
            core += band(length(a-grain), .022) * .85;
        }
        front = .20;
    } else if (shape == 6) { // Oblivion: two broad inward folding wings and a pale moon crest.
        vec2 a = p - vec2(0, -.13);
        for (int i = 0; i < 2; i++) {
            vec2 b = a * vec2(float(i)*2.0-1.0, 1.0);
            float outer = length((b - vec2(.10, 0)) * vec2(1.0, .82)) - .52;
            float inner = length((b - vec2(-.10, -.13)) * vec2(1.0, .84)) - .50;
            float wing = max(max(outer, -inner), -b.x + .03);
            body += fill(wing) * (.7 + n * .35);
            core += band(wing, .014) * .75;
        }
        vec2 moon = a - vec2(0, -.59);
        float crest = max(length(moon)-.16, -(length(moon-vec2(.065,-.055))-.145));
        core += fill(crest) * .85;
        dust = band(length(a*vec2(1.1,.8)), .58) * n * .16;
        front = .24;
    } else if (shape == 7) { // Corona: a broad glowing circlet with five distinct flame points.
        vec2 a = p - vec2(0, .04);
        for (int i = 0; i < 5; i++) {
            float k = float(i)-2.0;
            float height = .61 + (1.0-abs(k)*.28)*.22;
            vec2 b = a - vec2(k*.235, .20-abs(k)*.06);
            b.x += sin(b.y*8.0-flow_time*5.0+k)*.12 * smoothstep(0.0,.6,-b.y);
            float flame = wedge(b, -height, .10, .14);
            body += fill(flame) * (.65 + n * .50);
            core += fill(wedge(b, -height*.68, .06, .053)) * .9;
            core += band(flame, .013) * .30;
            dust += band(b.x,.16) * smoothstep(-height-.08,-height+.15,b.y) * (1.0-smoothstep(-.3,.2,b.y)) * n * .18;
        }
        float circlet = length(a * vec2(1, 3.2)) - .61;
        float bottom = smoothstep(-.03, .10, a.y);
        body += band(circlet, .14) * bottom * .7;
        core += band(circlet, .028) * bottom * .85;
        front = mix(.22, .80, smoothstep(-.07, .12, a.y));
    } else if (shape == 8) { // Tempest: broad jagged column rather than equally thin branch lines.
        float bolt = 10.0;
        for (int i = 0; i < 6; i++) {
            float k = float(i);
            vec2 a = vec2(sin(k*4.3)*.17, -.86+k*.19);
            vec2 b = vec2(sin((k+1.0)*4.3)*.17, -.67+k*.19);
            bolt = min(bolt, segment(p, a, b));
        }
        body = band(bolt, .12) * (.7+n*.3);
        core = band(bolt, .038) * 1.15;
        for (int i = 0; i < 2; i++) {
            float side = float(i)*2.0-1.0;
            float branch = min(segment(p, vec2(0,-.35), vec2(side*.42,-.20)), segment(p, vec2(side*.42,-.20), vec2(side*.31,.20)));
            body += band(branch,.053)*.8;
            core += band(branch,.017)*.9;
        }
    } else { // Paris exception: disruption shards, no hourglass or sleep silhouette.
        for (int i = 0; i < 5; i++) {
            float k = float(i);
            vec2 a = rot(p - vec2(sin(k*2.4)*(.25+u*.15), -.4+cos(k*2.4)*.22), k*.75+u*.30);
            float shard = wedge(a, -.22, .12, .09);
            body += fill(shard) * .85;
            core += band(shard,.015) * .8;
        }
        front = .35;
    }

    // One contact accent, then fragment motion: never repeated damage-like pulses.
    bool forceful = shape <= 4 || shape == 7 || shape == 8;
    vec2 hit = p - vec2(0, .28);
    if (forceful) {
        float angle = atan(hit.y, hit.x);
        float star = .09 + .17 * pow(abs(cos(angle*4.0 + .2)), 12.0);
        core += fill(length(hit)-star) * contact * 1.5;
    }
    for (int i = 0; i < 12; i++) {
        float k = float(i);
        float angle = k * 2.39996 + seed_value;
        float drift = .21 + u*.60;
        vec2 center = forceful ? vec2(cos(angle)*drift, .12+sin(angle)*drift*.65) : vec2(sin(angle)*.62, .25-u*.9+k*.025);
        vec2 shard = rot(p-center, angle+u*.8);
        float d = abs(shard.x)/.016 + abs(shard.y)/(.026+mod(k,3.0)*.013) - 1.0;
        dust += fill(d*.015) * smoothstep(.045,.18,u) * (1.0-smoothstep(.45,.98,u));
    }
    float edge = smoothstep(0.0,.025,UV.x) * (1.0-smoothstep(.975,1.0,UV.x));
    edge *= smoothstep(0.0,.025,UV.y) * (1.0-smoothstep(.975,1.0,UV.y));
    float plane = layer > .5 ? front : 1.0-front;
    float mass = body * dissolve * tail;
    float light = core * tail * mix(1.0, dissolve, smoothstep(.42,.82,u));
    float alpha = clamp(mass*.76+light*.92+dust*.60,0.0,.97) * plane * opacity * edge;
    vec3 shaded = body_color * (.66 + n*.30);
    vec3 color = mix(shaded, core_color, clamp(light / max(.08, mass+light) + dust*.45,0.0,1.0));
    COLOR = vec4(color, alpha);
}
