shader_type canvas_item;

// Brume atmospherique "vivante" : les volutes se DEFORMENT sur place au lieu de
// glisser en bloc (domain warping anime). Pensee pour un effet de tableau vivant
// dans une poche de vallee/gorge : dense en bas, presente mais legere en haut,
// mouvement lent et organique. Data-driven : tous les uniforms sont pilotes par
// brume_vivante.gd via @export.

// --- Forme / echelle ---
uniform float echelle : hint_range(0.001, 0.02) = 0.004;
uniform float etirement_vertical : hint_range(0.5, 6.0) = 1.6;
// Force du "domain warping" : a quel point les volutes se tordent. 0 = bruit
// lisse et sage ; grand = formes torturees, tres nuageuses.
uniform float turbulence : hint_range(0.0, 4.0) = 2.0;

// --- Mouvement (la vie) ---
// Vitesse a laquelle les formes se DEFORMENT (morphing sur place).
uniform float vitesse : hint_range(0.0, 1.0) = 0.06;
// Derive laterale, comme un vent doux (negatif = vers la gauche).
uniform float derive : hint_range(-1.0, 1.0) = 0.04;
// Convection : la brume monte lentement des gorges (positif = vers le haut).
uniform float montee : hint_range(-1.0, 1.0) = 0.12;
// Respiration globale : la brume s'epaissit/s'affine en boucle lente.
uniform float respiration_vitesse : hint_range(0.0, 2.0) = 0.25;
uniform float respiration_amplitude : hint_range(0.0, 1.0) = 0.1;

// --- Densite / degrade vertical ---
uniform float densite : hint_range(0.0, 2.0) = 1.0;
uniform float seuil_bas : hint_range(0.0, 1.0) = 0.15;
uniform float seuil_haut : hint_range(0.0, 1.0) = 0.9;
// Quantite minimale de brume EN HAUT de la zone (0 = rien en haut, 1 = autant
// qu'en bas). C'est le reglage qui garantit "visible partout".
uniform float plancher_haut : hint_range(0.0, 1.0) = 0.4;
// Courbe du degrade bas(dense) -> haut(leger). 1 = lineaire ; >1 = le dense
// reste concentre plus bas ; <1 = ca remonte vite.
uniform float degrade : hint_range(0.2, 4.0) = 1.5;

// --- Couleurs ---
uniform vec4 couleur_fumee : source_color = vec4(0.90, 0.85, 0.75, 1.0);
uniform vec4 couleur_ombre : source_color = vec4(0.66, 0.66, 0.68, 1.0);

// Bornes verticales du polygone (espace local), injectees par brume_vivante.gd
// a partir de son propre tableau `polygon` : le degrade reste correct meme si
// tu deplaces les points de la zone.
uniform float zone_haut = 0.0;
uniform float zone_bas = 100.0;

// --- Fondu de bord ---
// Contour du polygone (espace local) injecte par le script, pour effacer les
// bords : l'alpha tombe a 0 en approchant du contour, quelle que soit la forme.
const int MAX_BORDS = 256;
uniform vec2 bords[MAX_BORDS];
uniform int nb_bords = 0;
// Largeur du fondu de bord, en pixels locaux. 0 = bord net (polygone visible) ;
// grand = brume qui se dissout tres progressivement vers le contour.
uniform float marge_bord : hint_range(0.0, 300.0) = 60.0;

varying vec2 position_locale;

void vertex() {
	position_locale = VERTEX;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(hash2(i), f),
			dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * bruit(p);
		p = p * 2.0 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Distance d'un point p au segment [a, b].
float dist_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float t = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return length(pa - ba * t);
}

// Fondu de bord : 1 loin du contour, tombe a 0 sur la largeur marge_bord en
// approchant du bord le plus proche du polygone. Tous les fragments dessines
// sont a l'interieur du polygone, donc pas besoin de test dedans/dehors.
float fondu_bord(vec2 p) {
	if (nb_bords < 3 || marge_bord <= 0.0) {
		return 1.0;
	}
	float d = 100000.0;
	for (int i = 0; i < nb_bords; i++) {
		vec2 a = bords[i];
		vec2 b = bords[(i + 1) % nb_bords];
		d = min(d, dist_segment(p, a, b));
	}
	return smoothstep(0.0, marge_bord, d);
}

void fragment() {
	float t = TIME * vitesse;
	vec2 base = FRAGCOORD.xy * echelle;
	base.y /= etirement_vertical;
	// Deplacement lent du champ : vent lateral + convection montante.
	base += vec2(derive, -montee) * TIME * 0.1;

	// Domain warping ANIME : on echantillonne le bruit a une position elle-meme
	// deformee par du bruit qui evolue dans le temps. Resultat : les volutes se
	// tordent et se recomposent sur place -> sensation de brume vivante, au lieu
	// d'une texture qui defile rigidement.
	vec2 q = vec2(fbm(base + t),
				  fbm(base + vec2(5.2, 1.3) - t));
	vec2 r = vec2(fbm(base + turbulence * q + vec2(1.7, 9.2) + 0.7 * t),
				  fbm(base + turbulence * q + vec2(8.3, 2.8) - 0.5 * t));
	float n = fbm(base + turbulence * r);
	float n01 = clamp(n * 0.5 + 0.5, 0.0, 1.0);

	// Seuillage doux : de vrais creux entre les volutes, jamais un aplat.
	float voile = smoothstep(seuil_bas, seuil_haut, n01);

	// Degrade vertical avec plancher : dense en bas, jamais nul en haut.
	float h = clamp((position_locale.y - zone_haut) / max(zone_bas - zone_haut, 1.0), 0.0, 1.0);
	float gradient = mix(plancher_haut, 1.0, pow(h, degrade));

	float respiration = 1.0 + sin(TIME * respiration_vitesse) * respiration_amplitude;
	float alpha = clamp(voile * gradient * densite * respiration, 0.0, 1.0);

	// Efface le contour du polygone : la brume se dissout vers les bords.
	alpha *= fondu_bord(position_locale);

	// La couleur va de l'ombre (creux) a la fumee eclairee (crete dense).
	vec3 couleur = mix(couleur_ombre.rgb, couleur_fumee.rgb, n01);
	COLOR = vec4(couleur, alpha);
}
