@tool
class_name PaintedHaltManifestService
extends RefCounted

## Native authoring boundary: source art stays immutable, builds are disposable,
## and the manifest + derived files are installed as one rollbackable transaction.

const ScaleReference := preload("res://hub/painted_halt/halt_scale_reference.gd")
const HASH_MODE := "lf_utf8_v1"
const KINDS := ["sanctuary", "merchant", "hub", "lore", "forge"]
const CHANNELS := ["water", "cascades", "foliage", "stone_reflections"]
const BackdropService := preload(
	"res://addons/dungeon_draft_arena_studio/services/arena_backdrop_transaction_service.gd"
)
const BackdropSource := preload(
	"res://addons/dungeon_draft_arena_studio/domain/arena_backdrop_source_definition.gd"
)
const Arena := preload("res://addons/dungeon_draft_arena_studio/domain/arena_definition.gd")


static func text_hash(text: String) -> String:
	return text.trim_prefix("\ufeff").replace("\r\n", "\n").replace("\r", "\n").sha256_text()


static func manifest_hash(path: String) -> String:
	return text_hash(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else ""


static func list_maps() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for file in DirAccess.get_files_at("res://data/halts"):
		if file.ends_with(".json"):
			var path := "res://data/halts/" + file
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if (
				parsed is Dictionary and parsed.get("schema_version") == 1
				and _valid_id(str(parsed.get("id", "")))
				and parsed.has("world") and parsed.has("source")
			):
				result.append(
					{
						"path": path,
						"title": str(parsed.get("title", file)),
						"id": str(parsed.get("id", "")),
					}
				)
	return result


static func load_manifest(path: String) -> Dictionary:
	if not _safe_path(path) or not FileAccess.file_exists(path):
		return _failure("Manifeste introuvable ou chemin hors projet.")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return _failure("Le manifeste doit être un objet JSON.")
	var result := validate(parsed, true)
	result.merge({ "path": path, "manifest": parsed, "manifest_sha256": manifest_hash(path) })
	result["source_image"] = null
	if result.ok and not parsed.get("source", { }).is_empty():
		result.source_image = Image.load_from_file(
			ProjectSettings.globalize_path(str(parsed.source.image))
		)
	return result


static func validate(manifest: Dictionary, allow_calibration := false) -> Dictionary:
	var errors: Array[String] = []
	if manifest.get("schema_version") != 1 or not _valid_id(str(manifest.get("id", ""))):
		errors.append("Schéma inconnu ou identifiant invalide.")
	if not str(manifest.get("kind", "sanctuary")) in KINDS:
		errors.append("Type de halte inconnu.")
	var stage := str(manifest.get("stage", ""))
	if not stage in (
		["planning", "calibration", "playable_study", "reviewed"]
		if allow_calibration
		else ["playable_study", "reviewed"]
	):
		errors.append("Calibration incomplète : définir les chemins et passer à playable_study.")
	for key in ["source", "world", "navigation", "water", "review", "ambience", "foliage_motion"]:
		if manifest.has(key) and not manifest[key] is Dictionary:
			errors.append("%s doit être un objet." % key)
	for key in ["landmarks", "cascades", "torches", "foliage", "bounce", "mist", "foreground"]:
		if manifest.has(key) and not manifest[key] is Array:
			errors.append("%s doit être une liste." % key)
	if not errors.is_empty():
		return { "ok": false, "errors": errors }
	var source: Dictionary = manifest.get("source", { })
	if source.is_empty():
		if not allow_calibration:
			errors.append("Illustration originale manquante.")
	else:
		_validate_source(source, errors)
	var build_dir := str(manifest.get("build_dir", ""))
	if not _safe_path(build_dir) or build_dir == "res://":
		errors.append("Dossier de construction invalide.")
	for filename in ["materials.png", "flow.png", "build.json"]:
		if _same_path(str(source.get("image", "")), build_dir.path_join(filename)):
			errors.append("Le dossier de construction écraserait l’original.")
	var style := str(manifest.get("style", ""))
	if not _safe_path(style) or not FileAccess.file_exists(style):
		errors.append("Référence artistique manquante.")
	var world: Dictionary = manifest.get("world", { })
	_range(world.get("width", 0), 1000, 6000, "Largeur du monde", errors)
	if world.has("player_height_ratio"):
		_range(world.player_height_ratio, 0.06, 0.35, "Hauteur relative d’Achille", errors)
	else:
		_range(world.get("player_scale", 0), 0.2, 1.0, "Échelle d’Achille", errors)
	_range(world.get("speed", 195), 1, 1000, "Vitesse d’Achille", errors)
	_range(world.get("foot_clearance", 12), 0, 100, "Marge des pieds", errors)
	var nav: Dictionary = manifest.get("navigation", { })
	var outline: Variant = nav.get("outline", [])
	_validate_polygon(outline, "Chemin", errors, allow_calibration)
	_validate_polygon_list(nav.get("obstacles", []), "Obstacle", errors)
	var water: Dictionary = manifest.get("water", { })
	for key in ["caustic_strength", "distortion_strength"]:
		if water.has(key):
			_range(water[key], 0, 4, "water." + key, errors)
	if water.has("far_fade"):
		var far_fade: Variant = water.far_fade
		if not _point_valid(far_fade) or float(far_fade[0]) > float(far_fade[1]):
			errors.append("water.far_fade nécessite deux bornes normalisées avec début <= fin.")
	_validate_polygon_list(water.get("polygons", []), "Eau", errors)
	_validate_polygon_list(water.get("exclusions", []), "Exclusion eau", errors)
	var regions: Variant = water.get("regions", [])
	if not regions is Array:
		errors.append("water.regions doit être une liste.")
	else:
		for region in regions:
			if not region is Dictionary:
				errors.append("Région d’eau invalide.")
				continue
			_validate_polygon(region.get("polygon", []), "Courant", errors)
			var direction: Variant = region.get("direction", [1.0, 0.0])
			if (
				not _finite_pair(direction)
				or Vector2(float(direction[0]), float(direction[1])).length() < 0.001
			):
				errors.append("Le courant nécessite une direction non nulle.")
			_range(region.get("speed", 1.0), 0, 4, "Vitesse du courant", errors)
	var foliage_motion: Dictionary = manifest.get("foliage_motion", { })
	for key in ["strength", "speed"]:
		if foliage_motion.has(key):
			_range(foliage_motion[key], 0, 4, "foliage_motion." + key, errors)
	for key in ["foliage", "bounce"]:
		_validate_polygon_list(manifest.get(key, []), key, errors)
	_validate_anchor(world.get("spawn", []), "Arrivée", errors, allow_calibration)
	var landmarks: Array = manifest.get("landmarks", [])
	if landmarks.is_empty() and not allow_calibration:
		errors.append("Placer au moins une destination.")
	var ids := { }
	for landmark in landmarks:
		if not landmark is Dictionary:
			errors.append("Destination invalide.")
			continue
		var id := str(landmark.get("id", ""))
		if not _valid_id(id) or ids.has(id):
			errors.append("Chaque destination nécessite un identifiant unique.")
		ids[id] = true
		_validate_anchor(landmark.get("point", []), "Destination " + id, errors)
		if (
			landmark.has("action")
			and not str(landmark.action) in ["sanctuary", "merchant", "dialogue", "rest", "exit"]
		):
			errors.append("Type d’interaction inconnu : " + id)
		if landmark.has("description") and not landmark.description is String:
			errors.append("La description de l’interaction doit être un texte.")
		if landmark.has("focus"):
			_validate_anchor(landmark.focus, "Foyer de l’interaction " + id, errors)
		if landmark.has("radius"):
			_range(landmark.radius, 0.001, 0.3, "Portée d’interaction normalisée", errors)
	for cascade in manifest.get("cascades", []):
		if not cascade is Dictionary:
			errors.append("Cascade invalide.")
			continue
		_validate_polygon(cascade.get("polygon", []), "Cascade", errors)
		_validate_anchor(cascade.get("splash", []), "Impact de cascade", errors)
		_range(cascade.get("width", 20), 1, 1000, "Largeur de cascade", errors)
	var torches: Array = manifest.get("torches", [])
	if torches.size() > 12:
		errors.append("Maximum douze torches.")
	for torch in torches:
		if not torch is Dictionary:
			errors.append("Torche invalide.")
			continue
		_validate_anchor(torch.get("point", []), "Torche", errors)
		if torch.has("enclosed") and not torch.enclosed is bool:
			errors.append("torches.enclosed doit être un booléen.")
		var radius: Variant = torch.get("radius", [])
		if not _point_valid(radius) or float(radius[0]) <= 0 or float(radius[1]) <= 0:
			errors.append("Les rayons d’une torche doivent être positifs et normalisés.")
	for foreground in manifest.get("foreground", []):
		if not foreground is Dictionary:
			errors.append("Premier plan invalide.")
			continue
		_validate_polygon(foreground.get("polygon", []), "Premier plan", errors)
		_validate_anchor(foreground.get("anchor", []), "Ancrage de premier plan", errors)
		if foreground.has("depth_y"):
			_range(foreground.depth_y, 0, 1, "Ancrage de profondeur", errors)
	for mist in manifest.get("mist", []):
		if (
			not mist is Dictionary or not mist.get("rect", []) is Array
			or mist.get("rect", []).size() != 4
		):
			errors.append("Rectangle de brume invalide.")
			continue
		for value in mist.rect:
			_range(value, 0, 1, "Rectangle de brume", errors)
		_range(mist.get("alpha", 0.1), 0, 1, "Opacité de brume", errors)
	var review: Dictionary = manifest.get("review", { })
	for key in review:
		if str(key).ends_with("_pixel"):
			_validate_anchor(review[key], "Contrôle " + str(key), errors, true)
	var forbidden: Variant = review.get("forbidden_points", [])
	if forbidden is Array:
		for at in forbidden:
			_validate_anchor(at, "Point interdit", errors)
	else:
		errors.append("Les points interdits doivent être une liste.")
	var ambience: Dictionary = manifest.get("ambience", { })
	if str(ambience.get("footsteps", "stone")) != "stone":
		errors.append("Matière de pas non prise en charge.")
	var emitters: Variant = ambience.get("sources", [])
	if not emitters is Array:
		errors.append("Les sources sonores doivent être une liste.")
	else:
		for emitter in emitters:
			if not emitter is Dictionary:
				errors.append("Source sonore invalide.")
				continue
			if not str(emitter.get("kind", "fire")) in ["water", "fire"]:
				errors.append("Type de source sonore non pris en charge.")
			_validate_anchor(emitter.get("point", []), "Source sonore", errors)
			_range(emitter.get("radius", 0.3), 0.001, 1, "Portée sonore", errors)
			_range(emitter.get("gain_db", -17), -40, -6, "Volume sonore", errors)
	# Geometry membership is checked for authored anchors only; the runtime still
	# owns clearance, connected routes and the final walkability proof.
	if errors.is_empty() and not allow_calibration:
		var nav_polygon := _packed_polygon(outline)
		for at in [world.get("spawn", [])] + landmarks.map(
			func(item: Dictionary) -> Array:
				return item.point,
		):
			var p := Vector2(float(at[0]), float(at[1]))
			if not Geometry2D.is_point_in_polygon(p, nav_polygon):
				errors.append("Arrivée ou destination hors du chemin.")
			for obstacle in nav.get("obstacles", []):
				if Geometry2D.is_point_in_polygon(p, _packed_polygon(obstacle)):
					errors.append("Arrivée ou destination dans un obstacle.")
	return { "ok": errors.is_empty(), "errors": errors }


static func prepare_images(manifest: Dictionary) -> Dictionary:
	var checked := validate(manifest)
	if not checked.ok:
		return checked
	var size := Vector2i(int(manifest.source.size[0]), int(manifest.source.size[1]))
	var water: Dictionary = manifest.get("water", { })
	var water_polygons: Array = water.get("polygons", []).duplicate(true)
	for region in water.get("regions", []):
		water_polygons.append(region.polygon)
	var layers: Array[PackedByteArray] = []
	var specifications := [
		water_polygons,
		manifest.get("cascades", []).map(
			func(c: Dictionary) -> Array:
				return c.polygon,
		),
		manifest.get("foliage", []),
		manifest.get("bounce", []),
	]
	for channel in 4:
		var layer := Image.create(size.x, size.y, false, Image.FORMAT_L8)
		layer.fill(Color.BLACK)
		for polygon in specifications[channel]:
			_rasterize(layer, polygon, Color.WHITE)
		if channel == 0:
			for polygon in water.get("exclusions", []):
				_rasterize(layer, polygon, Color.BLACK)
		# Native resampling feathers the material boundaries without touching the
		# painting or running millions of Geometry2D point-in-polygon queries.
		var downscale := 2 if channel < 2 else 6
		layer.resize(
			maxi(1, size.x / downscale),
			maxi(1, size.y / downscale),
			Image.INTERPOLATE_BILINEAR,
		)
		layer.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
		layers.append(layer.get_data())
	var flow := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	flow.fill(Color(0.947214, 0.723607, 0.25, 0))
	for region in water.get("regions", []):
		var raw_direction: Array = region.get("direction", [1.0, 0.0])
		var direction := Vector2(float(raw_direction[0]), float(raw_direction[1])).normalized()
		_rasterize(
			flow,
			region.polygon,
			Color(
				direction.x * 0.5 + 0.5,
				direction.y * 0.5 + 0.5,
				float(region.get("speed", 1.0)) / 4.0,
				1,
			),
		)
	var packed := PackedByteArray()
	packed.resize(size.x * size.y * 4)
	var flow_data := flow.get_data()
	for pixel in size.x * size.y:
		var offset := pixel * 4
		packed[offset] = layers[0][pixel]
		packed[offset + 1] = layers[1][pixel]
		packed[offset + 2] = layers[2][pixel]
		packed[offset + 3] = layers[3][pixel]
		flow_data[offset + 3] = layers[0][pixel]
	return {
		"ok": true,
		"errors": [],
		"materials": Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, packed),
		"flow": Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, flow_data),
	}


