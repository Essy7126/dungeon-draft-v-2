extends GutTest

const RUN: RunData = preload("res://data/runs/odyssey.tres")
const PAINTED := {"achilles": "painted_g"}
const VISUAL_PROPERTIES := ["visual_scene", "preview_visual_scene", "preview_sprite_frames", "preview_sprite_frames_path", "preview_sprite_animation", "portrait_texture_override"]


class HarnessManager:
	extends "res://core/game_manager.gd"
	var requested_battles := 0
	func start_next_battle() -> void:
		_room_outcome_resolved = false
		requested_battles += 1
	func save_expedition(_path: String = ExpeditionSaveService.SAVE_PATH) -> bool:
		return not get_expedition_snapshot().is_empty()


var managers: Array[HarnessManager] = []
var save_paths: Array[String] = []


func after_each() -> void:
	for manager in managers:
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()
	managers.clear()
	for path in save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save_paths.clear()


func test_visual_variant_changes_only_presentation_on_an_isolated_runtime_copy() -> void:
	var classic := RunHeroResolver.resolve_runtime_hero_data(RUN, false)
	var run := _painted_run()
	var painted := RunHeroResolver.resolve_runtime_hero_data(run, false)
	assert_true(classic.is_valid())
	assert_true(painted.is_valid(), str(painted.errors))
	if not painted.is_valid():
		return
	assert_eq(painted.heroes.size(), 1)
	var old: UnitData = classic.heroes[0]
	var fresh: UnitData = painted.heroes[0]
	assert_eq(fresh.get_effective_unit_id(), &"achilles")
	assert_eq(fresh.unit_name, old.unit_name)
	assert_eq(fresh.visual_scene.resource_path, RunHeroVisualVariants.PAINTED_SCENE_PATH)
	assert_eq(fresh.preview_sprite_frames_path, RunHeroVisualVariants.PAINTED_FRAMES_PATH)
	for property in old.get_property_list():
		var key := str(property.name)
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or key in VISUAL_PROPERTIES:
			continue
		assert_eq(fresh.get(key), old.get(key), "Gameplay property changed: %s" % key)
	assert_same(fresh.progression_profile, old.progression_profile)
	assert_same(run.content_profile, RUN.content_profile)
	assert_same(classic.hero_profiles[0], painted.hero_profiles[0])
	assert_true(RUN.hero_visual_variants.is_empty())
	assert_ne(RUN.content_profile.hero_profiles[0].base_unit_data.visual_scene.resource_path, RunHeroVisualVariants.PAINTED_SCENE_PATH)


func test_painted_portrait_reaches_the_hud_without_mutating_the_classic_theme() -> void:
	var classic: UnitData = RunHeroResolver.resolve_runtime_hero_data(RUN, false).heroes[0]
	var painted: UnitData = RunHeroResolver.resolve_runtime_hero_data(_painted_run(), false).heroes[0]
	var original := CharacterHUDThemeCatalog.resolve_refined(classic)
	var original_portrait := original.portrait_texture
	var variant := CharacterHUDThemeCatalog.resolve_refined(painted)
	assert_not_same(variant, original)
	assert_same(variant.portrait_texture, painted.portrait_texture_override)
	assert_eq(variant.portrait_texture.resource_path, RunHeroVisualVariants.PAINTED_PORTRAIT_PATH)
	assert_same(variant.get_spell_icon(&"achilles_peleid_strike"), original.get_spell_icon(&"achilles_peleid_strike"))
	var runtime := Unit.from_data(painted)
	assert_same(runtime.portrait_texture_override, painted.portrait_texture_override)
	assert_same(CharacterHUDThemeCatalog.resolve_refined(runtime).portrait_texture, painted.portrait_texture_override)
	assert_same(CharacterHUDThemeCatalog.resolve_refined(classic), original)
	assert_same(original.portrait_texture, original_portrait)
	assert_null(classic.portrait_texture_override)


func test_configured_launch_preserves_choice_through_cinematic_consumption_and_route_factory() -> void:
	var manager := _manager()
	var run := _painted_run()
	assert_true(manager.configure_next_run(run, 0))
	assert_same(manager.peek_next_run_data(), run)
	var transferred := manager.take_next_run_data(RUN)
	assert_same(transferred, run)
	assert_false(manager.has_next_run_configuration())
	assert_true(manager.configure_next_run(transferred, 0))
	assert_true(manager.start_configured_run())
	assert_false(manager.has_next_run_configuration())
	assert_eq(manager.requested_battles, 1)
	assert_eq(manager.expedition.route.current_node_id, "d01_0")
	assert_eq(manager.get_ordered_heroes().size(), 1)
	assert_eq(manager.get_ordered_heroes()[0].unit_id, &"achilles")
	assert_eq(manager.get_ordered_heroes()[0].visual_scene.resource_path, RunHeroVisualVariants.PAINTED_SCENE_PATH)
	assert_not_null(manager.get_character_state(&"achilles"))
	assert_null(manager.get_character_state(&"achilles_painted_g"))
	assert_eq(manager.get_expedition_snapshot().hero_visual_variants, PAINTED)


