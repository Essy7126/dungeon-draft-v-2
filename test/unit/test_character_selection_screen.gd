extends GutTest

const SCREEN_SCENE := preload("res://ui/selection/CharacterSelectionScreen.tscn")
const CATABASE_RUN: RunData = preload("res://data/runs/odyssey.tres")
const TRIO_RUN: RunData = preload("res://data/runs/first_run.tres")


class AdventureManager:
	extends Node
	var accept_configuration := true
	var requests := 0
	var configured_run: RunData = null
	var configured_room := -1

	func configure_next_run(run_data: RunData, room_index: int) -> bool:
		requests += 1
		if not accept_configuration:
			return false
		configured_run = run_data
		configured_room = room_index
		return true


var screen: CharacterSelectionScreen


func before_each() -> void:
	screen = SCREEN_SCENE.instantiate() as CharacterSelectionScreen
	add_child_autofree(screen)
	await wait_process_frames(3)


func test_catalog_exposes_real_run_stats_and_resolved_spell_kits() -> void:
	var entries := screen.get_entries()
	assert_eq(entries.map(func(entry): return entry["id"]), [
		&"achilles", &"elf", &"mage", &"warrior",
	])
	for entry in entries:
		var unit := entry["unit"] as UnitData
		var run := entry["run"] as RunData
		var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
		assert_true(resolution.is_valid())
		var matching := resolution.heroes.filter(func(hero):
			return hero.get_effective_unit_id() == unit.get_effective_unit_id()
		)
		assert_eq(matching.size(), 1)
		if matching.is_empty():
			continue
		var expected := matching[0] as UnitData
		assert_eq(unit.max_hp, expected.max_hp)
		assert_eq(unit.max_ap, expected.max_ap)
		assert_eq(unit.max_mp, expected.max_mp)
		assert_eq(unit.initiative, expected.initiative)
		assert_eq(unit.spells.size(), 4, str(entry["id"]))
		assert_eq(_spell_ids(unit), _spell_ids(expected))
		assert_eq(unit.get_skill_trees().size(), expected.get_skill_trees().size())
	assert_eq(entries[0]["run"], CATABASE_RUN)
	assert_true(str(entries[0]["party_note"]).contains("solo"))


func test_character_selection_refreshes_stats_kit_and_preview_together() -> void:
	assert_eq(screen.selected_index, 0)
	_assert_visible_stats(screen.get_selected_entry()["unit"] as UnitData)
	assert_true(screen.select_spell(3))
	assert_eq(screen.selected_spell_index, 3)
	assert_true(screen.select_character(2))
	assert_eq(screen.get_selected_entry()["id"], &"mage")
	assert_eq(screen.selected_spell_index, 0)
	var mage := screen.get_selected_entry()["unit"] as UnitData
	_assert_visible_stats(mage)
	assert_eq(screen.get_preview().unit_data.get_effective_unit_id(), &"mage")
	assert_false(screen.get_preview().is_using_fallback())
	assert_true(screen.get_preview().get_visual_instance() is MageVisual3D)
	assert_true(screen.select_spell(mage.spells.size() - 1))
	assert_eq(screen.selected_spell_index, mage.spells.size() - 1)


func test_invalid_character_or_spell_indices_preserve_the_current_selection() -> void:
	assert_true(screen.select_spell(2))
	var unit := screen.get_selected_entry()["unit"] as UnitData
	assert_false(screen.select_character(-1))
	assert_false(screen.select_character(screen.get_entries().size()))
	assert_eq(screen.selected_index, 0)
	assert_eq(screen.get_selected_entry()["unit"], unit)
	assert_eq(screen.selected_spell_index, 2)
	assert_false(screen.select_spell(-1))
	assert_false(screen.select_spell(unit.spells.size()))
	assert_eq(screen.selected_spell_index, 2)


