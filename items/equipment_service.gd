class_name EquipmentService
extends RefCounted

var _catalog: ItemCatalog = null
var _stat_service := EquipmentStatService.new()


func initialize(catalog: ItemCatalog) -> bool:
	if catalog == null or not catalog.rebuild_index():
		return false
	_catalog = catalog
	return true


func equip(
		inventory: RunInventory,
		state: CharacterRunState,
		instance_id: StringName,
		slot: int
	) -> Dictionary:
	var validation := _validate_equip(inventory, state, instance_id, slot)
	if not validation.get("success", false):
		return validation
	var new_instance := inventory.get_instance(instance_id)
	var definition := _catalog.get_definition(new_instance.definition_id)
	var old_instance := state.equipment_loadout.get_item(slot)
	if old_instance != null and old_instance.instance_id == instance_id:
		return _success(state, slot, old_instance, new_instance)
	var taken := inventory.take_instance(instance_id, false)
	if not taken.get("success", false):
		return taken
	var freed_slot := int(taken.get("slot_index", -1))
	if old_instance != null and not inventory.try_insert_instance(
			old_instance,
			freed_slot,
			false,
		):
		inventory.try_insert_instance(new_instance, freed_slot, false)
		inventory.notify_changed()
		return _failure("TRANSACTION_ROLLBACK", "Échange d’équipement annulé.")
	state.equipment_loadout.set_item(slot, new_instance, false)
	if old_instance != null:
		var old_definition := _catalog.get_definition(old_instance.definition_id)
		_stat_service.remove_item(state.unit, old_instance, old_definition)
	if not _stat_service.apply_item(state.unit, new_instance, definition):
		state.equipment_loadout.set_item(slot, old_instance, false)
		if old_instance != null:
			inventory.take_instance(old_instance.instance_id, false)
			var old_definition := _catalog.get_definition(old_instance.definition_id)
			_stat_service.apply_item(state.unit, old_instance, old_definition)
		inventory.try_insert_instance(new_instance, freed_slot, false)
		inventory.notify_changed()
		return _failure("STAT_APPLICATION_FAILED", "Bonus d’équipement invalide.")
	inventory.notify_changed()
	state.equipment_loadout.notify_slot_changed(
		slot,
		old_instance.instance_id if old_instance != null else &"",
		new_instance.instance_id,
	)
	return _success(state, slot, old_instance, new_instance)


func unequip(
		inventory: RunInventory,
		state: CharacterRunState,
		slot: int
	) -> Dictionary:
	if inventory == null or state == null or state.equipment_loadout == null:
		return _failure("STATE_INVALID", "État d’équipement indisponible.")
	var instance := state.equipment_loadout.get_item(slot)
	if instance == null:
		return _failure("SLOT_EMPTY", "Cet emplacement est vide.")
	if inventory.get_empty_slot_count() <= 0:
		return _failure("INVENTORY_FULL", "Libérez une place dans l’inventaire.")
	var definition := _catalog.get_definition(instance.definition_id)
	if definition == null:
		return _failure("ITEM_DEFINITION_UNKNOWN", "Définition d’objet absente.")
	state.equipment_loadout.set_item(slot, null, false)
	if not inventory.try_insert_instance(instance, -1, false):
		state.equipment_loadout.set_item(slot, instance, false)
		return _failure("TRANSACTION_ROLLBACK", "Retrait d’équipement annulé.")
	_stat_service.remove_item(state.unit, instance, definition)
	inventory.notify_changed()
	state.equipment_loadout.notify_slot_changed(slot, instance.instance_id, &"")
	return {
		"success": true,
		"character_id": state.character_id,
		"slot": slot,
		"unequipped_instance_id": instance.instance_id,
	}


func rebuild_state(state: CharacterRunState) -> bool:
	return _stat_service.rebuild_loadout(state, _catalog)


func clear_state_stats(state: CharacterRunState) -> void:
	_stat_service.clear_loadout(state, _catalog)


func _validate_equip(
		inventory: RunInventory,
		state: CharacterRunState,
		instance_id: StringName,
		slot: int
	) -> Dictionary:
	if _catalog == null or inventory == null or state == null \
			or state.unit == null or state.equipment_loadout == null:
		return _failure("STATE_INVALID", "État d’équipement indisponible.")
	var instance := inventory.get_instance(instance_id)
	if instance == null:
		return _failure("ITEM_NOT_FOUND", "Objet absent de l’inventaire.")
	var definition := _catalog.get_definition(instance.definition_id)
	if definition == null:
		return _failure("ITEM_DEFINITION_UNKNOWN", "Définition d’objet absente.")
	if not definition.is_equippable() or definition.equipment_slot != slot:
		return _failure("SLOT_INCOMPATIBLE", "Cet objet ne va pas dans cet emplacement.")
	if not definition.is_compatible_with(state.character_id):
		return _failure("CHARACTER_INCOMPATIBLE", "Ce héros ne peut pas utiliser cet objet.")
	return {"success": true}


func _success(
		state: CharacterRunState,
		slot: int,
		old_instance: ItemInstance,
		new_instance: ItemInstance
	) -> Dictionary:
	return {
		"success": true,
		"character_id": state.character_id,
		"slot": slot,
		"equipped_instance_id": new_instance.instance_id,
		"unequipped_instance_id": (
			old_instance.instance_id if old_instance != null else &""
		),
	}


func _failure(code: String, message: String) -> Dictionary:
	return {"success": false, "error_code": code, "error": message}
