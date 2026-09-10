extends "res://tools/ui_chrome/menus_review.gd"
const GLYPHS := preload("res://ui/theme/catabase_icon_library.gd")


func _run() -> void:
	var preview_generated := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("output_dir="):
			_output = argument.trim_prefix("output_dir=")
		if argument == "preview_generated=true":
			preview_generated = true
	if _output.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(GLYPHS.ROOT + "manifest.json")
	)
	var bg := ColorRect.new()
	bg.color = Color("121615")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var heading := Label.new()
	heading.position = Vector2(32, 18)
	heading.theme = CatabaseUITheme.get_theme()
	heading.add_theme_font_size_override("font_size", 26)
	bg.add_child(heading)
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(page)
	var batches := [
		["SORTS · Formes fondamentales", ["spells"], true],
		["ÉQUIPEMENT · Armes, reliques et consommables", ["equipment"], false],
		["COMMANDES · Ressources, carte et états", ["nav", "resources", "states", "route"], false],
		[
			"PROGRESSION · Statistiques, doctrines et effets",
			["stats", "emblems", "effects", "attributes"],
			false,
		],
		["MAÎTRISES · Le grimoire d’Achille", ["masteries"], false],
		["SORTS · Mutations, légendes et signatures", ["spells"], false],
	]
	for index in batches.size():
		for child in page.get_children():
			child.free()
		var batch: Array = batches[index]
		heading.text = batch[0]
		var entries: Array = []
		for entry: Dictionary in manifest.icons:
			if entry.group not in batch[1]:
				continue
			if preview_generated and not FileAccess.file_exists(_painted_path(entry)):
				continue
			if index == 0 and not String(entry.rank).is_empty():
				continue
			if index == 5 and String(entry.rank).is_empty():
				continue
			entries.append(entry)
		var controls: Array = []
		var columns := 9
		var cell := Vector2((get_viewport().get_visible_rect().size.x - 64) / columns, 108)
		for item_index in entries.size():
			var entry: Dictionary = entries[item_index]
			var origin := Vector2(32, 78) + Vector2(item_index % columns, item_index / columns) * cell
			var texture := GLYPHS.icon(entry.group, entry.id)
			if preview_generated:
				var source := Image.load_from_file(_painted_path(entry))
				source.generate_mipmaps()
				texture = ImageTexture.create_from_image(source)
			_check(texture != null, "Imported " + entry.id)
			for extent in [48, 24]:
				var art := TextureRect.new()
				art.texture = texture
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				art.position = origin + (Vector2(57, 20) if extent == 24 else Vector2.ZERO)
				art.size = Vector2.ONE * extent
				page.add_child(art)
				controls.append(art)
			var caption := Label.new()
			caption.position = origin + Vector2(0, 55)
			caption.size = Vector2(cell.x - 8, 40)
			caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			caption.add_theme_font_size_override("font_size", 12)
			var readable_id := String(entry.id)
			for prefix in ["catabase_", "achilles_", "exp_", "odyssey_"]:
				readable_id = readable_id.trim_prefix(prefix)
			caption.text = readable_id.replace("_", " ")
			page.add_child(caption)
		await _capture("icons_%02d" % index, controls)
	await _finish()


func _painted_path(entry: Dictionary) -> String:
	return "res://assets/catabase/emerald_icons_v2/" + entry.group + "/" + entry.id + ".png"
