shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float progress = 0.0;
uniform vec4 body_color : source_color = vec4(0.6, 0.8, 0.8, 1);
uniform vec4 core_color : source_color = vec4(1, 0.95, 0.8, 1);
uniform bool echo = false;
void fragment() {
    float x = UV.x;
    float y = UV.y - 0.5;
    float behind = progress - x;
    float trail = smoothstep(0.0, 0.05, behind) * (1.0 - smoothstep(0.1, 0.42, behind));
    float wave = sin(x * 24.0 - progress * 13.0) * 0.024 * behind;
    float line = exp(-pow((y + wave) / (0.025 + max(behind, 0.0) * 0.12), 2.0));
    float point = exp(-pow((x - progress) * 65.0, 2.0) - pow(y * 16.0, 2.0));
    vec3 color = body_color.rgb * trail * line * 0.62 + core_color.rgb * point * 0.72;
    if (echo) color = body_color.rgb * exp(-y * y * 1300.0) * (1.0 - progress) * sin(x * 3.14159) * 0.28;
    COLOR = vec4(color, 1.0);
}
