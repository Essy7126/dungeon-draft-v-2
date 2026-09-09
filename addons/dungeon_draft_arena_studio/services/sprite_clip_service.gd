@tool
extends RefCounted
## Clip documents share one implementation between the workshop and headless builds.
## Pixels are copied from pinned sources; this service does not invent drawings.

const SCHEMA := 1
const SOURCE_ROOT := "res://art/source/sprite_workshop/"
const OUTPUT_ROOT := "res://artifacts/sprite_workshop/"
const TEST_ROOT := "user://sprite_workshop/tests/"


static func failure(message: String) -> Dictionary:
	return { "ok": false, "errors": [message], "warnings": [] }


static func project_path(path: String) -> bool:
	return (
		(path.begins_with("res://") or path.begins_with(TEST_ROOT))
		and not ".." in path and not "\\" in path
	)


static func writable(path: String) -> bool:
	return (
		project_path(path)
		and (
			path.begins_with(SOURCE_ROOT) or path.begins_with(OUTPUT_ROOT)
			or path.begins_with(TEST_ROOT)
		)
	)


static func read_document(path: String) -> Dictionary:
	if not project_path(path) or not FileAccess.file_exists(path):
		return failure("Document absent ou chemin invalide : " + path)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return failure("JSON invalide : " + parser.get_error_message())
	return { "ok": true, "document": parser.data }


static func write_json(path: String, value: Dictionary) -> Dictionary:
	if not writable(path) or path.get_extension() != "json":
		return failure("Écriture réservée aux documents et exports de l'atelier.")
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return failure(error_string(error))
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return failure(error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(value, "\t", true) + "\n")
	file.close()
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	return { "ok": true, "path": path } if error == OK else failure(error_string(error))


static func fingerprint(document: Dictionary) -> String:
	var content := document.duplicate(true)
	content.erase("review")
	# JSON numbers are floats after reading. Normalize before hashing so a save/reload
	# cannot expire an approval or create another export directory on its own.
	var normalized: Variant = JSON.parse_string(JSON.stringify(content, "", true))
	return JSON.stringify(normalized, "", true).sha256_text()


static func review_current(document: Dictionary) -> bool:
	var review: Variant = document.get("review", { })
	return (
		review is Dictionary and review.get("fingerprint", "") == fingerprint(document)
		and not str(review.get("reviewer", "")).strip_edges().is_empty()
		and not str(review.get("note", "")).strip_edges().is_empty()
	)


static func approve_visual(document: Dictionary, reviewer: String, note: String) -> Dictionary:
	var report := validate(document)
	if not report.ok:
		return report
	if reviewer.strip_edges().is_empty() or note.strip_edges().is_empty():
		return failure("Préciser l'auteur et les observations de la revue visuelle.")
	document.review = { "fingerprint": fingerprint(document), "reviewer": reviewer, "note": note }
	return { "ok": true }


static func texture_source(texture: Texture2D, frame_id: String, duration_ms: float) -> Dictionary:
	var source := texture
	var region := Rect2(Vector2.ZERO, texture.get_size())
	var placement := Vector2.ZERO
	if texture is AtlasTexture:
		source = texture.atlas
		region = texture.region
		placement = texture.margin.position
	if source == null or not source.resource_path.ends_with(".png"):
		return { }
	return {
		"id": frame_id,
		"source": source.resource_path,
		"sha256": FileAccess.get_sha256(source.resource_path),
		"region": [
			int(region.position.x),
			int(region.position.y),
			int(region.size.x),
			int(region.size.y),
		],
		"placement": [int(placement.x), int(placement.y)],
		"offset": [0, 0],
		"duration_ms": duration_ms,
	}


