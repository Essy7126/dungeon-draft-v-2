extends SceneTree

## Normaliseur deterministe des sources de dalles permanentes du laboratoire.
## Une seule intersection de bounding boxes, une seule transformation et un
## masque commun sont appliques a toutes les images.

const RAW_DIR := "res://tools/labs/dynamic_arena/assets/raw"
const NORMALIZED_DIR := "res://tools/labs/dynamic_arena/assets/normalized"
const COMPARISON_PATH := "res://artifacts/labs/dynamic_arena/normalized_tiles.png"
const OUTPUT_SIZE := ArenaTileVisualNormalizationService.OUTPUT_SIZE

const SOURCE_SPECS := [
	{
		"name": "stone",
		"raw": RAW_DIR + "/stone.png",
		"fallback": "res://tools/labs/dynamic_arena/assets/dalle_base.png",
	},
	{
		"name": "neutral",
		"raw": RAW_DIR + "/neutre.png",
		"fallback": "",
	},
	{
		"name": "lava",
		"raw": RAW_DIR + "/lava.png",
		"fallback": "res://tools/labs/dynamic_arena/assets/dalle_lave.png",
	},
	{
		"name": "ice",
		"raw": RAW_DIR + "/ice.png",
		"fallback": "res://tools/labs/dynamic_arena/assets/dalle_glace.png",
	},
	{
		"name": "water",
		"raw": RAW_DIR + "/water.png",
		"fallback": "res://tools/labs/dynamic_arena/assets/dalle_eau.png",
	},
	{
		"name": "poison",
		"raw": RAW_DIR + "/poison.png",
		"fallback": "",
	},
	{
		"name": "steam",
		"raw": RAW_DIR + "/vapeur.png",
		"fallback": "",
	},
	{
		"name": "electrified_water",
		"raw": RAW_DIR + "/électrique.png",
		"fallback": "",
	},
	{
		"name": "vortex",
		"raw": RAW_DIR + "/vortex.png",
		"fallback": "",
	},
]


func _initialize() -> void:
	call_deferred("_normalize_all")


func _normalize_all() -> void:
	var raw_absolute := ProjectSettings.globalize_path(RAW_DIR)
	var normalized_absolute := ProjectSettings.globalize_path(NORMALIZED_DIR)
	var artifact_absolute := ProjectSettings.globalize_path(COMPARISON_PATH).get_base_dir()
	DirAccess.make_dir_recursive_absolute(raw_absolute)
	DirAccess.make_dir_recursive_absolute(normalized_absolute)
	DirAccess.make_dir_recursive_absolute(artifact_absolute)

	var sources: Array[Image] = []
	var source_paths: Array[String] = []
	var alpha_bounds: Array[Rect2i] = []
	for spec in SOURCE_SPECS:
		var source_path := _ensure_raw_source(spec)
		if source_path.is_empty():
			push_error("Source absente pour %s." % str(spec["name"]))
			quit(1)
			return
		var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if image == null or image.is_empty():
			push_error("PNG illisible : %s" % source_path)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		sources.append(image)
		source_paths.append(source_path)
		alpha_bounds.append(_alpha_bounds(image))

	var shared_crop := _intersect_bounds(alpha_bounds)
	if shared_crop.size.x <= 0 or shared_crop.size.y <= 0:
		push_error("Les neuf sources n'ont pas de zone alpha commune.")
		quit(1)
		return

	var normalized: Array[Image] = []
	var failures := 0
	for index in range(SOURCE_SPECS.size()):
		var output := _normalize_image(sources[index], shared_crop)
		var output_path := NORMALIZED_DIR.path_join(
			"%s.png" % str(SOURCE_SPECS[index]["name"])
		)
		var error := output.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error("Echec d'ecriture %s : %s" % [output_path, error_string(error)])
			failures += 1
		else:
			print("NORMALIZED %s crop=%s size=%s" % [output_path, shared_crop, OUTPUT_SIZE])
		normalized.append(output)

	if failures == 0:
		failures += _save_comparison(sources, normalized)
	quit(1 if failures > 0 else 0)


func _ensure_raw_source(spec: Dictionary) -> String:
	var raw_path := str(spec["raw"])
	if FileAccess.file_exists(raw_path):
		return raw_path
	var fallback_path := str(spec["fallback"])
	if fallback_path.is_empty() or not FileAccess.file_exists(fallback_path):
		return ""
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(fallback_path),
		ProjectSettings.globalize_path(raw_path)
	)
	if copy_error != OK:
		push_error("Copie de source impossible : %s" % error_string(copy_error))
		return ""
	print("COPIED SOURCE %s -> %s" % [fallback_path, raw_path])
	return raw_path


func _alpha_bounds(image: Image) -> Rect2i:
	return ArenaTileVisualNormalizationService.alpha_bounds(image)


func _intersect_bounds(bounds: Array[Rect2i]) -> Rect2i:
	return ArenaTileVisualNormalizationService.intersect_bounds(bounds)


func _normalize_image(source: Image, shared_crop: Rect2i) -> Image:
	return ArenaTileVisualNormalizationService.normalize(source, shared_crop)


func _save_comparison(sources: Array[Image], normalized: Array[Image]) -> int:
	const PANEL_SIZE := Vector2i(272, 560)
	var canvas_size := Vector2i(24 + SOURCE_SPECS.size() * 292, 640)
	var canvas := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("101722"))
	var accents := [
		Color("98a8b8"), Color("d8c8a8"), Color("ff6437"),
		Color("a9eaff"), Color("39bde3"), Color("6fc241"),
		Color("c9c9c9"), Color("48c8ff"), Color("b65cff"),
	]
	for index in range(SOURCE_SPECS.size()):
		var panel_position := Vector2i(24 + index * 292, 40)
		canvas.fill_rect(Rect2i(panel_position, PANEL_SIZE), Color("1d2938"))
		canvas.fill_rect(Rect2i(panel_position, Vector2i(PANEL_SIZE.x, 8)), accents[index])
		var thumbnail := sources[index].duplicate()
		thumbnail.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		canvas.blend_rect(thumbnail, thumbnail.get_used_rect(), panel_position + Vector2i(8, 48))
		var normalized_position := panel_position + Vector2i(8, 384)
		canvas.blend_rect(
			normalized[index],
			Rect2i(Vector2i.ZERO, OUTPUT_SIZE),
			normalized_position
		)
		canvas.fill_rect(
			Rect2i(panel_position + Vector2i(8, 532), Vector2i(256, 3)),
			accents[index]
		)
	var error := canvas.save_png(ProjectSettings.globalize_path(COMPARISON_PATH))
	if error != OK:
		push_error("Echec de la planche comparative : %s" % error_string(error))
		return 1
	print("COMPARISON %s %dx%d" % [COMPARISON_PATH, canvas_size.x, canvas_size.y])
	return 0
