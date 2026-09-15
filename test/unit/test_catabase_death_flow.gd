extends GutTest
## Isolated real lifecycle; no player save and no combat-balance inference.

class DeathManager extends "res://core/game_manager.gd":
	var paths: Array[String] = []
	func start_next_battle() -> void:
		_room_outcome_resolved = false
	func _request_scene_change(path: String, _mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT) -> void:
		paths.append(path)
	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null

var _managers: Array[DeathManager] = []


func _manager(variant := "", difficulty := "normal") -> DeathManager:
	var manager := DeathManager.new()
	manager.expedition_save_path = "user://death_flow_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	_managers.append(manager)
	var variants := {} if variant.is_empty() else {"achilles": variant}
	assert_true(manager.start_expedition(2401, variants, false, false, difficulty))
	return manager


func after_each() -> void:
	for manager in _managers:
		ExpeditionSaveService.remove_snapshot(manager.expedition_save_path)
		manager.cleanup_run_state()
		manager.queue_free()
	_managers.clear()
	await get_tree().process_frame


func _lose(manager: DeathManager) -> void:
	manager.begin_combat_report()
	var hero: Unit = manager.get_ordered_heroes()[0]
	hero.current_hp = 0
	hero.is_alive = false
	manager.on_battle_lost()


func test_defeat_deletes_checkpoint_and_new_attempt_opens_only_catabase_selection() -> void:
	var manager := _manager()
	assert_true(FileAccess.file_exists(manager.expedition_save_path))
	_lose(manager)
	assert_false(manager.run_active)
	assert_eq(manager.paths, [manager.RUN_RESULT_SCREEN_PATH])
	assert_false(FileAccess.file_exists(manager.expedition_save_path))
	assert_true(manager.get_last_run_result().is_catabase)
	assert_true(manager.request_new_catabase_attempt())
	assert_eq(manager.paths.back(), manager.CHARACTER_SELECTION_SCREEN_PATH)
	assert_false(manager.paths.has(manager.START_HUB_SCREEN_PATH))
	assert_null(manager.expedition)
	assert_true(manager.heroes.is_empty())
	assert_null(manager.peek_next_run_data())
	assert_true(manager.get_last_run_result().is_empty())
	var count := manager.paths.size()
	assert_false(manager.request_new_catabase_attempt(), "A result is consumed only once")
	assert_eq(manager.paths.size(), count)
	assert_true(manager.start_expedition(991))
	assert_eq(manager.heroes.size(), 1)
	assert_eq((manager.heroes[0] as Unit).unit_id, &"achilles")
	assert_true((manager.heroes[0] as Unit).is_alive)
	assert_eq(manager.expedition.route.current_node_id, "d01_0")
	for entry: Dictionary in CharacterSelectionCatalog.get_entries():
		assert_true((entry.run as RunData).catabase_route_enabled)
		assert_eq((entry.unit as UnitData).get_effective_unit_id(), &"achilles")


func test_old_archivist_callback_after_catabase_is_redirected_but_explicit_legacy_hub_remains() -> void:
	var manager := _manager()
	_lose(manager)
	manager.return_to_hub()
	assert_eq(manager.paths.back(), manager.CHARACTER_SELECTION_SCREEN_PATH)
	assert_false(manager.paths.has(manager.START_HUB_SCREEN_PATH))
	var legacy := DeathManager.new()
	_managers.append(legacy)
	legacy.expedition_save_path = "user://death_legacy_unused.json"
	add_child(legacy)
	legacy.return_to_hub()
	assert_eq(legacy.paths, [legacy.START_HUB_SCREEN_PATH])


func test_terminal_deletion_failure_cannot_be_bypassed_by_menu_or_new_attempt() -> void:
	var manager := _manager()
	var real_path := manager.expedition_save_path
	manager.expedition_save_path = "user://"
	_lose(manager)
	assert_true(manager.run_active)
	assert_eq(manager.get_expedition_save_status().operation, "finish_defeat")
	assert_false(manager.request_new_catabase_attempt())
	assert_false(manager.request_return_to_title())
	assert_false(manager.request_abandon_run())
	manager.return_to_hub()
	assert_true(manager.paths.is_empty())
	assert_eq(manager.get_expedition_save_status().operation, "finish_defeat")
	manager.expedition_save_path = real_path
	assert_true(manager.retry_expedition_save())
	assert_false(FileAccess.file_exists(real_path))
	assert_eq(manager.paths, [manager.RUN_RESULT_SCREEN_PATH])
	assert_true(manager.request_new_catabase_attempt())


func test_live_attempt_cannot_be_discarded_by_result_action() -> void:
	var manager := _manager()
	var before := FileAccess.get_sha256(manager.expedition_save_path)
	assert_false(manager.request_new_catabase_attempt())
	assert_true(manager.run_active)
	assert_eq(FileAccess.get_sha256(manager.expedition_save_path), before)


func test_passe_rive_death_uses_route_facts_not_room_pool_and_grants_nothing() -> void:
	var manager := _manager("passe_rive", "easy")
	manager.begin_combat_report()
	manager.on_battle_won()
	while not manager.expedition.advancement_step.is_empty():
		while manager.expedition.character.champion_progression.unspent_attribute_points > 0:
			assert_true(manager.spend_champion_attribute(&"achilles", &"vitality"))
		assert_true(manager.advance_expedition_level_step().success)
	assert_true(manager.claim_expedition_reward("supplies").success)
	var next: Dictionary = manager.expedition.route.get_available_nodes()[0]
	assert_true(manager.choose_expedition_node(str(next.id)))
	var gold := manager.expedition.gold
	var xp := manager.expedition.character.champion_progression.current_xp
	_lose(manager)
	var result := manager.get_last_run_result()
	assert_true(result.is_expedition)
	assert_eq(result.featured_hero_name, "Passe-rive")
	assert_eq(result.depth_reached, 2)
	assert_eq(result.depth_total, 20)
	assert_eq(result.depths_cleared, 1)
	assert_eq(result.combats_won, 1)
	assert_eq(result.hero_level, 2)
	assert_eq(result.difficulty_id, "easy")
	assert_eq(result.reached_room_name, str(next.title))
	assert_false(str(result.epitaph).contains("Archiviste"))
	assert_eq(manager.expedition.gold, gold)
	assert_eq(manager.expedition.character.champion_progression.current_xp, xp)
	result["depth_reached"] = 999
	assert_eq(manager.get_last_run_result().depth_reached, 2, "Result is detached")


func test_victory_result_also_returns_to_catabase_without_archived_party() -> void:
	var manager := _manager()
	manager._finish_run(true)
	assert_true(manager.get_last_run_result().victory)
	assert_true(manager.request_new_catabase_attempt())
	assert_eq(manager.paths.back(), manager.CHARACTER_SELECTION_SCREEN_PATH)
	assert_false(manager.paths.has(manager.START_HUB_SCREEN_PATH))
