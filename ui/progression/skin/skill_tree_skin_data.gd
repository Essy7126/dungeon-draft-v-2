class_name SkillTreeSkinData
extends Resource

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
	return discipline_icons.get(icon_id) as Texture2D


func get_effect_glyph(glyph_id: StringName) -> Texture2D:
	return effect_glyphs.get(glyph_id) as Texture2D


func get_state_texture(state_id: StringName) -> Texture2D:
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
	var essentials := {
		&"main_panel_texture": main_panel_texture,
		&"detail_panel_texture": detail_panel_texture,
		&"node_standard_texture": node_standard_texture,
		&"node_root_texture": node_root_texture,
		&"node_capstone_texture": node_capstone_texture,
		&"character_tab_texture": character_tab_texture,
		&"discipline_tab_texture": discipline_tab_texture,
		&"xp_bar_frame_texture": xp_bar_frame_texture,
		&"state_lock_texture": state_lock_texture,
		&"state_selected_texture": state_selected_texture,
		&"state_excluded_texture": state_excluded_texture,
	}
	for texture_id in essentials:
		if essentials[texture_id] == null:
			missing.append(texture_id)
	return missing
