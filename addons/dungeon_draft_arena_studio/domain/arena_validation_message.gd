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
@export var blocks_integration := false
@export var acknowledged := false
@export var auto_fix_available := false


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
		"blocks_integration": blocks_integration,
		"acknowledged": acknowledged,
		"auto_fix_available": auto_fix_available,
		"why": why if not why.is_empty() else message,
		"technical_details": technical_details,
	}


func category_name() -> String:
	if blocks_integration:
		return "ERREUR BLOQUANTE"
	return ["ERREUR", "AVERTISSEMENT A VERIFIER", "INFORMATION"][severity]


func human_title() -> String:
	var value := str(code).replace("_", " ").capitalize()
	return value if not value.is_empty() else "Information"
