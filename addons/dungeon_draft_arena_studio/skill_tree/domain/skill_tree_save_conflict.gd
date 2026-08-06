@tool
class_name SkillTreeSaveConflict
extends RefCounted

enum Kind {
	PATH_COLLISION,
	TYPE_CONFLICT,
	EXTERNAL_MODIFICATION,
	UNSAFE_PATH,
	CACHE_ONLY_COLLISION,
	DEPENDENCY_MISSING,
}

var kind: Kind = Kind.PATH_COLLISION
var path := ""
var message := ""
var details := {}
var blocking := true


static func create(
		p_kind: Kind,
		p_path: String,
		p_message: String,
		p_details: Dictionary = {}
	) -> SkillTreeSaveConflict:
	var result := SkillTreeSaveConflict.new()
	result.kind = p_kind
	result.path = p_path
	result.message = p_message
	result.details = p_details.duplicate(true)
	return result


func to_dictionary() -> Dictionary:
	return {
		"kind": kind,
		"kind_name": Kind.keys()[kind],
		"path": path,
		"message": message,
		"details": details.duplicate(true),
		"blocking": blocking,
	}
