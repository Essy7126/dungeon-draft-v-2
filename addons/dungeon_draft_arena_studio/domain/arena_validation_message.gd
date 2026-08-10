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
@export_multiline var why := ""


func to_dict() -> Dictionary:
	return {
		"title": human_title(),
		"category": category_name(),
		"severity": ["error", "warning", "info"][severity],
		"code": str(code),
		"message": message,
		"cell": null if cell == GridTransformService.INVALID_CELL else [cell.x, cell.y],
		"subject_id": str(subject_id),
		"suggested_fix": str(suggested_fix),
		"can_localize": cell != GridTransformService.INVALID_CELL,
		"can_fix": suggested_fix != &"",
		"why": why if not why.is_empty() else message,
		"technical_details": technical_details,
	}


func category_name() -> String:
	return [
		"ERREUR BLOQUANTE",
		"AVERTISSEMENT A VERIFIER",
		"INFORMATION",
	][severity]


func human_title() -> String:
	var value := str(code).replace("_", " ").capitalize()
	return value if not value.is_empty() else "Information"
