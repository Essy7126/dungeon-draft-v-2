shader_type canvas_item;
render_mode unshaded;
uniform float effect_time = 0.0;
uniform sampler2D water_flow : filter_linear, repeat_disable;
varying vec2 native_position;
void vertex() { native_position = VERTEX; }
void fragment() {
 vec2 uv = native_position / vec2(1920.0,1200.0);
 vec2 size = vec2(1586.0,992.0);
 vec2 p = uv * size;
 vec4 original = texture(TEXTURE,uv);
 vec3 color = original.rgb;
 float t = effect_time;
 vec3 field = texture(water_flow,uv).rgb;
 vec2 direction = field.rg * 2.0 - 1.0;
 // Two short overlapping excursions avoid accumulated stretching and resets.
 float phase = t * 0.19 + sin(p.x * 0.008 + p.y * 0.006) * 0.12;
 float a = fract(phase);
 float b = fract(phase + 0.5);
 vec2 ua = uv - direction * 19.0 * (a - 0.5) / size;
 vec2 ub = uv - direction * 19.0 * (b - 0.5) / size;
 float safe = field.b * texture(water_flow,ua).b * texture(water_flow,ub).b;
 safe *= texture(water_flow,uv+vec2(6.0,0.0)/size).b * texture(water_flow,uv-vec2(6.0,0.0)/size).b;
 safe *= texture(water_flow,uv+vec2(0.0,6.0)/size).b * texture(water_flow,uv-vec2(0.0,6.0)/size).b;
 vec3 moving = mix(texture(TEXTURE,ua).rgb,texture(TEXTURE,ub).rgb,abs(a*2.0-1.0));
 color = mix(color,moving,safe*0.88);
 float lamp = 0.5 + 0.28*sin(t*3.7) + 0.16*sin(t*6.1+0.8);
 float reflection = exp(-pow((p.x-116.0)/31.0,2.0))*smoothstep(596.0,619.0,p.y)*(1.0-smoothstep(748.0,830.0,p.y));
 color *= 1.0 + safe*reflection*(lamp-0.5)*0.35;
 // Move only the flame, with its base pinned above the metal cup.
 float region = smoothstep(420.0,430.0,p.x)*(1.0-smoothstep(460.0,470.0,p.x))*smoothstep(49.0,57.0,p.y)*(1.0-smoothstep(106.0,110.0,p.y));
 float tip = clamp((109.0-p.y)/49.0,0.0,1.0);
 vec2 flame_uv = uv + vec2((sin(t*5.2-tip*3.0)*4.3+sin(t*8.1)*1.3)*tip,sin(t*4.2)*tip*2.0)/size;
 vec3 flame = texture(TEXTURE,flame_uv).rgb;
 color = mix(color,flame,region);
 float hot = smoothstep(0.32,0.65,flame.r-flame.b)*region;
 color = mix(color,color*(0.88+0.12*sin(t*5.2))+vec3(0.09,0.045,0.005),hot);
 vec2 td = (p-vec2(445.0,103.0))/vec2(54.0,74.0);
 float pulse = 0.5+0.3*sin(t*5.2)+0.13*sin(t*8.1+0.6);
 color += vec3(0.12,0.055,0.008)*exp(-dot(td,td)*2.0)*pulse;
 // Glass luminance and local bounce: bronze and hull do not distort.
 float glass = smoothstep(102.0,108.0,p.x)*(1.0-smoothstep(123.0,128.0,p.x))*smoothstep(549.0,555.0,p.y)*(1.0-smoothstep(577.0,582.0,p.y));
 color *= 1.0-glass*(0.10+0.22*(1.0-lamp));
 vec2 ld = (p-vec2(116.0,565.0))/vec2(48.0,57.0);
 color += vec3(0.15,0.085,0.015)*exp(-dot(ld,ld)*2.0)*lamp;
 COLOR = vec4(clamp(color,vec3(0.0),vec3(1.0)),original.a);
}
