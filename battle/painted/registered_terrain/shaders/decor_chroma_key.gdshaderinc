uniform vec4 key_color : source_color = vec4(1.0,0.0,1.0,1.0);
uniform float threshold = 0.10;
uniform float softness = 0.05;
// Optional decontamination for an RGB atlas rendered against a magenta matte.
// Off by default so native-alpha art and existing keyed palettes stay unchanged.
uniform float magenta_despill : hint_range(0.0, 1.0) = 0.0;
varying vec4 item_modulate;
void vertex() { item_modulate = COLOR; }
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float keep = smoothstep(threshold, threshold + max(softness,0.0001), distance(source.rgb,key_color.rgb));
    float spill = max(min(source.r, source.b) - source.g, 0.0);
    float edge_keep = 1.0 - smoothstep(0.04, 0.45, spill);
    keep *= mix(1.0, edge_keep, magenta_despill);
    source.rgb = max(source.rgb - vec3(spill, 0.0, spill) * magenta_despill, vec3(0.0));
    COLOR = vec4(source.rgb,source.a * keep) * item_modulate;
}
