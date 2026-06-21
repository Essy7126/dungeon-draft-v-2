shader_type canvas_item;

uniform float vitesse : hint_range(0.0, 1.0) = 0.02;
uniform float intensite : hint_range(0.0, 2.0) = 0.8;
uniform float nombre_rayons : hint_range(1.0, 20.0) = 3.0;
uniform float angle : hint_range(-1.0, 1.0) = 0.3;
uniform vec4 couleur_rayon : source_color = vec4(1.0, 0.9, 0.6, 1.0);

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	uv.x += uv.y * angle;
	uv.x += TIME * vitesse;

	float x = uv.x * nombre_rayons;
	float rayons = fract(x);
	rayons = smoothstep(0.0, 0.4, rayons) * smoothstep(1.0, 0.4, rayons);

	float variation = 0.75 + 0.25 * hash(floor(x));
	float pulsation = 0.6 + 0.4 * sin(TIME * 0.3 + hash(floor(x)) * 6.28);
	rayons *= variation * pulsation;

	float fondu_haut = 1.0 - UV.y;
	fondu_haut = pow(fondu_haut, 0.8);
	float alpha = rayons * fondu_haut * intensite;
	COLOR = vec4(couleur_rayon.rgb, alpha);
}