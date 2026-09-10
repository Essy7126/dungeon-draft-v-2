shader_type canvas_item;
render_mode unshaded;
uniform float effect_time = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.52;

float cloud(vec2 p) {
    vec2 q = p + vec2(sin(p.y * 0.73), cos(p.x * 0.81)) * 1.4;
    float broad = sin(q.x * 1.13 + q.y * 0.71) * cos(q.y * 1.21 - q.x * 0.43);
    float fine = sin(q.x * 2.17 - q.y * 1.41 + sin(q.y)) * cos(q.y * 2.03);
    return 0.5 + broad * 0.34 + fine * 0.16;
}
void fragment() {
    float t = effect_time;
    vec2 p = UV * vec2(9.0, 13.0);
    float low = cloud(p + vec2(-t * 0.11, t * 0.045));
    float high = cloud(p * vec2(1.8, 1.3) + vec2(t * 0.075, -t * 0.07));
    float curl = cloud(p + vec2(low * 2.1, high * 1.5) + vec2(-t * 0.06, 0.0));
    float vapor = smoothstep(0.32, 0.77, curl * 0.68 + high * 0.32);
    // A conservative clear rectangle encloses every playable floor polygon.
    float sides = max(1.0 - smoothstep(0.05, 0.205, UV.x), smoothstep(0.79, 0.98, UV.x));
    float bottom = smoothstep(0.81, 0.96, UV.y);
    float back = (1.0 - smoothstep(0.08, 0.22, UV.y)) * 0.28;
    float perimeter = max(max(sides, bottom), back);
    float edge = smoothstep(0.0, 0.025, min(min(UV.x, 1.0-UV.x), min(UV.y, 1.0-UV.y)));
    vec3 tint = mix(vec3(0.09, 0.31, 0.36), vec3(0.20, 0.58, 0.47), low);
    COLOR = vec4(tint, vapor * perimeter * edge * density);
}
