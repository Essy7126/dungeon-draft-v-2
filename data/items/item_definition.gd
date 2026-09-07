@tool
class_name ItemDefinition
extends Resource

enum Category {
	WEAPON,
	ARMOR,
	ACCESSORY,
	CONSUMABLE,
	SCROLL,
	RELIC,
}

enum EquipmentSlot {
	NONE = -1,
	WEAPON,
	ARMOR,
	ACCESSORY,
}

enum UseEffect {
	NONE,
	HEAL_FLAT,
	RESTORE_AP_FLAT,
}

@export_group("Identity")
@export var item_id: StringName = &""
@export var display_name := "Objet"
@export_multiline var description := ""
@export var icon: Texture2D = null
@export var inventory_icon: Texture2D = null
@export var card_texture: Texture2D = null
@export var rarity: StringName = &"common"
@export var tags: Array[StringName] = []

@export_group("Reward Presentation")
@export var reward_fx_profile: StringName = &"generic"
@export var reward_audio_profile: StringName = &"generic"

@export_group("Inventory")
@export var category: Category = Category.ACCESSORY
@export_range(1, 99, 1) var stack_limit := 1

@export_group("Equipment")
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var compatible_character_ids: Array[StringName] = []
@export var stat_modifiers: Array[ItemStatModifierData] = []
@export var spell_modifiers: Array[SpellModifier] = []
## Multiplicateurs défensifs portés par la source de Garde et résolus
## selon la classification explicite de l’attaque reçue.
@export_range(0.01, 5.0, 0.01) var guard_effectiveness_melee := 1.0
@export_range(0.01, 5.0, 0.01) var guard_effectiveness_projectile := 1.0

@export_group("Relic")
@export var reactive_effects: Array[ItemReactiveEffectData] = []

@export_group("Use")
@export var use_effect: UseEffect = UseEffect.NONE
@export var use_value := 0.0


func is_valid() -> bool:
	if item_id == &"" or display_name.strip_edges().is_empty() or stack_limit <= 0:
		return false
	if category in [Category.WEAPON, Category.ARMOR, Category.ACCESSORY] \
			and not is_equippable():
		return false
	if category in [Category.CONSUMABLE, Category.SCROLL] \
			and is_equippable():
		return false
	if category == Category.RELIC and (
			is_equippable() or stack_limit != 1 or reactive_effects.is_empty()
			or use_effect != UseEffect.NONE
			or not compatible_character_ids.is_empty()
			or not stat_modifiers.is_empty()
			or not spell_modifiers.is_empty()
		):
		return false
	if category == Category.WEAPON and equipment_slot != EquipmentSlot.WEAPON:
		return false
	if category == Category.ARMOR and equipment_slot != EquipmentSlot.ARMOR:
		return false
	if category == Category.ACCESSORY and equipment_slot != EquipmentSlot.ACCESSORY:
		return false
	if is_equippable() and stack_limit != 1:
		return false
	if guard_effectiveness_melee <= 0.0 \
			or guard_effectiveness_projectile <= 0.0:
		return false
	if category in [Category.CONSUMABLE, Category.SCROLL]:
		return use_effect != UseEffect.NONE and use_value > 0.0
	for modifier in stat_modifiers:
		if modifier == null or not modifier.is_valid():
			return false
	for modifier in spell_modifiers:
		if modifier == null:
			return false
		if modifier is ItemSpellModifierData \
				and not (modifier as ItemSpellModifierData).is_valid_modifier():
			return false
	for effect in reactive_effects:
		if effect == null or not effect.is_structurally_valid():
			return false
	return true


func is_equippable() -> bool:
	return equipment_slot != EquipmentSlot.NONE


func is_consumable() -> bool:
	return category in [Category.CONSUMABLE, Category.SCROLL]


func is_relic() -> bool:
	return category == Category.RELIC


# Sert à savoir si l'objet mérite une place dans la barre d'objets du combat :
# seuls les objets qu'un joueur peut déclencher lui-même y apparaissent.
func has_manual_activation() -> bool:
	for effect in reactive_effects:
		if effect != null and effect.enabled and effect.is_manual_trigger():
			return true
	return false


func is_compatible_with(character_id: StringName) -> bool:
	return compatible_character_ids.is_empty() or character_id in compatible_character_ids


func get_stack_limit() -> int:
	return maxi(1, stack_limit)


func get_inventory_icon() -> Texture2D:
	return inventory_icon if inventory_icon != null else icon


func get_reward_card_texture() -> Texture2D:
	return card_texture if card_texture != null else icon


func runtime_requirements() -> Array[StringName]:
	var result: Array[StringName] = []
	if not is_equal_approx(guard_effectiveness_melee, 1.0) \
			or not is_equal_approx(guard_effectiveness_projectile, 1.0):
		result.append(&"guard_attack_classification_hook")
	return result
