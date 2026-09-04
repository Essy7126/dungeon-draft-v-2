extends GutTest

const OVERLAY_SCENE := preload(
	"res://ui/progression/evolution/SkillEvolutionOverlay.tscn"
)
const ARCHER_CARD_UPGRADE_PATHS := [
	"res://data/characters/elf/upgrades/barbed_tip.tres",
	"res://data/characters/elf/upgrades/eagle_eye.tres",
	"res://data/characters/elf/upgrades/hindering_arrow.tres",
	"res://data/characters/elf/upgrades/impact_bolt.tres",
	"res://data/characters/elf/upgrades/long_range.tres",
	"res://data/characters/elf/upgrades/perfect_shot.tres",
	"res://data/characters/elf/upgrades/perfect_sight.tres",
	"res://data/characters/elf/upgrades/piercing_shot.tres",
	"res://data/characters/elf/upgrades/pin_arrow.tres",
	"res://data/characters/elf/upgrades/repel_arrow.tres",
	"res://data/characters/elf/upgrades/shatter.tres",
	"res://data/characters/elf/upgrades/siege_arrow.tres",
	"res://data/characters/elf/upgrades/siege_bolt.tres",
	"res://data/characters/elf/upgrades/stabilization.tres",
	"res://data/characters/elf/upgrades/stopping_arrow.tres",
	"res://data/characters/elf/upgrades/tactical_retreat.tres",
	"res://data/characters/elf/upgrades/transpiercing_bolt.tres",
]
const ACHILLES_DISCIPLINE_PATHS := [
	"res://data/characters/achilles/disciplines/spear.tres",
	"res://data/characters/achilles/disciplines/advance.tres",
	"res://data/characters/achilles/disciplines/sweep.tres",
	"res://data/characters/achilles/disciplines/guard.tres",
]


func _upgrade(file_name: String) -> SkillUpgradeData:
	return load(
		"res://data/characters/elf/upgrades/%s.tres" % file_name
	) as SkillUpgradeData


func _request(rank: int = 2) -> EvolutionRequest:
	return EvolutionRequest.create(
		&"elf",
		&"archer",
		rank,
		&"elf_archer_base",
		1,
		StringName("card_presentation_%d" % rank),
	)


func _choice(
		rank: int,
		first: SkillUpgradeData,
		second: SkillUpgradeData
	) -> Dictionary:
	return {
		"character_id": &"elf",
		"character_name": "Elfe",
		"discipline_id": &"archer",
		"discipline_name": "Archer",
		"rank": rank,
		"choices": [first, second],
	}


func _overlay() -> SkillEvolutionOverlay:
	var overlay := OVERLAY_SCENE.instantiate() as SkillEvolutionOverlay
	add_child_autofree(overlay)
	return overlay


func _achilles_upgrades() -> Array[SkillUpgradeData]:
	var result: Array[SkillUpgradeData] = []
	for resource_path in ACHILLES_DISCIPLINE_PATHS:
		var discipline := load(resource_path) as DisciplineData
		assert_not_null(discipline, resource_path)
		for rank in discipline.ranks:
			if rank == null:
				continue
			for upgrade in rank.choices:
				if upgrade != null:
					result.append(upgrade)
	return result


func test_elf_archer_assets_are_bound_to_every_generated_card() -> void:
	for resource_path in ARCHER_CARD_UPGRADE_PATHS:
		var upgrade := load(resource_path) as SkillUpgradeData
		assert_not_null(upgrade, resource_path)
		assert_not_null(upgrade.card_texture, resource_path)
		assert_same(upgrade.get_card_texture(), upgrade.card_texture, resource_path)
	var missing_asset := _upgrade("open_breach")
	assert_not_null(missing_asset)
	assert_null(missing_asset.get_card_texture())


func test_odyssey_evolution_assets_are_bound_cropped_and_import_bounded() -> void:
	var upgrades := _achilles_upgrades()
	assert_eq(upgrades.size(), 8)
	for upgrade in upgrades:
		var texture := upgrade.get_card_texture()
		assert_not_null(texture, str(upgrade.upgrade_id))
		assert_true(
			str(texture.resource_path).begins_with(
				"res://asset/ui/progression/achilles_evolutions_v1/"
			),
			str(upgrade.upgrade_id),
		)
		assert_has(
			SkillEvolutionCard.ARTWORK_CROP_REGIONS,
			texture.resource_path,
			str(upgrade.upgrade_id),
		)
		assert_lte(texture.get_width(), 768, str(upgrade.upgrade_id))
		assert_lte(texture.get_height(), 768, str(upgrade.upgrade_id))
	var spear_upgrades := upgrades.filter(func(value: SkillUpgradeData) -> bool:
		return value.discipline_id == &"spear"
	)
	assert_eq(spear_upgrades.size(), 2)
	var overlay := _overlay()
	await get_tree().process_frame
	var request := EvolutionRequest.create(
		&"achilles", &"spear", 2, &"achilles_spear_thrust", 1, &"odyssey_art_crop"
	)
	var choice := {
		"character_id": &"achilles",
		"character_name": "Achille",
		"discipline_id": &"spear",
		"discipline_name": "Lance",
		"rank": 2,
		"choices": spear_upgrades,
	}
	assert_true(overlay.present(request, choice, true))
	await get_tree().process_frame
	for card_index in 2:
		var cropped := overlay.get_card(card_index).card_texture.texture
		assert_true(cropped is AtlasTexture)
		assert_same((cropped as AtlasTexture).atlas, spear_upgrades[card_index].card_texture)


