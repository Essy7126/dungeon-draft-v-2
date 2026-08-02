class_name CharacterHUDThemeData
extends Resource

@export_category("Identity")
@export var character_id: StringName = &""
@export var display_name := ""
@export var discipline_name := ""
@export var default_discipline_id: StringName = &""

@export_category("Textures")
@export var character_bar_texture: Texture2D
@export var discipline_emblem_texture: Texture2D
@export var portrait_texture: Texture2D
@export var portrait_frame_texture: Texture2D
@export var turn_banner_texture: Texture2D
@export var spell_slot_frame_texture: Texture2D
@export var health_bar_frame_texture: Texture2D
@export var end_turn_button_texture: Texture2D
@export var move_action_icon: Texture2D
@export var utility_inventory_icon: Texture2D
@export var utility_map_icon: Texture2D
@export var utility_skills_icon: Texture2D
@export var refined_components := false

@export_category("Palette")
@export var primary_color := Color(0.25, 0.5, 0.28)
@export var secondary_color := Color(0.62, 0.43, 0.2)
@export var text_color := Color(0.96, 0.92, 0.8)

@export_category("Capabilities")
@export var spell_icon_mapping: Dictionary = {}
@export var spell_frame_mapping: Dictionary = {}


func matches_unit(unit) -> bool:
	return (
		unit != null
		and character_id != &""
		and StringName(unit.unit_id) == character_id
	)


func get_spell_icon(capability_id: StringName) -> Texture2D:
	var texture_value = spell_icon_mapping.get(capability_id)
	return texture_value as Texture2D


func get_spell_icon_for(spell) -> Texture2D:
	return get_spell_icon(_get_spell_id(spell))


func get_spell_frame(capability_id: StringName) -> Texture2D:
	var texture_value = spell_frame_mapping.get(capability_id)
	if texture_value is Texture2D:
		return texture_value as Texture2D
	return spell_slot_frame_texture


func get_spell_frame_for(spell) -> Texture2D:
	return get_spell_frame(_get_spell_id(spell))


func _get_spell_id(spell) -> StringName:
	if spell == null:
		return &""
	var spell_id := StringName()
	if spell.has_method("get_effective_spell_id"):
		spell_id = spell.get_effective_spell_id()
	else:
		spell_id = StringName(spell.get("spell_id"))
	return spell_id
