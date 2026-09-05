@tool
class_name CombatActionClassificationData
extends Resource

enum Classification {
	MELEE,
	PROJECTILE,
	AREA,
	SELF,
	MOVEMENT,
}

## Cette classification est une donnee explicite. Aucun runtime ne doit la
## deduire du nom, de l'icone ou de l'animation du sort.
@export var ability_id: StringName = &""
@export var classification: Classification = Classification.MELEE


func is_valid() -> bool:
	return ability_id != &""


func classification_id() -> StringName:
	match classification:
		Classification.MELEE:
			return &"MELEE"
		Classification.PROJECTILE:
			return &"PROJECTILE"
		Classification.AREA:
			return &"AREA"
		Classification.SELF:
			return &"SELF"
		Classification.MOVEMENT:
			return &"MOVEMENT"
	return &"MELEE"
