@tool
class_name ItemSaveConflict
extends RefCounted

var code: StringName = &""
var message := ""
var path := ""


func configure(p_code: StringName, p_message: String, p_path := "") -> ItemSaveConflict:
	code = p_code
	message = p_message
	path = p_path
	return self


func to_snapshot() -> Dictionary:
	return {"code": str(code), "message": message, "path": path}
