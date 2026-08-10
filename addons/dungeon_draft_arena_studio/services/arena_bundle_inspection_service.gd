@tool
class_name ArenaBundleInspectionService
extends RefCounted

const EMPTY := &"EMPTY"
const OWNED_COMPLETE := &"OWNED_COMPLETE"
const OWNED_INCOMPLETE := &"OWNED_INCOMPLETE"
const OWNED_DIRTY := &"OWNED_DIRTY"
const REFERENCED_COMPLETE := &"REFERENCED_COMPLETE"
const REFERENCED_INCOMPLETE := &"REFERENCED_INCOMPLETE"
const FOREIGN_CONTENT := &"FOREIGN_CONTENT"
const CORRUPT_MANIFEST := &"CORRUPT_MANIFEST"
const LEGACY_BUNDLE := &"LEGACY_BUNDLE"
const UNKNOWN := &"UNKNOWN"


static func inspect(
		directory: String,
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	var files := _files(directory)
	if files.is_empty():
		return _report(directory, EMPTY, files, {}, [], [], [])
	var manifest_path := directory.path_join(ArenaProductionService.MANIFEST_FILE)
	var references := _references(directory.path_join("arena.tres"), graph)
	if files.has("arena_principal.tres") and not files.has("arena.tres"):
		return _report(directory, LEGACY_BUNDLE, files, {}, [], [], references)
	if not FileAccess.file_exists(manifest_path):
		var structural_owned := files.has("arena.tres")
		var state := OWNED_INCOMPLETE if structural_owned else FOREIGN_CONTENT
		if not references.is_empty() and structural_owned:
			state = REFERENCED_INCOMPLETE
		return _report(directory, state, files, {}, ["production_manifest.json"], [], references)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(manifest_path)) != OK:
		return _report(directory, CORRUPT_MANIFEST, files, {}, [], [], references)
	var parsed = parser.data
	if not parsed is Dictionary:
		return _report(directory, CORRUPT_MANIFEST, files, {}, [], [], references)
	var manifest := parsed as Dictionary
	if not ArenaProductionService.COMPATIBLE_GENERATORS.has(
			str(manifest.get("generated_by", ""))
		):
		return _report(directory, FOREIGN_CONTENT, files, manifest, [], [], references)
	if not manifest.get("files", {}) is Dictionary:
		return _report(directory, CORRUPT_MANIFEST, files, manifest, [], [], references)
	var expected := manifest.get("files", {}) as Dictionary
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
	var complete := missing.is_empty()
	var state := OWNED_COMPLETE
	if not complete:
		state = REFERENCED_INCOMPLETE if not references.is_empty() else OWNED_INCOMPLETE
	elif not dirty.is_empty() or not foreign.is_empty():
		state = OWNED_DIRTY
	elif not references.is_empty():
		state = REFERENCED_COMPLETE
	return _report(directory, state, files, manifest, missing, dirty, references, foreign)


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


static func _references(
		arena_path: String,
		graph: StudioReferenceGraphService
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph != null:
		for usage in graph.usages(arena_path):
			result.append(usage)
		if not result.is_empty():
			return result
	for run in RunContentCatalogService.discover_runs():
		if run == null:
			continue
		for index in range(run.rooms.size()):
			var room := run.rooms[index]
			if room != null and room.resource_path == arena_path:
				result.append({
					"run_path": run.resource_path,
					"run_name": run.run_name,
					"room_index": index,
					"room_path": room.resource_path,
				})
	return result


static func _report(
		directory: String,
		state: StringName,
		files: Dictionary,
		manifest: Dictionary,
		missing: Variant,
		dirty: Variant,
		references: Array,
		foreign: Variant = PackedStringArray()
	) -> Dictionary:
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
		"referenced": not references.is_empty(),
		"complete": state in [OWNED_COMPLETE, REFERENCED_COMPLETE],
	}