func test_both_appearances_share_starting_stats_spells_and_route_progression() -> void:
	var classic := _manager()
	var painted := _manager()
	assert_true(classic.start_expedition(731))
	assert_true(painted.start_expedition(731, PAINTED))
	assert_eq(_gameplay_snapshot(painted), _gameplay_snapshot(classic))
	for manager in [classic, painted]:
		manager.begin_combat_report()
		manager.on_battle_won()
	assert_eq(painted.get_character_state(&"achilles").loadout.get_spell_slot_ids(), classic.get_character_state(&"achilles").loadout.get_spell_slot_ids())
	assert_eq(_gameplay_snapshot(painted), _gameplay_snapshot(classic))


func test_json_save_restore_retains_painted_choice_and_existing_build() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(915, PAINTED))
	manager.begin_combat_report()
	manager.on_battle_won()
	var snapshot := _json(manager.get_expedition_snapshot())
	var restored := _manager()
	assert_true(restored.restore_expedition_snapshot(snapshot))
	assert_eq(_json(restored.get_expedition_snapshot()), snapshot)
	assert_eq(restored.get_character_state(&"achilles").unit.visual_scene.resource_path, RunHeroVisualVariants.PAINTED_SCENE_PATH)
	assert_true(restored.resume_expedition(_write_save(snapshot)))
	assert_eq(restored.get_character_state(&"achilles").unit.visual_scene.resource_path, RunHeroVisualVariants.PAINTED_SCENE_PATH)
	assert_eq(CharacterHUDThemeCatalog.resolve_refined(restored.get_character_state(&"achilles").unit).portrait_texture.resource_path, RunHeroVisualVariants.PAINTED_PORTRAIT_PATH)


func test_existing_save_without_appearance_still_resumes_as_classic() -> void:
	var source := _manager()
	assert_true(source.start_expedition(918))
	var legacy := _json(source.get_expedition_snapshot())
	legacy.erase("hero_visual_variants")
	var restored := _manager()
	assert_true(restored.restore_expedition_snapshot(legacy))
	assert_true(restored.get_expedition_snapshot().hero_visual_variants.is_empty())
	assert_eq(restored.get_character_state(&"achilles").unit.visual_scene, RUN.content_profile.hero_profiles[0].base_unit_data.visual_scene)
	assert_null(restored.get_character_state(&"achilles").unit.portrait_texture_override)


func test_unknown_appearance_is_rejected_without_mutating_a_live_run() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(721, PAINTED))
	var before := _json(manager.get_expedition_snapshot())
	for invalid in [{"achilles": "unknown"}, {"mage": "painted_g"}, {"achilles": 2}, "painted_g"]:
		var snapshot := before.duplicate(true)
		snapshot.hero_visual_variants = invalid
		assert_false(manager.restore_expedition_snapshot(snapshot))
		assert_eq(_json(manager.get_expedition_snapshot()), before)
	assert_false(manager.start_expedition(721, {"achilles": "unknown"}))
	assert_eq(_json(manager.get_expedition_snapshot()), before)


func test_new_classic_selection_after_painted_clears_the_appearance() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(721, PAINTED))
	manager.cleanup_run_state()
	assert_true(manager.configure_next_run(RUN, 0))
	assert_true(manager.start_configured_run())
	assert_true(manager.get_expedition_snapshot().hero_visual_variants.is_empty())
	assert_eq(manager.get_character_state(&"achilles").unit.visual_scene, RUN.content_profile.hero_profiles[0].base_unit_data.visual_scene)


func _manager() -> HarnessManager:
	var manager := HarnessManager.new()
	manager._ready()
	managers.append(manager)
	return manager


func _painted_run() -> RunData:
	var run := RUN.duplicate(false) as RunData
	run.hero_visual_variants = PAINTED.duplicate()
	run.randomize_seed_each_run = false
	run.default_seed = 731
	return run


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))


func _gameplay_snapshot(manager: HarnessManager) -> Dictionary:
	var snapshot := _json(manager.get_expedition_snapshot())
	snapshot.erase("hero_visual_variants")
	# Inventory instance ids are intentionally unique per live run.
	snapshot.erase("inventory")
	snapshot.erase("equipment")
	return snapshot


func _write_save(snapshot: Dictionary) -> String:
	var path := OS.get_environment("TEMP").path_join("achilles_variant_test_%d.json" % Time.get_ticks_usec())
	assert_true(ExpeditionSaveService.write_snapshot(snapshot, path))
	save_paths.append(path)
	return path
