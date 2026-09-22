shader_type canvas_item;
render_mode unshaded;
uniform sampler2D artwork : source_color, filter_linear, repeat_disable;
uniform int frame_index = 0;
uniform float progress = 0.0;
uniform float flow_time = 0.0;
uniform float opacity = 1.0;
uniform float layer = 0.0;
uniform bool holding = false;
uniform bool frontal = false;
uniform bool recolor = false;
uniform bool clustered_pierce = false;
uniform vec4 body_color : source_color = vec4(.2,.65,.8,1);
uniform vec4 core_color : source_color = vec4(1,1,.9,1);
uniform int copies = 1;
uniform float angle = 0.0;
uniform vec2 direction = vec2(1,0);
uniform int staging = 0;
uniform float pose_scale = 1.0;

vec4 pose(vec2 p) {
	if (any(lessThan(p,vec2(0))) || any(greaterThan(p,vec2(1)))) return vec4(0);
	vec2 cell = vec2(float(frame_index % 3), float(frame_index / 3));
	vec4 art = texture(artwork, (cell + clamp(p, vec2(.003), vec2(.997))) / vec2(3,2));
	// Generated files stay intact. The cel material rejects the diffuse low-alpha fringe.
	art.a = smoothstep(.28,.60,art.a);
	if (recolor) {
		float v = dot(art.rgb, vec3(.299,.587,.114));
		vec3 ink = body_color.rgb * .20;
		art.rgb = v < .24 ? ink : (v < .7 ? body_color.rgb * (.68 + .42 * v) : core_color.rgb);
	}
	return art;
}
void fragment() {
	vec2 p = UV;
	vec4 result = vec4(0);
	if (holding) {
		float box = max(abs(p.x-.5), abs(p.y-.5));
		if (layer < .5) {
			vec3 col = box > .425 ? body_color.rgb : vec3(.035,.065,.08);
			result = vec4(col, (1.0-smoothstep(.47,.49,box))*.96);
		} else {
			result = pose((p-.5)*1.04+.5);
			result.rgb *= .95 + .05 * sin(flow_time*2.0);
		}
	} else {
		float a = angle;
		if (staging == 1 || staging == 2 || staging == 3) a += atan(direction.y,direction.x);
		if (staging == 2) a += 3.14159265;
		for (int i=0; i<5; i++) {
			if (i >= copies) break;
			float centered = float(i) - float(copies-1)*.5;
			float turn = a + centered * (clustered_pierce ? .10 : (staging == 3 ? .38 : .15));
			vec2 q = p - vec2(.5,.55);
			q = mat2(vec2(cos(turn),-sin(turn)),vec2(sin(turn),cos(turn))) * q;
			q = q / pose_scale;
			if (copies > 1) q = clustered_pierce ? q*2.1-vec2(0,centered*.25) : q*1.20-vec2(0,centered*.09);
			if (staging == 4 && i%2==1) q.x = -q.x;
			vec4 tex = pose(q+vec2(.5,.55));
			result.rgb = mix(result.rgb,tex.rgb,tex.a);
			result.a = tex.a + result.a*(1.0-tex.a);
		}
		// Wide eruptions sit behind the body; only their feet and side fragments pass in front.
		float front = frontal ? 1.0 : max(step(.81,p.y),step(.25,abs(p.x-.5)));
		result.a *= layer < .5 ? 1.0-front : front;
	}
	COLOR = vec4(result.rgb, result.a*opacity);
}
