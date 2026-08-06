class_name RunProgressionCloneResult
extends RefCounted

var profile: CharacterProgressionProfile = null
var source_to_clone: Dictionary = {}
var clone_to_source: Dictionary = {}
var resources: Array[Resource] = []
var allowed_shared_resources: Array[Resource] = []
var errors := PackedStringArray()
var manifest: Dictionary = {}


func is_valid() -> bool:
	return profile != null and errors.is_empty()
