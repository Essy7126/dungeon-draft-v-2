@tool
class_name ArenaSerializer
extends RefCounted

const CANONICAL_ROOT := "res://data/arenas"
const RECOVERY_ROOT := "user://dungeon_draft_studio/arena_studio/recovery"
const LEGACY_RECOVERY_ROOT := "user://arena_studio/recovery"
const PRODUCTION_VISUAL_ROOT := "res://data/maps/painted"


static func suggested_path(arena: ArenaDefinition) -> String:
	return CANONICAL_ROOT.path_join(str(arena.arena_id) + ".tres")


static func save_canonical(arena: ArenaDefinition, path := "") -> Error:
	if arena == null:
		return ERR_INVALID_PARAMETER
	if path.is_empty():
		path = suggested_path(arena)
	if not path.begins_with("res://") or not path.ends_with(".tres"):
		return ERR_INVALID_PARAMETER
	var backdrop_error := _materialize_staged_visual_assets(arena)
	if backdrop_error != OK:
		return backdrop_error
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var absolute := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return directory_error
	var save_error := ResourceSaver.save(arena, path)
	return save_error


const STAGING_ROOT := "user://dungeon_draft_studio/backdrop_staging/"
const STAGED_VISUAL_PROPERTIES := [
	"background_path", "foreground_path", "occlusion_mask_path",
]


## Plan de materialisation, sans aucune ecriture ni mutation. Il permet a la
## transaction de sauvegarde d'annoncer les fichiers crees avant de toucher au
## disque, et de savoir quoi supprimer en cas de rollback.
static func plan_staged_visual_assets(arena: ArenaDefinition) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "no_arena", "mapping": {}, "sources": {}}
	var target_dir := "res://data/arenas/assets/%s" % ArenaDefinition.sanitize_id(
		str(arena.arena_id)
	)
	var mapping := {}
	var sources := {}
	for property_name in STAGED_VISUAL_PROPERTIES:
		var source_path := str(arena.get(property_name))
		if source_path.is_empty() or not source_path.begins_with("user://"):
			continue
		if not source_path.begins_with(STAGING_ROOT):
			return {
				"ok": false, "error": "unowned_user_path",
				"property": property_name, "mapping": {}, "sources": {},
			}
		if not FileAccess.file_exists(source_path):
			return {
				"ok": false, "error": "staged_file_missing",
				"property": property_name, "mapping": {}, "sources": {},
			}
		var file_name := source_path.get_file() if property_name == "background_path" \
			else "%s_%s" % [property_name.trim_suffix("_path"), source_path.get_file()]
		mapping[property_name] = target_dir.path_join(file_name)
		sources[property_name] = source_path
	return {
		"ok": true, "error": "", "mapping": mapping, "sources": sources,
		"directory": target_dir,
	}


## Copie les images mises en attente. `apply` decide si les nouveaux chemins
## sont reportes sur `arena` : une transaction preferera materialiser sur une
## copie de publication et ne toucher au document edite qu'apres verification.
## En cas d'echec en cours de route, les fichiers deja crees sont supprimes :
## aucun asset partiel ne subsiste.
static func materialize_staged_visual_assets(
		arena: ArenaDefinition,
		apply := true
	) -> Dictionary:
	var plan := plan_staged_visual_assets(arena)
	if not bool(plan.get("ok", false)):
		return plan.merged({"created": PackedStringArray()}, true)
	var mapping := plan.mapping as Dictionary
	var created := PackedStringArray()
	if mapping.is_empty():
		return {"ok": true, "error": "", "mapping": mapping, "created": created}
	var absolute_dir := ProjectSettings.globalize_path(str(plan.directory))
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK:
		return {
			"ok": false, "error": "directory_failed", "code": directory_error,
			"mapping": mapping, "created": created,
		}
	for property_name in mapping:
		var source_path := str((plan.sources as Dictionary)[property_name])
		var target := str(mapping[property_name])
		var existed := FileAccess.file_exists(ProjectSettings.globalize_path(target))
		var bytes := FileAccess.get_file_as_bytes(source_path)
		var output := FileAccess.open(target, FileAccess.WRITE) if not bytes.is_empty() else null
		if bytes.is_empty() or output == null:
			_remove_created(created)
			return {
				"ok": false, "error": "copy_failed", "property": property_name,
				"mapping": mapping, "created": PackedStringArray(),
			}
		output.store_buffer(bytes)
		output.close()
		if not existed:
			created.append(target)
	if apply:
		for property_name in mapping:
			arena.set(property_name, str(mapping[property_name]))
	return {"ok": true, "error": "", "mapping": mapping, "created": created}


static func _remove_created(created: PackedStringArray) -> void:
	for path in created:
		var absolute := ProjectSettings.globalize_path(str(path))
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


