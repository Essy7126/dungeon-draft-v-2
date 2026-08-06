@tool
class_name ArenaArtRoundTripService
extends RefCounted

const MANIFEST_FILE := "arena_art_manifest.json"
const SCHEMA_VERSION := 2
const REQUIRED_IMAGES := [
	"reference_clean.png", "reference_grid.png", "reference_coordinates.png",
	"reference_gameplay.png", "reference_walls.png", "playable_mask.png",
	"void_mask.png", "wall_mask.png", "foreground_guide.png", "depth_guide.png",
]


static func validate_kit(directory: String) -> Dictionary:
	var manifest_path := directory.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(manifest_path):
		return _failure("MANIFEST_MISSING", "Le kit ne contient pas de manifeste 2.0.", directory)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return _failure("MANIFEST_INVALID", "Le manifeste art n'est pas un JSON valide.", directory)
	var manifest := parsed as Dictionary
	if int(manifest.get("schema_version", 0)) != SCHEMA_VERSION:
		return _failure("SCHEMA_MISMATCH", "Version de manifeste incompatible.", directory)
	var errors := PackedStringArray()
	var files := manifest.get("files", {}) as Dictionary
	for file_name in REQUIRED_IMAGES:
		var path := directory.path_join(file_name)
		if not FileAccess.file_exists(path):
			errors.append("Fichier absent : %s" % file_name)
			continue
		var expected := str((files.get(file_name, {}) as Dictionary).get("sha256", ""))
		var actual := _sha256_file(path)
		if expected.is_empty() or actual != expected:
			errors.append("Checksum invalide : %s" % file_name)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		var expected_size := manifest.get("resolution", []) as Array
		if image == null or expected_size.size() < 2 \
				or image.get_size() != Vector2i(int(expected_size[0]), int(expected_size[1])):
			errors.append("Resolution incompatible : %s" % file_name)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"manifest": manifest,
		"directory": directory,
		"fallback": str(manifest.get("fallback_background_path", "")),
	}


static func inspect_reimport(
		arena: ArenaDefinition,
		directory: String,
		image_file := "background.png"
	) -> Dictionary:
	if arena == null:
		return _failure("ARENA_MISSING", "Aucune ArenaDefinition cible.", directory)
	var validation := validate_kit(directory)
	if not validation.get("ok", false):
		return validation
	var manifest := validation.get("manifest", {}) as Dictionary
	if str(manifest.get("arena_id", "")) != str(arena.arena_id):
		return _failure("ARENA_ID_MISMATCH", "Le kit appartient a une autre arene.", directory, arena.background_path)
	var geometry := manifest.get("geometry", {}) as Dictionary
	if _vector2i(geometry.get("grid_size", [])) != arena.grid_size \
			or not _vector2(geometry.get("grid_origin", [])).is_equal_approx(arena.grid_origin) \
			or not _vector2(geometry.get("axis_x", [])).is_equal_approx(arena.axis_x) \
			or not _vector2(geometry.get("axis_y", [])).is_equal_approx(arena.axis_y) \
			or not _vector2(geometry.get("image_offset", [])).is_equal_approx(arena.image_offset) \
			or not _vector2(geometry.get("image_scale", [])).is_equal_approx(arena.image_scale) \
			or not _vector2(geometry.get("camera_offset", [])).is_equal_approx(arena.camera_offset) \
			or not is_equal_approx(float(geometry.get("camera_zoom", -1.0)), arena.camera_zoom):
		return _failure("GEOMETRY_MISMATCH", "La geometrie du kit ne correspond plus a l'arene.", directory, arena.background_path)
	var expected_fingerprint := str(manifest.get(
		"arena_fingerprint", manifest.get("arena_snapshot_sha256", "")
	))
	var actual_fingerprint := ArenaEditSession.fingerprint(arena.to_snapshot())
	if expected_fingerprint.is_empty() or actual_fingerprint != expected_fingerprint:
		return _failure(
			"FINGERPRINT_MISMATCH",
			"L'arene a change depuis l'export du kit artistique.",
			directory, arena.background_path
		).merged({
			"expected_fingerprint": expected_fingerprint,
			"actual_fingerprint": actual_fingerprint,
		}, true)
	var allowed := PackedStringArray([
		str(manifest.get("expected_background_filename", "background.png")),
		"map_clean.png",
	])
	if image_file not in allowed:
		return _failure("IMAGE_NOT_ALLOWED", "Le fichier demande n'appartient pas au contrat du kit.", directory, arena.background_path)
	var source_image := directory.path_join(image_file)
	if not FileAccess.file_exists(source_image):
		return _failure("ARTWORK_MISSING", "Le background artistique attendu est absent : %s" % image_file, directory, arena.background_path)
	var artwork := Image.load_from_file(ProjectSettings.globalize_path(source_image))
	var resolution := manifest.get("resolution", []) as Array
	var expected_size := _vector2i(resolution)
	if artwork == null or artwork.is_empty() or artwork.get_size() != expected_size:
		return _failure("RESOLUTION_MISMATCH", "Le decor a ete redimensionne ou recadre.", directory, arena.background_path).merged({
			"expected_resolution": expected_size,
			"actual_resolution": artwork.get_size() if artwork != null else Vector2i.ZERO,
		}, true)
	for optional_name in [
		str(manifest.get("expected_foreground_filename", "foreground.png")),
		str(manifest.get("expected_occlusion_filename", "occlusion.png")),
	]:
		var optional_path := directory.path_join(optional_name)
		if not FileAccess.file_exists(optional_path):
			continue
		var optional_image := Image.load_from_file(ProjectSettings.globalize_path(optional_path))
		if optional_image == null or optional_image.is_empty() \
				or optional_image.get_size() != expected_size:
			return _failure(
				"LAYER_RESOLUTION_MISMATCH",
				"La couche optionnelle %s n'a pas la resolution du manifeste." % optional_name,
				directory, arena.background_path
			)
	return {
		"ok": true,
		"source_image": source_image,
		"foreground_source": directory.path_join(str(manifest.get("expected_foreground_filename", "foreground.png"))),
		"occlusion_source": directory.path_join(str(manifest.get("expected_occlusion_filename", "occlusion.png"))),
		"calibration": {
			"grid_origin": arena.grid_origin,
			"axis_x": arena.axis_x,
			"axis_y": arena.axis_y,
			"image_offset": arena.image_offset,
			"image_scale": arena.image_scale,
		},
		"manifest": manifest,
		"requires_recalibration": false,
	}


