extends GutTest
const GLYPHS := preload("res://ui/theme/catabase_icon_library.gd")
const ART := preload("res://core/expedition/catabase_painted_icon_catalog.gd")


func test_entire_manifest_imports_with_nonempty_small_previews() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(GLYPHS.ROOT + "manifest.json")
	)
	assert_eq(manifest.icons.size(), 197)
	for entry in manifest.icons:
		var texture := GLYPHS.icon(entry.group, entry.id)
		assert_not_null(texture, entry.id)
		if texture == null:
			continue
		assert_eq(texture.get_width(), int(entry.size), entry.id)
		assert_eq(texture.resource_path, "res://" + String(entry.path), entry.id)
		assert_true(
			texture.resource_path.ends_with(".svg" if entry.group == "route" else ".png"),
			"Only map markers use vector symbols: " + entry.id,
		)
		var raster := texture.get_image()
		assert_not_null(raster, entry.id)
		if raster == null:
			continue
		raster.resize(24, 24, Image.INTERPOLATE_LANCZOS)
		assert_eq(raster.get_size(), Vector2i(24, 24), entry.id)
		var bright_pixels := 0
		for y in raster.get_height():
			for x in raster.get_width():
				var color := raster.get_pixel(x, y)
				if color.a > 0.25 and color.get_luminance() > 0.30:
					bright_pixels += 1
		assert_gt(bright_pixels, 10, "Small preview is not empty: " + entry.id)


func test_all_runtime_spells_and_equipment_use_the_new_library() -> void:
	var theme := load("res://data/ui/achilles_hud_theme_refined.tres") as CharacterHUDThemeData
	for spell in ExpeditionBuildCatalog.new().all_spells():
		assert_true(spell.icon.resource_path.begins_with(GLYPHS.ROOT + "spells/"), String(
				spell.spell_id
			))
		assert_same(theme.get_spell_icon_for(spell), spell.icon)
	for item in ExpeditionEquipmentCatalog.new().definitions():
		assert_true(item.icon.resource_path.begins_with(GLYPHS.ROOT + "equipment/"), String(
				item.item_id
			))
		assert_same(InventoryItemTile.presentation_icon(item), item.icon)
	for family in ART.SPELL_FAMILIES:
		for id in ART.SPELL_FAMILIES[family]:
			if (
				String(id).ends_with("_mutation") or String(id).ends_with("_legend")
				or String(id).ends_with("_signature")
			):
				assert_true(
					ART.spell_icon(id).resource_path.ends_with(String(id) + ".png"),
					"Upgraded form has its own illustration",
				)


func test_navigation_and_map_share_the_catalog_without_leaking_unknown_content() -> void:
	for id in ["equipment", "map", "tree", "lock", "close", "settings", "save", "check"]:
		assert_same(CatabaseUITheme.icon("nav", id), GLYPHS.icon("nav", id))
	for kind in ART.ROUTE_IDS:
		assert_same(ART.route_icon(kind), ART.map_icon(kind))
	assert_same(
		ART.map_node_icon({ "kind": "boss", "knowledge": "unknown" }),
		GLYPHS.icon("route", "unknown"),
	)
	assert_null(GLYPHS.icon("../spells", "braise"))
	assert_null(GLYPHS.icon("spells", "../braise"))
	assert_null(GLYPHS.icon("spells", "not_authored"))


func test_starting_consumables_and_all_canonical_rewards_have_dedicated_paintings() -> void:
	var catalog := load("res://data/items/catalogs/odyssey_item_catalog.tres") as ItemCatalog
	assert_eq(catalog.get_definitions().size(), 26)
	for item in catalog.get_definitions():
		assert_not_null(item.icon, String(item.item_id))
		if item.icon == null:
			continue
		assert_true(item.icon.resource_path.ends_with("/" + String(item.item_id) + ".png"))
		assert_same(item.get_inventory_icon(), item.icon)
		assert_same(item.get_reward_card_texture(), item.icon)


func test_map_marker_sources_are_unchanged() -> void:
	var hashes: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://art/source/catabase/emerald_icons_v2/route_before.json"
		)
	)
	assert_eq(hashes.size(), 12)
	for filename: String in hashes:
		assert_eq(
			FileAccess.get_sha256(GLYPHS.MAP_ROOT + "route/" + filename),
			hashes[filename],
			filename,
		)
