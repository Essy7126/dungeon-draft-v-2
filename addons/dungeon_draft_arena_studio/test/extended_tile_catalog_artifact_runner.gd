extends Node

const OUTPUT_ROOT := "res://artifacts/extended_terrain_catalog"
const INVENTORY_PATH := OUTPUT_ROOT + "/asset_inventory.json"
const THUMBNAIL_SIZE := Vector2i(256, 256)
const ROLES := ["neutral", "poison", "steam", "electrified_water", "vortex"]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var absolute_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root.path_join("previews"))
	_write_json(
		OUTPUT_ROOT.path_join("gameplay_coverage.json"),
		ArenaTileGameplayCoverageService.build()
	)
	var inventory = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY_PATH))
	if not inventory is Dictionary:
		failures.append("inventory_invalid")
		_finish(failures, [])
		return
	var role_mapping := inventory.get("role_mapping", {}) as Dictionary
	var contact := Image.create(
		THUMBNAIL_SIZE.x * ROLES.size(), THUMBNAIL_SIZE.y,
		false, Image.FORMAT_RGBA8
	)
	contact.fill(Color(0.055, 0.075, 0.11, 1.0))
	var previews: Array[Dictionary] = []
	for index in range(ROLES.size()):
		var role := str(ROLES[index])
		var resource_path := str(role_mapping.get(role, ""))
		var texture := load(resource_path) as Texture2D \
			if ResourceLoader.exists(resource_path) else null
		if texture == null:
			failures.append("texture_reload_failed:%s" % role)
			continue
		var source := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
		if source == null or source.is_empty():
			failures.append("image_load_failed:%s" % role)
			continue
		var thumbnail := source.duplicate()
		thumbnail.resize(
			THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y,
			Image.INTERPOLATE_LANCZOS
		)
		var preview_path := OUTPUT_ROOT.path_join("previews/%s.png" % role)
		if thumbnail.save_png(ProjectSettings.globalize_path(preview_path)) != OK:
			failures.append("thumbnail_save_failed:%s" % role)
		contact.blend_rect(
			thumbnail, Rect2i(Vector2i.ZERO, THUMBNAIL_SIZE),
			Vector2i(index * THUMBNAIL_SIZE.x, 0)
		)
		previews.append({
			"index": index,
			"stable_role": role,
			"source": resource_path,
			"preview": preview_path,
			"texture2d_reloadable": true,
			"uid": ResourceUID.id_to_text(ResourceLoader.get_resource_uid(resource_path)),
		})
	var contact_path := OUTPUT_ROOT.path_join("catalog_contact_sheet.png")
	if contact.save_png(ProjectSettings.globalize_path(contact_path)) != OK:
		failures.append("contact_sheet_save_failed")
	_write_json(OUTPUT_ROOT.path_join("preview_manifest.json"), {
		"schema_version": 1,
		"order": ROLES,
		"contact_sheet": contact_path,
		"thumbnail_size": [THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y],
		"previews": previews,
		"failures": failures,
	})
	_finish(failures, previews)


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "  "))
		file.close()


func _finish(failures: Array[String], previews: Array[Dictionary]) -> void:
	print("EXTENDED_TILE_CATALOG_ARTIFACTS=", JSON.stringify({
		"ok": failures.is_empty(),
		"failures": failures,
		"preview_count": previews.size(),
	}))
	get_tree().quit(0 if failures.is_empty() else 1)