static func save_and_prepare(path: String, manifest: Dictionary, expected_hash := "") -> Dictionary:
	var conflict := _check_save_path(path, manifest, expected_hash)
	if not conflict.ok:
		return conflict
	var prepared := prepare_images(manifest)
	if not prepared.ok:
		return prepared
	var text := JSON.stringify(manifest, "  ", false) + "\n"
	var mask_bytes: PackedByteArray = prepared.materials.save_png_to_buffer()
	var flow_bytes: PackedByteArray = prepared.flow.save_png_to_buffer()
	var build := {
		"schema_version": 1,
		"id": manifest.id,
		"manifest_sha256": text_hash(text),
		"manifest_hash_mode": HASH_MODE,
		"source_sha256": manifest.source.sha256,
		"mask_sha256": _bytes_hash(mask_bytes),
		"flow_sha256": _bytes_hash(flow_bytes),
		"size": manifest.source.size,
		"channels": CHANNELS,
		"flow_channels": ["direction_x", "direction_y", "speed_div_4", "water_coverage"],
		"generator": "godot_scanline_v1",
		"art_review": "candidate",
		"navigation_runtime_tested": false,
	}
	var build_dir := str(manifest.build_dir)
	var files := { }
	files[build_dir.path_join("materials.png")] = mask_bytes
	files[build_dir.path_join("materials.png.import")] = _import_settings(
		build_dir.path_join("materials.png")
	).to_utf8_buffer()
	files[build_dir.path_join("flow.png")] = flow_bytes
	files[build_dir.path_join("flow.png.import")] = _import_settings(
		build_dir.path_join("flow.png")
	).to_utf8_buffer()
	files[path] = text.to_utf8_buffer()
	# Build is committed last: readers never accept partially installed assets.
	files[build_dir.path_join("build.json")] = (JSON.stringify(build, "  ", false) + "\n").to_utf8_buffer()
	if str(manifest.source.sha256) != FileAccess.get_sha256(str(manifest.source.image)):
		return _failure("L’original a changé pendant la préparation.")
	conflict = _check_save_path(path, manifest, expected_hash)
	if not conflict.ok:
		return conflict
	var result := _install(files)
	result.merge(
		{
			"path": path,
			"manifest": manifest.duplicate(true),
			"manifest_sha256": build.manifest_sha256,
			"build": build,
		}
	)
	return result


