class_name SkillTreeSkinData
extends Resource

@export_category("REFINED V2")
@export var refined_config: SkillTreeRefinedConfig = null
@export var icon_catalog: SkillTreeIconCatalog = null

@export_category("Panels")
@export var main_panel_texture: Texture2D = null
@export var detail_panel_texture: Texture2D = null

@export_category("Nodes")
@export var node_standard_texture: Texture2D = null
@export var node_root_texture: Texture2D = null
@export var node_capstone_texture: Texture2D = null

@export_category("Chrome")
@export var rank_badge_texture: Texture2D = null
@export var character_tab_texture: Texture2D = null
@export var discipline_tab_texture: Texture2D = null
@export var xp_bar_frame_texture: Texture2D = null

@export_category("States")
@export var state_lock_texture: Texture2D = null
@export var state_selected_texture: Texture2D = null
@export var state_excluded_texture: Texture2D = null
@export var state_pending_texture: Texture2D = null

@export_category("Glyph libraries")
@export var discipline_icons: Dictionary = {}
@export var effect_glyphs: Dictionary = {}


func get_node_frame(rank: int) -> Texture2D:
	if rank <= 1:
		return node_root_texture
	if rank >= 5:
		return node_capstone_texture
	return node_standard_texture


func get_discipline_icon(icon_id: StringName) -> Texture2D:
	if icon_catalog != null:
		var parts := str(icon_id).split("_", true, 1)
		if parts.size() == 2:
			var catalog_icon := icon_catalog.get_branch_badge(
				StringName(parts[0]),
				StringName(parts[1])
			)
			if catalog_icon != null:
				return catalog_icon
	return discipline_icons.get(icon_id) as Texture2D


func get_effect_glyph(glyph_id: StringName) -> Texture2D:
	if icon_catalog != null:
		return icon_catalog.get_semantic_icon(glyph_id)
	return effect_glyphs.get(glyph_id) as Texture2D


func get_state_texture(state_id: StringName) -> Texture2D:
	if icon_catalog != null:
		return icon_catalog.get_state_icon(state_id)
	match state_id:
		&"selected":
			return state_selected_texture
		&"locked":
			return state_lock_texture
		&"excluded":
			return state_excluded_texture
		&"pending":
			return state_pending_texture
	return null


func get_missing_essential_textures() -> Array[StringName]:
	var missing: Array[StringName] = []
	if refined_config == null:
		missing.append(&"refined_config")
	elif refined_config.lock_icon_texture == null:
		missing.append(&"lock_icon_texture")
	if icon_catalog == null:
		missing.append(&"icon_catalog")
	elif icon_catalog.generic_upgrade_icon == null:
		missing.append(&"generic_upgrade_icon")
	return missing