static func apply_reimport(
		arena: ArenaDefinition,
		directory: String,
		destination_path: String,
		image_file := "background.png",
		hybrid_floor_policy := -1
	) -> Dictionary:
	var inspection := inspect_reimport(arena, directory, image_file)
	if not inspection.get("ok", false):
		return inspection
	if not destination_path.begins_with("res://") or destination_path.contains("..") \
			or destination_path.get_extension().to_lower() != "png":
		return _failure("DESTINATION_INVALID", "La destination PNG n'est pas autorisee.", directory, arena.background_path)
	var absolute := ProjectSettings.globalize_path(destination_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return _failure("DIRECTORY_FAILED", "Le dossier de destination ne peut pas etre cree.", directory, arena.background_path)
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(str(inspection.get("source_image", ""))), absolute
	)
	if copy_error != OK:
		return _failure("COPY_FAILED", error_string(copy_error), directory, arena.background_path)
	arena.background_path = destination_path
	var foreground_source := str(inspection.get("foreground_source", ""))
	if FileAccess.file_exists(foreground_source):
		var foreground_destination := destination_path.get_base_dir().path_join("foreground.png")
		if DirAccess.copy_absolute(
				ProjectSettings.globalize_path(foreground_source),
				ProjectSettings.globalize_path(foreground_destination)
			) == OK:
			arena.foreground_path = foreground_destination
	var occlusion_source := str(inspection.get("occlusion_source", ""))
	if FileAccess.file_exists(occlusion_source):
		var occlusion_destination := destination_path.get_base_dir().path_join("occlusion.png")
		if DirAccess.copy_absolute(
				ProjectSettings.globalize_path(occlusion_source),
				ProjectSettings.globalize_path(occlusion_destination)
			) == OK:
			arena.occlusion_mask_path = occlusion_destination
	arena.visual_mode = ArenaDefinition.VisualMode.HYBRID
	if arena.modular_visual_profile == null:
		arena.modular_visual_profile = ArenaModularVisualProfile.new()
		arena.modular_visual_profile.theme_id = arena.theme_id
	if hybrid_floor_policy >= ArenaModularVisualProfile.HybridFloorPolicy.NONE:
		arena.modular_visual_profile.hybrid_floor_policy = clampi(
			hybrid_floor_policy,
			ArenaModularVisualProfile.HybridFloorPolicy.NONE,
			ArenaModularVisualProfile.HybridFloorPolicy.ALL_DEFINED
		)
	return inspection.merged({"destination_path": destination_path}, true)


static func _failure(
		code: String,
		message: String,
		directory: String,
		fallback := ""
	) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"error": message,
		"directory": directory,
		"fallback": fallback,
	}


static func _sha256_file(path: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(FileAccess.get_file_as_bytes(path))
	return hashing.finish().hex_encode()


static func _vector2(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) \
		if value is Array and value.size() >= 2 else Vector2(INF, INF)


static func _vector2i(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1])) \
		if value is Array and value.size() >= 2 else Vector2i(-1, -1)
