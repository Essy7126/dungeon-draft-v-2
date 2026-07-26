extends SceneTree

## Pipeline reproductible pour les planches IA du Mage de glace.
##
## Usage :
##   Godot_v4.7.1-stable_win64_console.exe --headless --path <projet> \
##     --script res://tools/process_mage_glace_sprites.gd
##
## Les sources ne sont jamais modifiees. Les PNG individuels normalises et
## les planches horizontales sont ecrits sous characters/mage_glace/processed.

const SOURCE_ROOT := "res://characters/mage_glace"
const OUTPUT_ROOT := "res://characters/mage_glace/processed"
const FRAME_SIZE := Vector2i(384, 384)
const GROUND_ANCHOR := Vector2i(192, 350)
const BACKGROUND_DISTANCE := 0.22
const OPAQUE_DISTANCE := 0.16
const ALPHA_BBOX_THRESHOLD := 0.08

const SOURCES := {
	"idle": "Meshy_AI_1ec72e1a069e872ca21a723712542bd1466130207dcb46f5d98ea3490536b312.png",
	"walk": "Meshy_AI_dd394792180d55492db6a291cb7252436866ba1a33ebcd17feda88e72d56261b.png",
	"cast": "Meshy_AI_1c30e91d5d04329b59a046ef289a0c07e5dd4f32d6fd8ddda7b6cf185c17e380.png",
	"hit": "Meshy_AI_e6603f830831404fbe292f521dbf165a26e527dfe8dea1cd267dc77fca437dae.png",
	"death": "Meshy_AI_ed15dc9cc4f3153fcfd449b25b8f571f2542aa6525584dc0b275bf0823f1bce8.png",
	"portrait": "Meshy_AI_fd3dd0c185f3c51fe5f97c87287ef8b54150d196db9ccd75e222417a55db180d.png",
}

const ACTIONS := {
	"idle": {
		"grid": Vector2i(4, 2),
		"selection": [0, 1, 2, 3, 4, 5, 6, 7],
		"target_height": 304.0,
		"inset": 3,
		"expand_x": 0,
		"offsets": [
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
		],
	},
	"walk": {
		"grid": Vector2i(4, 2),
		"selection": [0, 1, 2, 3, 4, 5, 6, 7],
		"target_height": 298.0,
		"inset": 2,
		"expand_x": 86,
		"offsets": [
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
		],
	},
	"run": {
		"source_action": "walk",
		"grid": Vector2i(4, 2),
		"selection": [0, 1, 2, 3, 4, 5, 6, 7],
		"target_height": 298.0,
		"inset": 2,
		"expand_x": 86,
		"offsets": [
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
		],
	},
	"cast": {
		"rects": [
			Rect2i(0, 0, 285, 510),
			Rect2i(260, 0, 275, 510),
			Rect2i(510, 0, 275, 510),
			Rect2i(760, 0, 264, 510),
			Rect2i(0, 512, 290, 512),
			Rect2i(260, 512, 285, 512),
			Rect2i(500, 512, 300, 512),
			Rect2i(750, 512, 274, 512),
		],
		"selection": [0, 3, 4, 5],
		"target_height": 304.0,
		"inset": 2,
		"expand_x": 0,
		"offsets": [
			Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0),
		],
		"canvas_clips": [
			Rect2i(0, 0, 384, 384),
			Rect2i(55, 0, 265, 384),
			Rect2i(45, 0, 260, 384),
			Rect2i(80, 0, 205, 384),
		],
		"erase_rects": [
			[],
			[],
			[Rect2i(265, 190, 119, 194)],
			[
				Rect2i(0, 205, 130, 179),
				Rect2i(268, 0, 116, 220),
			],
		],
	},
	"hit": {
		"grid": Vector2i(3, 2),
		"selection": [0, 1, 2, 1, 0],
		"target_height": 298.0,
		"inset": 2,
		"expand_x": 0,
		"offsets": [
			Vector2i(0, 0), Vector2i(-2, 0), Vector2i(-5, 0),
			Vector2i(-2, 0), Vector2i(0, 0),
		],
	},
	"death": {
		"rects": [
			Rect2i(0, 0, 320, 510),
			Rect2i(240, 0, 330, 510),
			Rect2i(500, 0, 278, 510),
			Rect2i(760, 0, 264, 510),
			Rect2i(0, 512, 360, 512),
			Rect2i(330, 512, 335, 512),
			Rect2i(680, 512, 344, 512),
		],
		"selection": [0, 1, 2, 3, 4, 5, 6],
		"target_height": 298.0,
		"preserve_sequence_scale": true,
		"offsets": [
			Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 3), Vector2i(2, 5),
			Vector2i(4, 8), Vector2i(5, 11), Vector2i(8, 14),
		],
		"canvas_clips": [
			Rect2i(0, 0, 384, 384),
			Rect2i(0, 0, 384, 384),
			Rect2i(0, 0, 325, 384),
			Rect2i(40, 0, 344, 384),
			Rect2i(0, 0, 384, 384),
			Rect2i(0, 0, 384, 384),
			Rect2i(0, 0, 384, 384),
		],
	},
}


