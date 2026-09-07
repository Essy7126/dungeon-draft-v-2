// Shared by the ground underlay and the existing stone sprites.
uniform float band_width_cells = 0.42;
uniform vec4 band_earth : source_color = vec4(0.67843,0.53725,0.30980,1.0);
uniform vec4 band_light : source_color = vec4(0.75686,0.61569,0.35686,1.0);
uniform vec4 band_shadow : source_color = vec4(0.54118,0.45882,0.27451,1.0);

float gb_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float gb_noise(vec2 p) {
    vec2 i=floor(p), f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(gb_hash(i),gb_hash(i+vec2(1,0)),f.x),
        mix(gb_hash(i+vec2(0,1)),gb_hash(i+vec2(1,1)),f.x),f.y);
}
vec3 gb_soil(vec2 native, float distance_cells) {
    float broad=gb_noise(native/vec2(40.0,23.0));
    float grain=gb_noise(native/vec2(5.0,3.0));
    vec3 earth=mix(band_shadow.rgb,band_light.rgb,smoothstep(0.15,0.85,broad));
    earth=mix(band_earth.rgb,earth,0.80);
    earth+=(grain-0.5)*0.03;
    // Intermittent compacted contact, not a continuous dark platform outline.
    float contact=(1.0-smoothstep(0.006,0.032,distance_cells))
        * smoothstep(0.45,0.76,gb_noise(native/vec2(18.0,11.0)));
    return earth*(1.0-0.095*contact);
}
float gb_coverage(vec2 native, float distance_cells) {
    float wear=gb_noise(native/vec2(17.0,10.0))-0.5;
    float fine=gb_noise(native/vec2(4.0,2.5))-0.5;
    float width=band_width_cells*(0.94+0.10*wear+0.045*fine);
    return 1.0-smoothstep(width*0.52,width,distance_cells);
}
