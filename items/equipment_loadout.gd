class_name EquipmentLoadout
extends RefCounted

const SNAPSHOT_VERSION := 1
const EQUIPMENT_SLOTS: Array[int] = [
	ItemDefinition.EquipmentSlot.WEAPON,
	ItemDefinition.EquipmentSlot.ARMOR,
	ItemDefinition.EquipmentSlot.ACCESSORY,
]

signal changed(slot: int, old_instance_id: StringName, new_instance_id: StringName)

var character_id: StringName = &""
var _equipped: Dictionary = {}


func initialize(p_character_id: StringName) -> bool:
	if p_character_id == &"":
		return false
	character_id = p_character_id
	_equipped.clear()
	for slot in EQUIPMENT_SLOTS:
		_equipped[slot] = null
	return true


func get_item(slot: int) -> ItemInstance:
	return _equipped.get(slot) as ItemInstance


func get_equipped_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for slot in EQUIPMENT_SLOTS:
		var instance := get_item(slot)
		if instance != null:
			result.append(instance)
	return result


func set_item(slot: int, instance: ItemInstance, notify: bool = true) -> bool:
	if slot not in EQUIPMENT_SLOTS:
		return false
	var previous := get_item(slot)
	if previous == instance:
		return true
	_equipped[slot] = instance
	if notify:
		changed.emit(
			slot,
			previous.instance_id if previous != null else &"",
			instance.instance_id if instance != null else &"",
		)
	return true


func clear(notify: bool = true) -> void:
	for slot in EQUIPMENT_SLOTS:
		set_item(slot, null, notify)


func notify_slot_changed(
		slot: int,
		old_instance_id: StringName,
		new_instance_id: StringName
	) -> void:
	changed.emit(slot, old_instance_id, new_instance_id)


func to_snapshot() -> Dictionary:
	var slots := {}
	for slot in EQUIPMENT_SLOTS:
		var instance := get_item(slot)
		slots[_slot_key(slot)] = (
			instance.to_snapshot() if instance != null else null
		)
	return {
		"version": SNAPSHOT_VERSION,
		"character_id": str(character_id),
		"slots": slots,
	}


func restore_snapshot(snapshot: Dictionary, catalog: ItemCatalog) -> bool:
	if catalog == null \
			or int(snapshot.get("version", -1)) != SNAPSHOT_VERSION \
			or StringName(snapshot.get("character_id", &"")) != character_id:
		return false
	var slots := snapshot.get("slots", {}) as Dictionary
	var restored := {}
	var seen_ids := {}
	for slot in EQUIPMENT_SLOTS:
		var value = slots.get(_slot_key(slot))
		if value == null:
			restored[slot] = null
			continue
		if not value is Dictionary:
			return false
		var instance := ItemInstance.from_snapshot(value as Dictionary, catalog)
		var definition := (
			catalog.get_definition(instance.definition_id)
			if instance != null
			else null
		)
		if instance == null \
				or definition == null \
				or definition.equipment_slot != slot \
				or not definition.is_compatible_with(character_id) \
				or seen_ids.has(instance.instance_id):
			return false
		seen_ids[instance.instance_id] = true
		restored[slot] = instance
	_equipped = restored
	for slot in EQUIPMENT_SLOTS:
		var instance := get_item(slot)
		changed.emit(
			slot,
			&"",
			instance.instance_id if instance != null else &"",
		)
	return true


static func get_slot_display_name(slot: int) -> String:
	match slot:
		ItemDefinition.EquipmentSlot.WEAPON:
			return "Arme"
		ItemDefinition.EquipmentSlot.ARMOR:
			return "Armure"
		ItemDefinition.EquipmentSlot.ACCESSORY:
			return "Accessoire"
		_:
			return "Inconnu"


static func _slot_key(slot: int) -> String:
	match slot:
		ItemDefinition.EquipmentSlot.WEAPON:
			return "weapon"
		ItemDefinition.EquipmentSlot.ARMOR:
			return "armor"
		ItemDefinition.EquipmentSlot.ACCESSORY:
			return "accessory"
		_:
			return "unknown"