static func save_plan(path: String, manifest: Dictionary, expected_hash := "") -> Dictionary:
	var result := _check_save_path(path, manifest, expected_hash)
	if not result.ok:
		return result
	result = validate(manifest, true)
	if not result.ok:
		return result
	var text := JSON.stringify(manifest, "  ", false) + "\n"
	result = _install({ path: text.to_utf8_buffer() })
	result.merge(
		{ "path": path, "manifest": manifest.duplicate(true), "manifest_sha256": text_hash(text) }
	)
	return result


static func create_plan(identifier: String, title: String, kind := "sanctuary") -> Dictionary:
	if not _valid_id(identifier) or not kind in KINDS:
		return _failure("Identifiant ou type de halte invalide.")
	var path := "res://data/halts/%s.json" % identifier
	var build_dir := "res://asset/map/painted/halts/" + identifier
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(build_dir):
		return _failure("Cette version existe déjà : choisir un nouvel identifiant.")
	var manifest := {
		"schema_version": 1,
		"id": identifier,
		"title": title,
		"kind": kind,
		"stage": "planning",
		"style": "res://data/halts/styles/roots_bronze_v1.json",
		"source": { },
		"build_dir": build_dir,
		"world": {
			"width": 2200,
			"player_height_ratio": 0.22,
			"speed": 195,
			"foot_clearance": 12,
			"spawn": [],
		},
		"navigation": { "outline": [], "obstacles": [] },
		"landmarks": [],
		"water": { "tint": "#48d896", "polygons": [], "regions": [], "exclusions": [] },
		"cascades": [],
		"torches": [],
		"foliage": [],
		"bounce": [],
		"mist": [],
		"foreground": [],
		"review": { },
	}
	return save_plan(path, manifest)


