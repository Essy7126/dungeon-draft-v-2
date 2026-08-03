class_name ItemDefinition
extends Resource

enum Category {
	WEAPON,
	ARMOR,
	ACCESSORY,
	CONSUMABLE,
	SCROLL,
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
@export var rarity: StringName = &"common"
@export var tags: Array[StringName] = []

@export_group("Inventory")
@export var category: Category = Category.ACCESSORY
@export_range(1, 99, 1) var stack_limit := 1

@export_group("Equipment")
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var compatible_character_ids: Array[StringName] = []
@export var stat_modifiers: Array[ItemStatModifierData] = []

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
	if category == Category.WEAPON and equipment_slot != EquipmentSlot.WEAPON:
		return false
	if category == Category.ARMOR and equipment_slot != EquipmentSlot.ARMOR:
		return false
	if category == Category.ACCESSORY and equipment_slot != EquipmentSlot.ACCESSORY:
		return false
	if is_equippable() and stack_limit != 1:
		return false
	if category in [Category.CONSUMABLE, Category.SCROLL]:
		return use_effect != UseEffect.NONE and use_value > 0.0
	for modifier in stat_modifiers:
		if modifier == null or not modifier.is_valid():
			return false
	return true


func is_equippable() -> bool:
	return equipment_slot != EquipmentSlot.NONE


func is_consumable() -> bool:
	return category in [Category.CONSUMABLE, Category.SCROLL]


func is_compatible_with(character_id: StringName) -> bool:
	return compatible_character_ids.is_empty() or character_id in compatible_character_ids


func get_stack_limit() -> int:
	return maxi(1, stack_limit)
