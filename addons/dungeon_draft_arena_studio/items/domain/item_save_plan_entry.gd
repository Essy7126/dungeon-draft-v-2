@tool
class_name ItemSavePlanEntry
extends RefCounted

var source_path := ""
var destination_path := ""
var operation: StringName = &"CREATE"
var status: StringName = &"DRAFT"
var item_id: StringName = &""
var old_fingerprint := ""
var old_sha256 := ""
var target_uid := ""
var source_fingerprint := ""
var source_sha256 := ""
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
		"old_sha256": old_sha256,
		"target_uid": target_uid,
		"source_fingerprint": source_fingerprint,
		"source_sha256": source_sha256,
		"new_fingerprint": new_fingerprint,
		"subresource_count": subresource_count,
	}
