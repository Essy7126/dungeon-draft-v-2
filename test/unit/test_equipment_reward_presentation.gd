extends GutTest

const OVERLAY_SCENE := preload("res://ui/post_combat/EquipmentRewardOverlay.tscn")
const CATALOG := preload("res://data/items/catalogs/default_item_catalog.tres")


func test_hover_and_click_keep_selection_and_confirmation_distinct() -> void:
	var overlay := await _make_overlay()
	var left := overlay.get_card(0)
	left.interaction.mouse_entered.emit()
	assert_eq(overlay.get_selected_item_id(), &"")
	left.interaction.pressed.emit()
	assert_eq(overlay.get_selected_item_id(), left.item_id)
	assert_false(overlay.confirm_button.disabled)
	var confirmation_count := [0]
	overlay.confirmation_requested.connect(func(_item_id): confirmation_count[0] += 1)
	# Un double clic reste une sélection : seul le bouton dédié confirme.
	left.interaction.pressed.emit()
	left.interaction.pressed.emit()
	assert_eq(confirmation_count[0], 0)
	overlay.confirm_button.pressed.emit()
	overlay.confirm_button.pressed.emit()
	assert_eq(confirmation_count[0], 1)


func test_keyboard_or_gamepad_navigation_changes_card_and_escape_is_swallowed() -> void:
	var overlay := await _make_overlay()
	var right_event := InputEventAction.new()
	right_event.action = &"ui_right"
	right_event.pressed = true
	overlay._input(right_event)
	assert_eq(overlay.get_selected_item_id(), overlay.get_card(1).item_id)
	var left_event := InputEventAction.new()
	left_event.action = &"ui_left"
	left_event.pressed = true
	overlay._input(left_event)
	assert_eq(overlay.get_selected_item_id(), overlay.get_card(0).item_id)
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	overlay._input(cancel_event)
	assert_true(overlay.visible)
	assert_ne(overlay.get_selected_item_id(), &"")


func test_selection_is_visually_dominant_without_hiding_other_card() -> void:
	var overlay := await _make_overlay()
	assert_true(overlay.select_item_by_id(overlay.get_card(0).item_id))
	await get_tree().create_timer(0.2).timeout
	var snapshot := overlay.get_visual_snapshot()
	assert_gt(snapshot["card_scales"][0].x, snapshot["card_scales"][1].x)
	assert_true(overlay.get_card(0).selection_badge.visible)
	assert_gt(overlay.get_card(1).modulate.a, 0.5)


func test_cards_remain_centered_and_uncut_at_supported_resolutions() -> void:
	var overlay := await _make_overlay()
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		overlay.apply_viewport_size_for_test(viewport_size)
		await get_tree().process_frame
		var snapshot := overlay.get_visual_snapshot()
		var outer := snapshot["overlay_rect"] as Rect2
		var rects := snapshot["card_rects"] as Array
		assert_eq(rects.size(), 2)
		for rect in rects:
			assert_true(_rect_contains(outer, rect), str(viewport_size))
		var sizes := snapshot["card_sizes"] as Array
		assert_almost_eq(sizes[0].x / sizes[0].y, 0.535, 0.01)
		assert_lte(sizes[0].y, 735.0)


func test_missing_texture_uses_readable_fallback_and_reduced_motion() -> void:
	var overlay := OVERLAY_SCENE.instantiate() as EquipmentRewardOverlay
	add_child_autofree(overlay)
	await get_tree().process_frame
	var missing := ItemDefinition.new()
	missing.item_id = &"missing_visual"
	missing.display_name = "Vestige sans image"
	missing.description = "Fallback de validation"
	missing.category = ItemDefinition.Category.ACCESSORY
	missing.equipment_slot = ItemDefinition.EquipmentSlot.ACCESSORY
	var valid := CATALOG.get_definition(&"arc_maudit")
	var options: Array[Dictionary] = [
		{"item_id": missing.item_id, "reward_id": missing.item_id, "definition": missing},
		{"item_id": valid.item_id, "reward_id": valid.item_id, "definition": valid},
	]
	assert_true(overlay.present(options, true))
	assert_true(overlay.get_card(0).fallback.visible)
	assert_false(overlay.get_card(0).particles.emitting)
	assert_true(overlay.get_visual_snapshot()["reduced_motion"])