func test_rotating_achilles_changes_the_actual_displayed_orientation() -> void:
	var preview := screen.get_preview()
	assert_true(preview.is_using_sprite_preview())
	assert_eq(screen.orientation_index, 1)
	assert_eq(preview.get_sprite_instance().animation, &"idle_E")
	screen.rotate_preview(1)
	assert_eq(screen.orientation_index, 2)
	assert_eq(preview.get_sprite_instance().animation, &"idle_S")
	screen.rotate_preview(-2)
	assert_eq(screen.orientation_index, 0)
	assert_eq(preview.get_sprite_instance().animation, &"idle_N")
	screen.rotate_preview(-1)
	assert_eq(screen.orientation_index, 3)
	assert_eq(preview.get_sprite_instance().animation, &"idle_W")


func test_preview_poses_use_existing_clips_and_reject_unknown_actions() -> void:
	var preview := screen.get_preview()
	assert_true(screen.set_preview_pose(&"walk"))
	assert_eq(preview.get_sprite_instance().animation, &"walk_E")
	assert_true(preview.get_sprite_instance().is_playing())
	assert_true(screen.set_preview_pose(&"attack"))
	assert_eq(preview.get_sprite_instance().animation, &"attack_E")
	assert_false(screen.set_preview_pose(&"unavailable_skin"))
	assert_eq(preview.get_sprite_instance().animation, &"attack_E")
	assert_true(screen.set_preview_pose(&"idle"))
	assert_eq(preview.get_sprite_instance().animation, &"idle_E")


func test_preparing_achilles_configures_the_solo_run_at_room_zero() -> void:
	var manager := AdventureManager.new()
	add_child_autofree(manager)
	assert_true(screen.prepare_adventure(manager))
	assert_eq(manager.configured_run, CATABASE_RUN)
	assert_eq(manager.configured_room, 0)
	assert_true(screen.start_button.disabled)
	var resolution := RunHeroResolver.resolve_runtime_hero_data(manager.configured_run, false)
	assert_eq(resolution.heroes.map(func(hero): return hero.get_effective_unit_id()), [
		&"achilles",
	])


func test_browsing_a_trio_member_preserves_the_complete_playable_party() -> void:
	assert_true(screen.select_character(2))
	var selected := screen.get_selected_entry()
	assert_eq(selected["id"], &"mage")
	assert_eq(selected["run"], TRIO_RUN)
	for name_value in ["Elfe", "Mage", "Guerrier"]:
		assert_true(str(selected["party_note"]).contains(name_value))
	assert_true(str(selected["party_note"]).contains("fixe"))
	var manager := AdventureManager.new()
	add_child_autofree(manager)
	assert_true(screen.prepare_adventure(manager))
	assert_eq(manager.configured_run, TRIO_RUN)
	assert_eq(manager.configured_room, 0)
	var resolution := RunHeroResolver.resolve_runtime_hero_data(manager.configured_run, false)
	assert_eq(resolution.heroes.map(func(hero): return hero.get_effective_unit_id()), [
		&"elf", &"mage", &"warrior",
	])


func test_rejected_configuration_leaves_selection_available_for_retry() -> void:
	var manager := AdventureManager.new()
	manager.accept_configuration = false
	add_child_autofree(manager)
	assert_false(screen.prepare_adventure(manager))
	assert_null(manager.configured_run)
	assert_false(screen.start_button.disabled)
	assert_eq(screen.get_selected_entry()["id"], &"achilles")
	manager.accept_configuration = true
	assert_true(screen.prepare_adventure(manager))
	assert_eq(manager.requests, 2)
	assert_eq(manager.configured_run, CATABASE_RUN)
	assert_true(screen.start_button.disabled)


func test_missing_manager_cannot_commit_the_adventure() -> void:
	assert_false(screen.prepare_adventure(null))
	var invalid_manager := Node.new()
	add_child_autofree(invalid_manager)
	assert_false(screen.prepare_adventure(invalid_manager))
	assert_false(screen.start_button.disabled)


