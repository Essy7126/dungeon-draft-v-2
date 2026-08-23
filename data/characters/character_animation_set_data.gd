@tool
# data/characters/character_animation_set_data.gd
# ============================================================
# FICHE D'ANIMATIONS — associe chaque événement d'un personnage
# (Repos, Marche, Course, Attaque ou sort, Dégât reçu, Mort...)
# au nom du clip à jouer dans son modèle 3D.
#
# S'édite depuis le Studio des personnages, écran « Animations ».
#
# Une entrée absente ou vide signifie « rien de choisi » : une surcharge
# conserve alors le clip de la fiche canonique du visuel.
# ============================================================

class_name CharacterAnimationSetData
extends Resource

const CAST_ACTION_PREFIX := "cast:"

# Identifiant d'événement → nom du clip.
# La clé reste une StringName libre plutôt qu'un enum fermé aux neuf
# événements actuels : une granularité plus fine (une animation par sort)
# pourra s'ajouter plus tard sans migrer les fiches existantes.
@export var animation_names: Dictionary = {}


## Construit l'identifiant stable d'une animation propre a un sort.
## Le mapping reste porte par le personnage : un meme sort peut donc utiliser
## des clips differents selon le modele qui le lance.
static func cast_action_id_for_spell_id(spell_id: StringName) -> StringName:
	var normalized_id := str(spell_id).strip_edges()
	if normalized_id.is_empty():
		return &""
	return StringName(CAST_ACTION_PREFIX + normalized_id)


static func is_cast_action_id(action_id: StringName) -> bool:
	var normalized_action := str(action_id)
	return normalized_action.begins_with(CAST_ACTION_PREFIX) \
		and normalized_action.length() > CAST_ACTION_PREFIX.length()


static func spell_id_from_cast_action_id(action_id: StringName) -> StringName:
	if not is_cast_action_id(action_id):
		return &""
	return StringName(str(action_id).trim_prefix(CAST_ACTION_PREFIX))


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
