@tool
class_name MasteryCatalogData
extends Resource

@export var catalog_id: StringName = &""
@export var doctrines: Array[DisciplineData] = []
@export var advanced_catalog: AdvancedMasteryCatalogData = null
@export var advanced_nodes: Array[SkillTreeNodeData] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog_id == &"":
		errors.append("MASTERY_CATALOG_ID_EMPTY")
	if advanced_catalog != null:
		errors.append_array(advanced_catalog.validation_errors())
	errors.append_array(SkillTreeResolver.validate_champion_tree(
		doctrines, get_advanced_nodes()
	))
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func node_catalog() -> Dictionary:
	return SkillTreeResolver.champion_node_catalog(doctrines, get_advanced_nodes())


func get_advanced_nodes() -> Array[SkillTreeNodeData]:
	if advanced_catalog != null:
		return advanced_catalog.nodes.duplicate()
	return advanced_nodes.duplicate()
