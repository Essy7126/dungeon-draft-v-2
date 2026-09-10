shader_type canvas_item;
render_mode unshaded;

uniform float effect_time = 0.0;
varying vec2 native_position;
void vertex() { native_position = VERTEX; }

float wet(vec3 c) {
    return smoothstep(0.025, 0.13, min(c.g, c.b) - c.r);
}

void fragment() {
    vec2 size = vec2(1920.0, 1200.0);
    vec2 p = native_position / size;
    vec4 original = texture(TEXTURE, p);
    float water_mask = wet(original.rgb);
    float t = effect_time;
    // This material is confined to the Water surface beneath the authored Land polygon.
    vec2 ripple = vec2(sin(p.y * 112.0 - t * 1.6 + sin(p.x * 43.0)),
        cos(p.x * 95.0 + p.y * 53.0 - t * 1.1));
    vec2 drift = ripple * vec2(1.9, 1.1) * water_mask;
    vec3 painted = texture(TEXTURE, clamp(p + drift / size, vec2(0.0), vec2(1.0))).rgb;
    vec2 flow = p * vec2(65.0, 92.0);
    flow += vec2(sin(flow.y * 0.8 + t * 0.36), cos(flow.x * 0.6 - t * 0.29)) * 1.9;
    float waves = sin(flow.x + flow.y - t * 0.55) * sin(flow.y * 1.7 - flow.x * 0.4 + t * 0.39);
    float caustic = pow(max(0.0, 1.0 - abs(waves) * 7.0), 3.0);
    float current = 0.5 + 0.5 * sin(p.y * 137.0 + p.x * 52.0 - t * 1.2);
    painted += vec3(0.025, 0.14, 0.11) * caustic * water_mask;
    painted *= 1.0 + water_mask * (current - 0.5) * 0.13;
    COLOR = vec4(painted, original.a);
}