func _initialize() -> void:
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_ROOT)
	var error := DirAccess.make_dir_recursive_absolute(output_absolute)
	if error != OK:
		push_error("Impossible de creer %s (erreur %d)." % [output_absolute, error])
		quit(1)
		return
	error = DirAccess.make_dir_recursive_absolute(output_absolute.path_join("sheets"))
	if error != OK:
		push_error("Impossible de creer le dossier sheets (erreur %d)." % error)
		quit(1)
		return

	var requested_actions := OS.get_cmdline_user_args()
	var actions := ["idle", "walk", "run", "cast", "hit", "death"]
	if not requested_actions.is_empty():
		actions = actions.filter(func(action): return action in requested_actions)
	for action_name in actions:
		if not _process_action(action_name):
			quit(1)
			return
	if (requested_actions.is_empty() or "portrait" in requested_actions) \
			and not _process_portrait():
		quit(1)
		return
	print("Mage glace : traitement termine dans %s" % OUTPUT_ROOT)
	quit()


func _process_action(action_name: String) -> bool:
	_remove_stale_action_frames(action_name)
	var config: Dictionary = ACTIONS[action_name]
	var source_action: String = config.get("source_action", action_name)
	var source_path := SOURCE_ROOT.path_join(SOURCES[source_action])
	var source := Image.new()
	var error := source.load(ProjectSettings.globalize_path(source_path))
	if error != OK:
		push_error("%s : chargement impossible (erreur %d)." % [source_path, error])
		return false
	source.convert(Image.FORMAT_RGBA8)

	var rects: Array[Rect2i] = []
	if config.has("rects"):
		rects.assign(config["rects"])
	else:
		rects = _grid_rects(
			source.get_size(),
			config["grid"],
			config.get("inset", 0),
			config.get("expand_x", 0)
		)

	var raw_frames: Array[Dictionary] = []
	for source_index in config["selection"]:
		var rect: Rect2i = rects[source_index]
		var frame := source.get_region(rect)
		_remove_connected_background(frame)
		_keep_primary_component(frame)
		var bbox := _alpha_bbox(frame)
		if bbox.size == Vector2i.ZERO:
			push_error("%s : frame source %d vide apres detourage." % [action_name, source_index])
			return false
		raw_frames.append({
			"image": frame,
			"bbox": bbox,
			"source_index": source_index,
		})

	var reference_height := float(raw_frames[0]["bbox"].size.y)
	var aligned_frames: Array[Image] = []
	for frame_index in raw_frames.size():
		var raw: Dictionary = raw_frames[frame_index]
		var bbox: Rect2i = raw["bbox"]
		var content: Image = (raw["image"] as Image).get_region(bbox)
		var denominator := (
			reference_height
			if config.get("preserve_sequence_scale", false)
			else float(bbox.size.y)
		)
		var scale_factor: float = float(config["target_height"]) / maxf(denominator, 1.0)
		var scaled_size := Vector2i(
			maxi(1, roundi(content.get_width() * scale_factor)),
			maxi(1, roundi(content.get_height() * scale_factor))
		)
		content.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)

		var body_anchor_x := _lower_body_anchor_x(content)
		var foot_y := _central_foot_y(content, body_anchor_x)
		var manual_offset: Vector2i = config["offsets"][frame_index]
		var destination := Vector2i(
			GROUND_ANCHOR.x - body_anchor_x + manual_offset.x,
			GROUND_ANCHOR.y - foot_y + manual_offset.y
		)
		var canvas := Image.create_empty(
			FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8
		)
		canvas.fill(Color.TRANSPARENT)
		canvas.blend_rect(
			content,
			Rect2i(Vector2i.ZERO, content.get_size()),
			destination
		)
		if config.has("canvas_clips"):
			_clip_canvas(canvas, config["canvas_clips"][frame_index])
		if config.has("erase_rects"):
			_erase_rects(canvas, config["erase_rects"][frame_index])
		var output_name := "%s_%02d.png" % [action_name, frame_index]
		error = canvas.save_png(OUTPUT_ROOT.path_join(output_name))
		if error != OK:
			push_error("%s : sauvegarde impossible (erreur %d)." % [output_name, error])
			return false
		aligned_frames.append(canvas)
		print("%s[%d] <- source %d, bbox=%s, dest=%s" % [
			action_name, frame_index, raw["source_index"], bbox, destination,
		])

	return _save_sheet(action_name, aligned_frames)


