extends GutTest
## Interaction and readability regressions for the character-selection showcase.

const SCREEN_SCENE := preload("res://ui/selection/CharacterSelectionScreen.tscn")

var screen: CharacterSelectionScreen


func before_each() -> void:
	screen = SCREEN_SCENE.instantiate() as CharacterSelectionScreen
	add_child_autofree(screen)
	await wait_process_frames(3)


func test_codex_modal_freezes_rotation_zoom_and_pose_until_it_closes() -> void:
	assert_true(screen.set_preview_pose(&"walk"))
	screen.rotate_preview(1)
	screen._change_zoom(-0.1)
	var preview := screen.get_preview()
	var sprite := preview.get_sprite_instance()
	var orientation_before := screen.orientation_index
	var zoom_before := preview.get_showcase_zoom()
	var scale_before := sprite.scale
	var animation_before := sprite.animation
	assert_true(screen.open_spell_tree())
	var codex := screen.get_spell_tree()
	assert_not_null(codex)
	if codex == null:
		return
	assert_false(sprite.is_playing())
	screen.rotate_preview(1)
	screen._change_zoom(0.2)
	assert_false(screen.set_preview_pose(&"attack"))
	assert_eq(screen.orientation_index, orientation_before)
	assert_almost_eq(preview.get_showcase_zoom(), zoom_before, 0.0001)
	assert_eq(sprite.scale, scale_before)
	assert_eq(sprite.animation, animation_before)
	assert_false(sprite.is_playing(), "Hidden preview must not restart behind the codex")
	codex.close_screen()
	await wait_process_frames(3)
	assert_true(sprite.is_playing())
	assert_eq(sprite.animation, animation_before)
	screen.rotate_preview(1)
	screen._change_zoom(0.05)
	assert_ne(screen.orientation_index, orientation_before)
	assert_gt(preview.get_showcase_zoom(), zoom_before)
	assert_true(screen.set_preview_pose(&"attack"))


func test_closing_codex_returns_keyboard_focus_to_the_selected_technique() -> void:
	assert_true(screen.select_spell(3))
	var selected_button := screen._spell_buttons[3]
	selected_button.grab_focus()
	assert_true(screen.open_spell_tree())
	var codex := screen.get_spell_tree()
	assert_not_null(codex)
	if codex == null:
		return
	await wait_process_frames(3)
	codex.close_screen()
	await wait_process_frames(3)
	assert_null(screen.get_spell_tree())
	assert_same(screen.get_viewport().gui_get_focus_owner(), selected_button)
	assert_eq(screen.selected_spell_index, 3)
	assert_true(selected_button.button_pressed)


func test_codex_opened_from_history_restores_visible_focus_and_primary_navigation() -> void:
	assert_true(screen.select_spell(3))
	screen.show_details(1)
	await wait_process_frames(2)
	var lore_button := screen._lore.get_node("ExploreMasteriesFromLore") as Button
	var details_button := screen._details.get_node("ExploreMasteries") as Button
	assert_true(lore_button.is_visible_in_tree())
	assert_false(screen._spell_buttons[3].is_visible_in_tree())
	assert_same(screen.start_button.get_node(screen.start_button.focus_neighbor_top), lore_button)
	lore_button.grab_focus()
	lore_button.pressed.emit()
	var codex := screen.get_spell_tree()
	assert_not_null(codex)
	if codex == null:
		return
	await wait_process_frames(3)
	codex.close_screen()
	await wait_process_frames(3)
	assert_null(screen.get_spell_tree())
	var focus := screen.get_viewport().gui_get_focus_owner()
	assert_same(focus, lore_button, "Closing history exploration must not focus a technique hidden on the other tab")
	assert_true(lore_button.is_visible_in_tree())
	assert_true(screen._lore.is_visible_in_tree())
	assert_same(screen.start_button.get_node(screen.start_button.focus_neighbor_top), lore_button)
	screen.show_details(0)
	await wait_process_frames(2)
	assert_false(lore_button.is_visible_in_tree())
	assert_true(details_button.is_visible_in_tree())
	assert_same(screen.start_button.get_node(screen.start_button.focus_neighbor_top), details_button, "The primary action must navigate to the mastery button on the current tab")


