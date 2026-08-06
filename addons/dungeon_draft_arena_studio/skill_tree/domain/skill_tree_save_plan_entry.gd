@tool
class_name SkillTreeSavePlanEntry
extends RefCounted

enum Operation {
	CREATE,
	UPDATE,
	DETACH_REFERENCE,
	ARCHIVE,
	DELETE,
	UNCHANGED,
	ORPHANED,
}

var resource: Resource = null
var source: Resource = null
var source_path := ""
var target_path := ""
var source_fingerprint := ""
var working_fingerprint := ""
var dependencies := PackedStringArray()
var logical_owner := ""
var reachable := false
var operation: Operation = Operation.UNCHANGED
var conflict: SkillTreeSaveConflict = null
var warnings := PackedStringArray()
var can_rollback := true
var write_order := 0
var changes: Array[Dictionary] = []


func is_writable() -> bool:
	return operation in [Operation.CREATE, Operation.UPDATE, Operation.ARCHIVE, Operation.DELETE]


func to_dictionary() -> Dictionary:
	return {
		"resource": resource,
		"source": source,
		"source_path": source_path,
		"target_path": target_path,
		"path": target_path,
		"source_fingerprint": source_fingerprint,
		"working_fingerprint": working_fingerprint,
		"dependencies": dependencies.duplicate(),
		"logical_owner": logical_owner,
		"reachable": reachable,
		"operation": operation,
		"operation_name": Operation.keys()[operation],
		"conflict": conflict.to_dictionary() if conflict != null else {},
		"warnings": warnings.duplicate(),
		"can_rollback": can_rollback,
		"priority": write_order,
		"changes": changes.duplicate(true),
	}
