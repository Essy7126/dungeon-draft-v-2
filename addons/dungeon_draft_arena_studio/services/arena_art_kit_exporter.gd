@tool
class_name ArenaArtKitExporter
extends RefCounted

const IMAGE_SIZE := Vector2i(1280, 720)
const MANIFEST_SCHEMA_VERSION := 3
const MANIFEST_FILE := "arena_art_manifest.json"


static func export_kit(
		arena: ArenaDefinition,
		destination: String,
		validation: ArenaValidationReport,
		provided_images := {}
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	if not _valid_destination(destination):
		return {"ok": false, "error": "invalid_destination"}
	var resolution_contract := ArenaArtResolutionContract.from_arena(arena)
	var contract_errors := resolution_contract.validation_errors()
	if not contract_errors.is_empty():
		return {"ok": false, "error": "resolution_contract_invalid", "details": contract_errors}
	var absolute := ProjectSettings.globalize_path(destination)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute)
	if directory_error != OK:
		return {"ok": false, "error": error_string(directory_error)}
	var images := {
		"map_reference.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_clean", resolution_contract),
		"map_clean.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_clean", resolution_contract),
		"map_logic.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_gameplay", resolution_contract),
		"map_grid.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_grid", resolution_contract),
		"map_game_preview.png": ArenaArtProjectionRenderer.render_pass(arena, &"map_game_preview", resolution_contract),
		"reference_clean.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_clean", resolution_contract),
		"reference_grid.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_grid", resolution_contract),
		"reference_coordinates.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_coordinates", resolution_contract),
		"reference_gameplay.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_gameplay", resolution_contract),
		"reference_walls.png": ArenaArtProjectionRenderer.render_pass(arena, &"reference_walls", resolution_contract),
		"playable_mask.png": ArenaArtProjectionRenderer.render_pass(arena, &"playable_mask", resolution_contract),
		"void_mask.png": ArenaArtProjectionRenderer.render_pass(arena, &"void_mask", resolution_contract),
		"wall_mask.png": ArenaArtProjectionRenderer.render_pass(arena, &"wall_mask", resolution_contract),
		"foreground_guide.png": ArenaArtProjectionRenderer.render_pass(arena, &"foreground_guide", resolution_contract),
		"depth_guide.png": ArenaArtProjectionRenderer.render_pass(arena, &"depth_guide", resolution_contract),
		"alignment_markers.png": ArenaArtProjectionRenderer.render_pass(arena, &"alignment_markers", resolution_contract),
	}
	var export_size := resolution_contract.reference_export_size
	for file_name in images:
		var supplied = provided_images.get(file_name)
		if supplied is Image and not supplied.is_empty():
			if supplied.get_size() != export_size:
				return {
					"ok": false,
					"error": "provided_image_resolution_mismatch",
					"file": file_name,
					"expected": export_size,
					"actual": supplied.get_size(),
				}
			images[file_name] = supplied
		var image_value := images[file_name] as Image
		var image_error := image_value.save_png(
			ProjectSettings.globalize_path(destination.path_join(file_name))
		)
		if image_error != OK:
			return {"ok": false, "error": error_string(image_error), "file": file_name}
	var clone := ArenaDefinition.new()
	if not ArenaSnapshotService.restore(clone, ArenaSnapshotService.capture(arena)):
		return {"ok": false, "error": "snapshot_restore_failed"}
	ArenaRuntimeBridge.sync_runtime_resources(clone)
	var save_error := ResourceSaver.save(clone, destination.path_join("arena_definition.tres"))
	if save_error != OK:
		return {"ok": false, "error": error_string(save_error)}
	var report_data := validation.to_dict() if validation != null else {}
	report_data["generated_at"] = ""
	if not _write_text(destination.path_join("validation_report.json"), JSON.stringify(report_data, "  ")):
		return {"ok": false, "error": "validation_write_failed"}
	var brief := PackedStringArray([
		"DUNGEON DRAFT — KIT ARTISTIQUE",
		"",
		"Salle : %s (%s)" % [arena.display_name, arena.arena_id],
		"Mode visuel : %s" % ["PAINTED", "MODULAR", "HYBRID"][arena.visual_mode],
		"Grille : %d x %d" % [arena.grid_size.x, arena.grid_size.y],
		"Thème : %s" % arena.theme_id,
		"",
		"arena_definition.tres reste la source de vérité gameplay.",
		"Les PNG sont des références artistiques et ne doivent jamais être importés comme logique.",
		"Conserver la topologie, les ancres, les spawns, les objectifs et les zones d'occlusion.",
	])
	brief.append_array([
		"",
		"CONTRAINTES ROUND-TRIP",
		"- Ne pas recadrer ni modifier la resolution.",
		"- Ne pas modifier la perspective ou deplacer la plateforme.",
		"- Respecter les murs, zones jouables et la lisibilite tactique.",
		"- Livrer background.png et, si necessaire, foreground.png.",
		"- Le masque d'occlusion est un guide artistique ; le runtime utilise le foreground et son polygone.",
	])
	var brief_text := "\n".join(brief)
	if not _write_text(destination.path_join("art_brief.txt"), brief_text) \
			or not _write_text(destination.path_join("art_brief.md"), brief_text):
		return {"ok": false, "error": "brief_write_failed"}
	var files := {}
	for file_name in images:
		var path := destination.path_join(file_name)
		files[file_name] = {
			"sha256": _sha256_file(path),
			"role": _file_role(file_name),
			"resolution": [export_size.x, export_size.y],
		}
	var arena_path := destination.path_join("arena_definition.tres")
	files["arena_definition.tres"] = {
		"sha256": _sha256_file(arena_path),
		"role": "gameplay_authority_snapshot",
	}
	var generated_at := Time.get_datetime_string_from_system(true)
	var manifest := {
		"manifest_version": MANIFEST_SCHEMA_VERSION,
		"schema_version": MANIFEST_SCHEMA_VERSION,
		"studio_product_version": StudioVersion.PRODUCT_VERSION,
		"generated_by": StudioVersion.GENERATED_BY,
		"arena_schema_version": arena.schema_version,
		"arena_id": str(arena.arena_id),
		"display_name": arena.display_name,
		"arena_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
		"gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
		"document_path": arena.resource_path,
		"export_timestamp": generated_at,
		"generated_at": generated_at,
		"resolution_contract": resolution_contract.to_dict(),
		"native_art_size": [export_size.x, export_size.y],
		"canvas_size": [export_size.x, export_size.y],
		"source_image_size": [arena.source_image_size.x, arena.source_image_size.y],
		"resolution": [export_size.x, export_size.y],
		"crop": [0, 0, export_size.x, export_size.y],
		"safe_crop_rect": [0, 0, export_size.x, export_size.y],
		"expected_background_filename": "background.png",
		"expected_foreground_filename": "foreground.png",
		"expected_occlusion_filename": "",
		"occlusion_policy": "ART_GUIDE_ONLY_FOREGROUND_POLYGON_RUNTIME",
		"tile_layer_policy": "background < base_tiles < dynamic_surfaces < walls < units < foreground",
		"tile_counts": _tile_counts(arena),
		"wall_count": arena.obstacles.filter(func(value): return value != null and value.wall_id != &"").size(),
		"spawn_count": arena.spawns.filter(func(value): return value != null).size(),
		"objective_count": arena.objectives.filter(func(value): return value != null).size(),
		"floor_policy": arena.modular_visual_profile.hybrid_floor_policy \
			if arena.modular_visual_profile != null else -1,
		"reference_renderer_version": ArenaArtProjectionRenderer.RENDERER_VERSION,
		"geometry_report": ArenaArtProjectionRenderer.geometry_report(arena),
		"geometry": {
			"grid_size": [arena.grid_size.x, arena.grid_size.y],
			"grid_origin": [arena.grid_origin.x, arena.grid_origin.y],
			"axis_x": [arena.axis_x.x, arena.axis_x.y],
			"axis_y": [arena.axis_y.x, arena.axis_y.y],
			"image_offset": [arena.image_offset.x, arena.image_offset.y],
			"image_scale": [arena.image_scale.x, arena.image_scale.y],
			"camera_offset": [arena.camera_offset.x, arena.camera_offset.y],
			"camera_zoom": arena.camera_zoom,
			"calibration_cells": arena.calibration_cells.map(func(value): return [value.x, value.y]),
			"calibration_pixels": arena.calibration_pixels.map(func(value): return [value.x, value.y]),
		},
		"arena_snapshot_sha256": ArenaSnapshotService.arena_fingerprint(arena),
		"fallback_background_path": arena.background_path,
		"round_trip_target": "background.png",
		"expected_filenames": images.keys() + [
			"arena_definition.tres", "art_brief.txt", "art_brief.md",
			"validation_report.json", MANIFEST_FILE,
		],
		"files": files,
	}
	if not _write_text(
			destination.path_join(MANIFEST_FILE), JSON.stringify(manifest, "  ")
		):
		return {"ok": false, "error": "manifest_write_failed"}
	return {"ok": true, "directory": destination, "files": images.keys() + [
		"arena_definition.tres", "art_brief.txt", "art_brief.md", "validation_report.json",
		MANIFEST_FILE,
	]}


