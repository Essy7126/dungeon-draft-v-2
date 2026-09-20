shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform vec4 body_color : source_color;
uniform vec4 core_color : source_color;
uniform int kind = 0;
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float seed_value = 0.0;

float band(float d, float width) { return exp(-d * d / (width * width)); }
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float t = age;
    float n = texture(flow_noise, UV * 0.8 + vec2(seed_value, -t * 0.075)).r;
    float fine = texture(flow_noise, UV * 1.9 + vec2(t * 0.03, -t * 0.08)).r;
    float r = length(p + (n - 0.5) * 0.10);
    float a = atan(p.y, p.x);
    float field = 0.0;
    float core = 0.0;
    if (kind == 0) { // Embers travel through broken currents on the tile.
        field = band(r - 0.55 + sin(a * 3.0 + t) * 0.08, 0.11) * (0.18 + fine * 0.55);
        field += pow(max(0.0, sin(a * 4.0 + r * 10.0 - t * 1.5 + n * 3.0)), 6.0) * band(r - 0.4, 0.3) * 0.30;
        core = pow(fine, 5.0) * band(r - 0.5, 0.34) * 0.6;
    } else if (kind == 1) { // Frost veins retain a readable footprint.
        field = band(sin(a * 3.0 + n * 0.08) * r, 0.035) * (1.0 - smoothstep(0.1, 0.84, r)) * 0.55;
        field += band(r - 0.61 + sin(a * 6.0) * 0.07, 0.025) * (0.12 + n * 0.27);
        core = field * 0.20;
    } else { // Water, poison, steam and elemental reaction residues.
        field = band(r - 0.54 + sin(a * 2.0 - t * 0.5) * 0.1, 0.055) * (0.15 + fine * 0.4);
        field += band(r - 0.25, 0.28) * fine * 0.10;
        core = field * 0.1;
    }
    float edge = 1.0 - smoothstep(0.83, 0.99, max(abs(p.x), abs(p.y)));
    float breathe = 0.85 + 0.15 * sin(t * 1.3 + seed_value);
    COLOR = vec4((body_color.rgb * field + core_color.rgb * core) * edge * opacity * breathe, 1.0);
}
