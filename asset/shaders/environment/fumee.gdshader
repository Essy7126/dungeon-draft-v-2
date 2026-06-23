shader_type canvas_item;

uniform float vitesse : hint_range(0.0, 1.0) = 0.05;
uniform float echelle : hint_range(1.0, 20.0) = 3.0;
uniform float densite : hint_range(0.0, 1.0) = 0.6;
uniform float durete : hint_range(0.5, 8.0) = 2.0;
uniform vec4 couleur_fumee : source_color = vec4(0.7, 0.7, 0.7, 1.0);

vec2 bruit_hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float bruit_perlin(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(bruit_hash(i), f),
			dot(bruit_hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(bruit_hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(bruit_hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * bruit_perlin(p);
		p = p * 2.0 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * echelle + vec2(TIME * vitesse, TIME * vitesse * 0.3);
	float n = fbm(p + fbm(p + fbm(p)));
	float alpha = clamp(n * densite * durete, 0.0, 1.0);
	COLOR = vec4(couleur_fumee.rgb, alpha);
}