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


static func _materialize_staged_visual_assets(arena: ArenaDefinition) -> Error:
	const STAGING_ROOT := "user://dungeon_draft_studio/backdrop_staging/"
	var properties := ["background_path", "foreground_path", "occlusion_mask_path"]
	for property_name in properties:
		var source_path := str(arena.get(property_name))
		if source_path.is_empty() or not source_path.begins_with("user://"):
			continue
		if not source_path.begins_with(STAGING_ROOT):
			return ERR_INVALID_PARAMETER
		if not FileAccess.file_exists(source_path):
			return ERR_FILE_NOT_FOUND
	var target_dir := "res://data/arenas/assets/%s" % ArenaDefinition.sanitize_id(
		str(arena.arena_id)
	)
	var absolute_dir := ProjectSettings.globalize_path(target_dir)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK:
		return directory_error
	for property_name in properties:
		var source_path := str(arena.get(property_name))
		if not source_path.begins_with(STAGING_ROOT):
			continue
		var file_name := source_path.get_file() if property_name == "background_path" \
			else "%s_%s" % [property_name.trim_suffix("_path"), source_path.get_file()]
		var target := target_dir.path_join(file_name)
		var bytes := FileAccess.get_file_as_bytes(source_path)
		if bytes.is_empty():
			return FileAccess.get_open_error()
		var output := FileAccess.open(target, FileAccess.WRITE)
		if output == null:
			return FileAccess.get_open_error()
		output.store_buffer(bytes)
		output.close()
		arena.set(property_name, target)
	for property_name in properties:
		if str(arena.get(property_name)).begins_with("user://"):
			return ERR_INVALID_PARAMETER
	return OK


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


static func save_recovery(arena: ArenaDefinition) -> Error:
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
