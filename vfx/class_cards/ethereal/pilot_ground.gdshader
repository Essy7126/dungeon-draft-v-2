shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform int kind = 0;
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float seed_value = 0.0;
uniform int variant = 0;

float band(float d, float w) { return exp(-d * d / (w * w)); }
float segment(vec2 p, vec2 a, vec2 b) {
    vec2 v = b - a;
    return length(p - a - v * clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0));
}
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float n = texture(flow_noise, UV * 1.35 + seed_value * .13).r;
    float flow = texture(flow_noise, UV * 2.2 + vec2(age * .05, -age * .13) + seed_value).r;
    float extent = max(abs(p.x), abs(p.y));
    float edge = 1.0 - smoothstep(.84, .98, extent);
    float body = 0.0;
    float core = 0.0;
    vec3 dark;
    vec3 light;
    if (kind == 0) {
        // Porous bed of heat: broad translucent islands and discontinuous bright edges.
        float heat = n + flow * .20;
        body = smoothstep(.34, .70, heat) * .25 + n * .10;
        core = band(heat - .65, .040) * .10 * (.7 + .3 * sin(age * 1.8 + seed_value));
        core += pow(flow, 9.0) * 1.1;
        if (variant == 1) {
            // Faille ardente: two glowing torn seams rather than uniform lava.
            float crack = p.x - sin(p.y * 7.0 + seed_value) * .15;
            body = band(crack, .18) * (.45 + flow * .25);
            core = band(crack, .035) * .75;
            float branch = segment(p, vec2(0.0, -.15), vec2(.7, .35));
            body += band(branch, .12) * .35;
            core += band(branch, .023) * .6;
        } else if (variant == 2) {
            // Flèche incendiaire: scattered ember islands left by the arrow.
            body = smoothstep(.47, .73, heat) * .48;
            core = band(heat - .69, .035) * .38 + pow(flow, 10.0);
        }
        dark = vec3(.70, .23, .06);
        light = vec3(1.0, .77, .36);
    } else {
        // Asymmetric dendrites grow from an off-center vein, not a six-point icon.
        float turn = seed_value * 2.3;
        vec2 q = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn))) * p;
        float growth = smoothstep(0.0, .65, age);
        float trunk = q.x + sin(q.y * 4.0 + seed_value) * .1;
        float revealed = 1.0 - smoothstep(growth * 2.0 - 1.0, growth * 2.0 - .85, q.y);
        core = band(trunk, .014) * revealed * .6;
        body = band(trunk, .045) * revealed * .34;
        for (int i = 0; i < 7; i++) {
            float k = float(i);
            float y = -.72 + k * .23;
            float side = mod(k, 2.0) * 2.0 - 1.0;
            vec2 a = vec2(-sin(y * 4.0 + seed_value) * .1, y);
            vec2 b = a + vec2(side * (.36 + .12 * sin(k * 3.7 + seed_value)), .26);
            float d = segment(q, a, b);
            float born = smoothstep(k * .065, k * .065 + .20, age);
            body += band(d, .034) * born * .38;
            core += band(d, .010) * born * .48;
            for (int j = 1; j < 3; j++) {
                vec2 c = mix(a, b, float(j) * .30);
                float twig = segment(q, c, c + vec2(side * .06, .16));
                core += band(twig, .007) * born * .32;
            }
        }
        body += n * flow * .34;
        if (variant == 4) {
            // Piège: four low, tapered teeth, all clipped to this real cell.
            body = n * flow * .16;
            core = 0.0;
            for (int i = 0; i < 4; i++) {
                float k = float(i);
                vec2 a = p - vec2(mod(k, 2.0) * .8 - .4, floor(k * .5) * .8 - .4);
                float taper = max(.015, .15 * (1.0 - abs(a.y) / .3));
                float span = 1.0 - smoothstep(.16, .30, abs(a.y));
                body += band(a.x, taper) * span * .6;
                core += band(a.x + taper * .3, .026) * span * .7;
            }
        }
        dark = vec3(.12, .35, .43);
        light = vec3(.70, .94, 1.0);
    }
    // Soft inset coverage marks the tile; movement stays inside the real footprint.
    // The four 3-PA fields establish themselves with a single strong birth.
    // The quiet hold and the real polygon remain identical after 0.9 seconds.
    float birth = variant == 4 ? 0.0 : smoothstep(0.0,.10,age) * (1.0-smoothstep(.24,.90,age));
    core += band(extent - (.20+age*.8), .085) * birth * .35;
    body *= 1.0 + birth*.7;
    float alpha = clamp(body + core, 0.0, .90) * edge * opacity;
    COLOR = vec4(mix(dark, light, clamp(core / max(.01, body) + .12, 0.0, 1.0)), alpha);
}
