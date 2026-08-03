class_name RunInventory
extends RefCounted

const DEFAULT_CAPACITY := 24
const SNAPSHOT_VERSION := 1

signal changed

var capacity := DEFAULT_CAPACITY
var _catalog: ItemCatalog = null
var _slots: Array[ItemInstance] = []


func initialize(catalog: ItemCatalog, p_capacity: int = DEFAULT_CAPACITY) -> bool:
	if catalog == null or not catalog.rebuild_index() or p_capacity <= 0:
		return false
	_catalog = catalog
	capacity = p_capacity
	_slots.clear()
	_slots.resize(capacity)
	return true


func get_catalog() -> ItemCatalog:
	return _catalog


func get_slots() -> Array[ItemInstance]:
	return _slots.duplicate()


func get_slot(slot_index: int) -> ItemInstance:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slots[slot_index]


func get_empty_slot_count() -> int:
	return _slots.count(null)


func find_slot(instance_id: StringName) -> int:
	for slot_index in range(_slots.size()):
		var instance := _slots[slot_index]
		if instance != null and instance.instance_id == instance_id:
			return slot_index
	return -1


func get_instance(instance_id: StringName) -> ItemInstance:
	var slot_index := find_slot(instance_id)
	return _slots[slot_index] if slot_index >= 0 else null


func contains_definition(definition_id: StringName) -> bool:
	for instance in _slots:
		if instance != null and instance.definition_id == definition_id:
			return true
	return false


func can_accept(definition_id: StringName, quantity: int = 1) -> bool:
	var definition := _definition(definition_id)
	if definition == null or quantity <= 0:
		return false
	var remaining := quantity
	if definition.get_stack_limit() > 1:
		for instance in _slots:
			if instance != null and instance.definition_id == definition_id:
				remaining -= definition.get_stack_limit() - instance.quantity
				if remaining <= 0:
					return true
	var needed_slots := ceili(float(remaining) / float(definition.get_stack_limit()))
	return get_empty_slot_count() >= needed_slots


func try_add(definition_id: StringName, quantity: int = 1) -> Dictionary:
	var definition := _definition(definition_id)
	if definition == null:
		return _failure("ITEM_DEFINITION_UNKNOWN", "Objet inconnu.")
	if quantity <= 0:
		return _failure("QUANTITY_INVALID", "Quantité invalide.")
	if not can_accept(definition_id, quantity):
		return _failure("INVENTORY_FULL", "L’inventaire est plein.")
	var remaining := quantity
	var affected_ids: Array[StringName] = []
	var stack_limit := definition.get_stack_limit()
	if stack_limit > 1:
		for instance in _slots:
			if instance == null \
					or instance.definition_id != definition_id \
					or instance.quantity >= stack_limit:
				continue
			var added := mini(remaining, stack_limit - instance.quantity)
			instance.quantity += added
			remaining -= added
			affected_ids.append(instance.instance_id)
			if remaining <= 0:
				break
	while remaining > 0:
		var slot_index := _slots.find(null)
		var stack_quantity := mini(remaining, stack_limit)
		var instance := ItemInstance.new()
		instance.initialize(definition_id, stack_quantity)
		_slots[slot_index] = instance
		affected_ids.append(instance.instance_id)
		remaining -= stack_quantity
	changed.emit()
	return {
		"success": true,
		"definition_id": definition_id,
		"quantity": quantity,
		"instance_ids": affected_ids,
	}


func take_instance(instance_id: StringName, notify: bool = true) -> Dictionary:
	var slot_index := find_slot(instance_id)
	if slot_index < 0:
		return _failure("ITEM_NOT_FOUND", "Objet absent de l’inventaire.")
	var instance := _slots[slot_index]
	_slots[slot_index] = null
	if notify:
		changed.emit()
	return {
		"success": true,
		"instance": instance,
		"slot_index": slot_index,
	}


func try_insert_instance(
		instance: ItemInstance,
		preferred_slot: int = -1,
		notify: bool = true
	) -> bool:
	if not _is_instance_valid_for_catalog(instance):
		return false
	if find_slot(instance.instance_id) >= 0:
		return false
	var slot_index := preferred_slot
	if slot_index < 0 or slot_index >= _slots.size() or _slots[slot_index] != null:
		slot_index = _slots.find(null)
	if slot_index < 0:
		return false
	_slots[slot_index] = instance
	if notify:
		changed.emit()
	return true


func notify_changed() -> void:
	changed.emit()


func remove_quantity(instance_id: StringName, quantity: int = 1) -> Dictionary:
	var instance := get_instance(instance_id)
	if instance == null:
		return _failure("ITEM_NOT_FOUND", "Objet absent de l’inventaire.")
	if quantity <= 0 or quantity > instance.quantity:
		return _failure("QUANTITY_INVALID", "Quantité indisponible.")
	instance.quantity -= quantity
	if instance.quantity == 0:
		_slots[find_slot(instance_id)] = null
	changed.emit()
	return {
		"success": true,
		"instance_id": instance_id,
		"removed_quantity": quantity,
	}


func clear() -> void:
	if _slots.all(func(instance): return instance == null):
		return
	_slots.fill(null)
	changed.emit()


func to_snapshot() -> Dictionary:
	var slots_snapshot: Array = []
	for instance in _slots:
		slots_snapshot.append(instance.to_snapshot() if instance != null else null)
	return {
		"version": SNAPSHOT_VERSION,
		"capacity": capacity,
		"slots": slots_snapshot,
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if _catalog == null \
			or int(snapshot.get("version", -1)) != SNAPSHOT_VERSION \
			or int(snapshot.get("capacity", -1)) != capacity:
		return false
	var saved_slots := snapshot.get("slots", []) as Array
	if saved_slots.size() != capacity:
		return false
	var restored: Array[ItemInstance] = []
	restored.resize(capacity)
	var seen_ids := {}
	for slot_index in range(saved_slots.size()):
		var value = saved_slots[slot_index]
		if value == null:
			continue
		if not value is Dictionary:
			return false
		var instance := ItemInstance.from_snapshot(value as Dictionary, _catalog)
		if instance == null or seen_ids.has(instance.instance_id):
			return false
		seen_ids[instance.instance_id] = true
		restored[slot_index] = instance
	_slots = restored
	changed.emit()
	return true


func _definition(definition_id: StringName) -> ItemDefinition:
	return _catalog.get_definition(definition_id) if _catalog != null else null


func _is_instance_valid_for_catalog(instance: ItemInstance) -> bool:
	if instance == null or instance.instance_id == &"":
		return false
	var definition := _definition(instance.definition_id)
	return definition != null \
		and instance.quantity > 0 \
		and instance.quantity <= definition.get_stack_limit()


func _failure(code: String, message: String) -> Dictionary:
	return {"success": false, "error_code": code, "error": message}
