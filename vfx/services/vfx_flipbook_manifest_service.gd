class_name VFXFlipbookManifestService
extends RefCounted

const SYNTHETIC_GENERATOR_PATH := \
		"res://tools/labs/vfx_flipbook_foundation/generate_synthetic_flipbooks.gd"


func load_and_validate(path: String, asset: VFXFlipbookAsset = null) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _report(["Manifeste absent : %s" % path])
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return _report(["JSON manifeste invalide."])
	return validate(parser.data as Dictionary, asset, path)


func validate(
		manifest: Dictionary,
		asset: VFXFlipbookAsset = null,
		manifest_path := ""
	) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for field in [
		"schema_version", "asset_id", "source_tool", "columns", "rows", "frame_count",
		"frames_per_second", "loop", "playback_mode", "blend_mode", "alpha_mode",
		"pivot_normalized", "nominal_size_in_cells", "art_status", "license_status",
		"variants", "generator_checksum", "texture_checksums",
	]:
		if not manifest.has(field):
			errors.append("Champ manifeste absent : %s." % field)
	if not errors.is_empty():
		return _report(errors, warnings, manifest)
	errors.append_array(_validate_field_types(manifest))
	if not errors.is_empty():
		return _report(errors, warnings, manifest)
	if int(manifest.schema_version) != 1:
		errors.append("schema_version manifeste inconnu.")
	if str(manifest.asset_id).is_empty():
		errors.append("asset_id manifeste absent.")
	if str(manifest.source_tool).is_empty():
		errors.append("source_tool manifeste absent.")
	var columns := int(manifest.columns)
	var rows := int(manifest.rows)
	var frame_count := int(manifest.frame_count)
	if columns <= 0 or rows <= 0 or frame_count <= 0 or frame_count > columns * rows:
		errors.append("Layout manifeste incompatible.")
	if float(manifest.frames_per_second) <= 0.0:
		errors.append("FPS manifeste invalide.")
	var pivot := manifest.pivot_normalized as Array
	var nominal := manifest.nominal_size_in_cells as Array
	if float(pivot[0]) < 0.0 or float(pivot[0]) > 1.0 \
			or float(pivot[1]) < 0.0 or float(pivot[1]) > 1.0:
		errors.append("Pivot manifeste hors de [0, 1].")
	if float(nominal[0]) <= 0.0 or float(nominal[1]) <= 0.0:
		errors.append("Taille nominale manifeste invalide.")
	if StringName(manifest.playback_mode) not in VFXFlipbookAsset.PLAYBACK_MODES:
		errors.append("Mode de lecture manifeste inconnu.")
	if StringName(manifest.blend_mode) not in VFXFlipbookAsset.BLEND_MODES:
		errors.append("Mode de fusion manifeste inconnu.")
	if StringName(manifest.alpha_mode) not in VFXFlipbookAsset.ALPHA_MODES:
		errors.append("Mode alpha manifeste inconnu.")
	if StringName(manifest.art_status) not in VFXFlipbookAsset.ART_STATUSES:
		errors.append("Statut artistique manifeste inconnu.")
	if str(manifest.license_status).is_empty():
		errors.append("Statut de licence manifeste absent.")
	elif StringName(manifest.license_status) not in VFXFlipbookAsset.LICENSE_STATUSES:
		errors.append("Statut de licence manifeste inconnu.")
	var generator_checksum := str(manifest.generator_checksum)
	if not _is_sha256(generator_checksum):
		errors.append("Checksum generateur invalide.")
	elif str(manifest.source_tool) == "SYNTHETIC_TEST_GENERATOR" \
			and FileAccess.file_exists(SYNTHETIC_GENERATOR_PATH) \
			and generator_checksum != FileAccess.get_sha256(SYNTHETIC_GENERATOR_PATH):
		errors.append("Checksum generateur incorrect.")
	var ids := {}
	var texture_checksums := manifest.texture_checksums as Dictionary
	for checksum in texture_checksums.values():
		if not _is_sha256(str(checksum)):
			errors.append("Checksum texture invalide dans texture_checksums.")
	var manifest_variants := manifest.variants as Array
	if manifest_variants.is_empty():
		errors.append("Au moins une variante manifeste est requise.")
	for value in manifest_variants:
		if not value is Dictionary:
			errors.append("Variante manifeste invalide.")
			continue
		var variant := value as Dictionary
		var id := str(variant.get("variant_id", ""))
		if id.is_empty() or ids.has(id):
			errors.append("Variante manifeste absente ou dupliquée : %s." % id)
		ids[id] = true
		for quality in ["low", "medium", "high"]:
			var texture_path := str(variant.get("texture_%s" % quality, ""))
			if texture_path.is_empty():
				if quality == "low":
					errors.append("Texture manifeste absente : %s/%s." % [id, quality])
				continue
			if not FileAccess.file_exists(texture_path):
				errors.append("Texture manifeste absente : %s/%s." % [id, quality])
				continue
			var expected := str(texture_checksums.get(texture_path, ""))
			if not _is_sha256(expected) or FileAccess.get_sha256(texture_path) != expected:
				errors.append("Checksum texture incorrect : %s." % texture_path)
			var texture := ResourceLoader.load(texture_path) as Texture2D
			var frame_size := int(variant.get("frame_size_%s" % quality, 0))
			if texture == null or frame_size <= 0 \
					or texture.get_width() != columns * frame_size \
					or texture.get_height() != rows * frame_size:
				errors.append("Dimensions texture incohérentes : %s." % texture_path)
	if asset != null:
		for asset_error in asset.validate_structure():
			errors.append("Resource flipbook invalide : %s" % asset_error)
		errors.append_array(_compare_asset(manifest, asset, manifest_path))
	if str(manifest.license_status) in ["INTERNAL_TEST", "EVALUATION_ONLY"]:
		warnings.append("Asset non éligible release : licence %s." % manifest.license_status)
	return _report(errors, warnings, manifest)