static func attach_source(
	path: String,
	manifest: Dictionary,
	image_path: String,
	expected_hash := "",
) -> Dictionary:
	if not manifest.get("source", { }).is_empty():
		return _failure("L’original de cette version existe déjà. Créer une nouvelle version.")
	var checked := _check_save_path(path, manifest, expected_hash)
	if not checked.ok:
		return checked
	checked = validate(manifest, true)
	if not checked.ok:
		return checked
	var extension := image_path.get_extension().to_lower()
	if not extension in ["png", "jpg", "jpeg", "webp"] or not FileAccess.file_exists(image_path):
		return _failure("Choisir une illustration PNG, JPEG ou WebP existante.")
	var image := Image.load_from_file(ProjectSettings.globalize_path(image_path))
	if image == null or image.is_empty() or image.get_width() * image.get_height() > 33554432:
		return _failure("Illustration illisible.")
	var target := str(manifest.build_dir).path_join("source." + extension)
	if not _safe_path(target) or FileAccess.file_exists(target):
		return _failure("Cette version possède déjà un original.")
	var copy := manifest.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(image_path)
	copy["source"] = {
		"image": target,
		"size": [image.get_width(), image.get_height()],
		"sha256": _bytes_hash(bytes),
		"provider": "author_import",
	}
	var spatial_plan := str(
		manifest.get("spatial_plan", "res://art/source/halts/%s/spatial_plan.svg" % manifest.id)
	)
	if _safe_path(spatial_plan) and FileAccess.file_exists(spatial_plan):
		copy.source["spatial_plan"] = spatial_plan
	copy["stage"] = "calibration"
	var text := JSON.stringify(copy, "  ", false) + "\n"
	var result := _install({ target: bytes, path: text.to_utf8_buffer() })
	result.merge(
		{
			"path": path,
			"manifest": copy,
			"manifest_sha256": text_hash(text),
			"source_image": image,
		}
	)
	return result