func test_zoom_is_bounded_and_changes_the_actual_sprite_scale() -> void:
	var preview := screen.get_preview()
	var sprite := preview.get_sprite_instance()
	var original_scale := sprite.scale
	assert_true(preview.is_showcase_mode())
	screen._change_zoom(100.0)
	assert_almost_eq(screen._zoom, 1.1, 0.0001)
	assert_almost_eq(preview.get_showcase_zoom(), 1.1, 0.0001)
	assert_eq(screen._zoom_label.text, "110 %")
	assert_gt(sprite.scale.x, original_scale.x)
	var maximum_scale := sprite.scale
	screen._change_zoom(0.05)
	assert_eq(sprite.scale, maximum_scale, "Repeated enlargement must not exceed the maximum")
	screen._change_zoom(-100.0)
	assert_almost_eq(screen._zoom, 0.85, 0.0001)
	assert_almost_eq(preview.get_showcase_zoom(), 0.85, 0.0001)
	assert_eq(screen._zoom_label.text, "85 %")
	assert_lt(sprite.scale.x, original_scale.x)
	var minimum_scale := sprite.scale
	screen._change_zoom(-0.05)
	assert_eq(sprite.scale, minimum_scale, "Repeated reduction must not exceed the minimum")


func test_selecting_another_hero_or_adventure_restores_one_hundred_percent_zoom() -> void:
	screen._change_zoom(0.1)
	assert_true(screen.select_character(2))
	assert_eq(screen.get_selected_entry().get("id"), &"mage")
	assert_false(screen.get_preview().is_using_sprite_preview())
	assert_almost_eq(screen._zoom, 1.0, 0.0001)
	assert_almost_eq(screen.get_preview().get_showcase_zoom(), 1.0, 0.0001)
	assert_eq(screen._zoom_label.text, "100 %")
	screen._change_zoom(-0.15)
	assert_true(screen.select_character(screen.get_entries().size() - 1))
	assert_eq(screen.get_selected_entry().get("run").resource_path, "res://data/runs/philosopher_trial.tres")
	assert_true(screen.get_preview().is_using_sprite_preview())
	assert_almost_eq(screen._zoom, 1.0, 0.0001)
	assert_almost_eq(screen.get_preview().get_showcase_zoom(), 1.0, 0.0001)
	assert_eq(screen._zoom_label.text, "100 %")


func test_roster_folio_preview_and_primary_action_fit_common_screen_sizes() -> void:
	assert_eq(screen.get_entries().size(), 5)
	assert_eq(screen._roster_buttons.size(), 5)
	var folio := screen.find_child("CharacterFolio", true, false) as Control
	var note := screen.find_child("RosterNote", true, false) as Control
	assert_not_null(folio)
	assert_not_null(note)
	if folio == null or note == null:
		return
	for viewport_size in [Vector2(1280, 720), Vector2(1440, 900), Vector2(1920, 1080)]:
		screen.size = viewport_size
		await wait_process_frames(3)
		for character_index in range(screen.get_entries().size()):
			assert_true(screen.select_character(character_index))
			screen.show_details(0)
			await wait_process_frames(2)
			var context := "%s, entry %d" % [viewport_size, character_index]
			var controls: Array[Control] = [folio, note, screen.get_preview(), screen.start_button, screen._details]
			controls.append_array(screen._roster_buttons)
			controls.append_array(screen._spell_buttons)
			controls.append_array(screen._pose_buttons)
			controls.append_array(screen._tab_buttons)
			for control in controls:
				_assert_control_fits(control, context)
			assert_false(folio.get_global_rect().intersects(screen.start_button.get_global_rect()), "Folio must not cover the primary action: " + context)
			screen.show_details(1)
			await wait_process_frames(2)
			_assert_control_fits(screen._lore, context + ", history")
			_assert_control_fits(screen._lore.get_node("ExploreMasteriesFromLore") as Control, context + ", history")


