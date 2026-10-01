extends GutTest
## Static selection assets remain UI-only and preserve run configuration.

const SCREEN := preload("res://ui/selection/CharacterSelectionScreen.tscn")
var screen: CharacterSelectionScreen
var previous_variant: String


func before_each() -> void:
	previous_variant = GameManager.selected_run_variant
	GameManager.selected_run_variant = "classic"
	screen = SCREEN.instantiate()
	add_child_autofree(screen)
	await wait_process_frames(3)


func after_each() -> void:
	GameManager.selected_run_variant = previous_variant


func test_illustrated_appearances_preserve_real_run_variants_and_inventory() -> void:
	var inventory := GameManager.get_inventory_equipment_snapshot().duplicate(true)
	var expected_variants := ["", "painted_g", "passe_rive"]
	var regions: Array[Rect2] = []
	assert_eq(screen.get_entries().size(), 3)
	for index in screen.get_entries().size():
		screen._roster_buttons[index].pressed.emit()
		assert_eq(screen.selected_index, index)
		var entry := screen.get_selected_entry()
		assert_eq(entry.run.hero_visual_variants.get("achilles", ""), expected_variants[index])
		var art := screen._hero_art.texture as AtlasTexture
		assert_not_null(art)
		if art != null:
			for region in regions:
				assert_false(region.intersects(art.region), "Appearance regions remain independent")
			regions.append(art.region)
		assert_true(screen._roster_buttons[index].button_pressed)
		assert_false(screen.get_preview().visible)
		assert_eq(screen._pose_buttons.size(), 0)
	assert_eq(GameManager.get_inventory_equipment_snapshot(), inventory)


func test_classic_tabs_and_masteries_keep_keyboard_focus_without_preview_controls() -> void:
	screen._tab_buttons[1].pressed.emit()
	assert_true(screen._lore.visible)
	assert_false(screen._details.visible)
	(screen._lore.get_node("ExploreMasteriesFromLore") as Button).grab_focus()
	assert_true(screen.open_spell_tree())
	await wait_process_frames(3)
	screen.get_spell_tree().close_screen()
	await wait_process_frames(3)
	assert_same(get_viewport().gui_get_focus_owner(), screen._lore.get_node(
			"ExploreMasteriesFromLore"
		))
	screen._tab_buttons[0].pressed.emit()
	screen._spell_buttons[3].pressed.emit()
	assert_eq(screen.selected_spell_index, 3)
	assert_true(screen._details.visible)
	screen._spell_buttons[3].grab_focus()
	assert_true(screen.open_spell_tree())
	await wait_process_frames(3)
	screen.get_spell_tree().close_screen()
	await wait_process_frames(3)
	assert_same(get_viewport().gui_get_focus_owner(), screen._spell_buttons[3])


func test_cards_mode_keeps_its_existing_setup_and_preview() -> void:
	GameManager.selected_run_variant = "cards"
	var cards := SCREEN.instantiate() as CharacterSelectionScreen
	add_child_autofree(cards)
	await wait_process_frames(3)
	assert_not_null(cards._cards_setup)
	assert_null(cards._hero_art)
	assert_not_null(cards.get_preview())
	assert_eq(cards.get_entries().size(), 3)
