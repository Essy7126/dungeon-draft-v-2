@tool
class_name ArenaArtKitExporter
extends RefCounted

const IMAGE_SIZE := Vector2i(1280, 720)


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
	}
	for file_name in images:
		var supplied = provided_images.get(file_name)
		if supplied is Image and not supplied.is_empty():
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
	if not _write_text(destination.path_join("art_brief.txt"), "\n".join(brief)):
		return {"ok": false, "error": "brief_write_failed"}
	return {"ok": true, "directory": destination, "files": images.keys() + [
		"arena_definition.tres", "art_brief.txt", "validation_report.json",
	]}


static func _background_image(arena: ArenaDefinition) -> Image:
	var image := Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
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
	source.resize(IMAGE_SIZE.x, IMAGE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return source


static func _logic_image(arena: ArenaDefinition, grid_only: bool) -> Image:
	var image := Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("101722"))
	var margin := 44
	var cell_width := maxf(1.0, float(IMAGE_SIZE.x - margin * 2) / maxf(1.0, arena.grid_size.x))
	var cell_height := maxf(1.0, float(IMAGE_SIZE.y - margin * 2) / maxf(1.0, arena.grid_size.y))
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


static func _mark_cell(
		image: Image, cell: Vector2i, size: Vector2i, color: Color,
		margin: int, inset_ratio: float
	) -> void:
	if not GridTransformService.is_cell_in_bounds(cell, size):
		return
	var width := float(IMAGE_SIZE.x - margin * 2) / maxf(1.0, size.x)
	var height := float(IMAGE_SIZE.y - margin * 2) / maxf(1.0, size.y)
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
