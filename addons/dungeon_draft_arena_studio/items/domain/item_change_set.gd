@tool
class_name ItemChangeSet
extends RefCounted

var before := {}
var after := {}
var changed_fields: Array[String] = []


static func between(before_snapshot: Dictionary, after_snapshot: Dictionary) -> ItemChangeSet:
	var result := ItemChangeSet.new()
	result.before = before_snapshot.duplicate(true)
	result.after = after_snapshot.duplicate(true)
	var keys: Array = before_snapshot.keys()
	for key in after_snapshot.keys():
		if key not in keys:
			keys.append(key)
	keys.sort_custom(func(a, b): return str(a) < str(b))
	for key in keys:
		if before_snapshot.get(key) != after_snapshot.get(key):
			result.changed_fields.append(str(key))
	return result


func is_empty() -> bool:
	return changed_fields.is_empty()
