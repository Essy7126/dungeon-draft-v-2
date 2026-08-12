extends SceneTree

const OUTPUT_PATH := "res://artifacts/complete_terrain_catalog/asset_inventory.json"
const ASSETS := [
	[&"stone", "stone.png", "res://addons/dungeon_draft_arena_studio/catalog/terrains/stone.tres"],
	[&"neutral", "neutre.png", "res://addons/dungeon_draft_arena_studio/catalog/terrains/neutral.tres"],
	[&"water", "water.png", "res://addons/dungeon_draft_arena_studio/catalog/terrains/water.tres"],
	[&"ice", "ice.png", "res://addons/dungeon_draft_arena_studio/catalog/terrains/ice.tres"],
	[&"lava", "lava.png", "res://addons/dungeon_draft_arena_studio/catalog/terrains/lava.tres"],
	[&"poison", "poison.png", "res://addons/dungeon_draft_arena_studio/catalog/terrains/poison.tres"],
	[&"steam", "vapeur.png", "res://addons/dungeon_draft_arena_studio/catalog/terrains/steam.tres"],
	[&"electrified_water", "électrique.png", "res://addons/dungeon_draft_arena_studio/catalog/terrains/electrified_water.tres"],
	[&"vortex", "vortex.png", "res://addons/dungeon_draft_arena_studio/catalog/interactives/vortex.tres"],
]


func _init() -> void:
	var entries: Array[Dictionary] = []
	var normalized_textures: Array[Texture2D] = []
	for asset in ASSETS:
		var stable_id := StringName(asset[0])
		var raw_path := "res://tools/labs/dynamic_arena/assets/raw/%s" % asset[1]
		var normalized_path := "res://tools/labs/dynamic_arena/assets/normalized/%s.png" % stable_id
		var raw_texture := load(raw_path) as Texture2D
		var normalized_texture := load(normalized_path) as Texture2D
		normalized_textures.append(normalized_texture)
		entries.append({
			"stable_id": str(stable_id),
			"classification": "SPATIAL_INTERACTIVE" if stable_id == &"vortex" else "PERMANENT_TERRAIN",
			"source": _texture_report(raw_path, raw_texture),
			"normalized": _texture_report(normalized_path, normalized_texture),
			"pivot": [128.0, 64.0],
			"footprint_corners": [[128.0, 0.0], [255.0, 64.0], [128.0, 127.0], [0.0, 64.0]],
			"catalog_resource": asset[2],
			"current_usages": [asset[2]],
		})
	var alignment := ArenaTileVisualNormalizationService.alignment_report(normalized_textures)
	var payload := {
		"schema_version": 2,
		"mission": "ARENA_COMPLETE_TERRAIN_CATALOG_CHARACTER_STATUS_EFFECTS_AND_VORTEX_RUNTIME",
		"generated_at": Time.get_datetime_string_from_system(true),
		"normalization_service": "res://addons/dungeon_draft_arena_studio/services/arena_tile_visual_normalization_service.gd",
		"shared_crop": [29, 188, 963, 682],
		"output_size": [256, 128],
		"alpha_threshold": ArenaTileVisualNormalizationService.ALPHA_THRESHOLD,
		"alignment": alignment,
		"assets": entries,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH).get_base_dir())
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Impossible d'écrire %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()
	print("COMPLETE_TERRAIN_ASSET_INVENTORY_OK ", OUTPUT_PATH)
	quit(0)


func _texture_report(path: String, texture: Texture2D) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	var image := texture.get_image() if texture != null else null
	# Image.get_used_rect() est natif et évite un scan GDScript de neuf sources
	# 1024² ; les sources sont RGBA et leurs pixels RGB hors alpha sont nuls.
	var bounds := image.get_used_rect() if image != null else Rect2i()
	var import_path := path + ".import"
	var uid_value := ResourceLoader.get_resource_uid(path)
	return {
		"path": path,
		"bytes": FileAccess.get_file_as_bytes(path).size() if FileAccess.file_exists(path) else 0,
		"sha256": FileAccess.get_sha256(path),
		"dimensions": [image.get_width(), image.get_height()] if image != null else [0, 0],
		"has_alpha": image != null and image.detect_alpha() != Image.ALPHA_NONE,
		"non_transparent_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"useful_center": [bounds.get_center().x, bounds.get_center().y],
		"uid": ResourceUID.id_to_text(uid_value) if uid_value != ResourceUID.INVALID_ID else "",
		"godot_import": {
			"path": import_path,
			"exists": FileAccess.file_exists(import_path),
			"sha256": FileAccess.get_sha256(import_path) if FileAccess.file_exists(import_path) else "",
			"importer": "texture",
			"type": "CompressedTexture2D",
		},
		"texture_reloadable": texture != null and ResourceLoader.exists(path),
		"absolute_path": absolute,
	}
