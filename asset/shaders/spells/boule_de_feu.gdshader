shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float vitesse : hint_range(0.0, 2.0) = 0.8;
uniform float echelle : hint_range(1.0, 10.0) = 4.0;
uniform vec4 couleur_coeur : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 couleur_bord  : source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform float intensite : hint_range(0.0, 3.0) = 1.2;

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
    for (int i = 0; i < 4; i++) {
        v += a * bruit_perlin(p);
        p = p * 2.0 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 centre = UV - vec2(0.5);
    float dist = length(centre);
    float masque = 1.0 - smoothstep(0.3, 0.5, dist);
    vec2 p = UV * echelle + vec2(TIME * vitesse, TIME * vitesse * 0.6);
    float n = fbm(p + fbm(p)) * 0.5 + 0.5;
    float t = clamp(dist * 2.2, 0.0, 1.0);
    vec4 couleur = mix(couleur_coeur, couleur_bord, t);
    float alpha = masque * n * intensite;
    COLOR = vec4(couleur.rgb * alpha, alpha);
}