func test_reused_cards_reset_confirmation_translation_before_next_choice() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	var first := _upgrade("eagle_eye")
	var second := _upgrade("repel_arrow")
	assert_true(overlay.present(_request(), _choice(2, first, second), true))
	assert_true(overlay.select_upgrade_by_id(first.upgrade_id))
	assert_true(overlay.request_confirmation())
	overlay.resolve_confirmation(true)
	await overlay.confirmation_finished
	assert_gt(overlay.get_card(1).visual_root.position.x, 50.0)
	assert_lt(overlay.get_card(1).modulate.a, 0.1)
	assert_true(overlay.present(_request(), _choice(2, first, second), true))
	await get_tree().process_frame
	for card_index in 2:
		var card := overlay.get_card(card_index)
		assert_almost_eq(card.visual_root.position.x, 0.0, 0.01)
		assert_almost_eq(card.modulate.a, 1.0, 0.01)


func test_overlay_requires_two_cards_and_separates_hover_selection_and_confirmation() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	var first := _upgrade("eagle_eye")
	var second := _upgrade("repel_arrow")
	assert_true(overlay.present(_request(), _choice(2, first, second), true))
	await get_tree().process_frame
	assert_eq(overlay.get_card_count(), 2)
	assert_eq(overlay.get_available_upgrade_ids(), [
		first.upgrade_id,
		second.upgrade_id,
	])
	overlay.get_card(0).interaction.mouse_entered.emit()
	assert_eq(overlay.get_selected_upgrade_id(), &"")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	overlay._input(cancel)
	assert_true(overlay.visible)
	assert_true(overlay.select_upgrade_by_id(second.upgrade_id))
	assert_true(overlay.get_card(1).is_selected())
	assert_false(overlay.get_card(0).is_selected())
	var confirmations := [0]
	overlay.confirmation_requested.connect(func(_request_id, _upgrade_id):
		confirmations[0] += 1
	)
	assert_true(overlay.request_confirmation())
	assert_false(overlay.request_confirmation())
	assert_eq(confirmations[0], 1)


func test_overlay_uses_a_data_driven_fallback_when_a_card_asset_is_missing() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	var missing_asset := _upgrade("open_breach")
	var generated_asset := _upgrade("perfect_shot")
	assert_true(overlay.present(
		_request(5),
		_choice(5, missing_asset, generated_asset),
		true,
	))
	await get_tree().process_frame
	assert_true(overlay.get_card(0).fallback.visible)
	assert_false(overlay.get_card(0).card_texture.visible)
	assert_eq(overlay.get_card(0).fallback_title.text, missing_asset.display_name.to_upper())
	assert_false(overlay.get_card(1).fallback.visible)


func test_overlay_cards_remain_inside_common_run_resolutions() -> void:
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		var overlay := _overlay()
		await get_tree().process_frame
		assert_true(overlay.present(
			_request(),
			_choice(2, _upgrade("eagle_eye"), _upgrade("repel_arrow")),
			true,
		))
		overlay.apply_viewport_size_for_test(viewport_size)
		await get_tree().process_frame
		var snapshot := overlay.get_visual_snapshot()
		var overlay_rect := snapshot.get("overlay_rect") as Rect2
		var card_rects := snapshot.get("card_rects") as Array
		var card_layouts := snapshot.get("card_layouts") as Array
		assert_eq(card_rects.size(), 2)
		assert_eq(card_layouts.size(), 2)
		assert_true(overlay_rect.encloses(card_rects[0]), str(viewport_size))
		assert_true(overlay_rect.encloses(card_rects[1]), str(viewport_size))
		assert_false((card_rects[0] as Rect2).intersects(card_rects[1]), str(viewport_size))
		for layout in card_layouts:
			var card_global := layout.get("card_global") as Rect2
			assert_true(card_global.encloses(layout.get("art_global") as Rect2), str(viewport_size))
			assert_true(card_global.encloses(layout.get("title_global") as Rect2), str(viewport_size))
			assert_true(card_global.encloses(layout.get("description_global") as Rect2), str(viewport_size))
			assert_true(card_global.encloses(layout.get("rank_global") as Rect2), str(viewport_size))
		if viewport_size == Vector2(1280, 720):
			assert_true(bool(card_layouts[0].get("compact_mode")))
			assert_lte(float(card_layouts[0].get("art_minimum_height")), 170.0)
			assert_gte(float(card_layouts[0].get("description_minimum_height")), 68.0)
			assert_gte(int(card_layouts[0].get("description_font_size")), 12)
		elif viewport_size == Vector2(2560, 1440):
			assert_false(bool(card_layouts[0].get("compact_mode")))
			assert_gt(float(card_layouts[0].get("presentation_scale")), 1.0)
			assert_gte((snapshot.get("card_sizes") as Array)[0].y, 700.0)
			assert_gte(int(card_layouts[0].get("description_font_size")), 15)
		overlay.queue_free()
		await get_tree().process_frame


func test_selection_badge_sits_on_art_and_never_masks_the_eyebrow() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	var first := _upgrade("eagle_eye")
	assert_true(overlay.present(
		_request(),
		_choice(2, first, _upgrade("repel_arrow")),
		true,
	))
	overlay.apply_viewport_size_for_test(Vector2(1280, 720))
	assert_true(overlay.select_upgrade_by_id(first.upgrade_id))
	await get_tree().process_frame
	var layout := overlay.get_card(0).get_layout_snapshot()
	assert_true(bool(layout.get("compact_mode")))
	assert_false(
		(layout.get("selection_badge_global") as Rect2).intersects(
			layout.get("eyebrow_global") as Rect2
		)
	)
	assert_true(
		(layout.get("art_global") as Rect2).encloses(
			layout.get("selection_badge_global") as Rect2
		)
	)
