extends SceneTree

## One-shot source processor for the Achilles 2D POC.
##
## It reads the three untouched 6x6 Ludo exports and writes only derived PNGs
## below assets/characters/Achilles/processed. Every selected frame keeps the
## sheet cell's horizontal registration; only its opaque foot contact is moved
## vertically onto the shared FOOT_LINE_Y.

const GRID := Vector2i(6, 6)
const OUTPUT_SIZE := Vector2i(128, 160)
const FOOT_LINE_Y := 144
const REFERENCE_CHARACTER_HEIGHT := 128.0
const OUTPUT_DIR := "res://assets/characters/Achilles/processed"

const CONFIG := {
	"idle": {
		"source": "res://assets/characters/Achilles/idle.png",
		"indices": [0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33],
		"reference_frame": 0,
	},
	"walk": {
		"source": "res://assets/characters/Achilles/walk.png",
		"indices": [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34],
		"reference_frame": 0,
	},
	"attack": {
		"source": "res://assets/characters/Achilles/attack.png",
		"indices": [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34],
		"reference_frame": 0,
	},
}

var _manifest := {
	"grid": [GRID.x, GRID.y],
	"normalization": {
		"output_frame_size": [OUTPUT_SIZE.x, OUTPUT_SIZE.y],
		"processed_foot_anchor": [OUTPUT_SIZE.x / 2, FOOT_LINE_Y],
		"godot_node_foot_anchor": [0, 0],
		"reference_character_height": REFERENCE_CHARACTER_HEIGHT,
	},
	"animations": {},
}


func _initialize() -> void:
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if mkdir_error != OK:
		push_error("Achilles processor: cannot create %s (error %d)." % [absolute_output, mkdir_error])
		quit(1)
		return
	for animation_name in CONFIG:
		var error := _process_animation(animation_name, CONFIG[animation_name])
		if error != OK:
			quit(1)
			return
	var manifest_path := "%s/source_audit.json" % OUTPUT_DIR
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		push_error("Achilles processor: cannot write %s." % manifest_path)
		quit(1)
		return
	manifest_file.store_string(JSON.stringify(_manifest, "\t"))
	print("ACHILLES_FRAME_PROCESSING_OK")
	quit()


