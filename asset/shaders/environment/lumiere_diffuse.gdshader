shader_type canvas_item;

uniform float angle = 20.0;
uniform float position : hint_range(-1.0, 1.0) = 0.0;
uniform float spread : hint_range(0.0, 1.0) = 0.95;
uniform float cutoff : hint_range(-1.0, 1.0) = 0.05;
uniform float height : hint_range(0.0, 1.0) = 0.4;
uniform float falloff : hint_range(0.0, 1.0) = 0.18;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.3;
uniform float speed = 0.15;
uniform float ray_density = 3.0;
uniform float diffusion : hint_range(0.0, 1.0) = 0.5;
uniform float intensity : hint_range(0.0, 4.0) = 2.2;
uniform vec4 color : source_color = vec4(1.0, 0.93, 0.78, 0.4);
uniform bool hdr = false;
uniform float seed = 5.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float random(vec2 _uv) {
	_uv += min(TIME, 0.0);
	return fract(sin(dot(_uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(in vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = random(i);
	float b = random(i + vec2(1.0, 0.0));
	float c = random(i + vec2(0.0, 1.0));
	float d = random(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

mat2 rotate(float _angle) {
	_angle = radians(_angle);
	return mat2(vec2(cos(_angle), -sin(_angle)), vec2(sin(_angle), cos(_angle)));
}

vec4 screen(vec4 base, vec4 blend) {
	return 1.0 - (1.0 - base) * (1.0 - blend);
}

// Etale plusieurs echantillons du bruit sur un rayon horizontal pour lisser
// les faisceaux en une nappe de lumiere douce plutot que des raies nettes.
const int DIFFUSION_SAMPLES = 6;

float diffused_rays(vec2 transformed_uv, float cut) {
	float rays = 0.0;
	for (int i = 0; i < DIFFUSION_SAMPLES; i++) {
		float t = (float(i) / float(DIFFUSION_SAMPLES - 1)) - 0.5;
		float blur_offset = t * diffusion * 0.35;
		vec2 ray = vec2((transformed_uv.x + blur_offset) * ray_density + sin(TIME * speed) * (ray_density * 0.1) + seed, 1.0);
		rays += noise(ray);
	}
	rays /= float(DIFFUSION_SAMPLES);
	rays *= cut;
	if (!hdr) {
		rays = clamp(rays, 0.0, 1.0);
	}
	return rays;
}

void fragment() {
	vec2 transformed_uv = (rotate(angle) * (UV - position)) / ((UV.y + spread) - (UV.y * spread));

	float cut = step(cutoff, transformed_uv.x) * step(cutoff, 1.0 - transformed_uv.x);
	float rays = diffused_rays(transformed_uv, cut);

	// Adoucit le contraste sans remonter le plancher : le degrade doit
	// retomber a 0 loin de la source, sinon toute la scene se teinte en gris.
	rays = smoothstep(0.0, 1.0, rays);

	// Masque vertical strict : la lumiere n'existe que dans la bande du haut
	// de l'ecran (ciel / montagnes en arriere-plan) et retombe a 0 avant le
	// sol jouable, au lieu de couvrir tout l'ecran.
	float vertical_mask = 1.0 - smoothstep(height - falloff, height + falloff, UV.y);
	rays *= vertical_mask;

	rays *= smoothstep(0.0 + cutoff, edge_fade + cutoff, transformed_uv.x);
	rays *= smoothstep(0.0 + cutoff, edge_fade + cutoff, 1.0 - transformed_uv.x);

	rays *= intensity;

	vec3 shine = screen(texture(SCREEN_TEXTURE, SCREEN_UV), vec4(color)).rgb;

	COLOR = vec4(shine, clamp(rays * color.a, 0.0, 1.0));
}
