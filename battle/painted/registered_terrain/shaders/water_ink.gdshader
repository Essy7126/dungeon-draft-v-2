shader_type canvas_item;
render_mode unshaded;

// Local background treatment: chroma isolates the drawn turquoise water.
// Gameplay, tactical tiles, units and props never use this material.
uniform float motion_amount : hint_range(0.0, 1.0) = 0.65;
uniform float ripple_strength : hint_range(0.0, 0.12) = 0.045;

float water_weight(vec3 c) {
    float cool = smoothstep(0.05, 0.18, min(c.g, c.b) - c.r);
    float saturation = smoothstep(0.1, 0.25, c.g - c.r);
    return cool * saturation;
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float water = water_weight(source.rgb);
    vec2 drift = vec2(
        sin(UV.y * 145.0 + TIME * 0.72),
        cos(UV.x * 119.0 - TIME * 0.53)
    ) * vec2(0.00055, 0.00032) * water * motion_amount;
    vec4 displaced = texture(TEXTURE, UV + drift);
    // Keep shore edges stationary when the neighboring texel is dry.
    float safe_water = water * water_weight(displaced.rgb);
    vec3 painted = mix(source.rgb, displaced.rgb, safe_water);
    float phase = sin(UV.x * 225.0 + UV.y * 116.0 - TIME * 1.1)
        * sin(UV.y * 247.0 - UV.x * 84.0 + TIME * 0.63);
    float fine_ripple = smoothstep(0.72, 0.98, phase);
    painted += vec3(0.54, 0.92, 0.84) * fine_ripple
        * ripple_strength * safe_water * motion_amount;
    COLOR = vec4(painted, source.a);
}

