shader_type canvas_item;
render_mode unshaded;
uniform float flow_amount : hint_range(0.0,1.0) = 0.6;
uniform float ember_pulse : hint_range(0.0,0.2) = 0.045;
varying vec4 liquid_tint;
void vertex() { liquid_tint=COLOR; }
void fragment() {
    vec2 drift=vec2(sin(UV.y*18.0+TIME*0.19),cos(UV.x*15.0-TIME*0.14))
        *vec2(0.0008,0.0005)*flow_amount;
    vec4 painted=texture(TEXTURE,UV+drift);
    float molten=smoothstep(0.18,0.55,painted.r-painted.b);
    float pulse=0.5+0.5*sin(UV.x*21.0+UV.y*13.0+TIME*0.45);
    painted.rgb+=vec3(1.0,0.24,0.035)*molten*pulse*ember_pulse;
    COLOR=painted*liquid_tint;
}

