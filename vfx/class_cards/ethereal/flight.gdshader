shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float progress = 0.0;
uniform vec4 body_color : source_color = vec4(0.6, 0.8, 0.8, 1);
uniform vec4 core_color : source_color = vec4(1, 0.95, 0.8, 1);
uniform bool echo = false;
uniform bool dagger = false;
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
    if (echo && dagger) {
        // Instant damage: a fading directional afterimage, never a late-arriving projectile.
        float taper = .006 + (1.0 - x) * .016;
        float blade = exp(-pow(y / taper, 2.0)) * smoothstep(.12, .70, x) * (1.0 - smoothstep(.94, 1.0, x));
        float silk = exp(-pow((y + sin(x * 8.0) * .019) / .027, 2.0)) * sin(x * 3.14159);
        color = (vec3(.70, .93, 1.0) * blade * .7 + vec3(.24, .55, .61) * silk * .16) * pow(1.0 - progress, 2.0);
    }
    COLOR = vec4(color, 1.0);
}