static func export_plan(manifest: Dictionary, path: String) -> Dictionary:
	if not _safe_path(path) or not path.ends_with(".svg"):
		return _failure("Le plan doit être un fichier SVG dans le projet.")
	var checked := validate(manifest, true)
	if not checked.ok:
		return checked
	var source_size: Array = manifest.get("source", { }).get("size", [1600, 900])
	var extent := Vector2(1600, 1600.0 * float(source_size[1]) / float(source_size[0]))
	var lines := PackedStringArray(
		[
			'<svg xmlns="http://www.w3.org/2000/svg" width="%f" height="%f" viewBox="0 0 %f %f">'
			% [extent.x, extent.y, extent.x, extent.y],
			'<rect width="%f" height="%f" fill="#17252b"/>' % [extent.x, extent.y],
		]
	)
	var nav: Dictionary = manifest.get("navigation", { })
	for spec in [[nav.get("outline", []), "#b8a57d"]]:
		if not spec[0].is_empty():
			lines.append(_svg_polygon(spec[0], spec[1], extent))
	for polygon in nav.get("obstacles", []):
		lines.append(_svg_polygon(polygon, "#344c58", extent))
	for polygon in manifest.get("water", { }).get("polygons", []):
		lines.append(_svg_polygon(polygon, "#328e97", extent))
	for region in manifest.get("water", { }).get("regions", []):
		lines.append(_svg_polygon(region.polygon, "#328e97", extent))
	var spawn: Array = manifest.get("world", { }).get("spawn", [])
	if _point_valid(spawn):
		lines.append(
			'<circle cx="%f" cy="%f" r="12" fill="#87db8b"/>'
			% [spawn[0] * extent.x, spawn[1] * extent.y]
		)
	for landmark in manifest.get("landmarks", []):
		var at: Array = landmark.point
		lines.append(
			'<circle cx="%f" cy="%f" r="10" fill="#f2b85e"/>' % [at[0] * extent.x, at[1] * extent.y]
		)
		lines.append(
			'<text x="%f" y="%f" fill="white" font-family="sans-serif" font-size="22">%s</text>'
			% [
				at[0] * extent.x + 16,
				at[1] * extent.y,
				str(landmark.get("title", landmark.get("id", ""))).xml_escape(),
			]
		)
	var references: Array = []
	if _point_valid(spawn):
		references.append(spawn)
	for landmark in manifest.get("landmarks", []):
		references.append(landmark.point)
	var png := Marshalls.raw_to_base64(ScaleReference.texture().get_image().save_png_to_buffer())
	for at: Array in references:
		var rect := ScaleReference.texture_rect(
			manifest,
			Vector2(at[0] * extent.x, at[1] * extent.y),
			extent.y,
		)
		lines.append(
			'<image x="%f" y="%f" width="%f" height="%f" href="data:image/png;base64,%s" opacity="0.8"/>'
			% [rect.position.x, rect.position.y, rect.size.x, rect.size.y, png]
		)
	lines.append(
		'<text x="24" y="36" fill="white" font-family="sans-serif" font-size="22">Achille = %.1f%% hauteur image. Repères uniquement : aucun personnage dans le décor final.</text>'
		% (ScaleReference.height_ratio(manifest) * 100)
	)
	lines.append('</svg>')
	var result := _install({ path: "\n".join(lines).to_utf8_buffer() })
	result["path"] = path
	return result


