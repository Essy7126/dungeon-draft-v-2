@tool
class_name RoomDataSnapshotService
extends RefCounted

## Snapshots stables de RoomData. Les empreintes sont semantiques : les
## sous-ressources sont comparees par contenu et les ressources externes par
## chemin, jamais par instance_id.


static func to_gameplay_snapshot(room: RoomData) -> Dictionary:
	return RoomIntegrationFieldPolicy.signature(
		room, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)


static func to_room_snapshot(room: RoomData) -> Dictionary:
	var result := {}
	if room == null:
		return result
	for property_name in RoomIntegrationFieldPolicy.stored_property_names(room):
		if property_name == &"script":
			continue
		result[str(property_name)] = RoomIntegrationFieldPolicy.stable_value(
			room.get(property_name)
		)
	return result


static func gameplay_fingerprint(room: RoomData) -> String:
	return _fingerprint(to_gameplay_snapshot(room))


static func room_fingerprint(room: RoomData) -> String:
	return _fingerprint(to_room_snapshot(room))


static func capture(room: RoomData) -> Dictionary:
	var properties := {}
	if room == null:
		return {"ok": false, "properties": properties}
	for property_name in RoomIntegrationFieldPolicy.stored_property_names(room):
		if property_name == &"script":
			continue
		properties[str(property_name)] = _copy_value(room.get(property_name))
	return {
		"ok": true,
		"class": room.get_class(),
		"resource_path": room.resource_path,
		"properties": properties,
		"fingerprint": room_fingerprint(room),
	}


static func restore(room: RoomData, snapshot: Dictionary) -> bool:
	if room == null or not bool(snapshot.get("ok", false)):
		return false
	var properties := snapshot.get("properties", {}) as Dictionary
	var available := {}
	for property_name in RoomIntegrationFieldPolicy.stored_property_names(room):
		available[str(property_name)] = true
	for property_name in properties:
		if not available.has(str(property_name)) or property_name == "script":
			continue
		room.set(StringName(property_name), _copy_value(properties[property_name]))
	return room_fingerprint(room) == str(snapshot.get("fingerprint", ""))


static func to_runtime_projection(room: RoomData) -> ArenaRuntimeState:
	return ArenaRuntimeProjectionService.build(room as ArenaDefinition) \
		if room is ArenaDefinition else null


static func _fingerprint(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot, "", true).sha256_text()


static func _copy_value(value: Variant) -> Variant:
	if value is Resource:
		var resource := value as Resource
		if not resource.resource_path.is_empty() and "::" not in resource.resource_path:
			return resource
		return resource.duplicate(true)
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	if value is PackedByteArray or value is PackedInt32Array \
			or value is PackedInt64Array or value is PackedFloat32Array \
			or value is PackedFloat64Array or value is PackedStringArray \
			or value is PackedVector2Array or value is PackedVector3Array \
			or value is PackedColorArray:
		return value.duplicate()
	return value
