@tool
class_name ArenaValidationReport
extends Resource

@export var arena_id: StringName = &""
@export var generated_at := ""
@export var messages: Array[ArenaValidationMessage] = []
@export var metrics := {}


func add_message(
		severity: int,
		code: StringName,
		message: String,
		cell: Vector2i = GridTransformService.INVALID_CELL,
		suggested_fix: StringName = &"",
		technical_details := ""
	) -> ArenaValidationMessage:
	var entry := ArenaValidationMessage.new()
	entry.severity = severity
	entry.code = code
	entry.message = message
	entry.cell = cell
	entry.suggested_fix = suggested_fix
	entry.technical_details = technical_details
	messages.append(entry)
	return entry


func error_count() -> int:
	return messages.filter(func(entry):
		return entry.severity == ArenaValidationMessage.Severity.ERROR
	).size()


func warning_count() -> int:
	return messages.filter(func(entry):
		return entry.severity == ArenaValidationMessage.Severity.WARNING
	).size()


func info_count() -> int:
	return messages.filter(func(entry):
		return entry.severity == ArenaValidationMessage.Severity.INFO
	).size()


func is_valid() -> bool:
	return error_count() == 0


func verdict() -> String:
	if not is_valid():
		return "ARENE INVALIDE — %d ERREUR(S) BLOQUANTE(S)" % error_count()
	return "ARENE VALIDE — %d POINT(S) A VERIFIER" % warning_count() \
		if warning_count() > 0 else "ARENE VALIDE"


func technical_verdict() -> String:
	if not is_valid():
		return "ARENA_INVALID"
	return "ARENA_VALID_WITH_WARNINGS" if warning_count() > 0 else "ARENA_VALID"


func to_dict() -> Dictionary:
	return {
		"arena_id": str(arena_id),
		"generated_at": generated_at,
		"verdict": verdict(),
		"technical_verdict": technical_verdict(),
		"metrics": metrics.duplicate(true),
		"errors": error_count(),
		"warnings": warning_count(),
		"information": info_count(),
		"messages": messages.map(func(entry): return entry.to_dict()),
	}


func to_markdown() -> String:
	var lines := PackedStringArray([
		"# Rapport Arena Studio — %s" % arena_id,
		"",
		"Verdict : **%s**" % verdict(),
		"",
		"- Erreurs : %d" % error_count(),
		"- Avertissements : %d" % warning_count(),
		"- Informations : %d" % info_count(),
		"",
		"## Resultats",
		"",
	])
	for entry in messages:
		var prefix: String = ["ERREUR", "AVERTISSEMENT", "INFO"][entry.severity]
		var location := ""
		if entry.cell != GridTransformService.INVALID_CELL:
			location = " — cellule (%d, %d)" % [entry.cell.x, entry.cell.y]
		lines.append("- **%s** `%s`%s : %s" % [prefix, entry.code, location, entry.message])
	return "\n".join(lines)
