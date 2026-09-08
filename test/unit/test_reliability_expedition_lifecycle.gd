extends GutTest
## Isolated failure injection; victories are simulated, no player save is touched.

class ReliabilityManager:
	extends "res://core/game_manager.gd"
	var requested_battles := 0
	var requested_scene := ""
	var create_ui := false
	func start_next_battle() -> void:
		_room_outcome_resolved = false
		requested_battles += 1
	func _request_scene_change(path: String, _mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT) -> void:
		requested_scene = path
	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return super._ensure_persistent_run_ui() if create_ui else null

var _managers: Array[ReliabilityManager] = []
var _directory := ""


func before_each() -> void:
	_directory = "res://artifacts/project_audit/2026-09-08/reliability-%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(_directory), OK)


func after_each() -> void:
	for manager in _managers:
		manager.cleanup_run_state()
		manager.queue_free()
	_managers.clear()
	await get_tree().process_frame
	get_tree().paused = false


func _manager(file_name := "checkpoint.json", with_ui := false) -> ReliabilityManager:
	var manager := ReliabilityManager.new()
	manager.expedition_save_path = _directory.path_join(file_name)
	manager.create_ui = with_ui
	add_child(manager)
	_managers.append(manager)
	return manager


func test_unconfirmed_new_expedition_cannot_replace_disk_or_live_state() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var session := manager.expedition
	var digest := FileAccess.get_sha256(manager.expedition_save_path)
	assert_false(manager.start_expedition(81723))
	assert_same(manager.expedition, session)
	assert_eq(manager.run_seed, 2401)
	assert_eq(FileAccess.get_sha256(manager.expedition_save_path), digest)
	assert_eq(manager.last_restore_error, &"EXPEDITION_REPLACEMENT_CONFIRMATION_REQUIRED")
	var guard := manager.get_expedition_replacement_guard()
	assert_true(guard.exists)
	assert_true(guard.resumable)
	assert_true(manager.confirm_expedition_replacement(guard.token))
	assert_true(manager.start_expedition(81723))
	assert_eq(manager.run_seed, 81723)
	assert_false(manager.start_expedition(999), "Consent authorizes exactly one replacement")


func test_stale_or_canceled_confirmation_cannot_replace_a_changed_checkpoint() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var guard := manager.get_expedition_replacement_guard()
	var external := ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
	external["external_revision"] = 2
	assert_true(ExpeditionSaveService.write_snapshot(external, manager.expedition_save_path))
	var digest := FileAccess.get_sha256(manager.expedition_save_path)
	assert_false(manager.confirm_expedition_replacement(guard.token))
	assert_false(manager.start_expedition(33))
	assert_eq(FileAccess.get_sha256(manager.expedition_save_path), digest)
	guard = manager.get_expedition_replacement_guard()
	assert_true(manager.confirm_expedition_replacement(guard.token))
	manager.cancel_expedition_replacement()
	assert_false(manager.start_expedition(34))


func test_failed_replacement_preserves_previous_bytes_and_waits_before_combat() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var digest := FileAccess.get_sha256(manager.expedition_save_path)
	# A directory at the temporary-file path makes the atomic write fail.
	assert_eq(DirAccess.make_dir_absolute(manager.expedition_save_path + ".tmp"), OK)
	var guard := manager.get_expedition_replacement_guard()
	assert_true(manager.confirm_expedition_replacement(guard.token))
	assert_false(manager.start_expedition(81723))
	assert_true(manager.run_active)
	assert_eq(manager.run_seed, 81723)
	assert_eq(manager.requested_battles, 1, "Replacement fight waits for a committed entry")
	assert_eq(FileAccess.get_sha256(manager.expedition_save_path), digest)
	assert_true(manager.get_expedition_save_status().pending)
	assert_eq(DirAccess.remove_absolute(manager.expedition_save_path + ".tmp"), OK)
	assert_true(manager.retry_expedition_save())
	assert_eq(manager.requested_battles, 2)
	assert_false(manager.get_expedition_save_status().pending)
	assert_eq(int(ExpeditionSaveService.read_snapshot(manager.expedition_save_path).session.route.seed), 81723)


