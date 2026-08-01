@tool
extends Sprite2D

## Drapeau iso : vent (shader) + maintien VERTICAL sur une couche inclinee.
##
## Probleme resolu : la couche decor recopie la grille du terrain, skew compris.
## Une tuile posee dessus penche donc comme le sol. Un drapeau, lui, doit rester
## DEBOUT : seul son pied (le bas du mat) est plante sur la case ; le tissu monte
## droit. On annule ici le cisaillement/la rotation herites de la couche parente,
## tout en gardant la position que la couche a calculee (le pied reste sur le bon
## losange). Optionnellement on ecrase un peu l'axe vertical pour coller a la
## perspective (perspective_scale_y).

## --- Vent (parametres du shader asset/shaders/environment/drapeau_vent.gdshader) ---

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

## --- Maintien vertical ---

## Garder le drapeau debout meme si la couche est inclinee (skew du terrain).
## A desactiver seulement si tu veux qu'il se couche avec le sol.
@export var rester_vertical := true

## Ecrase (ou etire) la hauteur du drapeau pour coller a la perspective du sol.
## 1.0 = drapeau plein debout ; < 1.0 = un peu tasse comme vu de trois-quarts.
@export var perspective_scale_y: float = 1.0:
	set(value):
		perspective_scale_y = value
		if is_inside_tree():
			_apply_upright()

var _base_scale := Vector2.ONE


func _ready() -> void:
	# On memorise l'echelle voulue du drapeau AVANT de retoucher la transform,
	# pour la reprojeter droite ensuite.
	_base_scale = scale
	# Le vent : en editeur on laisse les valeurs de la scene ; en jeu on applique
	# les exports (source de verite a l'execution).
	if not Engine.is_editor_hint():
		_apply_shader_params()
	# Recalage vertical en continu : suit les changements de la couche parente
	# (donc du terrain) aussi bien en editeur qu'en jeu.
	set_process(rester_vertical)
	_apply_upright()


func _process(_delta: float) -> void:
	if rester_vertical:
		_apply_upright()


func _apply_shader_params() -> void:
	if material == null:
		return
	material.set_shader_parameter("amplitude", amplitude)
	material.set_shader_parameter("frequence", frequence)
	material.set_shader_parameter("vitesse", vitesse)
	material.set_shader_parameter("zone_haut", zone_haut)
	material.set_shader_parameter("zone_milieu", zone_milieu)
	material.set_shader_parameter("zone_bas", zone_bas)
	material.set_shader_parameter("zone_hampe", zone_hampe)


## Reprojette le drapeau droit : le pied reste sur la case (position inchangee),
## mais son orientation ecran est forcee verticale, en annulant le cisaillement
## et la rotation herites de la couche parente.
func _apply_upright() -> void:
	if not rester_vertical:
		return
	# Orientation ecran voulue : axes bien horizontaux/verticaux, a l'echelle
	# d'origine du drapeau (avec l'ecrasement de perspective optionnel).
	var desired := Transform2D(
		Vector2(_base_scale.x, 0.0),
		Vector2(0.0, _base_scale.y * perspective_scale_y),
		Vector2.ZERO
	)
	# Partie lineaire (sans translation) de la couche parente.
	var parent_basis := Transform2D.IDENTITY
	var parent := get_parent()
	if parent is Node2D:
		var g: Transform2D = (parent as Node2D).global_transform
		parent_basis = Transform2D(g.x, g.y, Vector2.ZERO)
	# On cherche la transform locale telle que (parent * locale) soit droite.
	var local_basis := parent_basis.affine_inverse() * desired
	# On garde la position calculee par la couche (le pied sur le losange).
	transform = Transform2D(local_basis.x, local_basis.y, position)
