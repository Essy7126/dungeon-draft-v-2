@tool
class_name GoldenHourLight
extends Node

## Pilote (data-driven) le materiau lumiere golden hour applique aux persos et a
## la grille. Chaque parametre est expose ET DOCUMENTE ici : il apparait donc
## avec sa description dans l'Inspecteur, et est pousse vers le materiau via
## set_shader_parameter(). Le .tres ne contient que la reference au shader ;
## aucune valeur n'est reglee en dur dedans.

## Le materiau lumiere a piloter (res://battle/iso/golden_hour_light.tres).
@export var light_material: ShaderMaterial:
	set(value):
		light_material = value
		_apply()

@export_group("Soleil & couleurs")
## Direction VERS le soleil, en espace ecran (x+ = droite, y+ = bas).
@export var sun_dir := Vector2(0.9, -0.35):
	set(value): sun_dir = value; _apply()
## Couleur chaude de la lumiere principale (cle) — ambre dore.
@export var key_color := Color(0.96, 0.8, 0.5):
	set(value): key_color = value; _apply()
## Couleur froide du cote a l'ombre — bleu-mauve desature.
@export var shadow_color := Color(0.34, 0.38, 0.46):
	set(value): shadow_color = value; _apply()
## Couleur du lisere (rim) sur le bord tourne vers le soleil — or clair.
@export var rim_color := Color(1.0, 0.95, 0.8):
	set(value): rim_color = value; _apply()

@export_group("Modele")
## Force de la coloration directionnelle (0 = aucune, 1 = tres marquee).
@export_range(0.0, 1.0) var grade_strength := 0.6:
	set(value): grade_strength = value; _apply()
## Assombrissement du cote a l'ombre.
@export_range(0.0, 1.0) var shadow_darken := 0.35:
	set(value): shadow_darken = value; _apply()
## Remontee chaude d'ambiance (noirs leves, golden hour).
@export_range(0.0, 0.5) var ambient_warmth := 0.08:
	set(value): ambient_warmth = value; _apply()
## Douceur du degrade (0 = lineaire, 1 = tres doux).
@export_range(0.0, 1.0) var gradient_softness := 0.8:
	set(value): gradient_softness = value; _apply()
## Part du degrade base sur la position ecran (vs UV du sprite). Plus haut =
## marche aussi sur les placeholders (primitives sans UV) : leur teinte suit
## alors leur position dans la scene (droite chaude / gauche froide).
@export_range(0.0, 1.0) var macro_weight := 0.55:
	set(value): macro_weight = value; _apply()

@export_group("Rim (lisere soleil)")
## Intensite du lisere dore sur les silhouettes.
@export_range(0.0, 2.0) var rim_strength := 0.6:
	set(value): rim_strength = value; _apply()
## Largeur d'echantillonnage du lisere.
@export_range(0.0, 0.2) var rim_width := 0.05:
	set(value): rim_width = value; _apply()

@export_group("Nuages qui derivent")
## Amplitude des ombres de nuages (0 = fige). Monte-la pour un passage marque.
@export_range(0.0, 1.0) var cloud_strength := 0.45:
	set(value): cloud_strength = value; _apply()
## Vitesse de derive des nuages.
@export var cloud_speed := 0.4:
	set(value): cloud_speed = value; _apply()
## Taille des taches de nuage (petit = grandes nappes, grand = petites taches).
@export var cloud_scale := 0.7:
	set(value): cloud_scale = value; _apply()


func _ready() -> void:
	_apply()


## Pousse tous les parametres documentes vers le materiau.
func _apply() -> void:
	if light_material == null:
		return
	light_material.set_shader_parameter("sun_dir", sun_dir)
	light_material.set_shader_parameter("key_color", key_color)
	light_material.set_shader_parameter("shadow_color", shadow_color)
	light_material.set_shader_parameter("rim_color", rim_color)
	light_material.set_shader_parameter("grade_strength", grade_strength)
	light_material.set_shader_parameter("shadow_darken", shadow_darken)
	light_material.set_shader_parameter("ambient_warmth", ambient_warmth)
	light_material.set_shader_parameter("gradient_softness", gradient_softness)
	light_material.set_shader_parameter("macro_weight", macro_weight)
	light_material.set_shader_parameter("rim_strength", rim_strength)
	light_material.set_shader_parameter("rim_width", rim_width)
	light_material.set_shader_parameter("cloud_strength", cloud_strength)
	light_material.set_shader_parameter("cloud_speed", cloud_speed)
	light_material.set_shader_parameter("cloud_scale", cloud_scale)