func test_return_to_menu_during_combat_preserves_only_the_entry_checkpoint() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var path := manager.expedition_save_path
	var entry := ExpeditionSaveService.read_snapshot(path)
	manager.begin_combat_report()
	manager.expedition.character.unit.current_hp = 1
	assert_true(manager.get_expedition_snapshot().is_empty())
	assert_true(manager.request_return_to_title())
	assert_false(manager.run_active)
	assert_eq(manager.requested_scene, manager.TITLE_SCREEN_PATH)
	assert_eq(ExpeditionSaveService.read_snapshot(path), entry)
	assert_true(manager.resume_expedition())
	assert_eq(manager.expedition.character.unit.current_hp, int(entry.current_hp))


func test_failed_menu_exit_keeps_live_run_until_successful_retry() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var good_path := manager.expedition_save_path
	var session := manager.expedition
	manager.expedition_save_path = _directory.path_join("missing/checkpoint.json")
	assert_false(manager.request_return_to_title())
	assert_true(manager.run_active)
	assert_same(manager.expedition, session)
	assert_eq(manager.requested_scene, "")
	assert_eq(manager.get_expedition_save_status().operation, "return_to_title")
	manager.expedition_save_path = good_path
	assert_true(manager.retry_expedition_save())
	assert_false(manager.run_active)
	assert_eq(manager.requested_scene, manager.TITLE_SCREEN_PATH)
	assert_false(ExpeditionSaveService.read_snapshot(good_path).is_empty())


func test_abandon_removes_resume_instead_of_saving_and_failure_is_retryable() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var path := manager.expedition_save_path
	manager.expedition_save_path = _directory
	assert_false(manager.request_abandon_run())
	assert_true(manager.run_active)
	assert_eq(manager.requested_scene, "")
	assert_true(FileAccess.file_exists(path))
	manager.expedition_save_path = path
	assert_true(manager.retry_expedition_save())
	assert_false(manager.run_active)
	assert_false(FileAccess.file_exists(path))
	assert_false(manager.resume_expedition())
	assert_eq(manager.requested_scene, manager.TITLE_SCREEN_PATH)


func test_applied_purchase_reports_unsaved_and_retry_does_not_purchase_twice() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	manager.begin_combat_report()
	manager.on_battle_won()
	var path := manager.expedition_save_path
	var old_digest := FileAccess.get_sha256(path)
	manager.expedition_save_path = _directory.path_join("missing/checkpoint.json")
	var result := manager.purchase_expedition_technique("colere.root")
	assert_true(result.success)
	assert_false(result.saved)
	assert_string_contains(result.message, "Réessayez")
	var build := JSON.stringify(manager.expedition.build.to_snapshot())
	assert_eq(FileAccess.get_sha256(path), old_digest)
	manager.expedition_save_path = path
	assert_true(manager.retry_expedition_save())
	assert_eq(JSON.stringify(manager.expedition.build.to_snapshot()), build)
	assert_ne(FileAccess.get_sha256(path), old_digest)


func test_confirmed_child_pause_signal_retires_ui_without_freeing_its_emitter() -> void:
	for reason in [&"return_to_title", &"abandon"]:
		var manager := _manager(str(reason) + ".json", true)
		assert_true(manager.start_expedition(2401))
		var run_ui := manager.get_persistent_run_ui()
		var pause := run_ui.get_pause_menu()
		var old_id := run_ui.get_instance_id()
		pause.set("_pending_exit_reason", reason)
		pause.get_confirmation_dialog().confirmed.emit()
		assert_null(manager.get_persistent_run_ui())
		assert_true(is_instance_valid(run_ui), "The emitting subtree survives until the signal returns")
		assert_true(run_ui.is_queued_for_deletion())
		run_ui.unbind_combat_context() # A late battle exit must tolerate retirement.
		assert_false(manager.run_active)
		assert_eq(FileAccess.file_exists(manager.expedition_save_path), reason != &"abandon")
		await get_tree().process_frame
		assert_false(is_instance_id_valid(old_id))
		assert_false(get_tree().paused)


