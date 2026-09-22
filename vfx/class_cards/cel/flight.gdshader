shader_type canvas_item;
render_mode unshaded;
uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform float progress = 0.0;
uniform float span = 200.0;
uniform vec4 body_color : source_color = vec4(.4,.8,.9,1);
uniform vec4 core_color : source_color = vec4(1,.95,.8,1);
uniform bool echo = false;
uniform bool dagger = false;
void fragment() {
    vec2 pixel = vec2(UV.x * span, (UV.y-.5)*64.0);
    float head = progress * span;
    vec2 p = vec2((pixel.x-head)/72.0+.82, pixel.y/48.0+.5);
    vec4 art = vec4(0.0);
    if (p.x>0.0 && p.x<1.0 && p.y>0.0 && p.y<1.0) {
        art = texture(artwork, p/vec2(3.0,2.0));
        art.a = smoothstep(.28,.6,art.a);
        if (!dagger) {
            float value = dot(art.rgb,vec3(.299,.587,.114));
            art.rgb = mix(body_color.rgb*.4,core_color.rgb,smoothstep(.15,.92,value));
        }
    }
    if (echo) {
        // Confirmed instant hit: one receding speed line, never a late projectile.
        float end = 1.0-progress*.3;
        float taper = (dagger ? 2.2 : 1.6) * (1.0-UV.x);
        float line = (1.0-smoothstep(taper,taper+.6,abs(pixel.y))) * step(.08+progress*.55,UV.x) * step(UV.x,end);
        art = vec4(mix(body_color.rgb,core_color.rgb,.65), line*(1.0-progress));
    }
    COLOR = art;
}
