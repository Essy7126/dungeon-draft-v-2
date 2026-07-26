shader_type canvas_item;

uniform float vitesse : hint_range(0.0, 1.0) = 0.03;
uniform float echelle : hint_range(0.001, 0.05) = 0.006;
uniform float etirement_vertical : hint_range(1.0, 8.0) = 3.0;
uniform float densite : hint_range(0.0, 2.0) = 1.0;
uniform float seuil_bas : hint_range(0.0, 1.0) = 0.2;
uniform float seuil_haut : hint_range(0.0, 1.0) = 0.75;
uniform float position_masque : hint_range(0.0, 1.0) = 0.45;
uniform float douceur_masque : hint_range(0.05, 1.0) = 0.4;
uniform vec4 couleur_fumee : source_color = vec4(0.96, 0.94, 0.87, 1.0);
uniform vec4 couleur_ombre : source_color = vec4(0.78, 0.75, 0.68, 1.0);
uniform float respiration_vitesse : hint_range(0.0, 2.0) = 0.2;
uniform float respiration_amplitude : hint_range(0.0, 1.0) = 0.08;

// Bornes verticales du polygone (en espace local), calculees et injectees
// par brume_vallee.gd a partir de son propre tableau `polygon` : la zone de
// brume reste toujours correcte, meme si les points sont retouches a la main.
uniform float zone_haut = 0.0;
uniform float zone_bas = 100.0;

varying vec2 position_locale;

void vertex() {
	position_locale = VERTEX;
}

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
	// Bruit etire verticalement (etirement_vertical) pour des volutes hautes
	// et fines plutot que des blobs ronds, avec une derive qui monte
	// legerement en plus de deriver sur le cote (vent + convection).
	vec2 base = FRAGCOORD.xy * echelle;
	vec2 p = vec2(base.x, base.y / etirement_vertical) + vec2(TIME * vitesse, -TIME * vitesse * 0.4);
	float n = fbm(p + fbm(p + fbm(p)));
	float n_normalise = clamp(n * 0.5 + 0.5, 0.0, 1.0);

	// Seuillage doux : cree de vrais trous entre les volutes plutot qu'un
	// voile uniforme (la brume n'est jamais un aplat).
	float texture = smoothstep(seuil_bas, seuil_haut, n_normalise);

	// Masque vertical base sur la position reelle dans le polygone (VERTEX),
	// jamais sur l'UV auto-genere : dense pres du sol de la poche, se dissipe
	// vers le haut. Un bruit basse frequence rend le bord du banc de brume
	// irregulier plutot qu'une ligne droite.
	float hauteur = clamp((position_locale.y - zone_haut) / max(zone_bas - zone_haut, 1.0), 0.0, 1.0);
	float bruit_bord = fbm(base * 0.3 + vec2(0.0, TIME * vitesse * 0.2)) * 0.5 + 0.5;
	float hauteur_irreguliere = hauteur + (bruit_bord - 0.5) * 0.35;
	float masque_vertical = smoothstep(position_masque - douceur_masque, position_masque + douceur_masque, hauteur_irreguliere);

	float respiration = 1.0 + sin(TIME * respiration_vitesse) * respiration_amplitude;
	float alpha = clamp(texture * masque_vertical * densite * respiration, 0.0, 1.0);

	vec3 couleur = mix(couleur_ombre.rgb, couleur_fumee.rgb, n_normalise);
	COLOR = vec4(couleur, alpha);
}
