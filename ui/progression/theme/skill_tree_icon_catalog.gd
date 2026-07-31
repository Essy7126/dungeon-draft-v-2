class_name SkillTreeIconCatalog
extends Resource

@export var node_icons: Dictionary = {}
@export var semantic_icons: Dictionary = {}
@export var branch_badges: Dictionary = {}
@export var root_icons: Dictionary = {}
@export var capstone_icons: Dictionary = {}
@export var specialization_icons: Dictionary = {}
@export var state_icons: Dictionary = {}
@export var generic_upgrade_icon: Texture2D = null
@export var hidden_icon: Texture2D = null
@export var locked_icon: Texture2D = null


func get_node_icon(
		node_id: StringName,
		semantic_category: StringName = &"upgrade"
	) -> Texture2D:
	var exact := node_icons.get(node_id) as Texture2D
	if exact != null:
		return exact
	return get_semantic_icon(semantic_category)


func get_semantic_icon(category: StringName) -> Texture2D:
	var icon := semantic_icons.get(category) as Texture2D
	return icon if icon != null else generic_upgrade_icon


func get_branch_badge(
		character_id: StringName,
		discipline_id: StringName
	) -> Texture2D:
	return branch_badges.get(_branch_key(character_id, discipline_id)) as Texture2D


func get_root_icon(
		character_id: StringName,
		discipline_id: StringName
	) -> Texture2D:
	var icon := root_icons.get(_branch_key(character_id, discipline_id)) as Texture2D
	return icon if icon != null else get_branch_badge(character_id, discipline_id)


func get_capstone_icon(node_id: StringName) -> Texture2D:
	var icon := capstone_icons.get(node_id) as Texture2D
	return icon if icon != null else get_node_icon(node_id)


func get_specialization_icon(node_id: StringName) -> Texture2D:
	var icon := specialization_icons.get(node_id) as Texture2D
	return icon if icon != null else get_node_icon(node_id)


func get_state_icon(state_id: StringName) -> Texture2D:
	if state_id == &"locked" and locked_icon != null:
		return locked_icon
	return state_icons.get(state_id) as Texture2D


func _branch_key(
		character_id: StringName,
		discipline_id: StringName
	) -> StringName:
	return StringName("%s:%s" % [character_id, discipline_id])
