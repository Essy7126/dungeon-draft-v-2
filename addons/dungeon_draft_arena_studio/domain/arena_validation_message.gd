@tool
class_name ArenaValidationMessage
extends Resource

enum Severity {
	ERROR,
	WARNING,
	INFO,
}

@export var severity: int = Severity.INFO
@export var code: StringName = &"information"
@export var message := ""
@export var cell := GridTransformService.INVALID_CELL
@export var subject_id: StringName = &""
@export var suggested_fix: StringName = &""
@export_multiline var technical_details := ""


func to_dict() -> Dictionary:
	return {
		"severity": ["error", "warning", "info"][severity],
		"code": str(code),
		"message": message,
		"cell": null if cell == GridTransformService.INVALID_CELL else [cell.x, cell.y],
		"subject_id": str(subject_id),
		"suggested_fix": str(suggested_fix),
		"technical_details": technical_details,
	}
