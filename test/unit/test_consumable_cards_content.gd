extends GutTest
const Content := preload("res://core/expedition/consumable_cards_content.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")


func test_seven_maps_use_studio_projection_without_geometry_drift() -> void:
	for id in Catalog.data().maps:
		var arena := Content.arena(id)
		assert_not_null(arena)
		assert_eq(arena.grid_size, Vector2i(7, 7))
		var grid := Content.grid(id)
		var walls := 0
		for x in 7:
			for y in 7:
				if not grid.is_walkable(Vector2i(x, y)):
					walls += 1
		assert_eq(walls, Catalog.data().maps[id].walls.size())
		for cell in [Vector2i(3, 5), Vector2i(3, 1), Vector2i(1, 1), Vector2i(5, 1), Vector2i(3, 2)]:
			assert_true(grid.is_walkable(cell), "%s %s" % [id, cell])


func test_twenty_six_items_roundtrip_through_studio_services() -> void:
	var catalog := Content.items()
	assert_not_null(catalog)
	if catalog == null:
		return
	assert_true(catalog.validate_catalog().valid)
	assert_eq(catalog.get_definitions().size(), 26)
	var copier := ItemDeepCopyService.new()
	var validator := ItemStudioValidationService.new()
	for item in catalog.get_definitions():
		var family := str(item.item_id).trim_prefix("cc2_")
		var authored: Array = Catalog.data().equipment.filter(func(row): return row.id == family)
		if authored.is_empty():
			assert_eq(item.profile_relic_rule, family)
		else:
			assert_eq(item.profile_modifiers, authored[0].mods, "Published equipment must match the rules manifest")
		var copy := copier.duplicate_definition(item)
		assert_true(copy is ConsumableCardItemDefinition)
		assert_true(copy.is_valid(), str(item.item_id))
		assert_eq(
			ItemFingerprintService.semantic_fingerprint(copy),
			ItemFingerprintService.semantic_fingerprint(item),
		)
		var report := validator.validate(copy, null)
		assert_eq(int(report.get("error_count", 0)), 0, JSON.stringify(report))
		if not copy.profile_modifiers.is_empty():
			var original := ItemFingerprintService.semantic_fingerprint(item)
			copy.profile_modifiers[copy.profile_modifiers.keys()[0]] += .01
			assert_ne(ItemFingerprintService.semantic_fingerprint(copy), original)
			assert_eq(ItemFingerprintService.semantic_fingerprint(item), original, "detached edit")


func test_studio_undo_redo_preserves_profile_fields_and_detaches_source() -> void:
	var source = Content.items().get_definitions()[0]
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(source))
	var original := ItemFingerprintService.semantic_fingerprint(source)
	assert_true(
		document.record_edit(
			"Modifier le profil",
			func():
				document.working_copy.profile_modifiers = { "damage": .25 }
				document.working_copy.profile_relic_rule = "mirror",
		)
	)
	var edited := document.current_fingerprint()
	assert_ne(edited, original)
	assert_true(document.history.undo())
	assert_eq(document.current_fingerprint(), original)
	assert_true(document.working_copy is ConsumableCardItemDefinition)
	assert_true(document.history.redo())
	assert_eq(document.current_fingerprint(), edited)
	assert_eq(ItemFingerprintService.semantic_fingerprint(source), original)
	document.history.configure(Callable(), Callable())
	for signal_name in ["history_changed", "dirty_state_changed"]:
		for connection in document.history.get_signal_connection_list(signal_name):
			document.history.disconnect(signal_name, connection.callable)
	document.history.clear()
	document.history.undo_redo.free()
