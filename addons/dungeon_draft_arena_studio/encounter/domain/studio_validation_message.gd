@tool
class_name StudioValidationMessage
extends RefCounted

enum Severity { ERROR, WARNING, INFO }

var severity := Severity.INFO
var code: StringName = &"information"
var title := "Information"
var explanation := ""
var resource_path := ""
var room_index := -1
var wave_index := -1
var cell := Vector2i(-1, -1)
var fix_id: StringName = &""


static func create(
		message_severity: Severity,
		message_code: StringName,
		message_title: String,
		message_explanation: String,
		context: Dictionary = {}
	) -> StudioValidationMessage:
	var message := StudioValidationMessage.new()
	message.severity = message_severity
	message.code = message_code
	message.title = message_title
	message.explanation = message_explanation
	message.resource_path = str(context.get("resource_path", ""))
	message.room_index = int(context.get("room_index", -1))
	message.wave_index = int(context.get("wave_index", -1))
	message.cell = context.get("cell", Vector2i(-1, -1)) as Vector2i
	message.fix_id = StringName(context.get("fix_id", &""))
	return message


func severity_label() -> String:
	match severity:
		Severity.ERROR: return "ERREUR"
		Severity.WARNING: return "AVERTISSEMENT"
	return "INFORMATION"


func to_dictionary() -> Dictionary:
	return {
		"severity": severity_label(),
		"code": str(code),
		"title": title,
		"explanation": explanation,
		"resource_path": resource_path,
		"room_index": room_index,
		"wave_index": wave_index,
		"cell": [cell.x, cell.y] if cell != Vector2i(-1, -1) else [],
		"fix_id": str(fix_id),
	}


func display_text() -> String:
	var location := ""
	if room_index >= 0:
		location += " • Salle %d" % (room_index + 1)
	if wave_index >= 0:
		location += " / Affrontement %d" % (wave_index + 1)
	if cell != Vector2i(-1, -1):
		location += " • Case %s" % cell
	return "%s — %s%s" % [severity_label(), title, location]
