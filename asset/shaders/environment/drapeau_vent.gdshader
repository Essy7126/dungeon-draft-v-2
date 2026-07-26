shader_type canvas_item;

// Deforme uniquement la zone du tissu (pas la hampe) en decalant l'UV
// horizontalement selon une onde sinusoidale. zone_haut/zone_milieu font
// monter l'effet a travers le drapeau, zone_bas/zone_hampe le font
// redescendre a zero avant la hampe en bois, qui doit rester rigide.

// A quel point le tissu part sur les cotes. Plus c'est grand, plus le
// drapeau gonfle fort dans le vent. A 0, il ne bouge pas du tout.
uniform float amplitude : hint_range(0.0, 0.1) = 0.02;

// Le nombre de "vagues" sur la hauteur du drapeau en meme temps. Plus
// c'est grand, plus il y a de petits plis rapproches (comme une banniere
// qui ondule beaucoup) ; plus c'est petit, plus le tissu fait une seule
// grande vague lente.
uniform float frequence : hint_range(1.0, 20.0) = 6.0;

// A quelle vitesse les vagues avancent dans le temps. Plus c'est grand,
// plus le vent a l'air fort et rapide ; a 0, le drapeau est fige.
uniform float vitesse : hint_range(0.0, 5.0) = 2.0;

// La hauteur (0 = tout en haut de l'image, 1 = tout en bas) a partir
// de laquelle le tissu commence a peine a bouger. En dessous de cette
// ligne, c'est encore le bois : ca ne doit pas onduler.
uniform float zone_haut : hint_range(0.0, 1.0) = 0.08;

// La hauteur a partir de laquelle le tissu bouge a fond. Entre
// zone_haut et zone_milieu, le mouvement monte petit a petit (il
// n'apparait pas d'un coup).
uniform float zone_milieu : hint_range(0.0, 1.0) = 0.3;

// La hauteur a partir de laquelle le tissu commence a arreter de
// bouger a fond (le bas du drapeau, avant que ca redevienne du bois).
uniform float zone_bas : hint_range(0.0, 1.0) = 0.5;

// La hauteur a partir de laquelle le mouvement est totalement coupe.
// En dessous, c'est le baton en bois : il doit rester parfaitement
// immobile, meme si le tissu au-dessus bouge beaucoup.
uniform float zone_hampe : hint_range(0.0, 1.0) = 0.58;

void fragment() {
	float montee = smoothstep(zone_haut, zone_milieu, UV.y);
	float descente = 1.0 - smoothstep(zone_bas, zone_hampe, UV.y);
	float poids = clamp(montee * descente, 0.0, 1.0);
	float vague = sin(UV.y * frequence + TIME * vitesse) * amplitude * poids;
	vec2 uv_deformee = vec2(UV.x + vague, UV.y);
	COLOR = texture(TEXTURE, uv_deformee);
}
