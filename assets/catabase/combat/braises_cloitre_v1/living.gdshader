shader_type canvas_item;
render_mode unshaded;
uniform float effect_time = 0.0;
varying vec2 native_position;
void vertex() { native_position = VERTEX; }
void fragment() {
    vec2 uv=native_position/vec2(1920.0,1200.0);
    vec2 p=uv*vec2(1586.0,992.0);
    vec4 source=texture(TEXTURE,uv);
    float hot=smoothstep(0.12,0.4,source.r-max(source.g,source.b));
    vec3 painted=source.rgb;
    // Local coals and fire bowls only. Rock, architecture and abyss remain fixed.
    for(int i=0;i<4;i++) {
        vec2 center=vec2(174.0,240.0);
        vec2 radius=vec2(25.0,22.0);
        if(i==1) { center=vec2(1541.0,486.0); }
        if(i==2) { center=vec2(590.0,153.0); radius=vec2(19.0,12.0); }
        if(i==3) { center=vec2(83.0,380.0); radius=vec2(18.0,52.0); }
        vec2 q=(p-center)/radius;
        float glow=exp(-dot(q,q)*1.6)*hot;
        painted+=vec3(0.25,0.10,0.008)*glow*(0.6+0.4*sin(effect_time*1.35+float(i)));
    }
    COLOR=vec4(clamp(painted,vec3(0.0),vec3(1.0)),source.a);
}
