shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float vitesse             : hint_range(0.0, 2.0)  = 0.8;
uniform float echelle             : hint_range(1.0, 10.0) = 4.0;
uniform vec4  couleur_coeur       : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4  couleur_bord        : source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform float intensite           : hint_range(0.0, 3.0)  = 1.2;
uniform float blob_rayon_orbite   : hint_range(0.05, 0.35) = 0.18;
uniform float blob_vitesse_orbite : hint_range(0.5, 3.0)   = 1.1;
uniform float blob_taille         : hint_range(0.02, 0.15) = 0.09;

vec2 bruit_hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float bruit_perlin(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(bruit_hash(i),                f),
			dot(bruit_hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(bruit_hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(bruit_hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * bruit_perlin(p);
		p  = p * 2.0 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// UV décalé : centre brillant vers la tête (côté +X = sens du vol)
	vec2  centre = UV - vec2(0.58, 0.5);
	float dist   = length(centre);

	// Corps principal organique (FBM)
	float masque     = 1.0 - smoothstep(0.28, 0.5, dist);
	vec2  p          = UV * echelle + vec2(TIME * vitesse, TIME * vitesse * 0.6);
	float n          = fbm(p + fbm(p)) * 0.5 + 0.5;
	float t          = clamp(dist * 2.2, 0.0, 1.0);
	vec4  couleur    = mix(couleur_coeur, couleur_bord, t);
	float alpha_corps = masque * n * intensite;

	// 8 blobs satellites orbitaux (miroir du visuel HTML)
	float blobs = 0.0;
	for (int i = 0; i < 8; i++) {
		float fi          = float(i);
		float base_angle  = fi / 8.0 * TAU;
		float angle       = base_angle + TIME * blob_vitesse_orbite + sin(TIME * 0.7 + fi) * 0.4;
		float orbit       = blob_rayon_orbite + sin(TIME * 2.3 + fi * 1.1) * 0.03;
		vec2  bpos        = vec2(cos(angle) * orbit, sin(angle) * orbit * 0.7);
		float bd          = length(centre - bpos);
		float bsize       = blob_taille + sin(TIME * 1.8 + fi * 0.9) * 0.02;
		blobs            += smoothstep(bsize, 0.0, bd) * 0.95;
	}
	blobs = clamp(blobs, 0.0, 1.5);

	// Halo extérieur très doux
	float halo = (1.0 - smoothstep(0.0, 0.5, dist)) * 0.18;

	// Point blanc brillant au centre
	float pinpoint = smoothstep(0.07, 0.0, dist);

	// Composition finale additive
	vec3  couleur_blob = mix(couleur_coeur.rgb, vec3(1.0, 0.35, 0.0), 0.6);
	vec3  rgb = couleur.rgb * alpha_corps
			  + couleur_blob * blobs
			  + couleur_bord.rgb * halo
			  + vec3(1.0) * pinpoint;
	float alpha = clamp(alpha_corps + blobs * 0.9 + halo + pinpoint, 0.0, 1.0);

	COLOR = vec4(rgb * alpha, alpha);
}
