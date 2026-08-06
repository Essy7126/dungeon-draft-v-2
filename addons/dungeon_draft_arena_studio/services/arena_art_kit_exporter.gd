@tool
class_name ArenaArtKitExporter
extends RefCounted

const IMAGE_SIZE := Vector2i(1280, 720)
const MANIFEST_SCHEMA_VERSION := 2
const MANIFEST_FILE := "arena_art_manifest.json"


static func export_kit(
		arena: ArenaDefinition,
		destination: String,
		validation: ArenaValidationReport,
		provided_images := {}
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	if not destination.begins_with("res://") or ".." in destination:
		return {"ok": false, "error": "invalid_destination"}
	var absolute := ProjectSettings.globalize_path(destination)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute)
	if directory_error != OK:
		return {"ok": false, "error": error_string(directory_error)}
	var images := {
		"map_reference.png": _background_image(arena),
		"map_clean.png": _background_image(arena),
		"map_logic.png": _logic_image(arena, false),
		"map_grid.png": _logic_image(arena, true),
		"map_game_preview.png": _game_image(arena),
		"reference_clean.png": _background_image(arena),
		"reference_grid.png": _logic_image(arena, true),
		"reference_coordinates.png": _logic_image(arena, false),
		"reference_gameplay.png": _game_image(arena),
		"reference_walls.png": _logic_image(arena, false),
		"playable_mask.png": _mask_image(arena, &"playable"),
		"void_mask.png": _mask_image(arena, &"void"),
		"wall_mask.png": _mask_image(arena, &"wall"),
		"foreground_guide.png": _mask_image(arena, &"foreground"),
		"depth_guide.png": _logic_image(arena, true),
	}
	var export_size := _export_size(arena)
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
	if not clone.restore_snapshot(arena.to_snapshot()):
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
		"- Livrer background.png et, si necessaire, foreground.png / occlusion.png.",
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
			"role": file_name.get_basename(),
		}
	var arena_path := destination.path_join("arena_definition.tres")
	files["arena_definition.tres"] = {
		"sha256": _sha256_file(arena_path),
		"role": "gameplay_authority_snapshot",
	}
	var manifest := {
		"manifest_version": MANIFEST_SCHEMA_VERSION,
		"schema_version": MANIFEST_SCHEMA_VERSION,
		"arena_schema_version": arena.schema_version,
		"arena_id": str(arena.arena_id),
		"display_name": arena.display_name,
		"arena_fingerprint": ArenaEditSession.fingerprint(arena.to_snapshot()),
		"document_path": arena.resource_path,
		"export_timestamp": Time.get_datetime_string_from_system(true),
		"generated_at": Time.get_datetime_string_from_system(true),
		"canvas_size": [export_size.x, export_size.y],
		"source_image_size": [arena.source_image_size.x, arena.source_image_size.y],
		"resolution": [export_size.x, export_size.y],
		"crop": [0, 0, export_size.x, export_size.y],
		"safe_crop_rect": [0, 0, export_size.x, export_size.y],
		"expected_background_filename": "background.png",
		"expected_foreground_filename": "foreground.png",
		"expected_occlusion_filename": "occlusion.png",
		"tile_layer_policy": "background < base_tiles < dynamic_surfaces < walls < units < foreground",
		"tile_counts": _tile_counts(arena),
		"wall_count": arena.obstacles.filter(func(value): return value != null).size(),
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
		"arena_snapshot_sha256": JSON.stringify(arena.to_snapshot()).sha256_text(),
		"fallback_background_path": arena.background_path,
		"round_trip_target": "background.png",
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
	var output_size := _export_size(arena)
	var image := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("101722"))
	if arena.background_path.is_empty() or not ResourceLoader.exists(arena.background_path):
		return image
	var texture := load(arena.background_path) as Texture2D
	if texture == null:
		return image
	var source := texture.get_image()
	if source == null or source.is_empty():
		return image
	source = source.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	if source.get_size() != output_size:
		source.resize(output_size.x, output_size.y, Image.INTERPOLATE_LANCZOS)
	return source


static func _logic_image(arena: ArenaDefinition, grid_only: bool) -> Image:
	var output_size := _export_size(arena)
	var image := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("101722"))
	var margin := 44
	var cell_width := maxf(1.0, float(output_size.x - margin * 2) / maxf(1.0, arena.grid_size.x))
	var cell_height := maxf(1.0, float(output_size.y - margin * 2) / maxf(1.0, arena.grid_size.y))
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			var definition := arena.get_cell_definition(Vector2i(x, y))
			var color := Color("18202d")
			if definition != null and definition.defined:
				color = ArenaTerrainRegistry.color_for(definition.terrain_id)
				if definition.border:
					color = Color("37475b")
			if grid_only:
				color.a = 0.36
			var rect := Rect2i(
				margin + int(x * cell_width), margin + int(y * cell_height),
				maxi(1, int(cell_width) - 1), maxi(1, int(cell_height) - 1)
			)
			image.fill_rect(rect, color)
	for obstacle in arena.obstacles:
		if obstacle != null:
			_mark_cell(image, obstacle.cell, arena.grid_size, Color("ff814d"), margin, 0.30)
	if not grid_only:
		for spawn in arena.spawns:
			if spawn != null:
				_mark_cell(image, spawn.cell, arena.grid_size, Color("75ddff"), margin, 0.52)
		for objective in arena.objectives:
			if objective != null:
				_mark_cell(image, objective.cell, arena.grid_size, Color("ffd166"), margin, 0.68)
	return image


static func _game_image(arena: ArenaDefinition) -> Image:
	var background := _background_image(arena)
	var overlay := _logic_image(arena, true)
	background.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), Vector2i.ZERO)
	return background


static func _mask_image(arena: ArenaDefinition, kind: StringName) -> Image:
	var output_size := _export_size(arena)
	var image := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for definition in arena.cells:
		if definition == null or not definition.defined:
			continue
		var matches := false
		match kind:
			&"playable":
				matches = definition.playable and not definition.border
			&"void":
				matches = definition.border or not definition.playable \
					or definition.cell_type == GridData.CellType.HOLE
			&"wall":
				matches = definition.cell_type == GridData.CellType.WALL \
					or arena.obstacle_at(definition.coordinate) != null
			&"foreground":
				matches = not arena.foreground_occluder_polygon.is_empty()
		if matches:
			_mark_cell(
				image, definition.coordinate, arena.grid_size,
				Color.WHITE, 44, 0.02
			)
	return image


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
	if arena != null and not arena.background_path.is_empty() \
			and ResourceLoader.exists(arena.background_path):
		var texture := load(arena.background_path) as Texture2D
		if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
			return Vector2i(texture.get_width(), texture.get_height())
	if arena != null and arena.source_image_size.x > 0 and arena.source_image_size.y > 0:
		return arena.source_image_size
	return IMAGE_SIZE


static func _sha256_file(path: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(FileAccess.get_file_as_bytes(path))
	return hashing.finish().hex_encode()