func test_spell_tree_opens_the_selected_spell_for_each_hero_without_registering_a_run() -> void:
	var registered_states := GameManager.get_ordered_character_states()
	var registered_snapshots := registered_states.map(func(state):
		return state.get_progression_snapshot()
	)
	for index in range(screen.get_entries().size()):
		assert_true(screen.select_character(index))
		var resolved_data := screen.get_selected_entry()["unit"] as UnitData
		assert_true(screen.select_spell(resolved_data.spells.size() - 1))
		var selected_spell := resolved_data.spells[screen.selected_spell_index]
		assert_true(screen.open_spell_tree())
		var spell_tree := screen.get_spell_tree()
		assert_not_null(spell_tree)
		if spell_tree == null:
			continue
		assert_eq(spell_tree.character_id, resolved_data.get_effective_unit_id())
		assert_eq(spell_tree.current_discipline_id, selected_spell.skill_tree.discipline_id)
		assert_true(spell_tree.is_consultative())
		assert_eq(spell_tree.get_tab_count(), resolved_data.get_skill_trees().size())
		assert_null(spell_tree.progression_controller)
		var preview_state := spell_tree._get_character_state()
		assert_false(registered_states.has(preview_state))
		for progress in preview_state.get_spell_progressions().values():
			assert_eq(progress.xp, 0)
			assert_true(progress.get_selected_upgrade_ids().is_empty())
		spell_tree.close_screen()
		await wait_process_frames(2)
	assert_eq(GameManager.get_ordered_character_states(), registered_states)
	assert_eq(registered_states.map(func(state):
		return state.get_progression_snapshot()
	), registered_snapshots)


func test_closing_spell_tree_releases_preview_state_and_restores_hero_animation() -> void:
	assert_true(screen.set_preview_pose(&"walk"))
	screen.rotate_preview(1)
	var preview := screen.get_preview()
	var sprite := preview.get_sprite_instance()
	assert_true(sprite.is_playing())
	assert_true(screen.open_spell_tree())
	var spell_tree := screen.get_spell_tree()
	var preview_state := spell_tree._get_character_state()
	assert_false(sprite.is_playing())
	assert_eq(spell_tree.get_parent(), screen)
	await wait_process_frames(3)
	assert_eq(spell_tree.size, screen.size)
	spell_tree.close_screen()
	assert_null(screen.get_spell_tree())
	assert_null(preview_state.unit)
	assert_true(sprite.is_playing())
	assert_eq(sprite.animation, &"walk_S")
	assert_eq(screen.orientation_index, 2)


func test_spell_tree_modal_prevents_duplicate_opening_and_underlying_navigation() -> void:
	var manager := AdventureManager.new()
	add_child_autofree(manager)
	assert_true(screen.select_spell(2))
	assert_true(screen.open_spell_tree())
	var spell_tree := screen.get_spell_tree()
	assert_false(screen.open_spell_tree())
	assert_same(screen.get_spell_tree(), spell_tree)
	assert_false(screen.select_character(1))
	assert_false(screen.select_spell(0))
	assert_false(screen.prepare_adventure(manager))
	assert_eq(manager.requests, 0)
	assert_eq(screen.selected_index, 0)
	assert_eq(screen.selected_spell_index, 2)
	spell_tree.close_screen()
	await wait_process_frames(2)
	assert_true(screen.select_character(1))
	assert_true(screen.open_spell_tree())
	assert_eq(screen.get_spell_tree().character_id, &"elf")


func test_leaving_selection_disposes_an_open_spell_tree_preview() -> void:
	assert_true(screen.open_spell_tree())
	var spell_tree := screen.get_spell_tree()
	var preview_state := spell_tree._get_character_state()
	screen.queue_free()
	await wait_process_frames(3)
	assert_null(preview_state.unit)
	assert_true(preview_state.get_spell_progressions().is_empty())
	assert_false(is_instance_valid(spell_tree))

func _spell_ids(unit: UnitData) -> Array:
	return unit.spells.map(func(spell): return spell.spell_id)


func _assert_visible_stats(unit: UnitData) -> void:
	assert_eq((screen.stats_labels["hp"] as Label).text, str(unit.max_hp))
	assert_eq((screen.stats_labels["ap"] as Label).text, str(unit.max_ap))
	assert_eq((screen.stats_labels["mp"] as Label).text, str(unit.max_mp))
	assert_eq((screen.stats_labels["initiative"] as Label).text, str(unit.initiative))