func test_failed_exit_from_child_signal_keeps_retry_feedback_visible() -> void:
	var manager := _manager("feedback.json", true)
	assert_true(manager.start_expedition(2401))
	var run_ui := manager.get_persistent_run_ui()
	manager.expedition_save_path = _directory.path_join("missing/checkpoint.json")
	run_ui.get_pause_menu().return_to_title_requested.emit(&"return_to_title")
	await get_tree().process_frame
	assert_same(manager.get_persistent_run_ui(), run_ui)
	assert_true(manager.run_active)
	assert_true(run_ui.get_node("ExpeditionSaveFeedback/ExpeditionSaveFailure").visible)
	assert_true(run_ui.get_node("ExpeditionSaveFeedback/RetryExpeditionSave").visible)
	assert_eq(manager.requested_scene, "")


func test_sanctuary_preparation_cannot_grant_services_and_combat_cannot_enter() -> void:
	var manager := _manager()
	var context := manager.get_sanctuary_context()
	assert_eq(context.mode, "preparation")
	assert_eq(context.balance, 0)
	assert_true(context.services.is_empty())
	assert_true(context.inventory.is_empty())
	assert_true(manager.open_sanctuary(manager.CHARACTER_SELECTION_SCREEN_PATH).success)
	assert_eq(manager.requested_scene, manager.SANCTUARY_SCREEN_PATH)
	assert_true(manager.return_from_sanctuary().success)
	assert_eq(manager.requested_scene, manager.CHARACTER_SELECTION_SCREEN_PATH)
	assert_true(manager.continue_from_sanctuary().success)
	assert_eq(manager.requested_scene, manager.CHARACTER_SELECTION_SCREEN_PATH)
	assert_true(manager.start_expedition(2401))
	context = manager.get_sanctuary_context()
	assert_eq(context.mode, "blocked")
	assert_false(context.departure_enabled)
	assert_false(manager.open_sanctuary().success)
	assert_true(context.services.is_empty())
	manager.cleanup_run_state()
	context = manager.get_sanctuary_context()
	assert_eq(context.departure_label, "Reprendre Catabase")
	assert_true(manager.continue_from_sanctuary().success)
	assert_eq(manager.run_seed, 2401)


func test_staying_after_exit_error_cancels_navigation_but_keeps_save_retry() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var path := manager.expedition_save_path
	manager.expedition_save_path = _directory.path_join("missing/checkpoint.json")
	assert_false(manager.request_return_to_title())
	manager.postpone_expedition_exit()
	manager.expedition_save_path = path
	assert_true(manager.retry_expedition_save())
	assert_true(manager.run_active)
	assert_eq(manager.requested_scene, "")
	assert_false(manager.get_expedition_save_status().pending)


func _advance_to_halt(manager: ReliabilityManager, failing_entry_path := "") -> void:
	for depth in range(1, 5):
		if depth > 1:
			var choices := manager.expedition.route.get_available_nodes()
			var selected: Dictionary = choices[0]
			for node in choices:
				if node.kind == "hub":
					selected = node
			if depth == 4 and not failing_entry_path.is_empty():
				manager.expedition_save_path = failing_entry_path
				assert_false(manager.choose_expedition_node(str(selected.id)))
			else:
				assert_true(manager.choose_expedition_node(str(selected.id)))
		if manager.expedition.route.phase == "combat":
			manager.begin_combat_report()
			manager.on_battle_won()
		if depth < 4:
			var options := manager.expedition.reward_options(manager.item_catalog)
			assert_true(manager.claim_expedition_reward(str(options.back().id)).success)
	assert_true(ExpeditionRouteCatalog.is_halt(str(manager.expedition.route.get_current_node().kind)))