func test_long_technique_description_scrolls_and_a_new_technique_starts_at_the_top() -> void:
	var description := screen._spell_description
	var scroll := screen._spell_scroll
	assert_false(description.clip_text, "Technique text must remain fully readable")
	assert_same(description.get_parent(), scroll)
	assert_eq(description.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_ne(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	var long_description := "La garde absorbe les dégâts, protège Achille puis expire au début de son activation suivante. "
	description.text = long_description.repeat(18) + "FIN DE DESCRIPTION"
	await wait_process_frames(5)
	var scrollbar := scroll.get_v_scroll_bar()
	assert_gt(description.size.y, scroll.size.y, "Long descriptions must extend vertically instead of being truncated")
	assert_gt(scrollbar.max_value, scrollbar.page, "All remaining text must be reachable by vertical scrolling")
	scroll.scroll_vertical = int(scrollbar.max_value)
	await wait_process_frames(3)
	assert_gt(scroll.scroll_vertical, 0)
	assert_true(description.text.ends_with("FIN DE DESCRIPTION"))
	assert_true(screen.select_spell(1))
	await wait_process_frames(3)
	assert_eq(scroll.scroll_vertical, 0, "Switching techniques must reveal the next description from its beginning")
	assert_false(description.text.contains("FIN DE DESCRIPTION"))


func test_all_technique_descriptions_use_readable_glossary_terms_instead_of_tokens() -> void:
	for character_index in range(screen.get_entries().size()):
		assert_true(screen.select_character(character_index))
		var entry := screen.get_selected_entry()
		var unit: UnitData = entry.get("unit")
		assert_eq(unit.spells.size(), 4)
		for spell_index in range(unit.spells.size()):
			assert_true(screen.select_spell(spell_index))
			var displayed := screen._spell_description.text
			assert_false(displayed.is_empty(), "%s technique %d has a readable effect" % [unit.unit_name, spell_index])
			assert_false(displayed.contains("[kw:"), "%s technique %d must not expose glossary markup" % [unit.unit_name, spell_index])
			if entry.get("id") == &"mage" and spell_index == 0:
				assert_true(displayed.contains("Lave"), "Boule de feu must display the player-facing glossary term Lave")


func test_roster_displays_four_distinct_illustrated_portraits_and_reuses_achilles() -> void:
	var entries := screen.get_entries()
	assert_eq(entries.size(), 5)
	var portraits: Array[Texture2D] = []
	var unique_portraits: Dictionary = {}
	var atlas_regions: Dictionary = {}
	for index in range(entries.size()):
		var unit: UnitData = entries[index].get("unit")
		var portrait := screen._portrait_for(unit)
		assert_not_null(portrait, "Every visible hero must have an illustrated portrait")
		if portrait == null:
			return
		assert_true(portrait.resource_path.contains("illustrated_v2"), "Roster should use the new selection artwork")
		var rendered_portraits := screen._roster_buttons[index].find_children("*", "TextureRect", true, false)
		assert_eq(rendered_portraits.size(), 1, "Each roster card renders one portrait")
		if not rendered_portraits.is_empty():
			assert_same((rendered_portraits[0] as TextureRect).texture, portrait)
		portraits.append(portrait)
		if index < 4:
			unique_portraits[portrait.get_instance_id()] = true
			if portrait is AtlasTexture:
				var atlas_key := "%d:%s" % [portrait.atlas.get_instance_id(), portrait.region]
				assert_false(atlas_regions.has(atlas_key), "Different heroes must not share the same atlas crop")
				atlas_regions[atlas_key] = true
	assert_eq(unique_portraits.size(), 4)
	assert_same(portraits[0], portraits[4], "Achille keeps his portrait across Catabase and the philosopher trial")


func _assert_control_fits(control: Control, context: String) -> void:
	assert_true(control.is_visible_in_tree(), "%s remains visible: %s" % [control.name, context])
	assert_true(screen.get_global_rect().grow(1.0).encloses(control.get_global_rect()), "%s remains inside the screen: %s" % [control.name, context])
