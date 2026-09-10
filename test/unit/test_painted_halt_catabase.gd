extends GutTest
## Real saved session under an isolated manager; scene transitions are observed.
const BRIDGE := preload("res://hub/painted_halt/halt_session_bridge.gd")


class HaltManager extends "res://core/game_manager.gd":
	var requested_scene := ""


	func start_next_battle() -> void:
		_room_outcome_resolved = false


	func _request_scene_change(
		path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		requested_scene = path


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


class HaltScreenSpy extends "res://hub/painted_halt/expedition_halt.gd":
	var recovery_requests := 0


	func _ready() -> void:
		# Exercise only scene ownership; never bind the live singleton or paint.
		set_process(false)


	func _recover_saved_destination() -> void:
		recovery_requests += 1


var _managers: Array[HaltManager] = []
var _screens: Array[HaltScreenSpy] = []
var _original_scene: Node
var _directory := ""


func before_each() -> void:
	_original_scene = get_tree().current_scene
	_directory = "res://artifacts/dev/halt-catabase-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_directory)


func after_each() -> void:
	get_tree().current_scene = _original_scene
	for screen: HaltScreenSpy in _screens:
		screen.queue_free()
	_screens.clear()
	for manager in _managers:
		manager.cleanup_run_state()
		manager.queue_free()
	_managers.clear()
	await get_tree().process_frame


func _manager(file := "checkpoint.json") -> HaltManager:
	var manager := HaltManager.new()
	manager.expedition_save_path = _directory.path_join(file)
	add_child(manager)
	_managers.append(manager)
	return manager


func _advance(manager: HaltManager, kind: String) -> void:
	assert_true(manager.start_expedition(2401))
	for depth in range(1, 9):
		if depth > 1:
			var choices := manager.expedition.route.get_available_nodes()
			var selected: Dictionary = choices[0]
			if depth == 8:
				for node: Dictionary in choices:
					if str(node.kind) == kind:
						selected = node
			assert_true(manager.choose_expedition_node(str(selected.id)))
		if manager.expedition.route.phase == "combat":
			manager.begin_combat_report()
			manager.on_battle_won()
		if depth < 8:
			var options := manager.expedition.reward_options(manager.item_catalog)
			assert_true(manager.claim_expedition_reward(str(options.back().id)).success)
	# Allocate any outstanding attributes through the actual progression API.
	var progression := manager.expedition.character.champion_progression
	while progression.unspent_attribute_points > 0:
		var before: int = progression.unspent_attribute_points
		assert_true(manager.spend_champion_attribute(&"achilles", &"vitality"))
		if progression.unspent_attribute_points == before:
			break


func test_bound_halt_services_and_return_survive_real_checkpoint() -> void:
	var manager := _manager()
	_advance(manager, "merchant")
	assert_eq(str(manager.expedition.route.get_current_node().kind), "merchant")
	# The guard must route outstanding progression before any painted halt.
	assert_eq(manager.expedition.character.champion_progression.unspent_attribute_points, 0)
	assert_true(manager.is_painted_halt_active())
	assert_true(manager.get_painted_halt_manifest().ends_with("bronze_forge_v1.json"))
	assert_true(manager.open_painted_halt())
	assert_eq(manager.requested_scene, manager.PAINTED_HALT_SCREEN_PATH)
	var bridge := BRIDGE.new()
	bridge.configure(false, manager)
	var gold := manager.expedition.gold
	var offer: Dictionary = manager.expedition.hub_services(manager.item_catalog)[0]
	assert_true(str(offer.id).begins_with("buy:"))
	assert_true(bridge.use_service(str(offer.id)).success)
	assert_eq(manager.expedition.gold, gold - int(offer.cost))
	assert_false(bridge.use_service(str(offer.id)).success)
	var node_id := manager.expedition.route.current_node_id
	var snapshot := ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
	assert_true(snapshot.session.hub_used_ids[node_id].has(str(offer.id)))
	assert_true(manager.open_expedition_workshop())
	assert_eq(manager.requested_scene, manager.EXPEDITION_SCREEN_PATH)
	assert_true(manager.open_painted_halt())
	assert_eq(manager.requested_scene, manager.PAINTED_HALT_SCREEN_PATH)
	var resume := _manager("resume.json")
	assert_true(ExpeditionSaveService.write_snapshot(snapshot, resume.expedition_save_path))
	assert_true(resume.resume_expedition())
	assert_eq(resume.expedition.route.current_node_id, node_id)
	assert_eq(resume.requested_scene, resume.PAINTED_HALT_SCREEN_PATH)
	assert_false(resume.use_catabase_hub_service(str(offer.id)).success)


func test_sanctuary_departure_failure_is_applied_once_then_retry_finishes_exit() -> void:
	var manager := _manager()
	_advance(manager, "sanctuary")
	assert_eq(manager.expedition.character.champion_progression.unspent_attribute_points, 0)
	assert_true(manager.get_painted_halt_manifest().ends_with("emerald_sanctuary_v1.json"))
	assert_true(manager.open_painted_halt())
	var bridge := BRIDGE.new()
	bridge.configure(false, manager)
	var path := manager.expedition_save_path
	manager.expedition_save_path = _directory.path_join("missing/checkpoint.json")
	var result := bridge.leave()
	assert_false(result.success)
	assert_true(result.get("applied", false))
	assert_eq(manager.expedition.route.phase, "map")
	assert_eq(manager.requested_scene, manager.PAINTED_HALT_SCREEN_PATH)
	assert_false(bridge.leave().success)
	manager.expedition_save_path = path
	assert_true(bridge.retry_save().success)
	assert_eq(manager.requested_scene, manager.EXPEDITION_SCREEN_PATH)
	assert_eq(ExpeditionSaveService.read_snapshot(path).session.route.phase, "map")


func _screen() -> HaltScreenSpy:
	var screen := HaltScreenSpy.new()
	get_tree().root.add_child(screen)
	_screens.append(screen)
	return screen


func test_saved_departure_recovery_does_not_reopen_from_replaced_scene() -> void:
	var departing := _screen()
	var replacement := _screen()
	get_tree().current_scene = departing
	departing._return_queued = true
	# The coroutine starts now, then the normal transition wins before its guard.
	departing._return_to_map()
	get_tree().current_scene = replacement
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(departing.recovery_requests, 0)
	assert_false(departing._return_queued)


func test_saved_departure_recovery_runs_only_while_halt_stays_current() -> void:
	var screen := _screen()
	get_tree().current_scene = screen
	screen._return_queued = true
	screen._return_to_map()
	assert_eq(screen.recovery_requests, 0, "Recovery must give the normal transition one frame.")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(screen.recovery_requests, 1)
	assert_false(screen._return_queued)
