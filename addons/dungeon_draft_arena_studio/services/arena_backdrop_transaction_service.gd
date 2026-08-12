@tool
class_name ArenaBackdropTransactionService
extends RefCounted

enum CopyMode { BACKGROUND_ONLY, DECOR_CALIBRATION_CAMERA, FULL_VISUAL_PACK }

var recovery_snapshot := {}


func inspect(
		arena: ArenaDefinition,
		source: ArenaBackdropSourceDefinition,
		mode: CopyMode
	) -> Dictionary:
	if arena == null or source == null or not source.is_loadable():
		return {"ok": false, "error": "source_not_loadable"}
	var actual_size := _image_size(source.background_path)
	if actual_size == Vector2i.ZERO:
		return {"ok": false, "error": "background_texture_failed"}
	return {
		"ok": true,
		"mode": mode,
		"source": source.to_summary(),
		"actual_image_size": actual_size,
		"dimensions_differ": arena.source_image_size != actual_size,
		"cell_count": arena.cells.size(),
		"gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
		"calibration_delta": {
			"origin": arena.grid_origin.distance_to(source.grid_origin),
			"axis_x": arena.axis_x.distance_to(source.axis_x),
			"axis_y": arena.axis_y.distance_to(source.axis_y),
		},
	}


func apply(
		arena: ArenaDefinition,
		source: ArenaBackdropSourceDefinition,
		mode: CopyMode
	) -> Dictionary:
	var inspection := inspect(arena, source, mode)
	if not bool(inspection.get("ok", false)):
		return inspection
	recovery_snapshot = arena.to_snapshot().duplicate(true)
	var gameplay_before := ArenaSnapshotService.gameplay_fingerprint(arena)
	arena.background_path = source.background_path
	arena.source_image_size = source.source_image_size
	if mode >= CopyMode.DECOR_CALIBRATION_CAMERA:
		arena.grid_origin = source.grid_origin
		arena.axis_x = source.axis_x
		arena.axis_y = source.axis_y
		arena.image_offset = source.image_offset
		arena.image_scale = source.image_scale
		arena.camera_offset = source.camera_offset
		arena.camera_zoom = source.camera_zoom
	if mode == CopyMode.FULL_VISUAL_PACK:
		arena.foreground_path = source.foreground_path
		arena.occlusion_mask_path = source.occlusion_mask_path
		arena.foreground_offset = source.foreground_offset
		arena.foreground_scale = source.foreground_scale
		arena.foreground_occluder_polygon = source.foreground_occluder_polygon.duplicate()
		arena.foreground_occluder_sort_y = source.foreground_occluder_sort_y
		arena.foreground_full_hide_rect = source.foreground_full_hide_rect
		if not source.presentation_profile_path.is_empty():
			arena.presentation_profile_path = source.presentation_profile_path
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var gameplay_after := ArenaSnapshotService.gameplay_fingerprint(arena)
	if gameplay_after != gameplay_before:
		arena.restore_snapshot(recovery_snapshot)
		ArenaRuntimeBridge.sync_runtime_resources(arena)
		return {"ok": false, "error": "gameplay_fingerprint_changed"}
	return {
		"ok": true,
		"before": recovery_snapshot.duplicate(true),
		"after": arena.to_snapshot(),
		"gameplay_before": gameplay_before,
		"gameplay_after": gameplay_after,
		"visual_changed": ArenaEditSession.fingerprint(recovery_snapshot) \
			!= ArenaEditSession.fingerprint(arena.to_snapshot()),
	}


func restore(arena: ArenaDefinition) -> bool:
	if arena == null or recovery_snapshot.is_empty():
		return false
	var restored := arena.restore_snapshot(recovery_snapshot)
	if restored:
		ArenaRuntimeBridge.sync_runtime_resources(arena)
	return restored


static func stage_external_image(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "error": "external_file_missing"}
	var bytes := FileAccess.get_file_as_bytes(path)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var digest := hashing.finish().hex_encode()
	var extension := path.get_extension().to_lower()
	if not extension in ["png", "jpg", "jpeg", "webp"]:
		return {"ok": false, "error": "unsupported_extension"}
	var target := "user://dungeon_draft_studio/backdrop_staging/%s.%s" % [digest, extension]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	var output := FileAccess.open(target, FileAccess.WRITE)
	if output == null:
		return {"ok": false, "error": "staging_write_failed"}
	output.store_buffer(bytes)
	output.close()
	return {"ok": true, "staged_path": target, "sha256": digest}


static func _image_size(path: String) -> Vector2i:
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		return Vector2i(texture.get_size()) if texture != null else Vector2i.ZERO
	if path.begins_with("user://") or path.is_absolute_path():
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		return image.get_size() if image != null and not image.is_empty() else Vector2i.ZERO
	return Vector2i.ZERO