static func _svg_polygon(points: Array, color: String, extent: Vector2) -> String:
	var pairs := PackedStringArray()
	for at in points:
		pairs.append("%f,%f" % [at[0] * extent.x, at[1] * extent.y])
	return '<polygon points="%s" fill="%s" stroke="#dce8e5" stroke-width="3"/>' % [
		" ".join(pairs),
		color,
	]


static func _validate_source(source: Dictionary, errors: Array[String]) -> void:
	var path := str(source.get("image", ""))
	if not _safe_path(path) or not FileAccess.file_exists(path):
		errors.append("Illustration introuvable ou hors projet.")
		return
	var size: Variant = source.get("size", [])
	if (
		not _finite_pair(size) or int(size[0]) <= 0 or int(size[1]) <= 0
		or int(size[0]) * int(size[1]) > 33554432 or float(size[0]) != floorf(float(size[0]))
		or float(size[1]) != floorf(float(size[1]))
	):
		errors.append("Dimensions source invalides (maximum 32 mégapixels).")
		return
	var backdrop := BackdropSource.new()
	backdrop.background_path = path
	backdrop.source_image_size = Vector2i(int(size[0]), int(size[1]))
	var arena := Arena.new()
	arena.source_image_size = backdrop.source_image_size
	var inspection := BackdropService.new().inspect(
		arena,
		backdrop,
		BackdropService.CopyMode.BACKGROUND_ONLY,
	)
	if (
		not inspection.get("ok", false)
		or inspection.get("actual_image_size") != backdrop.source_image_size
	):
		errors.append("Les dimensions de l’original ont changé : recalibrer une nouvelle version.")
	if FileAccess.get_sha256(path) != str(source.get("sha256", "")):
		errors.append("L’empreinte de l’original a changé : créer une nouvelle version.")


static func _validate_polygon_list(value: Variant, name: String, errors: Array[String]) -> void:
	if not value is Array:
		errors.append(name + " doit être une liste de polygones.")
		return
	for polygon in value:
		_validate_polygon(polygon, name, errors)


static func _validate_polygon(
	value: Variant,
	name: String,
	errors: Array[String],
	allow_empty := false,
) -> void:
	if not value is Array or (value.size() < 3 and not (allow_empty and value.is_empty())):
		errors.append(name + " nécessite au moins trois points.")
		return
	if value.is_empty():
		return
	for at in value:
		if not _point_valid(at):
			errors.append(name + " contient des coordonnées non normalisées.")
			return
	var polygon := _packed_polygon(value)
	var area := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		area += a.cross(b)
		if a.is_equal_approx(b):
			errors.append(name + " contient des points successifs identiques.")
		for j in range(i + 2, polygon.size()):
			if i == 0 and j == polygon.size() - 1:
				continue
			if Geometry2D.segment_intersects_segment(
				a,
				b,
				polygon[j],
				polygon[(j + 1) % polygon.size()],
			) != null:
				errors.append(name + " se croise lui-même.")
				return
	if absf(area) < 0.00000001:
		errors.append(name + " est dégénéré.")


