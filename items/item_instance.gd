class_name ItemInstance
extends RefCounted

var instance_id: StringName = &""
var definition_id: StringName = &""
var quantity := 1

static var _next_sequence := 0


func initialize(
		p_definition_id: StringName,
		p_quantity: int = 1,
		p_instance_id: StringName = &""
	) -> bool:
	if p_definition_id == &"" or p_quantity <= 0:
		return false
	definition_id = p_definition_id
	quantity = p_quantity
	instance_id = p_instance_id if p_instance_id != &"" else _new_instance_id()
	return instance_id != &""


func duplicate_instance() -> ItemInstance:
	var copy := ItemInstance.new()
	copy.initialize(definition_id, quantity, instance_id)
	return copy


func to_snapshot() -> Dictionary:
	return {
		"instance_id": str(instance_id),
		"definition_id": str(definition_id),
		"quantity": quantity,
	}


static func from_snapshot(snapshot: Dictionary, catalog: ItemCatalog) -> ItemInstance:
	if catalog == null:
		return null
	var definition_id := StringName(snapshot.get("definition_id", &""))
	var saved_instance_id := StringName(snapshot.get("instance_id", &""))
	var saved_quantity := int(snapshot.get("quantity", 0))
	var definition := catalog.get_definition(definition_id)
	if definition == null \
			or saved_instance_id == &"" \
			or saved_quantity <= 0 \
			or saved_quantity > definition.get_stack_limit():
		return null
	var instance := ItemInstance.new()
	return instance if instance.initialize(
		definition_id,
		saved_quantity,
		saved_instance_id,
	) else null


static func _new_instance_id() -> StringName:
	_next_sequence += 1
	return StringName("item_%d_%d" % [Time.get_ticks_usec(), _next_sequence])
