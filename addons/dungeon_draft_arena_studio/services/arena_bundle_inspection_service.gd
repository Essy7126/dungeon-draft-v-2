@tool
class_name ArenaBundleInspectionService
extends RefCounted

const EMPTY := &"EMPTY"
const OWNED_CLEAN := &"OWNED_CLEAN"
# Compatibility name retained for callers compiled against Studio 2.0. New
# reports deliberately expose OWNED_CLEAN so the ownership verdict is literal.
const OWNED_COMPLETE := OWNED_CLEAN
const OWNED_INCOMPLETE := &"OWNED_INCOMPLETE"
const OWNED_DIRTY := &"OWNED_DIRTY"
const REFERENCED_COMPLETE := &"REFERENCED_COMPLETE"
const REFERENCED_INCOMPLETE := &"REFERENCED_INCOMPLETE"
const FOREIGN_CONTENT := &"FOREIGN_CONTENT"
const CORRUPT_MANIFEST := &"CORRUPT_MANIFEST"
const LEGACY_BUNDLE := &"LEGACY_BUNDLE"
const LEGACY_LOGICAL_FINGERPRINT := &"LEGACY_LOGICAL_FINGERPRINT"
const UNKNOWN := &"UNKNOWN"


static func inspect(
		directory: String,
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	var files := _files(directory)
	if files.is_empty():
		return _report(directory, EMPTY, files, {}, [], [], [])
	var manifest_path := directory.path_join(ArenaProductionService.MANIFEST_FILE)
	var reference_report := _inspect_bundle_references(directory, files, graph)
	var references: Array = reference_report.get("canonical_references", [])
	if files.has("arena_principal.tres") and not files.has("arena.tres"):
		return _report(directory, LEGACY_BUNDLE, files, {}, [], [], references, [], reference_report)
	if not FileAccess.file_exists(manifest_path):
		var structural_owned := files.has("arena.tres")
		var state := OWNED_INCOMPLETE if structural_owned else FOREIGN_CONTENT
		if not references.is_empty() and structural_owned:
			state = REFERENCED_INCOMPLETE
		return _report(directory, state, files, {}, ["production_manifest.json"], [], references, [], reference_report)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(manifest_path)) != OK:
		return _report(directory, CORRUPT_MANIFEST, files, {}, [], [], references, [], reference_report)
	var parsed = parser.data
	if not parsed is Dictionary:
		return _report(directory, CORRUPT_MANIFEST, files, {}, [], [], references, [], reference_report)
	var manifest := parsed as Dictionary
	if not ArenaProductionService.COMPATIBLE_GENERATORS.has(
			str(manifest.get("generated_by", ""))
		):
		return _report(directory, FOREIGN_CONTENT, files, manifest, [], [], references, [], reference_report)
	var schema_version := int(manifest.get(
		"manifest_schema_version", manifest.get("version", 0)
	))
	var physical_hash_value: Variant = manifest.get("physical_file_hash", null)
	if schema_version >= ArenaProductionService.MANIFEST_SCHEMA_VERSION \
			and not physical_hash_value is Dictionary:
		return _report(directory, CORRUPT_MANIFEST, files, manifest, [], [], references, [], reference_report)
	if not physical_hash_value is Dictionary:
		physical_hash_value = manifest.get("files", {})
	if not physical_hash_value is Dictionary:
		return _report(directory, CORRUPT_MANIFEST, files, manifest, [], [], references, [], reference_report)
	var expected := physical_hash_value as Dictionary
	var missing := PackedStringArray()
	var dirty := PackedStringArray()
	for relative_path in expected:
		if not files.has(str(relative_path)):
			missing.append(str(relative_path))
		elif str((files[str(relative_path)] as Dictionary).sha256) \
				!= str(expected[relative_path]):
			dirty.append(str(relative_path))
	if not files.has("arena.tres"):
		missing.append("arena.tres")
	var allowed := {"production_manifest.json": true}
	for relative_path in expected:
		allowed[str(relative_path)] = true
	var foreign := PackedStringArray()
	for relative_path in files:
		# Godot owns these deterministic import sidecars. They are neither
		# production payload nor foreign user content and never enter hashes.
		if str(relative_path).ends_with(".import"):
			continue
		if not allowed.has(str(relative_path)):
			foreign.append(str(relative_path))
	var state := OWNED_CLEAN
	var manifest_complete := bool(manifest.get("complete", false))
	var current_logical_contract := schema_version \
			>= ArenaProductionService.MANIFEST_SCHEMA_VERSION \
		and str(manifest.get("fingerprint_algorithm_id", "")) \
			== ArenaProductionService.FINGERPRINT_ALGORITHM_ID
	if current_logical_contract and not manifest_complete:
		missing.append("manifest:complete")
	if not missing.is_empty():
		state = REFERENCED_INCOMPLETE if not references.is_empty() else OWNED_INCOMPLETE
	elif not dirty.is_empty() or not foreign.is_empty():
		state = OWNED_DIRTY
	elif not current_logical_contract:
		# A physically intact v1/v2 bundle is neither dirty nor current. It needs
		# an explicit, backed-up manifest migration before being writable again.
		state = LEGACY_LOGICAL_FINGERPRINT
	else:
		_append_logical_fingerprint_issues(directory, manifest, dirty)
		if not dirty.is_empty():
			state = OWNED_DIRTY
		elif not references.is_empty():
			state = REFERENCED_COMPLETE
	return _report(
		directory, state, files, manifest, missing, dirty, references, foreign,
		reference_report
	)


