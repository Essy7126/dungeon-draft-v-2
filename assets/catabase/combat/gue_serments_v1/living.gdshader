shader_type canvas_item;
render_mode unshaded;
uniform float effect_time = 0.0;
varying vec2 native_position;
void vertex() { native_position = VERTEX; }
void fragment() {
    vec2 size = vec2(1920.0,1200.0);
    vec2 uv = native_position / size;
    vec2 p = uv * vec2(1586.0,992.0);
    vec4 source = texture(TEXTURE,uv);
    // Conservative regions entirely outside the ford; color isolates incandescent lava.
    bool river = (p.y > 805.0 && p.y < 915.0 && p.x > 650.0 && p.x < 1180.0)
        || (p.x < 180.0 && p.y > 420.0 && p.y < 615.0)
        || (p.x > 1475.0 && p.y > 410.0 && p.y < 640.0)
        || (p.x > 490.0 && p.x < 650.0 && p.y > 187.0 && p.y < 225.0)
        || (p.x > 760.0 && p.x < 930.0 && p.y > 65.0 && p.y < 128.0);
    float hot = smoothstep(0.12,0.4,source.r-max(source.g,source.b));
    float lava = river ? hot : 0.0;
    float t = effect_time;
    vec2 drift = vec2(sin(p.y*0.065-t*0.55),cos(p.x*0.05-t*0.4));
    vec3 painted = texture(TEXTURE,clamp(uv+drift*lava*0.7/size,vec2(0.0),vec2(1.0))).rgb;
    painted += vec3(0.12,0.038,0.003)*lava*(0.5+0.5*sin(p.x*0.04+p.y*0.055-t*0.75));
    for (int i=0;i<3;i++) {
        vec2 center = vec2(229.0,111.0);
        if (i==1) { center=vec2(1126.0,183.0); }
        if (i==2) { center=vec2(1406.0,114.0); }
        vec2 q=(p-center)/vec2(12.0,18.0);
        float lamp=exp(-dot(q,q)*1.6)*hot;
        painted += vec3(0.26,0.12,0.014)*lamp*(0.6+0.4*sin(t*2.1+float(i)));
    }
    COLOR=vec4(clamp(painted,vec3(0.0),vec3(1.0)),source.a);
}
