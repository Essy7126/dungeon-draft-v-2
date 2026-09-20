extends GutTest
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const Art := preload("res://core/expedition/class_icon_catalog.gd")
const Equipment := preload("res://core/expedition/class_equipment_catalog.gd")
const Runes := preload("res://core/expedition/class_rune_catalog.gd")


func test_every_live_card_and_crest_has_distinct_painted_art() -> void:
	var regions := { }
	for profession in Cards.CLASSES:
		for id in Cards.pool(profession) + [profession]:
			var texture := Cards.icon(id)
			assert_true(texture is AtlasTexture, id)
			if not texture is AtlasTexture:
				continue
			var key: String = texture.atlas.resource_path + str(texture.region)
			assert_false(regions.has(key), "unique silhouette: " + id)
			regions[key] = true
			assert_true(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), id)
			assert_gt(texture.region.size.x, 200., "enough source pixels for detail views")
			assert_true(texture.filter_clip, "neighboring cells never bleed into icons")
	assert_eq(regions.size(), 64)


func test_equipment_runes_and_empty_slots_have_separate_art() -> void:
	var regions := { }
	for item in Equipment.definitions():
		assert_true(item.icon is AtlasTexture, str(item.item_id))
		if item.icon is AtlasTexture:
			assert_string_contains(item.icon.atlas.resource_path, "equipment.png")
			regions[str(item.icon.region)] = true
	assert_eq(regions.size(), 24, "24 equipment models shared by three explicit loot tiers")
	for id in Runes.ROWS:
		var item := Runes.definition(id)
		assert_true(item.icon is AtlasTexture, id)
		assert_string_contains(item.icon.atlas.resource_path, "runes.png")
	for index in 6:
		var silhouette := Art.empty_slot(index)
		assert_not_null(silhouette)
		assert_eq(silhouette.get_size(), Vector2(96, 96))
	for id in Art.PREPARATION:
		var parts: PackedStringArray = id.split("_")
		var texture := CatabasePreparationCatalog.choice_icon(parts[0], parts[1])
		assert_true(texture is AtlasTexture, id)
		assert_string_contains(texture.atlas.resource_path, "relics.png")
	for id in Art.ARMORS:
		var parts: PackedStringArray = id.split("_")
		var texture := CatabasePreparationCatalog.choice_icon(parts[0], parts[1])
		assert_true(texture is AtlasTexture, id)
		assert_string_contains(texture.atlas.resource_path, "armors.png")