static func _range(
	value: Variant,
	minimum: float,
	maximum: float,
	name: String,
	errors: Array[String],
) -> void:
	if (
		not _number(value) or not is_finite(float(value))
		or float(value) < minimum or float(value) > maximum
	):
		errors.append("%s : valeur attendue entre %s et %s." % [name, minimum, maximum])


static func _validate_anchor(
	value: Variant,
	name: String,
	errors: Array[String],
	allow_empty := false,
) -> void:
	if allow_empty and value is Array and value.is_empty():
		return
	if not _point_valid(value):
		errors.append(name + " nécessite un point normalisé [x,y].")


static func _number(value: Variant) -> bool:
	return value is float or value is int


static func _finite_pair(value: Variant) -> bool:
	return (
		value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])
		and is_finite(float(value[0])) and is_finite(float(value[1]))
	)


static func _point_valid(value: Variant) -> bool:
	return (
		_finite_pair(value) and float(value[0]) >= 0 and float(value[0]) <= 1
		and float(value[1]) >= 0 and float(value[1]) <= 1
	)


static func _packed_polygon(value: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for at in value:
		result.append(Vector2(float(at[0]), float(at[1])))
	return result


static func _rasterize(image: Image, points: Array, color: Color) -> void:
	var polygon := _packed_polygon(points)
	var low := image.get_height()
	var high := 0
	for index in polygon.size():
		polygon[index] *= Vector2(image.get_size())
		low = mini(low, floori(polygon[index].y))
		high = maxi(high, ceili(polygon[index].y))
	for y in range(maxi(0, low), mini(image.get_height(), high)):
		var intersections: Array[float] = []
		var sample_y := float(y) + 0.5
		for index in polygon.size():
			var a := polygon[index]
			var b := polygon[(index + 1) % polygon.size()]
			if (a.y <= sample_y and b.y > sample_y) or (b.y <= sample_y and a.y > sample_y):
				intersections.append(a.x + (sample_y - a.y) * (b.x - a.x) / (b.y - a.y))
		intersections.sort()
		for index in range(0, intersections.size() - 1, 2):
			var first := clampi(ceili(intersections[index] - 0.5), 0, image.get_width())
			var last := clampi(ceili(intersections[index + 1] - 0.5), 0, image.get_width())
			if last > first:
				image.fill_rect(Rect2i(first, y, last - first, 1), color)


static func _same_path(first: String, second: String) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	var a := ProjectSettings.globalize_path(first).simplify_path()
	var b := ProjectSettings.globalize_path(second).simplify_path()
	return a.to_lower() == b.to_lower() if OS.get_name() == "Windows" else a == b


static func _safe_path(path: String) -> bool:
	if (
		not path.begins_with("res://") or "\\" in path
		or path.trim_prefix("res://").is_absolute_path()
	):
		return false
	for component in path.trim_prefix("res://").split("/"):
		if component in [".", "..", ".git", ".godot", ".codex", ".agents"]:
			return false
	return true


static func _valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true


static func _check_save_path(
	path: String,
	manifest: Dictionary,
	expected_hash: String,
) -> Dictionary:
	if not manifest.get("source", { }) is Dictionary:
		return _failure("Source invalide.")
	if not _safe_path(path) or not path.ends_with(".json"):
		return _failure("Chemin du manifeste invalide.")
	if (
		_same_path(path, str(manifest.get("source", { }).get("image", "")))
		or _same_path(path, str(manifest.get("build_dir", "")).path_join("build.json"))
	):
		return _failure("Le manifeste écraserait une source ou un fichier dérivé.")
	if not expected_hash.is_empty() and manifest_hash(path) != expected_hash:
		return _failure("Le manifeste a changé sur disque. Recharger avant d’enregistrer.")
	if FileAccess.file_exists(path):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if previous is Dictionary:
			if previous.get("id") != manifest.get("id"):
				return _failure("Une autre halte occupe déjà ce chemin.")
			if not previous.get("source", { }) is Dictionary:
				return _failure("La source du manifeste existant est invalide.")
			var previous_source: Dictionary = previous.get("source", { })
			if not previous_source.is_empty():
				for field in ["image", "sha256"]:
					if previous_source.get(field) != manifest.get("source", { }).get(field):
						return _failure(
							"L’original est immuable dans cette version. Créer une nouvelle version."
						)
				# JSON parses numbers as floats, while new imports measure integer pixels.
				# Compare dimensions numerically instead of Array's strict element types.
				var previous_size: Variant = previous_source.get("size", [])
				var current_size: Variant = manifest.get("source", { }).get("size", [])
				if not _finite_pair(previous_size) or not _finite_pair(current_size):
					return _failure("Dimensions de l’original invalides.")
				if (
					float(previous_size[0]) != float(current_size[0])
					or float(previous_size[1]) != float(current_size[1])
				):
					return _failure(
						"Les dimensions de l’original sont immuables dans cette version."
					)
				if previous.get("build_dir") != manifest.get("build_dir"):
					return _failure("Le dossier de construction appartient à cette version.")
	return { "ok": true, "errors": [] }


static func _bytes_hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _import_settings(path: String) -> String:
	var settings := ConfigFile.new()
	settings.load(path + ".import")
	var cache := "res://.godot/imported/%s-%s.ctex" % [path.get_file(), path.md5_text()]
	settings.set_value("remap", "importer", "texture")
	settings.set_value("remap", "type", "CompressedTexture2D")
	settings.set_value("remap", "path", cache)
	settings.set_value("deps", "source_file", path)
	settings.set_value("deps", "dest_files", PackedStringArray([cache]))
	settings.set_value("params", "compress/mode", 0)
	settings.set_value("params", "compress/channel_pack", 0)
	settings.set_value("params", "mipmaps/generate", false)
	settings.set_value("params", "process/fix_alpha_border", false)
	settings.set_value("params", "process/premult_alpha", false)
	return settings.encode_to_text()


static func _install(files: Dictionary) -> Dictionary:
	# Same-directory staging and byte verification mirror Studio draft transactions.
	var suffix := ".halt-%d" % Time.get_ticks_usec()
	var stages := { }
	var backups := { }
	var installed: Array[String] = []
	for path: String in files:
		if not _safe_path(path):
			_cleanup(stages.values())
			return _failure("Écriture hors projet refusée.")
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
			_cleanup(stages.values())
			return _failure("Impossible de créer le dossier de destination.")
		var stage := absolute + suffix + ".tmp"
		var file := FileAccess.open(stage, FileAccess.WRITE)
		if file == null:
			_cleanup(stages.values())
			return _failure("Impossible d’écrire les fichiers temporaires.")
		file.store_buffer(files[path])
		file.close()
		stages[absolute] = stage
		if FileAccess.get_file_as_bytes(stage) != files[path]:
			_cleanup(stages.values())
			return _failure("Vérification des fichiers temporaires échouée.")
	for absolute: String in stages:
		if FileAccess.file_exists(absolute):
			var backup := absolute + suffix + ".previous"
			if (
				DirAccess.copy_absolute(absolute, backup) != OK
				or FileAccess.get_sha256(absolute) != FileAccess.get_sha256(backup)
			):
				_cleanup(stages.values() + backups.values() + [backup])
				return _failure("Sauvegarde de restauration impossible.")
			backups[absolute] = backup
	for absolute: String in stages:
		if FileAccess.file_exists(absolute) and DirAccess.remove_absolute(absolute) != OK:
			return _rollback(installed, stages, backups, "Remplacement impossible.")
		installed.append(absolute)
		if DirAccess.rename_absolute(stages[absolute], absolute) != OK:
			return _rollback(installed, stages, backups, "Installation impossible.")
	_cleanup(stages.values() + backups.values())
	return { "ok": true, "errors": [] }


static func _rollback(
	installed: Array[String],
	stages: Dictionary,
	backups: Dictionary,
	reason: String,
) -> Dictionary:
	var restored := true
	for absolute in installed:
		if FileAccess.file_exists(absolute):
			restored = DirAccess.remove_absolute(absolute) == OK and restored
		if backups.has(absolute):
			restored = DirAccess.copy_absolute(backups[absolute], absolute) == OK and restored
			restored = (
				FileAccess.get_sha256(backups[absolute]) == FileAccess.get_sha256(absolute)
				and restored
			)
	_cleanup(stages.values())
	if restored:
		_cleanup(backups.values())
	var result := _failure(
		reason
		+ (
			" Modifications précédentes restaurées." if restored else " Restauration incomplète : sauvegardes .previous conservées."
		)
	)
	result["rollback_ok"] = restored
	return result


static func _cleanup(paths: Array) -> void:
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func _failure(message: String) -> Dictionary:
	return { "ok": false, "errors": [message] }