func test_sanctuary_bridge_uses_real_currency_receipts_inventory_and_return_boundary() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	_advance_to_halt(manager)
	var context := manager.get_sanctuary_context()
	assert_eq(context.mode, "halt")
	assert_eq(context.balance, manager.expedition.gold)
	assert_eq(context.currency_label, "oboles")
	assert_eq(context.services, manager.expedition.hub_services(manager.item_catalog))
	assert_true(manager.open_sanctuary().success)
	assert_eq(manager.requested_scene, manager.SANCTUARY_SCREEN_PATH)
	var balance: int = manager.expedition.gold
	assert_true(manager.use_catabase_hub_service("lore").saved)
	assert_eq(manager.get_sanctuary_context().balance, balance + 20)
	assert_false(manager.use_catabase_hub_service("lore").success)
	var stock: Dictionary = context.services[0]
	assert_true(manager.use_catabase_hub_service(str(stock.id)).saved)
	context = manager.get_sanctuary_context()
	assert_true(context.inventory.any(func(item: Dictionary) -> bool: return item.item_id == stock.item_id and item.quantity == 1))
	assert_eq(manager.expedition.route.phase, "reward")
	assert_true(manager.return_from_sanctuary().success)
	assert_eq(manager.requested_scene, manager.EXPEDITION_SCREEN_PATH)
	assert_eq(manager.expedition.route.phase, "reward", "Return preserves the authored halt and its unclaimed departure")
	var node_id := manager.expedition.route.current_node_id
	var receipt := ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
	assert_true("lore" in receipt.session.hub_used_ids[node_id])
	assert_true(manager.continue_from_sanctuary().success)
	assert_eq(manager.expedition.route.phase, "map")
	assert_eq(manager.requested_scene, manager.EXPEDITION_SCREEN_PATH)
	assert_eq(ExpeditionSaveService.read_snapshot(manager.expedition_save_path).session.route.phase, "map")


func test_sanctuary_departure_write_failure_keeps_scene_and_retry_does_not_claim_twice() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	_advance_to_halt(manager)
	assert_true(manager.open_sanctuary().success)
	var path := manager.expedition_save_path
	manager.expedition_save_path = _directory.path_join("missing/checkpoint.json")
	var departure := manager.continue_from_sanctuary()
	assert_false(departure.success)
	assert_true(departure.applied)
	assert_eq(manager.requested_scene, manager.SANCTUARY_SCREEN_PATH)
	assert_eq(manager.expedition.route.phase, "map")
	var completed := manager.expedition.route.completed_node_ids.duplicate()
	manager.expedition_save_path = path
	assert_true(manager.retry_expedition_save())
	assert_eq(manager.requested_scene, manager.EXPEDITION_SCREEN_PATH)
	assert_eq(manager.expedition.route.completed_node_ids, completed)


func test_terminal_delete_retry_clears_feedback_and_cannot_leave_a_resumable_defeat() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var path := manager.expedition_save_path
	manager.expedition_save_path = _directory
	manager.begin_combat_report()
	manager.on_battle_lost()
	assert_true(manager.run_active)
	assert_eq(manager.get_expedition_save_status().operation, "finish_defeat")
	assert_eq(manager.requested_scene, "")
	manager.expedition_save_path = path
	assert_true(manager.retry_expedition_save())
	assert_false(manager.run_active)
	assert_false(manager.get_expedition_save_status().pending)
	assert_eq(manager.requested_scene, manager.RUN_RESULT_SCREEN_PATH)
	assert_false(FileAccess.file_exists(path))


func test_failed_halt_entry_retry_opens_the_applied_destination_without_awarding_twice() -> void:
	var manager := _manager()
	assert_true(manager.start_expedition(2401))
	var path := manager.expedition_save_path
	_advance_to_halt(manager, _directory.path_join("missing/checkpoint.json"))
	assert_eq(manager.expedition.route.phase, "reward")
	assert_eq(manager.get_expedition_save_status().operation, "open_destination")
	assert_true(manager.get_expedition_save_status().pending)
	assert_eq(ExpeditionSaveService.read_snapshot(path).session.route.phase, "map")
	var arrivals := manager.expedition.awarded_node_ids.duplicate()
	var gold := manager.expedition.gold
	manager.postpone_expedition_exit()
	assert_eq(manager.get_expedition_save_status().operation, "open_destination", "Staying keeps the already-applied arrival pending")
	manager.requested_scene = ""
	manager.expedition_save_path = path
	assert_true(manager.retry_expedition_save())
	assert_eq(manager.requested_scene, manager.EXPEDITION_SCREEN_PATH)
	assert_eq(manager.expedition.awarded_node_ids, arrivals)
	assert_eq(manager.expedition.gold, gold)
	assert_eq(ExpeditionSaveService.read_snapshot(path).session.route.phase, "reward")
