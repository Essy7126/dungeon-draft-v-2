class_name SkillTreeNodeData
extends SkillUpgradeData

@export var prerequisite_node_ids: Array[StringName] = []
@export var excluded_node_ids: Array[StringName] = []


func get_node_id() -> StringName:
	return upgrade_id
