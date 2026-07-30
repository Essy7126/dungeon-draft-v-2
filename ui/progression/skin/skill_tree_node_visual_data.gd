class_name SkillTreeNodeVisualData
extends Resource

@export var node_id: StringName = &""
@export var discipline_icon_id: StringName = &""
@export var primary_glyph_id: StringName = &""
@export var secondary_glyph_id: StringName = &""
@export var icon_override: Texture2D = null


func is_valid() -> bool:
	return node_id != &"" and (
		discipline_icon_id != &""
		or primary_glyph_id != &""
		or icon_override != null
	)
