extends SceneTree

const OUTPUT_DIR := "res://asset/ui/recraft_hud_v1/processed"
const TRANSPARENT_MARGIN := 24

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
	var used_rect := source.get_used_rect()
	if not used_rect.has_area():
		push_error("Asset Recraft entierement transparent : %s" % source_path)
		return false

	var normalized := Image.create(
		used_rect.size.x + TRANSPARENT_MARGIN * 2,
		used_rect.size.y + TRANSPARENT_MARGIN * 2,
		false,
		Image.FORMAT_RGBA8
	)
	normalized.fill(Color.TRANSPARENT)
	normalized.blit_rect(
		source,
		used_rect,
		Vector2i(TRANSPARENT_MARGIN, TRANSPARENT_MARGIN)
	)

	var output_path := OUTPUT_DIR.path_join(output_name)
	var save_error := normalized.save_png(output_path)
	if save_error != OK:
		push_error("Echec de sauvegarde de %s (erreur %d)." % [output_path, save_error])
		return false

	print(
		"%s -> %s | source=%dx%d used=%s output=%dx%d"
		% [
			source_path,
			output_path,
			source.get_width(),
			source.get_height(),
			used_rect,
			normalized.get_width(),
			normalized.get_height(),
		]
	)
	return true