static func _background_image(arena: ArenaDefinition) -> Image:
	return ArenaArtProjectionRenderer.render_pass(arena, &"reference_clean")


static func _logic_image(arena: ArenaDefinition, grid_only: bool) -> Image:
	return ArenaArtProjectionRenderer.render_pass(
		arena, &"reference_grid" if grid_only else &"reference_gameplay"
	)


static func _game_image(arena: ArenaDefinition) -> Image:
	return ArenaArtProjectionRenderer.render_pass(arena, &"map_game_preview")


static func _mask_image(arena: ArenaDefinition, kind: StringName) -> Image:
	var pass_id := {
		&"playable": &"playable_mask",
		&"void": &"void_mask",
		&"wall": &"wall_mask",
		&"foreground": &"foreground_guide",
	}.get(kind, &"playable_mask") as StringName
	return ArenaArtProjectionRenderer.render_pass(arena, pass_id)


static func _tile_counts(arena: ArenaDefinition) -> Dictionary:
	var counts := {}
	for definition in arena.cells:
		if definition == null or not definition.defined:
			continue
		var key := str(definition.terrain_id)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


static func _mark_cell(
		image: Image, cell: Vector2i, size: Vector2i, color: Color,
		margin: int, inset_ratio: float
	) -> void:
	if not GridTransformService.is_cell_in_bounds(cell, size):
		return
	var width := float(image.get_width() - margin * 2) / maxf(1.0, size.x)
	var height := float(image.get_height() - margin * 2) / maxf(1.0, size.y)
	var inset_x := int(width * inset_ratio)
	var inset_y := int(height * inset_ratio)
	image.fill_rect(Rect2i(
		margin + int(cell.x * width) + inset_x,
		margin + int(cell.y * height) + inset_y,
		maxi(1, int(width) - inset_x * 2),
		maxi(1, int(height) - inset_y * 2)
	), color)


