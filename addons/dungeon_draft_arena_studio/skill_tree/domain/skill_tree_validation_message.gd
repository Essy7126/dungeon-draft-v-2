@tool
class_name SkillTreeValidationMessage
extends RefCounted

enum Severity {
	INFORMATION,
	WARNING,
	ERROR,
}

var severity: Severity = Severity.INFORMATION
var code: StringName = &""
var title := ""
var explanation := ""
var suggestion := ""
var subject_id: StringName = &""
var property_name: StringName = &""
var rank := -1


static func create(
		p_severity: Severity,
		p_code: StringName,
		p_title: String,
		p_explanation: String,
		p_suggestion := "",
		p_subject_id: StringName = &"",
		p_property_name: StringName = &"",
		p_rank := -1
	) -> SkillTreeValidationMessage:
	var message := SkillTreeValidationMessage.new()
	message.severity = p_severity
	message.code = p_code
	message.title = p_title
	message.explanation = p_explanation
	message.suggestion = p_suggestion
	message.subject_id = p_subject_id
	message.property_name = p_property_name
	message.rank = p_rank
	return message


func is_error() -> bool:
	return severity == Severity.ERROR


func severity_label() -> String:
	match severity:
		Severity.ERROR:
			return "ERREUR"
		Severity.WARNING:
			return "AVERTISSEMENT"
		_:
			return "INFORMATION"


func to_dictionary() -> Dictionary:
	return {
		"severity": severity,
		"severity_label": severity_label(),
		"code": str(code),
		"title": title,
		"explanation": explanation,
		"suggestion": suggestion,
		"subject_id": str(subject_id),
		"property_name": str(property_name),
		"rank": rank,
	}