static func import_clip(resource_path: String, animation: String, profile_path := "") -> Dictionary:
	if not project_path(resource_path) or not FileAccess.file_exists(resource_path):
		return failure("SpriteFrames absent ou chemin invalide.")
	var sprites := ResourceLoader.load(
		resource_path,
		"SpriteFrames",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as SpriteFrames
	if (
		sprites == null or not sprites.has_animation(animation)
		or sprites.get_frame_count(animation) == 0
	):
		return failure("Animation absente ou vide : " + animation)
	var fps := sprites.get_animation_speed(animation)
	if fps <= 0.0:
		return failure("La vitesse source doit être positive.")
	var frames: Array = []
	var first := sprites.get_frame_texture(animation, 0)
	if first == null:
		return failure("La première pose est vide.")
	for index in sprites.get_frame_count(animation):
		var texture := sprites.get_frame_texture(animation, index)
		if texture == null or texture.get_size() != first.get_size():
			return failure("Les dessins doivent partager le même canevas logique.")
		var frame := texture_source(
			texture,
			"f%03d" % index,
			1000.0 * sprites.get_frame_duration(animation, index) / fps,
		)
		if frame.is_empty():
			return failure("Seuls les PNG et AtlasTexture sur PNG sont importés.")
		frames.append(frame)
	var doc := {
		"schema_version": SCHEMA,
		"id": animation.to_lower(),
		"animation": animation,
		"title": animation,
		"direction": animation.get_slice("_", animation.get_slice_count("_") - 1),
		"intent": "À préciser : intention, poses clés et défauts à corriger.",
		"canvas": [int(first.get_width()), int(first.get_height())],
		"anchor": [int(first.get_width() / 2), int(first.get_height() * 5 / 6)],
		"display_scale": 0.35,
		"frames": frames,
		"events": [],
		"playback": { "mode": "loop" if sprites.get_animation_loop(animation) else "once" },
		"provenance": { resource_path: FileAccess.get_sha256(resource_path) },
		"review": { },
		"open_questions": ["Validation artistique et essai en combat à réaliser."],
	}
	if not profile_path.is_empty():
		if not project_path(profile_path) or not FileAccess.file_exists(profile_path):
			return failure("Profil absent ou chemin invalide.")
		var profile := ResourceLoader.load(profile_path)
		if profile == null:
			return failure("Profil illisible.")
		doc.provenance[profile_path] = FileAccess.get_sha256(profile_path)
		for property in profile.get_property_list():
			if property.name == "display_scale":
				doc.display_scale = float(profile.get("display_scale"))
			elif property.name == "foot_anchor":
				var anchor: Vector2 = profile.get("foot_anchor")
				doc.anchor = [int(anchor.x), int(anchor.y)]
	var idle := "idle_" + str(doc.direction)
	if sprites.has_animation(idle):
		doc["reference"] = texture_source(sprites.get_frame_texture(idle, 0), "reference", 100.0)
	doc["baseline"] = {
		"frames": frames.duplicate(true),
		"events": [],
		"playback": doc.playback.duplicate(true),
		"anchor": doc.anchor.duplicate(),
		"display_scale": doc.display_scale,
	}
	return { "ok": true, "document": doc }


static func new_clip(paths: Array, reference_path: String, animation: String) -> Dictionary:
	if paths.is_empty() or paths.size() > 64:
		return failure("Choisir de 1 à 64 PNG normalisés.")
	var frames := []
	var canvas := Vector2i.ZERO
	var reference := { }
	var all_paths := paths.duplicate()
	all_paths.append(reference_path)
	for index in all_paths.size():
		var path := str(all_paths[index])
		if not project_path(path) or not path.ends_with(".png") or not FileAccess.file_exists(path):
			return failure("PNG absent ou chemin invalide : " + path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			return failure("PNG illisible : " + path)
		if index == 0:
			canvas = image.get_size()
		if image.get_size() != canvas:
			return failure(
				"Normaliser les dessins et la référence au même canevas, sans ajuster l'échelle par pose."
			)
		var frame := {
			"id": "f%03d" % index,
			"source": path,
			"sha256": FileAccess.get_sha256(path),
			"region": [0, 0, canvas.x, canvas.y],
			"placement": [0, 0],
			"offset": [0, 0],
			"duration_ms": 100.0,
		}
		if index < paths.size():
			frames.append(frame)
		else:
			frame.id = "reference"
			reference = frame
	var document := {
		"schema_version": SCHEMA,
		"id": animation.to_lower(),
		"animation": animation,
		"title": animation,
		"intent": "À préciser : intention, poses clés et défauts à corriger.",
		"direction": animation.get_slice("_", animation.get_slice_count("_") - 1),
		"canvas": [canvas.x, canvas.y],
		"anchor": [int(canvas.x / 2), int(canvas.y * 5 / 6)],
		"display_scale": 0.35,
		"frames": frames,
		"reference": reference,
		"playback": { "mode": "once" },
		"events": [],
		"review": { },
		"provenance": { },
		"open_questions": [
			"Revoir l'ancre, l'échelle, les événements, le dessin et la lecture en combat."
		],
	}
	document.baseline = {
		"frames": frames.duplicate(true),
		"events": [],
		"playback": { "mode": "once" },
		"anchor": document.anchor.duplicate(),
		"display_scale": document.display_scale,
	}
	var report := validate(document)
	return { "ok": true, "document": document } if report.ok else report


static func vector_array(value: Variant, count: int, integral := false) -> bool:
	if not value is Array or value.size() != count:
		return false
	for item in value:
		if not (item is float or item is int) or not is_finite(float(item)):
			return false
		if integral and float(item) != floor(float(item)):
			return false
	return true


static func validate(document: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	if document.get("schema_version") != SCHEMA:
		return failure("Version de document non supportée.")
	var identifier := str(document.get("id", ""))
	if (
		identifier.is_empty() or identifier != identifier.validate_filename()
		or "/" in identifier or ".." in identifier
	):
		return failure("Identifiant de clip invalide.")
	if not document.get("animation") is String or document.animation.is_empty():
		return failure("Nom d'animation absent.")
	if (
		not vector_array(document.get("canvas"), 2, true)
		or not vector_array(document.get("anchor"), 2, true)
	):
		return failure("Canevas et ancre : deux coordonnées entières requises.")
	var canvas := Vector2i(document.canvas[0], document.canvas[1])
	if canvas.x < 1 or canvas.y < 1 or canvas.x > 1024 or canvas.y > 1024:
		return failure("Canevas attendu entre 1 et 1024 pixels par côté.")
	if (
		document.anchor[0] < 0 or document.anchor[1] < 0
		or document.anchor[0] > canvas.x or document.anchor[1] > canvas.y
	):
		return failure("Ancre de sol hors du canevas.")
	if (
		not vector_array([document.get("display_scale")], 1)
		or document.display_scale <= 0 or document.display_scale > 4
	):
		return failure("Échelle d'affichage invalide.")
	if not document.get("direction") in ["N", "E", "S", "W"]:
		return failure("Direction attendue : N, E, S ou W.")
	if not document.get("provenance") is Dictionary:
		return failure("Provenance absente.")
	if not document.get("open_questions", []) is Array:
		return failure("Les questions ouvertes doivent être une liste.")
	for question in document.get("open_questions", []):
		if not question is String:
			return failure("Chaque question ouverte doit être un texte.")
	for path in document.provenance:
		if (
			not path is String or not project_path(path) or not FileAccess.file_exists(path)
			or FileAccess.get_sha256(path) != document.provenance[path]
		):
			errors.append("Source de référence modifiée ou absente : " + str(path))
	var cache := { }
	var current := _validate_track(document, canvas, cache)
	errors.append_array(current.errors)
	warnings.append_array(current.warnings)
	if not document.get("baseline") is Dictionary:
		errors.append("Comparaison d'origine absente.")
	else:
		if (
			not vector_array(document.baseline.get("anchor"), 2, true)
			or not vector_array([document.baseline.get("display_scale")], 1)
		):
			return failure("Ancre ou échelle de la comparaison d'origine absente.")
		var original := _validate_track(document.baseline, canvas, cache)
		for error in original.errors:
			errors.append("Original : " + error)
	if document.has("reference"):
		var reference_report := _validate_frames([document.reference], canvas, cache)
		errors.append_array(reference_report.errors)
	if not review_current(document):
		warnings.append("Revue artistique absente ou périmée après modification.")
	warnings.append("L'export ne valide pas l'intégration ni le comportement en combat.")
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"fingerprint": fingerprint(document),
		"frames": current.get("count", 0),
		"visual_review_current": review_current(document),
		"open_questions": document.get("open_questions", []),
	}


static func _validate_track(track: Dictionary, canvas: Vector2i, cache: Dictionary) -> Dictionary:
	var report := _validate_frames(track.get("frames"), canvas, cache)
	if not report.ok:
		return report
	var playback: Variant = track.get("playback")
	var events: Variant = track.get("events")
	if (
		not playback is Dictionary
		or not playback.get("mode") in ["once", "loop", "arrival"] or not events is Array
	):
		return failure("Lecture ou événements invalides.")
	var ids: Array = track.frames.map(
		func(frame: Dictionary) -> String:
			return str(frame.id),
	)
	if playback.mode == "arrival":
		if (
			not playback.get("hold_frame") in ids
			or ids.find(playback.get("hold_frame")) == ids.size() - 1
		):
			return failure("L'attente d'arrivée nécessite une pose suivie d'une réception.")
		if (
			not vector_array([playback.get("arrival_preview_ms")], 1)
			or float(playback.arrival_preview_ms) < _frame_start(track, str(playback.hold_frame))
			or float(playback.arrival_preview_ms) > 10000
		):
			return failure(
				"L'arrivée simulée doit suivre le début de la pose d'attente (maximum 10 s)."
			)
	var names := []
	for event in events:
		if (
			not event is Dictionary or not event.get("frame") in ids
			or not event.get("name") is String
			or event.name.is_empty() or event.get("name") in names
		):
			return failure("Chaque événement doit avoir un nom unique et une pose existante.")
		names.append(event.name)
	return report


static func _validate_frames(frames: Variant, canvas: Vector2i, cache: Dictionary) -> Dictionary:
	if not frames is Array or frames.is_empty() or frames.size() > 64:
		return failure("Un clip contient de 1 à 64 dessins.")
	var errors := []
	var warnings := []
	var ids := []
	for frame in frames:
		if (
			not frame is Dictionary or not frame.get("id") is String
			or frame.id.is_empty() or frame.get("id") in ids
		):
			return failure("Identifiants de poses absents ou répétés.")
		ids.append(frame.id)
		if (
			not vector_array(frame.get("region"), 4, true)
			or not vector_array(frame.get("placement"), 2, true)
			or not vector_array(frame.get("offset"), 2, true)
			or not vector_array([frame.get("duration_ms")], 1)
		):
			return failure("Région, position ou durée invalide : " + str(frame.id))
		if frame.duration_ms < 1 or frame.duration_ms > 10000:
			return failure("Durée attendue entre 1 et 10000 ms : " + str(frame.id))
		var path := str(frame.get("source", ""))
		if not project_path(path) or not path.ends_with(".png") or not FileAccess.file_exists(path):
			return failure("PNG absent ou chemin invalide : " + path)
		if not cache.has(path):
			cache[path] = {
				"hash": FileAccess.get_sha256(path),
				"image": Image.load_from_file(ProjectSettings.globalize_path(path)),
			}
		if cache[path].hash != frame.get("sha256"):
			return failure("PNG modifié depuis la sélection : " + path)
		var source: Image = cache[path].image
		if source == null or source.is_empty():
			return failure("PNG illisible : " + path)
		var rect := Rect2i(frame.region[0], frame.region[1], frame.region[2], frame.region[3])
		if (
			rect.size.x <= 0 or rect.size.y <= 0
			or not Rect2i(Vector2i.ZERO, source.get_size()).encloses(rect)
		):
			return failure("Découpe hors du PNG : " + str(frame.id))
		var crop := source.get_region(rect)
		var used := crop.get_used_rect()
		var position := Vector2i(
			frame.placement[0] + frame.offset[0],
			frame.placement[1] + frame.offset[1],
		)
		used.position += position
		if not used.has_area():
			errors.append("Pose vide : " + str(frame.id))
		elif not Rect2i(Vector2i.ZERO, canvas).encloses(used):
			errors.append("Pixels coupés par le canevas : " + str(frame.id))
		elif (
			used.position.x == 0 or used.position.y == 0
			or used.end.x == canvas.x or used.end.y == canvas.y
		):
			warnings.append("Pixels au bord du canevas, à examiner : " + str(frame.id))
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"count": frames.size(),
	}


static func frame_image(frame: Dictionary, canvas: Array, cache: Dictionary) -> Image:
	var path: String = frame.source
	if not cache.has(path):
		var source := Image.load_from_file(ProjectSettings.globalize_path(path))
		source.convert(Image.FORMAT_RGBA8)
		cache[path] = source
	var image := Image.create_empty(canvas[0], canvas[1], false, Image.FORMAT_RGBA8)
	image.blit_rect(
		cache[path],
		Rect2i(frame.region[0], frame.region[1], frame.region[2], frame.region[3]),
		Vector2i(frame.placement[0] + frame.offset[0], frame.placement[1] + frame.offset[1]),
	)
	return image


static func _frame_start(track: Dictionary, frame_id: String) -> float:
	var elapsed := 0.0
	for frame in track.frames:
		if frame.id == frame_id:
			return elapsed
		elapsed += float(frame.duration_ms)
	return elapsed


static func frame_duration(track: Dictionary, index: int, arrival_ms := -1.0) -> float:
	var frame: Dictionary = track.frames[index]
	if track.playback.mode == "arrival" and frame.id == track.playback.hold_frame:
		var arrival := arrival_ms if arrival_ms >= 0.0 else float(track.playback.arrival_preview_ms)
		return maxf(0.0, arrival - _frame_start(track, str(frame.id)))
	return float(frame.duration_ms)


static func sample(track: Dictionary, elapsed_ms: float, arrival_ms := -1.0) -> int:
	var total := duration(track, arrival_ms)
	var time := maxf(elapsed_ms, 0.0)
	if track.playback.mode == "loop" and total > 0:
		time = fmod(time, total)
	for index in track.frames.size():
		var hold := frame_duration(track, index, arrival_ms)
		if time < hold:
			return index
		time -= hold
	return track.frames.size() - 1


static func duration(track: Dictionary, arrival_ms := -1.0) -> float:
	var total := 0.0
	for index in track.frames.size():
		total += frame_duration(track, index, arrival_ms)
	return total


static func event_times(track: Dictionary) -> Array:
	var result := []
	for event in track.events:
		var start := 0.0
		for index in track.frames.size():
			if track.frames[index].id == event.frame:
				break
			start += frame_duration(track, index)
		result.append(
			{
				"name": event.name,
				"frame": event.frame,
				"preview_ms": start,
				"controller_owned": track.playback.mode == "arrival",
			}
		)
	return result


static func export_clip(document: Dictionary, output_root := OUTPUT_ROOT) -> Dictionary:
	var report := validate(document)
	if not report.ok:
		return report
	if (
		not (output_root.begins_with(OUTPUT_ROOT) or output_root.begins_with(TEST_ROOT))
		or not writable(output_root)
	):
		return failure("Les exports doivent rester dans le dossier de revue de l'atelier.")
	var directory := output_root.path_join(str(document.id) + "/" + fingerprint(document))
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		return failure(error_string(error))
	var canvas := Vector2i(document.canvas[0], document.canvas[1])
	var count: int = document.frames.size()
	var columns := mini(count, 4)
	var stride := canvas + Vector2i(2, 2)
	var atlas := Image.create_empty(
		stride.x * columns,
		stride.y * ceili(float(count) / columns),
		false,
		Image.FORMAT_RGBA8,
	)
	var cache := { }
	var images: Array[Image] = []
	error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory.path_join("frames"))
	)
	if error != OK:
		return failure(error_string(error))
	for index in count:
		var image := frame_image(document.frames[index], document.canvas, cache)
		images.append(image)
		atlas.blit_rect(
			image,
			Rect2i(Vector2i.ZERO, canvas),
			Vector2i(index % columns, index / columns) * stride + Vector2i.ONE,
		)
		error = image.save_png(directory.path_join("frames/%03d.png" % index))
		if error != OK:
			return failure(error_string(error))
	if document.has("reference"):
		var reference := frame_image(document.reference, document.canvas, cache)
		error = reference.save_png(directory.path_join("reference.png"))
		if error != OK:
			return failure(error_string(error))
	error = atlas.save_png(directory.path_join("atlas.png"))
	if error != OK:
		return failure(error_string(error))
	var texture := ImageTexture.create_from_image(atlas)
	var sprites := SpriteFrames.new()
	sprites.remove_animation("default")
	var animation := StringName(document.animation)
	sprites.add_animation(animation)
	sprites.set_animation_speed(animation, 1000.0)
	sprites.set_animation_loop(animation, document.playback.mode == "loop")
	var hashes := []
	for index in count:
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = texture
		frame_texture.region = Rect2(
			Vector2i(index % columns, index / columns) * stride + Vector2i.ONE,
			canvas,
		)
		frame_texture.filter_clip = true
		sprites.add_frame(animation, frame_texture, float(document.frames[index].duration_ms))
		hashes.append(images[index].get_data().hex_encode().sha256_text())
	# Embedded texture: this review resource works even under artifacts/.gdignore.
	var resource_path := directory.path_join("clip.res")
	error = ResourceSaver.save(sprites, resource_path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		return failure(error_string(error))
	var roundtrip := ResourceLoader.load(
		resource_path,
		"SpriteFrames",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as SpriteFrames
	if roundtrip == null or roundtrip.get_frame_count(animation) != count:
		return failure("Impossible de relire l'export SpriteFrames.")
	for index in count:
		var restored := roundtrip.get_frame_texture(animation, index).get_image()
		if (
			restored.get_data() != images[index].get_data()
			or not is_equal_approx(
				roundtrip.get_frame_duration(animation, index),
				float(document.frames[index].duration_ms),
			)
		):
			return failure("L'export ne restitue pas les pixels ou durées de la pose %d." % index)
	var snapshot_result := write_json(directory.path_join("clip.json"), document)
	if not snapshot_result.ok:
		return snapshot_result
	var timing_result := write_json(
		directory.path_join("timing.json"),
		{
			"schema_version": SCHEMA,
			"anchor": document.anchor,
			"display_scale": document.display_scale,
			"playback": document.playback,
			"events": event_times(document),
			"note": "Les événements et l'attente d'arrivée doivent être reliés au contrôleur du jeu. AnimatedSprite2D seul ne les exécute pas.",
		},
	)
	if not timing_result.ok:
		return timing_result
	report.merge(
		{
			"directory": directory,
			"sprite_frames": resource_path,
			"pixel_roundtrip": true,
			"frame_hashes": hashes,
			"events": event_times(document),
			"runtime_integration_verified": false,
			"godot_version": Engine.get_version_info().string,
		},
		true,
	)
	var report_result := write_json(directory.path_join("report.json"), report)
	return report if report_result.ok else report_result