func is_release_eligible(manifest: Dictionary, asset: VFXFlipbookAsset = null) -> bool:
	var report := validate(manifest, asset)
	return bool(report.ok) and str(manifest.get("license_status", "")) == "COMMERCIAL_CLEARED"


func _validate_field_types(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in ["schema_version", "columns", "rows", "frame_count"]:
		var number = manifest.get(field)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or float(number) != floorf(float(number)):
			errors.append("Type manifeste incorrect : %s." % field)
	if typeof(manifest.get("frames_per_second")) not in [TYPE_INT, TYPE_FLOAT]:
		errors.append("Type manifeste incorrect : frames_per_second.")
	if typeof(manifest.get("loop")) != TYPE_BOOL:
		errors.append("Type manifeste incorrect : loop.")
	for field in [
		"asset_id", "source_tool", "playback_mode", "blend_mode", "alpha_mode",
		"art_status", "license_status", "generator_checksum",
	]:
		if typeof(manifest.get(field)) != TYPE_STRING:
			errors.append("Type manifeste incorrect : %s." % field)
	for field in ["pivot_normalized", "nominal_size_in_cells", "variants"]:
		if typeof(manifest.get(field)) != TYPE_ARRAY:
			errors.append("Type manifeste incorrect : %s." % field)
	if typeof(manifest.get("texture_checksums")) != TYPE_DICTIONARY:
		errors.append("Type manifeste incorrect : texture_checksums.")
	for field in ["pivot_normalized", "nominal_size_in_cells"]:
		var value = manifest.get(field)
		if value is Array and value.size() != 2:
			errors.append("Vecteur manifeste invalide : %s." % field)
		elif value is Array:
			for component in value:
				if typeof(component) not in [TYPE_INT, TYPE_FLOAT]:
					errors.append("Type manifeste incorrect : %s." % field)
					break
	if manifest.get("variants") is Array:
		for value in manifest.variants as Array:
			if not value is Dictionary:
				continue
			var variant := value as Dictionary
			if typeof(variant.get("variant_id")) != TYPE_STRING:
				errors.append("Type manifeste incorrect : variant_id.")
			for quality in ["low", "medium", "high"]:
				var texture_field := "texture_%s" % quality
				var frame_field := "frame_size_%s" % quality
				if variant.has(texture_field) and typeof(variant.get(texture_field)) != TYPE_STRING:
					errors.append("Type manifeste incorrect : %s." % texture_field)
				if variant.has(frame_field):
					var frame_size = variant.get(frame_field)
					if typeof(frame_size) not in [TYPE_INT, TYPE_FLOAT] \
							or float(frame_size) != floorf(float(frame_size)):
						errors.append("Type manifeste incorrect : %s." % frame_field)
	if manifest.get("texture_checksums") is Dictionary:
		for checksum in (manifest.texture_checksums as Dictionary).values():
			if typeof(checksum) != TYPE_STRING:
				errors.append("Type manifeste incorrect : texture_checksums.")
	return errors


func _compare_asset(
		manifest: Dictionary,
		asset: VFXFlipbookAsset,
		manifest_path := ""
	) -> Array[String]:
	var errors: Array[String] = []
	if asset.schema_version != int(manifest.schema_version):
		errors.append("Divergence schema_version entre manifeste et Resource.")
	if str(asset.asset_id) != str(manifest.asset_id):
		errors.append("Divergence asset_id entre manifeste et Resource.")
	if not manifest_path.is_empty() and asset.manifest_path != manifest_path:
		errors.append("Divergence manifest_path entre manifeste et Resource.")
	for field in ["columns", "rows", "frame_count"]:
		if int(asset.get(field)) != int(manifest.get(field, -1)):
			errors.append("Divergence %s entre manifeste et Resource." % field)
	if not is_equal_approx(asset.frames_per_second, float(manifest.frames_per_second)):
		errors.append("Divergence frames_per_second entre manifeste et Resource.")
	if asset.loop != bool(manifest.loop):
		errors.append("Divergence loop entre manifeste et Resource.")
	for field in ["playback_mode", "blend_mode", "alpha_mode", "art_status", "license_status"]:
		if str(asset.get(field)) != str(manifest.get(field, "")):
			errors.append("Divergence %s entre manifeste et Resource." % field)
	var pivot := manifest.pivot_normalized as Array
	var nominal := manifest.nominal_size_in_cells as Array
	if not asset.pivot_normalized.is_equal_approx(Vector2(float(pivot[0]), float(pivot[1]))):
		errors.append("Divergence pivot_normalized entre manifeste et Resource.")
	if not asset.nominal_size_in_cells.is_equal_approx(Vector2(float(nominal[0]), float(nominal[1]))):
		errors.append("Divergence nominal_size_in_cells entre manifeste et Resource.")
	var manifest_variants := manifest.variants as Array
	if manifest_variants.size() != asset.variants.size():
		errors.append("Divergence variants entre manifeste et Resource.")
	else:
		for index in asset.variants.size():
			var resource_variant := asset.variants[index]
			var manifest_value = manifest_variants[index]
			if not manifest_value is Dictionary:
				errors.append("Divergence variante invalide entre manifeste et Resource.")
				continue
			var manifest_variant := manifest_value as Dictionary
			if resource_variant == null or str(resource_variant.variant_id) != str(manifest_variant.get("variant_id", "")):
				errors.append("Divergence variant_id entre manifeste et Resource.")
				continue
			for quality in ["low", "medium", "high"]:
				var texture := resource_variant.get("texture_%s" % quality) as Texture2D
				var texture_path := str(manifest_variant.get("texture_%s" % quality, ""))
				if (texture == null and not texture_path.is_empty()) \
						or (texture != null and texture.resource_path != texture_path):
					errors.append("Divergence texture_%s pour %s." % [quality, resource_variant.variant_id])
	return errors


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	var normalized := value.to_lower()
	for index in normalized.length():
		var character := normalized.substr(index, 1)
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _report(
		errors: Array[String],
		warnings: Array[String] = [],
		manifest: Dictionary = {}
	) -> Dictionary:
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "manifest": manifest}
