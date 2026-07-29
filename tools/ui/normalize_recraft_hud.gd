extends SceneTree

const OUTPUT_DIR := "res://asset/ui/recraft_hud_v1/processed"
const ALPHA_THRESHOLD := 8
const TRANSPARENT_MARGIN_RATIO := 0.04

const ASSETS := [
	{
		"source": "res://asset/ui/recraft_hud_v1/raw/ui_spell_slot_base_v1.png.png",
		"output": "spell_slot_base.png",
	},
	{
		"source": "res://asset/ui/recraft_hud_v1/raw/ui_spellbar_panel_v1..png",
		"output": "spellbar_panel.png",
	},
	{
		"source": "res://asset/ui/recraft_hud_v1/raw/cadre_jauge_v1.png",
		"output": "resource_bar_frame.png",
	},
	{
		"source": "res://asset/ui/dungeon_draft/generated/ui_portrait_frame_v1.png",
		"output": "portrait_frame.png",
	},
	{
		"source": "res://asset/ui/recraft_hud_v1/raw/ui_resource_badge_base_v1.png",
		"output": "resource_badge_base.png",
	},
	{
		"source": "res://asset/ui/recraft_hud_v1/raw/ui_button_primary_base_v1.png",
		"output": "primary_button_base.png",
	},
]


func _initialize() -> void:
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	if mkdir_error != OK:
		push_error("Impossible de creer %s (erreur %d)." % [OUTPUT_DIR, mkdir_error])
		quit(1)
		return

	var failed := false
	for definition in ASSETS:
		if not _normalize(definition["source"], definition["output"]):
			failed = true
	quit(1 if failed else 0)


func _normalize(source_path: String, output_name: String) -> bool:
	if not FileAccess.file_exists(source_path):
		push_error("Asset Recraft absent : %s" % source_path)
		return false

	var source := Image.new()
	var load_error := source.load(ProjectSettings.globalize_path(source_path))
	if load_error != OK or source.is_empty():
		push_error("Asset Recraft illisible : %s (erreur %d)" % [source_path, load_error])
		return false

	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	var used_rect := _alpha_bounding_box(source)
	if not used_rect.has_area():
		push_error("Asset Recraft entierement transparent : %s" % source_path)
		return false

	var transparent_margin := Vector2i(
		int(ceil(used_rect.size.x * TRANSPARENT_MARGIN_RATIO)),
		int(ceil(used_rect.size.y * TRANSPARENT_MARGIN_RATIO))
	)
	var normalized := Image.create(
		used_rect.size.x + transparent_margin.x * 2,
		used_rect.size.y + transparent_margin.y * 2,
		false,
		Image.FORMAT_RGBA8
	)
	normalized.fill(Color.TRANSPARENT)
	normalized.blit_rect(
		source,
		used_rect,
		transparent_margin
	)

	var output_path := OUTPUT_DIR.path_join(output_name)
	var save_error := normalized.save_png(output_path)
	if save_error != OK:
		push_error("Echec de sauvegarde de %s (erreur %d)." % [output_path, save_error])
		return false

	print(
		(
			"%s -> %s | source=%dx%d alpha>%d=%s "
			+ "margins=(L:%d T:%d R:%d B:%d) visible_ratio=%.4f "
			+ "normalized_margin=(X:%d Y:%d) output=%dx%d"
		)
		% [
			source_path,
			output_path,
			source.get_width(),
			source.get_height(),
			ALPHA_THRESHOLD,
			used_rect,
			used_rect.position.x,
			used_rect.position.y,
			source.get_width() - used_rect.end.x,
			source.get_height() - used_rect.end.y,
			float(used_rect.size.x) / float(used_rect.size.y),
			transparent_margin.x,
			transparent_margin.y,
			normalized.get_width(),
			normalized.get_height(),
		]
	)
	return true


func _alpha_bounding_box(image: Image) -> Rect2i:
	var width := image.get_width()
	var height := image.get_height()
	var bytes := image.get_data()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in height:
		var row_offset := y * width * 4
		for x in width:
			if bytes[row_offset + x * 4 + 3] <= ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
