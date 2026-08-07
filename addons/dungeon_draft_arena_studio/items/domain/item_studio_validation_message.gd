@tool
class_name ItemStudioValidationMessage
extends RefCounted

enum Severity { INFO, WARNING, ERROR }

var severity: Severity = Severity.INFO
var code: StringName = &""
var message := ""
var property_path := ""


func configure(
		p_severity: Severity,
		p_code: StringName,
		p_message: String,
		p_property_path := ""
	) -> ItemStudioValidationMessage:
	severity = p_severity
	code = p_code
	message = p_message
	property_path = p_property_path
	return self


func to_snapshot() -> Dictionary:
	return {
		"severity": int(severity), "code": str(code),
		"message": message, "property_path": property_path,
	}
