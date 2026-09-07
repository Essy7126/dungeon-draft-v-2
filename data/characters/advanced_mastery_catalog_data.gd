@tool
class_name AdvancedMasteryCatalogData
extends Resource

@export var catalog_id: StringName = &""
@export var nodes: Array[SkillTreeNodeData] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog_id == &"":
		errors.append("ADVANCED_MASTERY_CATALOG_ID_EMPTY")
	if nodes.size() != 9:
		errors.append("ADVANCED_MASTERY_NODE_COUNT: %d" % nodes.size())
	var node_ids := {}
	for node in nodes:
		if node == null or not node.is_champion_mastery():
			errors.append("ADVANCED_MASTERY_NODE_INVALID")
			continue
		if node_ids.has(node.upgrade_id):
			errors.append("ADVANCED_MASTERY_NODE_DUPLICATE: %s" % node.upgrade_id)
		node_ids[node.upgrade_id] = true
		errors.append_array(node.validation_errors())
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
