shader_type canvas_item;

// ============================================================
// GOLDEN HOUR LIGHT — reproduit la lumiere du fond montagne sur les
// elements de gameplay (persos, grille) pour qu'ils se fondent dans le decor.
// Le fond peint n'est PAS touche : ce materiau s'applique aux CanvasItem de jeu.
//
// Principe : un gradient directionnel en espace ECRAN, projete sur la direction
// du soleil. Cote soleil = cle chaude (ambre) qui eclaircit ; cote oppose =
// ombre froide (bleu-mauve) qui assombrit. Plus une remontee chaude d'ambiance
// (golden hour : noirs leves) et un liseré (rim) dore sur les bords tournes
// vers le soleil (sprites a alpha uniquement).
//
// Tous les parametres sont pilotables depuis l'Inspecteur (materiau .tres) ou,
// pour du data-driven par instance, via set_shader_parameter() dans un script.
// ============================================================

// Direction VERS le soleil, en espace ecran (x+ = droite, y+ = bas).
// Le fond a un soleil haut-droite tres bas sur l'horizon -> (0.90, -0.35).
uniform vec2 sun_dir = vec2(0.90, -0.35);

uniform vec4 key_color : source_color = vec4(0.96, 0.80, 0.50, 1.0);    // ambre dore (cle)
uniform vec4 shadow_color : source_color = vec4(0.34, 0.38, 0.46, 1.0); // bleu-mauve froid (ombre)
uniform vec4 rim_color : source_color = vec4(1.00, 0.95, 0.80, 1.0);    // or clair (rim soleil)

uniform float grade_strength : hint_range(0.0, 1.0) = 0.45;   // force de la teinte directionnelle
uniform float shadow_darken : hint_range(0.0, 1.0) = 0.35;    // assombrissement du cote ombre
uniform float ambient_warmth : hint_range(0.0, 0.5) = 0.06;   // remontee chaude des noirs
uniform float rim_strength : hint_range(0.0, 2.0) = 0.80;     // intensite du liseré soleil
uniform float rim_width : hint_range(0.0, 0.2) = 0.04;        // largeur d'echantillonnage du rim
uniform float gradient_softness : hint_range(0.0, 1.0) = 0.80; // 0 = lineaire, 1 = tres doux
// Part du gradient "macro" (position ecran) vs "local" (UV du sprite). 0 = tout
// local -> chaque perso a un cote soleil/ombre net sur son corps (bien visible).
uniform float macro_weight : hint_range(0.0, 1.0) = 0.25;

// --- Nuages qui derivent : modulation lente de luminosite (ombres de nuages). ---
uniform float cloud_strength : hint_range(0.0, 0.5) = 0.10; // amplitude (leger)
uniform float cloud_speed = 0.015;                          // vitesse de derive
uniform float cloud_scale = 2.0;                            // taille des taches (petit = grandes taches)

// Bruit de valeur + FBM, calcules dans le shader (aucune texture externe).
float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float _vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = _hash(i);
	float b = _hash(i + vec2(1.0, 0.0));
	float c = _hash(i + vec2(0.0, 1.0));
	float d = _hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float _fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 3; k++) {
		v += amp * _vnoise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// COLOR en entree = texture(TEXTURE, UV) * modulate. Marche pour les sprites
	// (elf) ET pour les primitives dessinees (placeholders : TEXTURE = blanc).
	vec4 base = COLOR;
	if (base.a < 0.003) {
		discard;
	}

	vec2 sd = normalize(sun_dir);

	// Gradient LOCAL : projete l'UV du sprite sur l'axe soleil -> le haut-droite
	// du perso (cote soleil) est eclaire, le bas-gauche est en ombre. C'est ce
	// qui donne un vrai modele sur chaque perso.
	float local = dot(UV - vec2(0.5), sd) + 0.5;
	// Gradient MACRO : position a l'ecran (persos a droite plus chauds).
	float macro = dot(SCREEN_UV - vec2(0.5), sd) + 0.5;
	float along = clamp(mix(local, macro, macro_weight), 0.0, 1.0);
	float lit = mix(along, smoothstep(0.05, 0.95, along), gradient_softness);

	vec3 col = base.rgb;

	// Teinte directionnelle : ombre froide (lit=0) -> cle chaude (lit=1).
	// Facteur modere (x1.35) : rechauffe/refroidit SANS sur-eclairer les pixels
	// deja clairs (evite le "washout" sur l'elfe blanc).
	vec3 tint = mix(shadow_color.rgb, key_color.rgb, lit);
	col *= mix(vec3(1.0), tint * 1.35, grade_strength);

	// Assombrit franchement le cote ombre.
	col *= mix(1.0 - shadow_darken, 1.0, lit);

	// Ambiance golden hour : legere remontee chaude uniforme.
	col += key_color.rgb * ambient_warmth;

	// Nuages qui derivent : OMBRES qui passent. Elles ASSOMBRISSENT seulement
	// (jamais de sur-eclairage) -> plus de washout sur les persos clairs.
	vec2 cloud_uv = SCREEN_UV * cloud_scale + TIME * cloud_speed * vec2(1.0, 0.4);
	float cloud = max(0.0, _fbm(cloud_uv) - 0.35) * cloud_strength;
	col *= 1.0 - clamp(cloud, 0.0, 0.85);

	// Rim chaud sur le bord tourne vers le soleil (silhouette des sprites).
	// Pour les primitives (placeholders), TEXTURE est blanc -> pas de rim.
	float a_sun = texture(TEXTURE, UV + sd * rim_width).a;
	float edge = clamp(base.a - a_sun, 0.0, 1.0);
	col += rim_color.rgb * edge * rim_strength;

	// Clamp final : jamais au-dela du blanc -> aucun artefact de sur-exposition.
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), base.a);
}