## Compatibilite : ancienne signature retournant un Error. Elle delegue
## desormais au chemin non partiel ci-dessus.
static func _materialize_staged_visual_assets(arena: ArenaDefinition) -> Error:
	var result := materialize_staged_visual_assets(arena, true)
	if bool(result.get("ok", false)):
		return OK
	match str(result.get("error", "")):
		"staged_file_missing":
			return ERR_FILE_NOT_FOUND
		"directory_failed":
			return int(result.get("code", ERR_CANT_CREATE)) as Error
		"copy_failed":
			return ERR_FILE_CANT_WRITE
	return ERR_INVALID_PARAMETER


static func load_canonical(path: String) -> ArenaDefinition:
	if not ResourceLoader.exists(path):
		return null
	# Une sauvegarde canonique doit relire les octets qui viennent d'être écrits,
	# pas une instance de ResourceLoader antérieure à une migration de schéma.
	var arena := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if arena != null:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


static func save_production_calibration(
		arena: ArenaDefinition,
		visual_path: String
	) -> Error:
	if arena == null or not _is_allowed_visual_path(visual_path):
		return ERR_INVALID_PARAMETER
	var visual := ResourceLoader.load(
		visual_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as PaintedMapVisualData
	if visual == null or visual.map_id != arena.arena_id:
		return ERR_INVALID_DATA
	visual.grid_origin = arena.grid_origin
	visual.axis_x = arena.axis_x
	visual.axis_y = arena.axis_y
	visual.calibration_cells = arena.calibration_cells.duplicate()
	visual.calibration_pixels = arena.calibration_pixels.duplicate()
	return ResourceSaver.save(visual, visual_path)


static func visual_calibration_fingerprint(path: String) -> String:
	if not ResourceLoader.exists(path):
		return ""
	var visual := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as PaintedMapVisualData
	return JSON.stringify(visual_calibration_snapshot(visual)).sha256_text() \
		if visual != null else ""


static func visual_calibration_snapshot(visual: PaintedMapVisualData) -> Dictionary:
	if visual == null:
		return {}
	return {
		"map_id": str(visual.map_id),
		"grid_origin": [visual.grid_origin.x, visual.grid_origin.y],
		"axis_x": [visual.axis_x.x, visual.axis_x.y],
		"axis_y": [visual.axis_y.x, visual.axis_y.y],
		"calibration_cells": visual.calibration_cells.map(
			func(value): return [value.x, value.y]
		),
		"calibration_pixels": visual.calibration_pixels.map(
			func(value): return [value.x, value.y]
		),
	}


static func production_visual_matches(arena: ArenaDefinition, path: String) -> bool:
	if arena == null or not ResourceLoader.exists(path):
		return false
	var visual := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as PaintedMapVisualData
	if visual == null:
		return false
	var expected := GridTransformSnapshot.from_arena(arena)
	var actual := GridTransformSnapshot.new(
		visual.grid_origin, visual.axis_x, visual.axis_y
	)
	return expected.is_equal_to(actual) \
		and visual.calibration_cells == arena.calibration_cells \
		and visual.calibration_pixels == arena.calibration_pixels


static func save_recovery(arena: ArenaDefinition, context := {}) -> Error:
	if arena == null:
		return ERR_INVALID_PARAMETER
	var path := recovery_path(arena.arena_id)
	var absolute := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var snapshot := arena.to_snapshot()
	snapshot["_studio_product_version"] = StudioVersion.PRODUCT_VERSION
	snapshot["_generated_by"] = StudioVersion.GENERATED_BY
	var recovery_context := (
		(context as Dictionary).duplicate(true) if context is Dictionary else {}
	)
	recovery_context["domain"] = StringName(recovery_context.get("domain", &"arena"))
	recovery_context["arena_id"] = str(arena.arena_id)
	recovery_context["source"] = str(recovery_context.get("source", path))
	recovery_context["status"] = str(recovery_context.get("status", "RECOVERABLE"))
	snapshot["_recovery_context"] = recovery_context
	snapshot["_recovery_saved_at_unix"] = int(Time.get_unix_time_from_system())
	file.store_string(JSON.stringify(snapshot, "  "))
	return OK


static func load_recovery(path: String) -> ArenaDefinition:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	var arena := ArenaDefinition.new()
	if not arena.restore_snapshot(parsed):
		return null
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


static func recovery_path(arena_id: StringName) -> String:
	return RECOVERY_ROOT.path_join(str(arena_id) + ".json")


static func recovery_files() -> PackedStringArray:
	var result := PackedStringArray()
	for root in [RECOVERY_ROOT, LEGACY_RECOVERY_ROOT]:
		var directory := DirAccess.open(root)
		if directory == null:
			continue
		for file_name in directory.get_files():
			if file_name.ends_with(".json"):
				result.append(root.path_join(file_name))
	result.sort()
	return result


static func remove_recovery(arena_id: StringName) -> void:
	for root in [RECOVERY_ROOT, LEGACY_RECOVERY_ROOT]:
		var absolute := ProjectSettings.globalize_path(
			root.path_join(str(arena_id) + ".json")
		)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


static func _is_allowed_visual_path(path: String) -> bool:
	return path.ends_with(".tres") and (
		path.begins_with(PRODUCTION_VISUAL_ROOT + "/") \
		or path.begins_with("user://dungeon_draft_studio/arena_studio/tests/")
	)
