shader_type canvas_item;
render_mode unshaded;
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float seed_value = 0.0;
uniform int kind = 0;
uniform int variant = 0;
uniform vec4 body_color : source_color = vec4(.9,.3,.05,1);
uniform vec4 core_color : source_color = vec4(1,.9,.5,1);
float line(vec2 p,vec2 a,vec2 b,float w){vec2 ab=b-a;return 1.-smoothstep(w,w+.012,length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.,1.)));}
void fragment(){
	vec2 p=UV;
	float edge=min(min(p.x,p.y),min(1.-p.x,1.-p.y));
	float border=(1.-smoothstep(.026,.045,edge))*smoothstep(0.,.012,edge);
	float shapes=0.;
	for(int i=0;i<5;i++){
		float n=float(i);
		vec2 a=vec2(.15+fract(n*.37+seed_value)*.68,.14+fract(n*.53)*.70);
		vec2 b=a+vec2(.09*(mod(n,2.)*2.-1.),-.12);
		if(variant == 1) {
			// Fault: one connected jagged fracture, not scattered embers.
			a=vec2(.15+n*.14,.44+mod(n,2.)*.12);
			b=vec2(.29+n*.14,.44+mod(n+1.,2.)*.12);
			shapes=max(shapes,line(p,a,b,.025));
		} else if(variant == 2) {
			shapes=max(shapes,1.-smoothstep(.024,.043,length(p-a)));
		} else if(variant == 4) {
			// Caltrops: separate crossed points on the affected cell.
			shapes=max(shapes,line(p,a-vec2(.045,.045),a+vec2(.045,.045),.013));
			shapes=max(shapes,line(p,a-vec2(.045,-.045),a+vec2(.045,-.045),.013));
		} else {
			shapes=max(shapes,line(p,a,b,kind==1?.018:.032));
			shapes=max(shapes,line(p,b,b+vec2(.08,.02),.017));
		}
	}
	float stipple=step(.56,fract(p.x*5.+p.y*3.+seed_value))*step(.3,fract(p.y*5.));
	float birth=smoothstep(0.,.24,age);
	float alpha=max(border*.85, shapes*.75)*birth;
	vec3 color=mix(body_color.rgb*.55,core_color.rgb,shapes);
	if(kind==2){alpha=max(alpha,stipple*.14*birth);}
	COLOR=vec4(color,alpha*opacity);
}