func test_offer_copy_and_card_meta_distinguish_relics_from_equipment() -> void:
	var overlay := OVERLAY_SCENE.instantiate() as EquipmentRewardOverlay
	add_child_autofree(overlay)
	await get_tree().process_frame
	var first_relic := CATALOG.get_definition(&"cendres_du_phenix")
	var second_relic := CATALOG.get_definition(&"chaines_de_promethee")
	assert_not_null(first_relic)
	assert_not_null(second_relic)
	var relic_options: Array[Dictionary] = [
		{
			"item_id": first_relic.item_id,
			"reward_id": first_relic.item_id,
			"definition": first_relic,
		},
		{
			"item_id": second_relic.item_id,
			"reward_id": second_relic.item_id,
			"definition": second_relic,
		},
	]
	assert_true(overlay.present(relic_options, true))
	assert_eq(overlay.title_label.text, "CHOISISSEZ UNE RELIQUE")
	assert_eq(
		overlay.subtitle_label.text,
		"Une seule relique rejoindra le Sac partagé",
	)
	assert_eq(overlay.get_card(0).fallback_meta.text, "RELIQUE DE L’ODYSSÉE")

	var first_equipment := CATALOG.get_definition(&"arc_maudit")
	var second_equipment := CATALOG.get_definition(&"excalibur")
	var equipment_options: Array[Dictionary] = [
		{
			"item_id": first_equipment.item_id,
			"reward_id": first_equipment.item_id,
			"definition": first_equipment,
		},
		{
			"item_id": second_equipment.item_id,
			"reward_id": second_equipment.item_id,
			"definition": second_equipment,
		},
	]
	assert_true(overlay.present(equipment_options, true))
	assert_eq(overlay.title_label.text, "CHOISISSEZ UN ÉQUIPEMENT")
	assert_eq(
		overlay.subtitle_label.text,
		"Un seul équipement sera attribué à un héros",
	)
	assert_eq(overlay.get_card(0).fallback_meta.text, "ARME · ÉQUIPEMENT")


func test_dedicated_reward_card_texture_takes_priority_over_composed_fallback() -> void:
	var overlay := await _make_overlay()
	var card := overlay.get_card(0)
	assert_not_null(card.card_texture.texture)
	assert_true(card.card_texture.visible)
	assert_false(card.fallback.visible)


func test_confirmation_transform_is_reset_before_the_next_offer() -> void:
	var overlay := OVERLAY_SCENE.instantiate() as EquipmentRewardOverlay
	add_child_autofree(overlay)
	await get_tree().process_frame
	overlay.apply_viewport_size_for_test(Vector2(1920, 1080))
	var first := CATALOG.get_definition(&"arc_maudit")
	var second := CATALOG.get_definition(&"excalibur")
	var options: Array[Dictionary] = [
		{"item_id": first.item_id, "reward_id": first.item_id, "definition": first},
		{"item_id": second.item_id, "reward_id": second.item_id, "definition": second},
	]
	assert_true(overlay.present(options, true))
	assert_true(overlay.select_item_by_id(first.item_id))
	overlay.resolve_confirmation(true)
	await get_tree().create_timer(0.2, true, false, true).timeout
	assert_ne(overlay.get_card(0).visual_root.position.x, 0.0)
	assert_true(overlay.present(options, true))
	assert_eq(overlay.get_card(0).visual_root.position.x, 0.0)
	assert_eq(overlay.get_card(1).visual_root.position.x, 0.0)


func _make_overlay() -> EquipmentRewardOverlay:
	var overlay := OVERLAY_SCENE.instantiate() as EquipmentRewardOverlay
	add_child_autofree(overlay)
	await get_tree().process_frame
	overlay.apply_viewport_size_for_test(Vector2(1920, 1080))
	var first := CATALOG.get_definition(&"arc_maudit")
	var second := CATALOG.get_definition(&"excalibur")
	var options: Array[Dictionary] = [
		{"item_id": first.item_id, "reward_id": first.item_id, "definition": first},
		{"item_id": second.item_id, "reward_id": second.item_id, "definition": second},
	]
	assert_true(overlay.present(options))
	await get_tree().create_timer(0.65).timeout
	return overlay


func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	const TOLERANCE := 1.0
	return inner.position.x >= outer.position.x - TOLERANCE \
		and inner.position.y >= outer.position.y - TOLERANCE \
		and inner.end.x <= outer.end.x + TOLERANCE \
		and inner.end.y <= outer.end.y + TOLERANCE
