class_name ItemInstance
extends RefCounted

var instance_id: StringName = &""
var definition_id: StringName = &""
var quantity := 1
var forge_level := 0

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
	copy.forge_level = forge_level
	return copy


func to_snapshot() -> Dictionary:
	return {
		"instance_id": str(instance_id),
		"definition_id": str(definition_id),
		"quantity": quantity,
		"forge_level": forge_level,
	}


static func from_snapshot(snapshot: Dictionary, catalog: ItemCatalog) -> ItemInstance:
	if catalog == null:
		return null
	var definition_id := StringName(snapshot.get("definition_id", &""))
	var saved_instance_id := StringName(snapshot.get("instance_id", &""))
	var saved_quantity := int(snapshot.get("quantity", 0))
	var saved_forge := int(snapshot.get("forge_level", 0))
	if saved_forge < 0 or saved_forge > 2:
		return null
	var definition := catalog.get_definition(definition_id)
	if definition == null \
			or saved_instance_id == &"" \
			or saved_quantity <= 0 \
			or saved_quantity > definition.get_stack_limit():
		return null
	if saved_forge > 0 and not definition.is_equippable():
		return null
	var instance := ItemInstance.new()
	instance.forge_level = saved_forge
	return instance if instance.initialize(
		definition_id,
		saved_quantity,
		saved_instance_id,
	) else null


static func _new_instance_id() -> StringName:
	_next_sequence += 1
	return StringName("item_%d_%d" % [Time.get_ticks_usec(), _next_sequence])
