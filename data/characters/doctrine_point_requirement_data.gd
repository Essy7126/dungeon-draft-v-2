@tool
class_name DoctrinePointRequirementData
extends Resource

@export var tree_id: StringName = &""
@export_range(1, 99, 1) var minimum_points: int = 1


func is_valid() -> bool:
	return tree_id != &"" and minimum_points > 0
