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


func test_elf_archer_assets_are_bound_to_every_generated_card() -> void:
	for resource_path in ARCHER_CARD_UPGRADE_PATHS:
		var upgrade := load(resource_path) as SkillUpgradeData
		assert_not_null(upgrade, resource_path)
		assert_not_null(upgrade.card_texture, resource_path)
		assert_same(upgrade.get_card_texture(), upgrade.card_texture, resource_path)
	var missing_asset := _upgrade("open_breach")
	assert_not_null(missing_asset)
	assert_null(missing_asset.get_card_texture())


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
		assert_eq(card_rects.size(), 2)
		assert_true(overlay_rect.encloses(card_rects[0]), str(viewport_size))
		assert_true(overlay_rect.encloses(card_rects[1]), str(viewport_size))
		assert_false((card_rects[0] as Rect2).intersects(card_rects[1]), str(viewport_size))
		overlay.queue_free()
		await get_tree().process_frame