func _remove_stale_action_frames(action_name: String) -> void:
	var directory := DirAccess.open(OUTPUT_ROOT)
	if directory == null:
		return
	for file_name in directory.get_files():
		var is_action_output := file_name.begins_with("%s_" % action_name)
		var is_generated_file := file_name.ends_with(".png") \
				or file_name.ends_with(".png.import")
		if is_action_output and is_generated_file:
			var error := directory.remove(file_name)
			if error != OK and error != ERR_FILE_NOT_FOUND:
				push_warning(
					"Impossible de supprimer le fichier obsolète %s (erreur %d)."
					% [file_name, error]
				)


func _process_portrait() -> bool:
	var source := Image.new()
	var source_path := SOURCE_ROOT.path_join(SOURCES["portrait"])
	var error := source.load(ProjectSettings.globalize_path(source_path))
	if error != OK:
		push_error("%s : chargement impossible (erreur %d)." % [source_path, error])
		return false
	source.convert(Image.FORMAT_RGBA8)
	_remove_connected_background(source)

	# Chapeau, visage, barbe et haut du buste. Le baton reste volontairement hors
	# cadre afin que le visage demeure lisible dans une carte 320 x 210.
	var portrait := source.get_region(Rect2i(286, 45, 470, 570))
	var bbox := _alpha_bbox(portrait)
	if bbox.size == Vector2i.ZERO:
		push_error("Portrait vide apres detourage.")
		return false
	portrait = portrait.get_region(bbox)
	var target := Vector2i(320, 320)
	var scale_factor := minf(
		float(target.x - 20) / portrait.get_width(),
		float(target.y - 16) / portrait.get_height()
	)
	portrait.resize(
		maxi(1, roundi(portrait.get_width() * scale_factor)),
		maxi(1, roundi(portrait.get_height() * scale_factor)),
		Image.INTERPOLATE_LANCZOS
	)
	var canvas := Image.create_empty(target.x, target.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var destination := Vector2i(
		(target.x - portrait.get_width()) / 2,
		target.y - portrait.get_height()
	)
	canvas.blend_rect(
		portrait,
		Rect2i(Vector2i.ZERO, portrait.get_size()),
		destination
	)
	error = canvas.save_png(OUTPUT_ROOT.path_join("portrait.png"))
	if error != OK:
		push_error("Sauvegarde du portrait impossible (erreur %d)." % error)
		return false
	return true


func _grid_rects(
	size: Vector2i,
	grid: Vector2i,
	inset: int,
	expand_x: int
	) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for row in grid.y:
		for column in grid.x:
			var left := maxi(
				0,
				floori(float(size.x) * column / grid.x) + inset - expand_x
			)
			var right := mini(
				size.x,
				floori(float(size.x) * (column + 1) / grid.x) - inset + expand_x
			)
			var top := floori(float(size.y) * row / grid.y) + inset
			var bottom := floori(float(size.y) * (row + 1) / grid.y) - inset
			rects.append(Rect2i(left, top, right - left, bottom - top))
	return rects


func _remove_connected_background(image: Image) -> void:
	var size := image.get_size()
	var background := _average_corner_color(image)
	var visited := PackedByteArray()
	visited.resize(size.x * size.y)
	var queue := PackedInt32Array()

	for x in size.x:
		_try_queue_background(image, x, 0, background, visited, queue)
		_try_queue_background(image, x, size.y - 1, background, visited, queue)
	for y in size.y:
		_try_queue_background(image, 0, y, background, visited, queue)
		_try_queue_background(image, size.x - 1, y, background, visited, queue)

	var cursor := 0
	while cursor < queue.size():
		var packed := queue[cursor]
		cursor += 1
		var x := packed % size.x
		var y := packed / size.x
		for neighbor in [
			Vector2i(x - 1, y), Vector2i(x + 1, y),
			Vector2i(x, y - 1), Vector2i(x, y + 1),
		]:
			if neighbor.x < 0 or neighbor.y < 0 \
					or neighbor.x >= size.x or neighbor.y >= size.y:
				continue
			_try_queue_background(
				image, neighbor.x, neighbor.y, background, visited, queue
			)

	for packed in queue:
		var x := packed % size.x
		var y := packed / size.x
		var color := image.get_pixel(x, y)
		var distance := _rgb_distance(color, background)
		color.a = smoothstep(0.018, OPAQUE_DISTANCE, distance)
		image.set_pixel(x, y, color)


func _try_queue_background(
	image: Image,
	x: int,
	y: int,
	background: Color,
	visited: PackedByteArray,
	queue: PackedInt32Array
	) -> void:
	var packed := y * image.get_width() + x
	if visited[packed] != 0:
		return
	visited[packed] = 1
	if _rgb_distance(image.get_pixel(x, y), background) <= BACKGROUND_DISTANCE:
		queue.append(packed)


func _average_corner_color(image: Image) -> Color:
	var sample_size := 12
	var sum := Vector3.ZERO
	var count := 0
	for y in sample_size:
		for x in sample_size:
			for point in [
				Vector2i(x, y),
				Vector2i(image.get_width() - 1 - x, y),
				Vector2i(x, image.get_height() - 1 - y),
				Vector2i(image.get_width() - 1 - x, image.get_height() - 1 - y),
			]:
				var color := image.get_pixelv(point)
				sum += Vector3(color.r, color.g, color.b)
				count += 1
	return Color(sum.x / count, sum.y / count, sum.z / count, 1.0)


func _rgb_distance(a: Color, b: Color) -> float:
	var delta := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return delta.length()


func _alpha_bbox(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= ALPHA_BBOX_THRESHOLD:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _keep_primary_component(image: Image) -> void:
	# Les collages IA laissent souvent depasser le baton ou la cape d'une pose
	# dans la cellule voisine. Une decoupe elargie recupere toute la silhouette ;
	# cette passe conserve ensuite le plus grand ilot alpha et elimine les
	# fragments de ses voisines.
	var size := image.get_size()
	var visited := PackedByteArray()
	visited.resize(size.x * size.y)
	var best_component := PackedInt32Array()

	for y in size.y:
		for x in size.x:
			var start := y * size.x + x
			if visited[start] != 0:
				continue
			visited[start] = 1
			if image.get_pixel(x, y).a <= ALPHA_BBOX_THRESHOLD:
				continue
			var component := PackedInt32Array([start])
			var queue := PackedInt32Array([start])
			var cursor := 0
			while cursor < queue.size():
				var packed := queue[cursor]
				cursor += 1
				var current_x := packed % size.x
				var current_y := packed / size.x
				for neighbor in [
					Vector2i(current_x - 1, current_y),
					Vector2i(current_x + 1, current_y),
					Vector2i(current_x, current_y - 1),
					Vector2i(current_x, current_y + 1),
				]:
					if neighbor.x < 0 or neighbor.y < 0 \
							or neighbor.x >= size.x or neighbor.y >= size.y:
						continue
					var neighbor_packed: int = neighbor.y * size.x + neighbor.x
					if visited[neighbor_packed] != 0:
						continue
					visited[neighbor_packed] = 1
					if image.get_pixelv(neighbor).a <= ALPHA_BBOX_THRESHOLD:
						continue
					queue.append(neighbor_packed)
					component.append(neighbor_packed)
			if component.size() > best_component.size():
				best_component = component

	var keep := PackedByteArray()
	keep.resize(size.x * size.y)
	for packed in best_component:
		keep[packed] = 1

	# Une dilatation de deux pixels rattache le bord anti-aliasse a la composante
	# opaque sans laisser revenir les fragments eloignes.
	for _pass in 2:
		var expanded := keep.duplicate()
		for packed in best_component:
			var x := packed % size.x
			var y := packed / size.x
			for neighbor in [
				Vector2i(x - 1, y), Vector2i(x + 1, y),
				Vector2i(x, y - 1), Vector2i(x, y + 1),
			]:
				if neighbor.x < 0 or neighbor.y < 0 \
						or neighbor.x >= size.x or neighbor.y >= size.y:
					continue
				var neighbor_packed: int = neighbor.y * size.x + neighbor.x
				if image.get_pixelv(neighbor).a > 0.0:
					expanded[neighbor_packed] = 1
		keep = expanded
		best_component.clear()
		for packed in keep.size():
			if keep[packed] != 0:
				best_component.append(packed)

	for packed in keep.size():
		if keep[packed] != 0:
			continue
		var color := image.get_pixel(packed % size.x, packed / size.x)
		if color.a == 0.0:
			continue
		color.a = 0.0
		image.set_pixel(packed % size.x, packed / size.x, color)


func _lower_body_anchor_x(image: Image) -> int:
	var start_y := floori(image.get_height() * 0.52)
	var end_y := floori(image.get_height() * 0.90)
	var weighted_x := 0.0
	var weight := 0.0
	for y in range(start_y, end_y):
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha <= 0.2:
				continue
			weighted_x += x * alpha
			weight += alpha
	return roundi(weighted_x / weight) if weight > 0.0 else image.get_width() / 2


func _central_foot_y(image: Image, anchor_x: int) -> int:
	# Le baton descend souvent plus bas que les chaussures. La recherche dans
	# une bande centree sur la masse du corps ignore ce faux point d'appui.
	var half_band := maxi(12, floori(image.get_width() * 0.28))
	var left := maxi(0, anchor_x - half_band)
	var right := mini(image.get_width(), anchor_x + half_band)
	for y in range(image.get_height() - 1, -1, -1):
		for x in range(left, right):
			if image.get_pixel(x, y).a > 0.2:
				return y
	return image.get_height() - 1


func _save_sheet(action_name: String, frames: Array[Image]) -> bool:
	var sheet := Image.create_empty(
		FRAME_SIZE.x * frames.size(),
		FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(Color.TRANSPARENT)
	for index in frames.size():
		sheet.blend_rect(
			frames[index],
			Rect2i(Vector2i.ZERO, FRAME_SIZE),
			Vector2i(index * FRAME_SIZE.x, 0)
		)
	var output_path := OUTPUT_ROOT.path_join("sheets/%s.png" % action_name)
	var error := sheet.save_png(output_path)
	if error != OK:
		push_error("%s : sauvegarde impossible (erreur %d)." % [output_path, error])
		return false
	return true


func _clip_canvas(canvas: Image, clip: Rect2i) -> void:
	var transparent := Color.TRANSPARENT
	if clip.position.x > 0:
		canvas.fill_rect(
			Rect2i(0, 0, clip.position.x, canvas.get_height()),
			transparent
		)
	var right := clip.position.x + clip.size.x
	if right < canvas.get_width():
		canvas.fill_rect(
			Rect2i(right, 0, canvas.get_width() - right, canvas.get_height()),
			transparent
		)
	if clip.position.y > 0:
		canvas.fill_rect(
			Rect2i(clip.position.x, 0, clip.size.x, clip.position.y),
			transparent
		)
	var bottom := clip.position.y + clip.size.y
	if bottom < canvas.get_height():
		canvas.fill_rect(
			Rect2i(
				clip.position.x,
				bottom,
				clip.size.x,
				canvas.get_height() - bottom
			),
			transparent
		)


func _erase_rects(canvas: Image, rects: Array) -> void:
	for rect in rects:
		canvas.fill_rect(rect, Color.TRANSPARENT)
