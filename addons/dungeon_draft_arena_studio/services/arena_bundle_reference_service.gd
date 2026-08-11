@tool
class_name ArenaBundleReferenceService
extends RefCounted

## Autorite de lecture des usages d'un bundle. Les references Resource/RunData
## sont bloquantes pour les mutations ; les transactions actives sont exposees
## separement afin de ne pas confondre historique et usage canonique.

const TERMINAL_TRANSACTION_STATES := [
	"COMMITTED", "FINALIZED", "ROLLED_BACK", "ROLLED_BACK_BY_INTEGRATION",
	"FINAL_VERIFICATION_ROLLBACK", "STAGING_FAILED",
	"STAGING_VERIFICATION_FAILED", "BEFORE_COMMIT_FAILED",
	"BACKUP_FAILED", "COMMIT_FAILED",
]

static var _transaction_index := {}
static var _transaction_directory_count := -1
static var _transaction_cache_dirty := true


static func inspect(
		arena_path: String,
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	var canonical: Array[Dictionary] = []
	var run_references: Array[Dictionary] = []
	var seen := {}
	if graph != null:
		for edge_value in graph.usages(arena_path):
			var edge := edge_value as Dictionary
			var normalized := _normalized_edge(edge)
			_append_unique(canonical, normalized, seen)
			if StringName(normalized.get("relation", &"")) == &"ROOM_AT":
				run_references.append(normalized.duplicate(true))
	var graph_ready := graph != null and (
		not graph.nodes.is_empty() or not graph.incoming.is_empty()
	)
	if not graph_ready:
		for run_data in RunContentCatalogService.discover_runs():
			if run_data == null:
				continue
			for room_index in range(run_data.rooms.size()):
				var room := run_data.rooms[room_index]
				if room == null or room.resource_path != arena_path:
					continue
				var usage := {
					"from": run_data.resource_path,
					"to": arena_path,
					"relation": &"ROOM_AT",
					"metadata": {"index": room_index},
					"run_path": run_data.resource_path,
					"run_name": run_data.run_name,
					"room_index": room_index,
					"room_number": room_index + 1,
				}
				if _append_unique(canonical, usage, seen):
					run_references.append(usage.duplicate(true))
	var transactions := _transaction_references(arena_path)
	var active_transactions: Array[Dictionary] = []
	for transaction in transactions:
		if bool(transaction.get("active", false)):
			active_transactions.append(transaction.duplicate(true))
	return {
		"ok": true,
		"arena_path": arena_path,
		"canonical_references": canonical,
		"run_references": run_references,
		"transaction_references": transactions,
		"active_transaction_references": active_transactions,
		"referenced": not canonical.is_empty(),
		"busy": not active_transactions.is_empty(),
		"canonical_count": canonical.size(),
		"transaction_count": transactions.size(),
	}


static func _normalized_edge(edge: Dictionary) -> Dictionary:
	var metadata := (edge.get("metadata", {}) as Dictionary).duplicate(true)
	var relation := StringName(edge.get("relation", &"RESOURCE_REFERENCE"))
	var room_index := int(metadata.get("index", -1)) if relation == &"ROOM_AT" else -1
	return {
		"from": str(edge.get("from", "")),
		"to": str(edge.get("to", "")),
		"relation": relation,
		"metadata": metadata,
		"run_path": str(edge.get("from", "")) if relation == &"ROOM_AT" else "",
		"run_name": "",
		"room_index": room_index,
		"room_number": room_index + 1 if room_index >= 0 else 0,
	}


static func _append_unique(
		target: Array[Dictionary],
		usage: Dictionary,
		seen: Dictionary
	) -> bool:
	var key := "%s|%s|%s|%s" % [
		usage.get("from", ""), usage.get("to", ""),
		usage.get("relation", ""), usage.get("room_index", -1),
	]
	if seen.has(key):
		return false
	seen[key] = true
	target.append(usage.duplicate(true))
	return true


static func _transaction_references(destination: String) -> Array[Dictionary]:
	var root := ArenaProductionTransactionService.TRANSACTION_ROOT
	var access := DirAccess.open(ProjectSettings.globalize_path(root))
	if access == null:
		_transaction_index.clear()
		_transaction_directory_count = 0
		_transaction_cache_dirty = false
		return []
	var children := access.get_directories()
	if _transaction_cache_dirty or children.size() != _transaction_directory_count:
		_rebuild_transaction_index(root, children)
	var key := destination.get_base_dir()
	var result: Array[Dictionary] = []
	for value in _transaction_index.get(key, []):
		result.append((value as Dictionary).duplicate(true))
	return result


static func invalidate_transaction_cache() -> void:
	_transaction_cache_dirty = true


static func _rebuild_transaction_index(root: String, children: PackedStringArray) -> void:
	_transaction_index.clear()
	_transaction_directory_count = children.size()
	_transaction_cache_dirty = false
	for child in children:
		var report_path := root.path_join(child).path_join("transaction_report.json")
		var report := ArenaProductionService._read_json(report_path)
		if report.is_empty():
			continue
		var status := str(report.get("status", "UNKNOWN"))
		var destination := str(report.get("destination", ""))
		if destination.is_empty():
			continue
		if not _transaction_index.has(destination):
			_transaction_index[destination] = []
		(_transaction_index[destination] as Array).append({
			"transaction_id": report.get("transaction_id", child),
			"report_path": report_path,
			"destination": destination,
			"status": status,
			"active": not status in TERMINAL_TRANSACTION_STATES,
		})
	for destination in _transaction_index:
		(_transaction_index[destination] as Array).sort_custom(
			func(a: Dictionary, b: Dictionary):
				return str(a.get("report_path", "")) < str(b.get("report_path", ""))
		)
