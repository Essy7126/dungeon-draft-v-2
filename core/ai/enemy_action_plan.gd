class_name EnemyActionPlan
extends RefCounted

const MAX_STEPS := 4

var target_unit: Unit = null
var selected_ability: Spell = null
var movement_before_cast: Array = []
var cast_position := Vector2i(-1, -1)
var movement_after_cast: Array = []
var fallback_action: Dictionary = {}
var actions: Array[Dictionary] = []


func append_action(action: Dictionary) -> bool:
	if action.is_empty() or actions.size() >= MAX_STEPS:
		return false
	actions.append(action)
	match StringName(action.get("type", &"")):
		&"move":
			if selected_ability == null:
				movement_before_cast = action.get("path", []).duplicate()
			else:
				movement_after_cast = action.get("path", []).duplicate()
		&"cast":
			selected_ability = action.get("spell") as Spell
			cast_position = action.get("cell", Vector2i(-1, -1))
		&"attack":
			target_unit = action.get("target") as Unit
	return true


func to_actions() -> Array[Dictionary]:
	return actions.duplicate(true)
