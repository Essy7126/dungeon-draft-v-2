uniform vec4 floor_shade : source_color = vec4(0.42,0.41,0.22,1.0);
uniform vec4 floor_body : source_color = vec4(0.69,0.62,0.32,1.0);
uniform vec4 floor_light : source_color = vec4(0.88,0.79,0.47,1.0);
#include "res://battle/painted/registered_terrain/shaders/combat_ground_surface.gdshaderinc"
uniform bool combat_band_enabled = false;

// Retain the actual stone texture and alpha; shade it in the shared terrain
// coordinate system. No second floor polygon is drawn on top.
uniform float warmth = 0.0;
uniform float painted_steps : hint_range(0.0, 1.0) = 0.24;
uniform float bevel_flatten_strength : hint_range(0.0, 1.0) = 0.90;
uniform sampler2D meadow_texture : source_color, repeat_enable, filter_linear;
uniform vec2 meadow_texture_scale = vec2(1.0);
uniform vec4 meadow_tint : source_color = vec4(1.0);
uniform bool meadow_repeat = true;
uniform float interior_joint_land_weight : hint_range(0.0, 1.0) = 1.0;
uniform vec2 cell_native_center = vec2(0.0);
uniform vec2 cell_native_span = vec2(103.2, 51.6);
uniform vec4 exterior_edges = vec4(0.0); // up, right, down, left
varying vec4 item_modulate;

void vertex() { item_modulate = COLOR; }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise21(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),
        mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    vec4 stone = texture(TEXTURE, UV);
    float source_luma = dot(stone.rgb, vec3(0.299, 0.587, 0.114));
    float lower_edge_depth = 1.0 - abs(UV.x - 0.5) - UV.y;
    float front_band = step(0.5, UV.y) * (1.0 - smoothstep(0.02, 0.09, lower_edge_depth));
    vec4 top_sample = texture(TEXTURE, mix(UV, vec2(0.5), 0.20));
    float top_luma = dot(top_sample.rgb, vec3(0.299, 0.587, 0.114));
    float value = mix(source_luma, top_luma, front_band * bevel_flatten_strength);
    value = clamp(value * 1.30 + 0.10 + warmth, 0.0, 1.0);
    value = mix(value, floor(value * 5.0 + 0.5) / 5.0, painted_steps);
    vec3 shade = floor_shade.rgb;
    vec3 body = floor_body.rgb;
    vec3 light = floor_light.rgb;
    vec3 color = mix(shade, body, smoothstep(0.03, 0.64, value));
    color = mix(color, light, smoothstep(0.48, 0.96, value));

    vec2 native = cell_native_center + (UV - vec2(0.5)) * cell_native_span;
    vec2 meadow_size = vec2(textureSize(meadow_texture,0));
    vec2 meadow_uv = native / max(abs(meadow_texture_scale), vec2(0.001)) / meadow_size;
    if (!meadow_repeat) {
        // Match Polygon2D's clamp without changing either sprite geometry or
        // stone alpha. Half-texel bounds prevent sampling the opposite edge.
        vec2 half_texel = vec2(0.5) / meadow_size;
        meadow_uv = clamp(meadow_uv, half_texel, vec2(1.0) - half_texel);
    }
    vec3 meadow = texture(meadow_texture, meadow_uv).rgb * meadow_tint.rgb;
    vec2 grid_uv = vec2(UV.x + UV.y - 1.0, UV.y - UV.x);
    vec4 edge_distance = vec4(grid_uv.y+0.5,0.5-grid_uv.x,0.5-grid_uv.y,grid_uv.x+0.5);
    vec4 active_distance = mix(vec4(2.0), edge_distance, exterior_edges);
    float outer_distance = min(min(active_distance.x,active_distance.y),min(active_distance.z,active_distance.w));
    float patch = noise21(native / vec2(25.0,16.0));
    float small_patch = noise21(native / vec2(7.0,5.0));
    float edge_width = 0.015 + smoothstep(0.27,0.73,patch) * 0.11;
    float ground_join = (1.0-smoothstep(0.0,edge_width,outer_distance)) * smoothstep(0.22,0.62,patch);
    float seam_distance = min(min(edge_distance.x,edge_distance.y),min(edge_distance.z,edge_distance.w));
    float seam_moss = (1.0-smoothstep(0.008,0.055,seam_distance)) * smoothstep(0.64,0.84,patch) * (0.3+0.7*small_patch);
    // Keep meadow moss on interior joints; exterior edges meet compacted earth.
    if (combat_band_enabled) { seam_moss *= smoothstep(0.01,0.085,outer_distance); }
    vec3 exterior_ground = combat_band_enabled ? gb_soil(native,0.0) : meadow;
    color = mix(color, exterior_ground, clamp(ground_join*0.88,0.0,0.9));
    color = mix(color, mix(gb_soil(native,0.0), meadow, interior_joint_land_weight), clamp(seam_moss*0.55,0.0,0.9));
    COLOR = vec4(color, stone.a) * item_modulate;
}
