extends Sprite2D

## Parametres exposes du shader de vent (asset/shaders/environment/drapeau_vent.gdshader).
## Modifiables par instance depuis l'Inspecteur, sans dupliquer le shader.

## A quel point le tissu part sur les cotes. Plus c'est grand, plus le
## drapeau gonfle fort dans le vent. A 0, il ne bouge pas du tout.
@export var amplitude: float = 0.02

## Le nombre de "vagues" sur la hauteur du drapeau en meme temps. Plus
## c'est grand, plus il y a de petits plis rapproches ; plus c'est petit,
## plus le tissu fait une seule grande vague lente.
@export var frequence: float = 6.0

## A quelle vitesse les vagues avancent dans le temps. Plus c'est grand,
## plus le vent a l'air fort et rapide ; a 0, le drapeau est fige.
@export var vitesse: float = 3.2

## La hauteur (0 = tout en haut de l'image, 1 = tout en bas) a partir de
## laquelle le tissu commence a peine a bouger. En dessous, c'est encore
## le bois : ca ne doit pas onduler.
@export var zone_haut: float = 0.129

## La hauteur a partir de laquelle le tissu bouge a fond. Entre zone_haut
## et zone_milieu, le mouvement monte petit a petit.
@export var zone_milieu: float = 0.258

## La hauteur a partir de laquelle le tissu commence a arreter de bouger
## a fond (le bas du drapeau, avant que ca redevienne du bois).
@export var zone_bas: float = 0.581

## La hauteur a partir de laquelle le mouvement est totalement coupe. En
## dessous, c'est le baton en bois : il doit rester parfaitement immobile.
@export var zone_hampe: float = 0.603

func _ready() -> void:
	if material == null:
		return
	material.set_shader_parameter("amplitude", amplitude)
	material.set_shader_parameter("frequence", frequence)
	material.set_shader_parameter("vitesse", vitesse)
	material.set_shader_parameter("zone_haut", zone_haut)
	material.set_shader_parameter("zone_milieu", zone_milieu)
	material.set_shader_parameter("zone_bas", zone_bas)
	material.set_shader_parameter("zone_hampe", zone_hampe)