static func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	return true


static func _export_size(arena: ArenaDefinition) -> Vector2i:
	return ArenaArtResolutionContract.from_arena(arena).reference_export_size


static func _sha256_file(path: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(FileAccess.get_file_as_bytes(path))
	return hashing.finish().hex_encode()


static func _valid_destination(path: String) -> bool:
	if path.is_empty() or ".." in path:
		return false
	return path.begins_with("res://") or path.begins_with("user://") \
		or path.is_absolute_path()


static func _file_role(file_name: String) -> String:
	var roles := {
		"reference_clean.png": "guide_artistique_background_sans_grille",
		"reference_grid.png": "guide_artistique_grille_affine_exacte",
		"reference_coordinates.png": "guide_artistique_coordonnees_centres_affines",
		"reference_gameplay.png": "guide_artistique_topologie_spawns_objectifs",
		"reference_walls.png": "guide_artistique_murs_orientes",
		"playable_mask.png": "masque_polygones_jouables",
		"void_mask.png": "masque_polygones_void",
		"wall_mask.png": "masque_silhouettes_murs",
		"foreground_guide.png": "guide_artistique_polygone_foreground",
		"depth_guide.png": "guide_artistique_profondeur_y_sort",
		"alignment_markers.png": "reperes_alignement_separes",
		"map_game_preview.png": "preview_jeu_controlee",
	}
	return str(roles.get(file_name, "compatibilite_%s" % file_name.get_basename()))
