extends Node2D

## Ombre de contact au sol qui epouse la case skewee (perspective).
## Le personnage reste DROIT (billboard) ; seule cette ombre suit l'inclinaison
## de la grille, ce qui ancre visuellement l'unite dans sa case.
##
## Le polygone recu est deja exprime dans le repere local de l'UnitView, donc
## il suit l'unite quand elle se deplace, sans recalcul (toutes les cases
## partagent la meme forme skewee, a une translation pres).

const SHADOW_COLOR := Color(0.03, 0.045, 0.05, 0.42)

var _polygon: PackedVector2Array = PackedVector2Array()


func setup(footprint_local: PackedVector2Array) -> void:
	name = "IsoGroundShadow"
	add_to_group("iso_ground_shadow")
	_polygon = footprint_local
	z_index = -1
	queue_redraw()


## Contour de la case (repere local de l'UnitView), pour que d'autres visuels
## (ex : surbrillance d'unite active) collent exactement a la meme case skewee.
func get_footprint() -> PackedVector2Array:
	return _polygon


func _draw() -> void:
	if _polygon.size() >= 3:
		draw_colored_polygon(_polygon, SHADOW_COLOR)