func _process_animation(animation_name: String, config: Dictionary) -> Error:
	var source := Image.load_from_file(config.source)
	if source == null or source.is_empty():
		push_error("Achilles processor: cannot load %s." % config.source)
		return ERR_CANT_OPEN
	var source_size := source.get_size()
	if source_size.x % GRID.x != 0 or source_size.y % GRID.y != 0:
		push_error("Achilles processor: %s is not divisible by the detected 6x6 grid." % config.source)
		return ERR_INVALID_DATA
	var cell_size := Vector2i(source_size.x / GRID.x, source_size.y / GRID.y)
	var source_audit := _audit_source(source, cell_size)
	var reference := _cell_image(source, cell_size, int(config.reference_frame))
	var reference_used := reference.get_used_rect()
	if reference_used.size == Vector2i.ZERO:
		push_error("Achilles processor: reference frame is empty in %s." % config.source)
		return ERR_INVALID_DATA
	var uniform_scale := REFERENCE_CHARACTER_HEIGHT / float(reference_used.size.y)
	_manifest.animations[animation_name] = {
		"source": config.source,
		"source_size": [source_size.x, source_size.y],
		"cell_size": [cell_size.x, cell_size.y],
		"source_frames": GRID.x * GRID.y,
		"retained_indices": config.indices.duplicate(),
		"retained_frames": config.indices.size(),
		"uniform_scale": uniform_scale,
		"source_audit": source_audit,
	}
	for output_index in range(config.indices.size()):
		var source_index: int = config.indices[output_index]
		var frame := _cell_image(source, cell_size, source_index)
		var used := frame.get_used_rect()
		if used.size == Vector2i.ZERO:
			push_error("Achilles processor: selected frame %d is empty in %s." % [source_index, config.source])
			return ERR_INVALID_DATA
		var source_foot_y := used.end.y - 1
		var resized_size := Vector2i(
			maxi(1, roundi(float(cell_size.x) * uniform_scale)),
			maxi(1, roundi(float(cell_size.y) * uniform_scale))
		)
		frame.resize(resized_size.x, resized_size.y, Image.INTERPOLATE_LANCZOS)
		var destination := Image.create_empty(OUTPUT_SIZE.x, OUTPUT_SIZE.y, false, Image.FORMAT_RGBA8)
		destination.fill(Color.TRANSPARENT)
		var paste_position := Vector2i(
			roundi(float(OUTPUT_SIZE.x - resized_size.x) * 0.5),
			FOOT_LINE_Y - roundi(float(source_foot_y) * uniform_scale)
		)
		destination.blit_rect(frame, Rect2i(Vector2i.ZERO, resized_size), paste_position)
		var output_path := "%s/%s_%02d.png" % [OUTPUT_DIR, animation_name, output_index]
		var save_error := destination.save_png(ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			push_error("Achilles processor: cannot save %s (error %d)." % [output_path, save_error])
			return save_error
	print(
		"%s: source=%s cell=%dx%d retained=%d scale=%.6f output=%dx%d foot_y=%d"
		% [
			animation_name,
			config.source,
			cell_size.x,
			cell_size.y,
			config.indices.size(),
			uniform_scale,
			OUTPUT_SIZE.x,
			OUTPUT_SIZE.y,
			FOOT_LINE_Y,
		]
	)
	return OK


func _cell_image(source: Image, cell_size: Vector2i, index: int) -> Image:
	var coordinate := Vector2i(index % GRID.x, index / GRID.x)
	return source.get_region(Rect2i(coordinate * cell_size, cell_size))


func _audit_source(source: Image, cell_size: Vector2i) -> Dictionary:
	var left_range := Vector2i(1_000_000, -1)
	var top_range := Vector2i(1_000_000, -1)
	var right_range := Vector2i(1_000_000, -1)
	var bottom_range := Vector2i(1_000_000, -1)
	var foot_y_range := Vector2i(1_000_000, -1)
	var empty_frames: Array[int] = []
	var exact_duplicates: Array = []
	var hashes := {}
	for index in range(GRID.x * GRID.y):
		var frame := _cell_image(source, cell_size, index)
		var used := frame.get_used_rect()
		if used.size == Vector2i.ZERO:
			empty_frames.append(index)
			continue
		var left := used.position.x
		var top := used.position.y
		var right := cell_size.x - used.end.x
		var bottom := cell_size.y - used.end.y
		var foot_y := used.end.y - 1
		left_range = Vector2i(mini(left_range.x, left), maxi(left_range.y, left))
		top_range = Vector2i(mini(top_range.x, top), maxi(top_range.y, top))
		right_range = Vector2i(mini(right_range.x, right), maxi(right_range.y, right))
		bottom_range = Vector2i(mini(bottom_range.x, bottom), maxi(bottom_range.y, bottom))
		foot_y_range = Vector2i(mini(foot_y_range.x, foot_y), maxi(foot_y_range.y, foot_y))
		var digest := _sha256(frame)
		if hashes.has(digest):
			exact_duplicates.append([hashes[digest], index])
		else:
			hashes[digest] = index
	return {
		"has_alpha": true,
		"empty_frames": empty_frames,
		"exact_duplicates": exact_duplicates,
		"internal_margin_ranges": {
			"left": [left_range.x, left_range.y],
			"top": [top_range.x, top_range.y],
			"right": [right_range.x, right_range.y],
			"bottom": [bottom_range.x, bottom_range.y],
		},
		"opaque_foot_y_range": [foot_y_range.x, foot_y_range.y],
	}


func _sha256(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()
