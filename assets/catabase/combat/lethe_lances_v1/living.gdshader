shader_type canvas_item;
render_mode unshaded;
uniform float effect_time = 0.0;
varying vec2 native_position;
void vertex() { native_position = VERTEX; }

void fragment() {
	vec2 size = vec2(1920.0, 1200.0);
	vec2 p = native_position;
	vec2 uv = p / size;
	vec4 source = texture(TEXTURE, uv);
	float t = effect_time;
	// Conservative native reserve: all engine floor and obstacles stay still.
	bool combat = p.x > 390.0 && p.x < 1470.0 && p.y > 245.0 && p.y < 985.0;
	bool boat = p.x > 90.0 && p.x < 505.0 && p.y > 575.0 && p.y < 840.0;
	float water = smoothstep(0.04, 0.16, min(source.g, source.b) - source.r);
	if (combat || boat) { water = 0.0; }
	vec2 drift = vec2(sin(p.y * 0.057 - t * 1.1 + sin(p.x * 0.019)), cos(p.x * 0.041 - t * 0.8));
	vec3 painted = texture(TEXTURE, clamp(uv + drift * water * 1.15 / size, vec2(0.0), vec2(1.0))).rgb;
	float wave = sin(p.x * 0.032 + sin(p.y * 0.024 + t * 0.3) - t * 0.7)
		* sin(p.y * 0.045 - p.x * 0.011 + t * 0.42);
	float caustic = pow(max(0.0, 1.0 - abs(wave) * 7.0), 3.0);
	painted += vec3(0.016, 0.085, 0.065) * water * caustic;
	painted *= 1.0 + water * sin(p.y * 0.06 - t * 1.05) * 0.025;
	// Light only: never warp the painted flame, lamp frame or surrounding stone.
	for (int i = 0; i < 2; i++) {
		vec2 center = i == 0 ? vec2(456.0, 76.0) : vec2(121.0, 666.0);
		vec2 radius = i == 0 ? vec2(18.0, 33.0) : vec2(15.0, 24.0);
		vec2 q = (p - center) / radius;
		vec2 h = (p - center) / vec2(77.0, 85.0);
		float f = 0.72 + 0.17 * sin(t * 1.8 + float(i) * 2.1) + 0.08 * sin(t * 3.1 + float(i));
		float hot = smoothstep(0.10, 0.30, source.r - source.b);
		float light = exp(-dot(q,q) * 1.5) * hot * 0.18 + exp(-dot(h,h) * 2.0) * 0.10;
		painted += vec3(1.0, 0.46, 0.09) * light * f;
	}
	COLOR = vec4(clamp(painted,vec3(0.0),vec3(1.0)),source.a);
}
