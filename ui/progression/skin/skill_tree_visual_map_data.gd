class_name SkillTreeVisualMapData
extends Resource

@export var entries: Array[SkillTreeNodeVisualData] = []

var _entries_by_id: Dictionary = {}


func get_visual(node_id: StringName) -> SkillTreeNodeVisualData:
	_ensure_index()
	return _entries_by_id.get(node_id) as SkillTreeNodeVisualData


func get_node_ids() -> Array[StringName]:
	_ensure_index()
	var result: Array[StringName] = []
	for node_id in _entries_by_id:
		result.append(StringName(node_id))
	return result


func get_entry_count() -> int:
	_ensure_index()
	return _entries_by_id.size()


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for entry in entries:
		if entry == null:
			errors.append("Entrée visuelle nulle.")
			continue
		if not entry.is_valid():
			errors.append("Entrée visuelle invalide : %s." % entry.node_id)
			continue
		if seen.has(entry.node_id):
			errors.append("Identifiant visuel dupliqué : %s." % entry.node_id)
		seen[entry.node_id] = true
	return errors


func _ensure_index() -> void:
	if _entries_by_id.size() == entries.size():
		return
	_entries_by_id.clear()
	for entry in entries:
		if entry != null and entry.node_id != &"":
			_entries_by_id[entry.node_id] = entry
