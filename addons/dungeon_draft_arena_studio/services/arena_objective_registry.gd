@tool
class_name ArenaObjectiveRegistry
extends RefCounted

## Types actuellement reconnus par l'editeur. Leur execution future reste
## explicite dans la couverture runtime ; une valeur libre inconnue est bloquee.
const ENTRIES := {
	&"reach": {
		"display_name": "Atteindre une cellule",
		"runtime_status": "FUTURE_EXPLICIT",
	},
}


static func has(objective_type: StringName) -> bool:
	return ENTRIES.has(objective_type)


static func get_entry(objective_type: StringName) -> Dictionary:
	return (ENTRIES.get(objective_type, {}) as Dictionary).duplicate(true)


static func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(ENTRIES.keys())
	result.sort()
	return result
