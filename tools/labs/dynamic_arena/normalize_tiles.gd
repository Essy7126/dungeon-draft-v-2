extends SceneTree

## Normaliseur deterministe des quatre sources du laboratoire.
## Une seule intersection de bounding boxes, une seule transformation et un
## masque commun sont appliques aux quatre images.

const RAW_DIR := "res://tools/labs/dynamic_arena/assets/raw"
const NORMALIZED_DIR := "res://tools/labs/dynamic_arena/assets/normalized"
const COMPARISON_PATH := "res://artifacts/labs/dynamic_arena/normalized_tiles.png"
const OUTPUT_SIZE := Vector2i(256, 128)
const ALPHA_THRESHOLD := 0.01

const SOURCE_SPECS := [
	{
		"name": "stone",
		"raw": RAW_DIR + "/stone.png",
		"fallback": "res://tools/labs/dynamic_arena/assets/dalle_base.png",
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
		push_error("Les quatre sources n'ont pas de zone alpha commune.")
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
	if not FileAccess.file_exists(fallback_path):
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
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _intersect_bounds(bounds: Array[Rect2i]) -> Rect2i:
	if bounds.is_empty():
		return Rect2i()
	var left := bounds[0].position.x
	var top := bounds[0].position.y
	var right := bounds[0].end.x
	var bottom := bounds[0].end.y
	for rect in bounds:
		left = maxi(left, rect.position.x)
		top = maxi(top, rect.position.y)
		right = mini(right, rect.end.x)
		bottom = mini(bottom, rect.end.y)
	return Rect2i(left, top, maxi(0, right - left), maxi(0, bottom - top))


func _normalize_image(source: Image, shared_crop: Rect2i) -> Image:
	var output := source.get_region(shared_crop)
	output.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	output.convert(Image.FORMAT_RGBA8)
	for y in range(OUTPUT_SIZE.y):
		for x in range(OUTPUT_SIZE.x):
			var color := output.get_pixel(x, y)
			if _inside_diamond(x, y):
				# Le masque est l'alpha final : bounding box identique et pas de
				# frange issue des fonds des images sources.
				color.a = 1.0
			else:
				color = Color(0.0, 0.0, 0.0, 0.0)
			output.set_pixel(x, y, color)
	return output


func _inside_diamond(x: int, y: int) -> bool:
	if y <= 64:
		var left := 128.0 - float(y) * 2.0
		var right := 128.0 + float(y) * (127.0 / 64.0)
		return float(x) >= left and float(x) <= right
	var lower_y := float(y - 64)
	var left := lower_y * (128.0 / 63.0)
	var right := 255.0 - lower_y * (127.0 / 63.0)
	return float(x) >= left and float(x) <= right


func _save_comparison(sources: Array[Image], normalized: Array[Image]) -> int:
	const CANVAS_SIZE := Vector2i(1200, 640)
	const PANEL_SIZE := Vector2i(272, 560)
	var canvas := Image.create(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("101722"))
	var accents := [Color("98a8b8"), Color("ff6437"), Color("a9eaff"), Color("39bde3")]
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
	print("COMPARISON %s %dx%d" % [COMPARISON_PATH, CANVAS_SIZE.x, CANVAS_SIZE.y])
	return 0
