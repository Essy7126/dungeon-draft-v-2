class_name SkillUpgradeData
extends Resource

@export var upgrade_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var card_texture: Texture2D = null
@export var discipline_id: StringName = &""
@export_range(1, 99) var rank: int = 1
@export var target_spell_id: StringName = &""
@export var spell_modifiers: Array[SpellModifier] = []


func get_spell_modifiers() -> Array[SpellModifier]:
	return spell_modifiers.duplicate()


func get_card_texture() -> Texture2D:
	return card_texture if card_texture != null else icon
