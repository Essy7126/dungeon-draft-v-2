@tool
class_name ArenaObjectiveDefinition
extends Resource

@export var objective_id: StringName = &"objective"
@export var cell := Vector2i.ZERO
@export var objective_type: StringName = &"reach"
@export var required := true
@export_multiline var description := ""


func to_dict() -> Dictionary:
	return {
		"objective_id": str(objective_id),
		"cell": [cell.x, cell.y],
		"objective_type": str(objective_type),
		"required": required,
		"description": description,
	}


static func from_dict(data: Dictionary) -> ArenaObjectiveDefinition:
	var value := ArenaObjectiveDefinition.new()
	value.objective_id = StringName(data.get("objective_id", "objective"))
	value.cell = ArenaDefinition._vector2i(data.get("cell", [0, 0]))
	value.objective_type = StringName(data.get("objective_type", "reach"))
	value.required = bool(data.get("required", true))
	value.description = str(data.get("description", ""))
	return value
