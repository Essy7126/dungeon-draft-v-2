@tool
class_name ArenaArtRoundTripService
extends RefCounted

const MANIFEST_FILE := "arena_art_manifest.json"
const SCHEMA_VERSION := 3
const MINIMUM_SCHEMA_VERSION := 2
const REQUIRED_IMAGES := [
	"reference_clean.png", "reference_grid.png", "reference_coordinates.png",
	"reference_gameplay.png", "reference_walls.png", "playable_mask.png",
	"void_mask.png", "wall_mask.png", "foreground_guide.png", "depth_guide.png",
]
const V3_REQUIRED_IMAGES := ["alignment_markers.png"]


static func validate_kit(directory: String) -> Dictionary:
	var manifest_path := directory.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(manifest_path):
		return _failure("MANIFEST_MISSING", "Le kit ne contient pas de manifeste artistique.", directory)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return _failure("MANIFEST_INVALID", "Le manifeste art n'est pas un JSON valide.", directory)
	var original_schema := int((parsed as Dictionary).get("schema_version", 0))
	if original_schema < MINIMUM_SCHEMA_VERSION or original_schema > SCHEMA_VERSION:
		return _failure("SCHEMA_MISMATCH", "Version de manifeste incompatible.", directory)
	var manifest := migrate_manifest(parsed as Dictionary)
	var errors := PackedStringArray()
	var files := manifest.get("files", {}) as Dictionary
	var required := REQUIRED_IMAGES.duplicate()
	if original_schema >= 3:
		required.append_array(V3_REQUIRED_IMAGES)
	var resolution_contract := ArenaArtResolutionContract.from_dict(
		manifest.get("resolution_contract", {}) as Dictionary
	)
	var expected_size := resolution_contract.reference_export_size
	for file_name in required:
		var path := directory.path_join(file_name)
		if not FileAccess.file_exists(path):
			errors.append("Fichier absent : %s" % file_name)
			continue
		var expected := str((files.get(file_name, {}) as Dictionary).get("sha256", ""))
		var actual := _sha256_file(path)
		if expected.is_empty() or actual != expected:
			errors.append("Checksum invalide : %s" % file_name)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.get_size() != expected_size:
			errors.append("Resolution incompatible : %s" % file_name)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"manifest": manifest,
		"original_schema_version": original_schema,
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
	var actual_fingerprint := ArenaSnapshotService.arena_fingerprint(arena) \
		if int(manifest.get("schema_version", 0)) >= 3 \
		else ArenaEditSession.fingerprint(arena.to_snapshot())
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
	var resolution_contract := ArenaArtResolutionContract.from_dict(
		manifest.get("resolution_contract", {}) as Dictionary
	)
	var expected_size := resolution_contract.reference_export_size
	if artwork == null or artwork.is_empty() or artwork.get_size() != expected_size:
		return _failure("RESOLUTION_MISMATCH", "Le decor a ete redimensionne ou recadre.", directory, arena.background_path).merged({
			"expected_resolution": expected_size,
			"actual_resolution": artwork.get_size() if artwork != null else Vector2i.ZERO,
		}, true)
	for optional_name in [
		str(manifest.get("expected_foreground_filename", "foreground.png")),
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
		"occlusion_source": "",
		"occlusion_policy": str(manifest.get(
			"occlusion_policy", "ART_GUIDE_ONLY_FOREGROUND_POLYGON_RUNTIME"
		)),
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
	var plan := ArenaArtImportTransaction.prepare(arena, directory, image_file)
	if not bool(plan.get("ok", false)):
		return plan
	# Cette methode est l'API historique d'application : son appel constitue la
	# confirmation du client. L'UI 2.0 utilise prepare/commit et expose la gate.
	return ArenaArtImportTransaction.commit(
		arena, plan, destination_path, true, hybrid_floor_policy
	)


static func migrate_manifest(source: Dictionary) -> Dictionary:
	var manifest := source.duplicate(true)
	var version := int(manifest.get("schema_version", 0))
	if version == 2:
		var resolution := _vector2i(manifest.get("resolution", [1280, 720]))
		var contract := ArenaArtResolutionContract.new()
		contract.native_art_size = resolution
		contract.source_image_size = _vector2i(
			manifest.get("source_image_size", [resolution.x, resolution.y])
		)
		contract.reference_export_size = resolution
		manifest["resolution_contract"] = contract.to_dict()
		manifest["studio_product_version"] = "historical_1_3_1"
		manifest["gameplay_fingerprint"] = ""
		manifest["occlusion_policy"] = "ART_GUIDE_ONLY_FOREGROUND_POLYGON_RUNTIME"
		manifest["original_schema_version"] = 2
		# Garder schema_version=2 pour choisir l'algorithme de fingerprint
		# historique pendant le round-trip.
	return manifest


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
