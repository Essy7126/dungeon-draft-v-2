shader_type canvas_item;

uniform float vitesse : hint_range(0.0, 0.5) = 0.06;
uniform float intensite : hint_range(0.0, 1.0) = 0.75;
uniform float nombre_rayons : hint_range(1.0, 20.0) = 8.0;
uniform float angle : hint_range(0.0, 1.0) = 0.25;
uniform vec4 couleur_rayon : source_color = vec4(1.0, 0.95, 0.75, 1.0);

void fragment() {
	vec2 uv = UV;
	uv.x += uv.y * angle;

	// Couche 1 - grands rayons lents
	float x1 = uv.x * nombre_rayons + TIME * vitesse;
	float rayon1 = sin(x1 * 3.14159) * sin(x1 * 1.7 + 0.5) * sin(x1 * 2.3 + 1.2);
	rayon1 = clamp(rayon1, 0.0, 1.0);
	rayon1 = pow(rayon1, 0.6);

	// Couche 2 - petits rayons plus rapides
	float x2 = uv.x * nombre_rayons * 1.8 + TIME * vitesse * 1.5 + 2.1;
	float rayon2 = sin(x2 * 3.14159) * sin(x2 * 2.1 + 1.0) * sin(x2 * 1.4 + 0.7);
	rayon2 = clamp(rayon2, 0.0, 1.0);
	rayon2 = pow(rayon2, 0.8);

	float rayons = rayon1 * 0.7 + rayon2 * 0.3;

	// Gradient vertical — fort en haut, disparaît vers le bas
	float gradient = pow(1.0 - UV.y, 1.2);

	// Halo lumineux en haut au centre
	float halo = exp(-pow((UV.x - 0.5) * 3.0, 2.0)) * 0.4;
	halo *= exp(-UV.y * 4.0);

	// Pulsation organique
	float pulsation = 1.0 + 0.12 * sin(TIME * 0.4) + 0.06 * sin(TIME * 1.1);

	float alpha = (rayons * gradient + halo) * intensite * pulsation;
	COLOR = vec4(couleur_rayon.rgb, clamp(alpha, 0.0, 1.0));
}