static func _append_logical_fingerprint_issues(
		directory: String,
		manifest: Dictionary,
		dirty: PackedStringArray
	) -> void:
	var arena := ResourceLoader.load(
		directory.path_join("arena.tres"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if arena == null:
		dirty.append("arena.tres:resource_load")
		return
	if ArenaSnapshotService.arena_fingerprint(arena) \
			!= str(manifest.get("logical_arena_fingerprint", "")):
		dirty.append("logical_arena_fingerprint")
	if ArenaSnapshotService.gameplay_fingerprint(arena) \
			!= str(manifest.get("gameplay_fingerprint", "")):
		dirty.append("gameplay_fingerprint")


static func _inspect_bundle_references(
		directory: String,
		files: Dictionary,
		graph: StudioReferenceGraphService
	) -> Dictionary:
	var resource_paths := PackedStringArray()
	for file_name in ["arena.tres", "arena_principal.tres"]:
		if files.has(file_name):
			resource_paths.append(directory.path_join(file_name))
	var canonical: Array[Dictionary] = []
	var run_references: Array[Dictionary] = []
	var transactions: Array[Dictionary] = []
	var active_transactions: Array[Dictionary] = []
	var canonical_seen := {}
	var run_seen := {}
	var transaction_seen := {}
	var active_transaction_seen := {}
	for resource_path in resource_paths:
		var report := ArenaBundleReferenceService.inspect(resource_path, graph)
		_append_unique_references(
			canonical, report.get("canonical_references", []), canonical_seen
		)
		_append_unique_references(
			run_references, report.get("run_references", []), run_seen
		)
		_append_unique_references(
			transactions, report.get("transaction_references", []), transaction_seen
		)
		_append_unique_references(
			active_transactions,
			report.get("active_transaction_references", []),
			active_transaction_seen
		)
	return {
		"ok": true,
		"arena_path": resource_paths[0] if not resource_paths.is_empty() else "",
		"arena_paths": resource_paths,
		"canonical_references": canonical,
		"run_references": run_references,
		"transaction_references": transactions,
		"active_transaction_references": active_transactions,
		"referenced": not canonical.is_empty(),
		"busy": not active_transactions.is_empty(),
		"canonical_count": canonical.size(),
		"transaction_count": transactions.size(),
	}


static func _append_unique_references(
		target: Array[Dictionary],
		values: Array,
		seen: Dictionary
	) -> void:
	for value in values:
		var entry := (value as Dictionary).duplicate(true)
		var key := "%s|%s|%s|%s|%s" % [
			entry.get("from", ""), entry.get("to", ""),
			entry.get("relation", ""), entry.get("room_index", -1),
			entry.get("transaction_id", ""),
		]
		if seen.has(key):
			continue
		seen[key] = true
		target.append(entry)


static func _files(directory: String) -> Dictionary:
	var result := {}
	_collect(directory, directory, result)
	return result


static func _collect(root: String, current: String, result: Dictionary) -> void:
	var access := DirAccess.open(ProjectSettings.globalize_path(current))
	if access == null:
		return
	for file_name in access.get_files():
		var path := current.path_join(file_name)
		var relative := path.trim_prefix(root.trim_suffix("/") + "/")
		result[relative] = {
			"size": FileAccess.get_file_as_bytes(path).size(),
			"sha256": FileAccess.get_sha256(path),
		}
	for child in access.get_directories():
		_collect(root, current.path_join(child), result)


static func _report(
		directory: String,
		state: StringName,
		files: Dictionary,
		manifest: Dictionary,
		missing: Variant,
		dirty: Variant,
		references: Array,
		foreign: Variant = PackedStringArray(),
	reference_report: Dictionary = {}
	) -> Dictionary:
	var owned_manifest_state := state in [
		OWNED_CLEAN, OWNED_INCOMPLETE, OWNED_DIRTY,
		REFERENCED_COMPLETE, REFERENCED_INCOMPLETE,
		LEGACY_LOGICAL_FINGERPRINT,
	]
	var physical_complete := owned_manifest_state \
		and _collection_is_empty(missing) and _collection_is_empty(dirty)
	return {
		"ok": state not in [CORRUPT_MANIFEST, UNKNOWN],
		"directory": directory,
		"state": state,
		"files": files,
		"manifest": manifest,
		"missing": missing,
		"dirty": dirty,
		"foreign": foreign,
		"references": references,
		"reference_report": reference_report,
		"referenced": not references.is_empty(),
		"transaction_active": bool(reference_report.get("busy", false)),
		"physical_complete": physical_complete,
		"logical_fingerprint_legacy": state == LEGACY_LOGICAL_FINGERPRINT,
		"complete": state in [OWNED_CLEAN, REFERENCED_COMPLETE],
	}


static func _collection_is_empty(value: Variant) -> bool:
	if value is Array:
		return (value as Array).is_empty()
	if value is PackedStringArray:
		return (value as PackedStringArray).is_empty()
	return false
