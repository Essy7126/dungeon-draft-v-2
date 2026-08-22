@tool
# data/characters/character_animation_set_data.gd
# ============================================================
# FICHE D'ANIMATIONS — associe chaque événement d'un personnage
# (Repos, Marche, Course, Attaque ou sort, Dégât reçu, Mort...)
# au nom du clip à jouer dans son modèle 3D.
#
# S'édite depuis le Studio des personnages, écran « Animations ».
#
# Une entrée absente ou vide signifie « rien de choisi » : le
# personnage conserve alors le clip inscrit par défaut dans son
# script visuel. Une fiche vide ne change donc STRICTEMENT rien.
# ============================================================

class_name CharacterAnimationSetData
extends Resource

# Identifiant d'événement → nom du clip.
# La clé reste une StringName libre plutôt qu'un enum fermé aux neuf
# événements actuels : une granularité plus fine (une animation par sort)
# pourra s'ajouter plus tard sans migrer les fiches existantes.
@export var animation_names: Dictionary = {}


func get_animation_name(action_id: StringName) -> StringName:
	if action_id == &"":
		return &""
	var stored: Variant = animation_names.get(action_id, &"")
	if stored == null:
		return &""
	return StringName(stored)


func has_animation_name(action_id: StringName) -> bool:
	return get_animation_name(action_id) != &""


func set_animation_name(action_id: StringName, animation_name: StringName) -> void:
	animation_names = names_with(action_id, animation_name)


## Renvoie une copie du dictionnaire portant la modification demandee.
## Le Studio a besoin d'une valeur neuve pour son historique d'annulation :
## muter le dictionnaire en place rendrait l'etat precedent irrecuperable.
func names_with(action_id: StringName, animation_name: StringName) -> Dictionary:
	var result := animation_names.duplicate(true)
	if action_id == &"":
		return result
	if animation_name == &"":
		result.erase(action_id)
		return result
	result[action_id] = animation_name
	return result


func configured_action_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in animation_names:
		var action_id := StringName(key)
		if get_animation_name(action_id) != &"":
			result.append(action_id)
	return result


func is_empty() -> bool:
	return configured_action_ids().is_empty()
