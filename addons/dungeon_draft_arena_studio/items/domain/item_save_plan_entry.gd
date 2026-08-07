@tool
class_name ItemSavePlanEntry
extends RefCounted

var source_path := ""
var destination_path := ""
var operation: StringName = &"CREATE"
var status: StringName = &"DRAFT"
var item_id: StringName = &""
var old_fingerprint := ""
var new_fingerprint := ""
var subresource_count := 0


func to_snapshot() -> Dictionary:
	return {
		"source_path": source_path,
		"destination_path": destination_path,
		"operation": str(operation),
		"status": str(status),
		"item_id": str(item_id),
		"old_fingerprint": old_fingerprint,
		"new_fingerprint": new_fingerprint,
		"subresource_count": subresource_count,
	}
