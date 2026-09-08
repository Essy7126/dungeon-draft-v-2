extends Node

## Three combat victories are explicit setup fixtures. Merchant transactions,
## scene routing, save failures/retries and UI visits use production code.
const HALL_PATH := "res://hub/merchant_hall/MerchantHall.tscn"
const MAP_PATH := "res://ui/expedition/ExpeditionScreen.tscn"
const OUTPUT_DIR := "res://artifacts/merchant_hall"
const STEP := 1.0 / 60.0

class HarnessManager:
	extends "res://core/game_manager.gd"
	var requested_battles := 0
	var requested_scenes: Array[String] = []
	func start_next_battle() -> void:
		_room_outcome_resolved = false
		requested_battles += 1
	func _request_scene_change(path: String, _mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT) -> void:
		requested_scenes.append(path)
	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null

var _root: Window
var _hall: Node
var _directory := ""
var _resolution := ""
var _capture_enabled := false
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _managers: Array[HarnessManager] = []
var _halt_snapshot: Dictionary = {}
var _user_save_hash := ""
var _started_ms := 0
var _movement_samples := 0
var _unsafe_movement_samples := 0
var _scene_requests: Array[String] = []


func _ready() -> void:
	_root = get_tree().root
	get_tree().current_scene = null
	_started_ms = Time.get_ticks_msec()
	_directory = OUTPUT_DIR.path_join("run_%d" % Time.get_ticks_usec())
	_capture_enabled = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_directory)
	_user_save_hash = ExpeditionSaveService.fingerprint(ExpeditionSaveService.SAVE_PATH)
	GameManager.expedition_save_path = _directory.path_join("unused_live_entry.json")
	GameManager.scene_change_requested.connect(func(path: String) -> void: _scene_requests.append(path))
	var methods: Array[StringName] = [&"is_merchant_hall_active", &"get_expedition_destination_scene", &"leave_merchant_hall", &"open_expedition_workshop"]
	var api_ready := true
	for method: StringName in methods:
		_check("manager_api_" + String(method), GameManager.has_method(method))
		api_ready = api_ready and GameManager.has_method(method)
	if api_ready:
		_test_routing_and_entry_retry()
		if not _halt_snapshot.is_empty():
			for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
				_root.size = size
				_resolution = "%dx%d" % [size.x, size.y]
				await _exercise_live_hall()
	for manager: HarnessManager in _managers:
		manager.cleanup_run_state()
		manager.queue_free()
	await _settle()
	_check("player_save_unchanged", ExpeditionSaveService.fingerprint(ExpeditionSaveService.SAVE_PATH) == _user_save_hash)
	_check("all_service_approach_steps_walkable", _movement_samples > 0 and _unsafe_movement_samples == 0, {"samples": _movement_samples, "unsafe": _unsafe_movement_samples})
	_write_report()
	for failure: String in _failures:
		push_error("MERCHANT_HALL_INTEGRATION: " + failure)
	print("MERCHANT_HALL_INTEGRATION: %s (%d checks; %d captures). %s/verification.json" % ["PASS" if _failures.is_empty() else "FAIL", _checks.size(), _captures.size(), OUTPUT_DIR])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _fixture(name: String) -> HarnessManager:
	var manager := HarnessManager.new()
	manager.expedition_save_path = _directory.path_join(name + ".json")
	add_child(manager)
	_managers.append(manager)
	_check(name + "_canonical_start", manager.start_expedition(2401))
	_check(name + "_opening_battle_unchanged", manager.requested_battles == 1 and manager.expedition.route.current_node_id == "d01_0")
	_check(name + "_combat_is_not_merchant_hall", not manager.call("is_merchant_hall_active"))
	for depth in range(1, 4):
		if depth > 1:
			var available := manager.expedition.route.get_available_nodes()
			if available.is_empty():
				_check(name + "_route_has_next_combat", false)
				return manager
			_check(name + "_choose_combat_%d" % depth, manager.choose_expedition_node(str(available[0].id)))
		_check(name + "_fixture_victory_%d" % depth, manager.expedition.combat_won())
		_check(name + "_claim_supplies_%d" % depth, bool(manager.claim_expedition_reward("supplies").get("success", false)))
	_check(name + "_three_real_combat_launch_requests", manager.requested_battles == 3)
	_check(name + "_merchant_reachable", manager.expedition.route.get_available_nodes().any(func(node: Dictionary) -> bool: return node.id == "d04_1" and node.kind == "merchant"))
	return manager


func _test_routing_and_entry_retry() -> void:
	var manager := _fixture("entry")
	var expected_nodes := ExpeditionRouteCatalog.create_nodes(2401)
	_check("authored_route_graph_unchanged", _json(manager.expedition.route.nodes) == _json(expected_nodes))
	var stock_before: Array = manager.expedition.hub_stock_ids.duplicate()
	_check("stock_empty_before_arrival", stock_before.is_empty())
	manager.requested_scenes.clear()
	_check("choose_d04_1_succeeds", manager.choose_expedition_node("d04_1"))
	_check("d04_1_is_only_merchant_hall", manager.call("is_merchant_hall_active") and manager.call("get_expedition_destination_scene") == HALL_PATH)
	_check("entry_requests_hall_scene", manager.requested_scenes == [HALL_PATH])
	_check("merchant_arrival_stays_reward", manager.expedition.route.phase == "reward" and manager.expedition.route.current_node_id == "d04_1")
	var stock: Array = manager.expedition.hub_stock_ids.duplicate()
	var services := manager.expedition.hub_services(manager.item_catalog)
	_check("three_fixed_merchant_items", stock.size() == 3 and services.size() == 5)
	for repeat in range(3):
		manager.expedition.hub_services(manager.item_catalog)
		manager.call("get_expedition_destination_scene")
	_check("inspection_does_not_reroll_stock", manager.expedition.hub_stock_ids == stock)
	_check("inspection_does_not_request_transition", manager.requested_scenes == [HALL_PATH])
	manager.expedition.character.unit.current_hp = maxi(1, manager.expedition.character.unit.max_hp.get_int() - 45)
	_check("fixture_hurt_state_saved", manager.save_expedition())
	_halt_snapshot = manager.get_expedition_snapshot().duplicate(true)
	var restored := HarnessManager.new()
	restored.expedition_save_path = manager.expedition_save_path
	add_child(restored)
	_managers.append(restored)
	_check("reward_save_resumes", restored.resume_expedition())
	_check("reward_resume_routes_hall", restored.requested_scenes == [HALL_PATH])
	_check("resume_retains_same_stock", restored.expedition.hub_stock_ids == stock)

	var failed := _fixture("failed_entry")
	var good_path := failed.expedition_save_path
	var committed := FileAccess.get_sha256(good_path)
	failed.expedition_save_path = _directory.path_join("missing_entry/checkpoint.json")
	failed.requested_scenes.clear()
	_check("entry_write_failure_blocks_transition", not failed.choose_expedition_node("d04_1") and failed.requested_scenes.is_empty())
	_check("failed_entry_keeps_previous_checkpoint", FileAccess.get_sha256(good_path) == committed)
	var applied_arrivals := failed.expedition.awarded_node_ids.duplicate()
	var applied_gold := failed.expedition.gold
	var applied_stock := failed.expedition.hub_stock_ids.duplicate()
	_check("failed_entry_reports_pending", bool(failed.get_expedition_save_status().pending))
	failed.expedition_save_path = good_path
	_check("entry_retry_succeeds", failed.retry_expedition_save())
	_check("entry_retry_opens_hall_once", failed.requested_scenes == [HALL_PATH])
	_check("entry_retry_has_no_second_award_or_roll", failed.expedition.awarded_node_ids == applied_arrivals and failed.expedition.gold == applied_gold and failed.expedition.hub_stock_ids == applied_stock)

	var other := _fixture("other_halt")
	for node: Dictionary in other.expedition.route.get_available_nodes():
		if node.id != "d04_1":
			_check("other_first_halt_entered", other.choose_expedition_node(str(node.id)))
			break
	_check("other_halt_uses_existing_screen", not other.call("is_merchant_hall_active") and other.call("get_expedition_destination_scene") == MAP_PATH)
	for depth in range(4, 8):
		var claim := "leave_hub" if ExpeditionRouteCatalog.is_halt(str(other.expedition.route.get_current_node().kind)) else "supplies"
		_check("other_route_claim_%d" % depth, bool(other.claim_expedition_reward(claim).get("success", false)))
		var available := other.expedition.route.get_available_nodes()
		var next_id := "d08_1" if depth == 7 else str(available[0].id)
		_check("other_route_enter_%s" % next_id, other.choose_expedition_node(next_id))
		if other.expedition.route.phase == "combat":
			_check("other_route_fixture_victory", other.expedition.combat_won())
	_check("later_merchant_preserves_existing_destination", other.expedition.route.get_current_node().kind == "merchant" and not other.call("is_merchant_hall_active") and other.call("get_expedition_destination_scene") == MAP_PATH)


func _exercise_live_hall() -> void:
	var save_path := _directory.path_join("live_" + _resolution + ".json")
	_check("write_isolated_halt_fixture", ExpeditionSaveService.write_snapshot(_halt_snapshot, save_path))
	GameManager.expedition_save_path = save_path
	_check("live_resume_halt", GameManager.resume_expedition())
	if not await _wait_scene(HALL_PATH):
		return
	_hall = get_tree().current_scene
	if not await _wait_hall_ready():
		return
	_hall.set_process(false)
	await _capture("merchant_arrival")
	var original_stock := GameManager.expedition.hub_stock_ids.duplicate()
	var offers := GameManager.expedition.hub_services(GameManager.item_catalog)
	if offers.is_empty():
		_check("live_stock_available", false)
		return
	var offer: Dictionary = offers[0]
	var offer_id := str(offer.id)
	var gold_before := GameManager.expedition.gold
	var item_before := _item_count(str(offer.item_id))
	if not await _open_service(offer_id):
		return
	await _capture("shop_before_purchase")
	_check("modal_blocks_world_move", not bool(_hall.call("request_move", Vector2(646, 628))))
	var digest_before := FileAccess.get_sha256(save_path)
	GameManager.expedition_save_path = _directory.path_join("missing_purchase_" + _resolution + "/checkpoint.json")
	var bought: Dictionary = _hall.call("activate_selected_service")
	_check("purchase_applied_with_save_failure", bool(bought.get("success", false)) and not bool(bought.get("saved", true)), bought)
	_check("purchase_debits_once", GameManager.expedition.gold == gold_before - int(offer.cost))
	_check("purchase_grants_one_item", _item_count(str(offer.item_id)) == item_before + 1)
	_check("failed_purchase_preserves_disk", FileAccess.get_sha256(save_path) == digest_before)
	_check("failed_purchase_pending", bool(GameManager.get_expedition_save_status().pending))
	await _capture("purchase_save_failure")
	var applied: Variant = _json(GameManager.get_expedition_snapshot())
	_check("pending_purchase_cannot_reapply", not bool((_hall.call("activate_selected_service") as Dictionary).get("success", false)))
	_check("pending_duplicate_preserves_economy", _json(GameManager.get_expedition_snapshot()) == applied)
	GameManager.expedition_save_path = save_path
	_check("purchase_save_retry", GameManager.retry_expedition_save())
	_check("purchase_retry_no_second_charge_or_item", _json(GameManager.get_expedition_snapshot()) == applied)
	_check("purchase_receipt_unique", _receipt_count(offer_id) == 1)
	await _capture("purchase_saved")
	_hall.call("close_service_panel")

	var hp_before := GameManager.expedition.character.unit.current_hp
	var max_hp := GameManager.expedition.character.unit.max_hp.get_int()
	gold_before = GameManager.expedition.gold
	if await _open_service("rest"):
		await _capture("rest_confirmation")
		var confirm := _hall.find_child("ConfirmService", true, false) as Button
		_check("rest_confirm_button_visible", confirm != null and confirm.is_visible_in_tree() and not confirm.disabled)
		if confirm != null and not confirm.disabled:
			await _click_button(confirm)
		_check("rest_charges_45_oboles", GameManager.expedition.gold == gold_before - 45)
		_check("rest_heals_exact_30_percent", GameManager.expedition.character.unit.current_hp == mini(max_hp, hp_before + roundi(max_hp * 0.3)))
		_check("rest_receipt_unique", _receipt_count("rest") == 1)
		_check("rest_not_repeatable", not bool(GameManager.use_catabase_hub_service("rest").get("success", false)))
		_hall.call("close_service_panel")
	gold_before = GameManager.expedition.gold
	var revealed_before := GameManager.expedition.route.revealed_node_ids.size()
	if await _open_service("lore"):
		var lore: Dictionary = _hall.call("activate_selected_service")
		_check("lore_succeeds_and_saves", bool(lore.get("success", false)) and bool(lore.get("saved", false)))
		_check("lore_awards_exact_20", GameManager.expedition.gold == gold_before + 20)
		_check("lore_reveals_one_secret", GameManager.expedition.route.revealed_node_ids.size() == revealed_before + 1)
		_check("lore_receipt_unique", _receipt_count("lore") == 1)
		var after_lore: Variant = _json(GameManager.get_expedition_snapshot())
		_check("lore_not_repeatable", not bool((_hall.call("activate_selected_service") as Dictionary).get("success", false)))
		_check("duplicate_lore_has_no_effect", _json(GameManager.get_expedition_snapshot()) == after_lore)
		await _capture("lore_used")
		_hall.call("close_service_panel")
	_check("all_services_stay_on_halt", GameManager.expedition.route.phase == "reward" and GameManager.expedition.route.current_node_id == "d04_1")
	_check("visiting_services_keeps_stock", GameManager.expedition.hub_stock_ids == original_stock)
	var saved_state: Variant = _json(GameManager.get_expedition_snapshot())
	_check("transactions_persist_complete_state", _json(ExpeditionSaveService.read_snapshot(save_path)) == saved_state)
	_check("reopen_saved_hall", GameManager.resume_expedition())
	if not await _wait_scene(HALL_PATH, _hall):
		return
	_hall = get_tree().current_scene
	if not await _wait_hall_ready():
		return
	_hall.set_process(false)
	_check("restore_keeps_stock_receipts_gold_hp_inventory", _json(GameManager.get_expedition_snapshot()) == saved_state)
	_check("restored_purchase_stays_used", not bool(GameManager.use_catabase_hub_service(offer_id).get("success", false)))
	await _capture("restored_hall")
	await _exercise_inspection_and_workshop()
	await _exercise_departure_retry(save_path)
	if _resolution == "1920x1080":
		await _exercise_other_save_recovery(saved_state as Dictionary)


func _exercise_inspection_and_workshop() -> void:
	var before_scene := get_tree().current_scene
	var before_snapshot: Variant = _json(GameManager.get_expedition_snapshot())
	var inspection: Node = load(MAP_PATH).instantiate()
	inspection.set("inspection_only", true)
	_root.add_child(inspection)
	await _settle()
	_check("inspection_does_not_redirect_or_consume_halt", get_tree().current_scene == before_scene and _json(GameManager.get_expedition_snapshot()) == before_snapshot)
	await _capture("map_inspection")
	inspection.queue_free()
	await _settle()
	_check("workshop_opens_explicitly", GameManager.call("open_expedition_workshop"))
	if not await _wait_scene(MAP_PATH):
		return
	_check("workshop_preserves_unclaimed_halt", GameManager.expedition.route.phase == "reward" and _json(GameManager.get_expedition_snapshot()) == before_snapshot)
	await _capture("workshop")
	var return_button := get_tree().current_scene.find_child("EnterMerchantHall", true, false) as Button
	_check("workshop_return_button_available", return_button != null and return_button.is_visible_in_tree() and not return_button.disabled)
	if return_button != null and not return_button.disabled:
		await _click_button(return_button)
	else:
		# Preserve the remaining save-failure coverage after a missing UI control.
		GameManager.resume_expedition()
	if await _wait_scene(HALL_PATH):
		_hall = get_tree().current_scene
		if await _wait_hall_ready():
			_hall.set_process(false)
			_check("workshop_return_preserves_economy", _json(GameManager.get_expedition_snapshot()) == before_snapshot)


func _exercise_departure_retry(save_path: String) -> void:
	if not is_instance_valid(_hall) or get_tree().current_scene != _hall:
		_check("hall_available_before_departure", false)
		return
	var saved_reward := FileAccess.get_sha256(save_path)
	var transition_start := _scene_requests.size()
	GameManager.expedition_save_path = _directory.path_join("missing_departure_" + _resolution + "/checkpoint.json")
	var result: Dictionary = GameManager.call("leave_merchant_hall")
	_check("departure_failure_blocks_transition", not bool(result.get("success", false)) and bool(result.get("applied", false)) and get_tree().current_scene == _hall, result)
	_check("departure_failure_preserves_reward_checkpoint", FileAccess.get_sha256(save_path) == saved_reward)
	_check("departure_applied_once_in_memory", GameManager.expedition.route.phase == "map")
	var committed_nodes := GameManager.expedition.route.completed_node_ids.duplicate()
	var economy: Variant = _json(GameManager.get_expedition_snapshot())
	await _capture("departure_save_failure")
	_check("pending_departure_cannot_reapply", not bool((GameManager.call("leave_merchant_hall") as Dictionary).get("success", false)))
	_check("pending_departure_preserves_state", _json(GameManager.get_expedition_snapshot()) == economy)
	GameManager.expedition_save_path = save_path
	_check("departure_retry_succeeds", GameManager.retry_expedition_save())
	if not await _wait_scene(MAP_PATH):
		return
	_hall = null
	_check("normal_departure_retry_requests_one_transition", _scene_requests.slice(transition_start) == [MAP_PATH])
	_check("departure_retry_no_second_claim", GameManager.expedition.route.completed_node_ids == committed_nodes and _json(GameManager.get_expedition_snapshot()) == economy)
	_check("departure_commits_map_phase", str(ExpeditionSaveService.read_snapshot(save_path).session.route.phase) == "map")
	var available := GameManager.expedition.route.get_available_nodes()
	_check("route_continues_at_depth_five", not available.is_empty() and available.all(func(node: Dictionary) -> bool: return int(node.depth) == 5))
	_check("merchant_no_longer_active_after_departure", not GameManager.call("is_merchant_hall_active"))
	await _capture("map_depth_five")


func _exercise_other_save_recovery(before_departure: Dictionary) -> void:
	# Restore the already-tested merchant receipts rather than replaying combat
	# or purchases. This reproduces an unrelated successful inventory-style save
	# after departure has been applied but its first disk write failed.
	var good_path := _directory.path_join("other_save_recovery.json")
	_check("recovery_fixture_keeps_existing_receipts", ExpeditionSaveService.write_snapshot(before_departure, good_path))
	GameManager.expedition_save_path = good_path
	_check("recovery_resume_reward", GameManager.resume_expedition())
	if not await _wait_scene(HALL_PATH):
		return
	_hall = get_tree().current_scene
	if not await _wait_hall_ready():
		return
	_hall.set_process(false)
	var transition_start := _scene_requests.size()
	GameManager.expedition_save_path = _directory.path_join("missing_other_save/checkpoint.json")
	var departure: Dictionary = GameManager.call("leave_merchant_hall")
	_check("other_save_departure_initially_fails", not bool(departure.get("success", false)) and bool(departure.get("applied", false)))
	var applied: Variant = _json(GameManager.get_expedition_snapshot())
	await _settle()
	var persistent := GameManager.get_persistent_run_ui()
	var dialog := persistent.get("_save_failure_dialog") as ConfirmationDialog if persistent != null else null
	_check("other_save_error_dialog_present", dialog != null and dialog.visible)
	if dialog != null:
		dialog.hide()
		dialog.canceled.emit()
	GameManager.expedition_save_path = good_path
	_check("unrelated_save_succeeds", GameManager.save_expedition())
	if not await _wait_scene(MAP_PATH):
		return
	_hall = null
	_check("unrelated_save_recovers_exactly_one_transition", _scene_requests.slice(transition_start) == [MAP_PATH], _scene_requests.slice(transition_start))
	_check("unrelated_save_does_not_reapply_departure_or_receipts", _json(GameManager.get_expedition_snapshot()) == applied)
	_check("unrelated_save_commits_map", _json(ExpeditionSaveService.read_snapshot(good_path)) == applied)
	_check("unrelated_save_leaves_no_pending_error", not bool(GameManager.get_expedition_save_status().pending))
	await _capture("map_after_other_save_recovery")


func _open_service(id: String) -> bool:
	var before: Vector2 = _hall.call("get_player_position")
	var accepted := bool(_hall.call("request_service", id))
	_check("request_service_" + id, accepted)
	_check("service_approach_does_not_teleport_" + id, (_hall.call("get_player_position") as Vector2).distance_to(before) < 0.01)
	if not accepted:
		return false
	var nav: RefCounted = _hall.call("get_navigation_service")
	for step in range(3000):
		if bool(_hall.call("is_service_panel_open")):
			_check("selected_service_" + id, str(_hall.call("get_selected_service_id")) == id)
			await _settle()
			return true
		_hall.call("advance_world", STEP)
		_movement_samples += 1
		if not bool(nav.call("is_walkable", _hall.call("get_player_position"))):
			_unsafe_movement_samples += 1
		if step % 120 == 0:
			await get_tree().process_frame
	_check("service_panel_arrives_" + id, false)
	return false


func _wait_hall_ready() -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while is_instance_valid(_hall) and not bool(_hall.call("is_ready_for_play")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ready := is_instance_valid(_hall) and bool(_hall.call("is_ready_for_play"))
	_check("merchant_hall_ready", ready)
	return ready


func _wait_scene(path: String, previous: Node = null) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path and (not is_instance_valid(previous) or scene != previous):
			await _settle()
			return true
	_check("scene_transition_" + path.get_file(), false)
	return false


func _item_count(item_id: String) -> int:
	var count := 0
	for item: ItemInstance in GameManager.run_inventory.get_slots():
		if item != null and str(item.definition_id) == item_id:
			count += item.quantity
	return count


func _receipt_count(service_id: String) -> int:
	var receipts: Array = GameManager.expedition.hub_used_ids.get("d04_1", [])
	return receipts.count(service_id)


func _click_button(button: Button) -> void:
	await _settle()
	var position := button.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.position = position
	release.global_position = position
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await _settle()


func _capture(label: String) -> void:
	if not _capture_enabled:
		return
	await _settle()
	await RenderingServer.frame_post_draw
	var image := _root.get_texture().get_image()
	var path := _directory.path_join(_resolution + "_" + label + ".png")
	var error := image.save_png(ProjectSettings.globalize_path(path)) if image != null and not image.is_empty() else ERR_CANT_CREATE
	_check("capture_" + label, error == OK)
	_check("capture_size_" + label, image != null and image.get_size() == _root.size)
	_captures.append({"label": label, "resolution": _resolution, "path": path, "saved": error == OK})


func _settle() -> void:
	for frame in range(3):
		await get_tree().process_frame


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _check(id: String, passed: bool, details: Variant = null) -> void:
	_checks.append({"id": id, "resolution": _resolution, "passed": passed, "details": details})
	if not passed:
		_failures.append("%s [%s]" % [id, _resolution])


func _write_report() -> void:
	var report := {"scene": HALL_PATH, "created_utc": Time.get_datetime_string_from_system(true),
		"elapsed_ms": Time.get_ticks_msec() - _started_ms, "godot_version": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(), "rendering_method": RenderingServer.get_current_rendering_method(),
		"capture_enabled": _capture_enabled, "passed": _failures.is_empty(), "checks": _checks,
		"check_count": _checks.size(), "failures": _failures, "captures": _captures,
		"movement_samples": _movement_samples, "unsafe_movement_samples": _unsafe_movement_samples,
		"isolated_checkpoint_directory": _directory,
		"method": "Canonical run uses three explicit Session.combat_won setup outcomes. Harness intercepts combat and scene dispatch to inspect routing and failed-entry retries. Then the real autoload GameManager restores isolated checkpoints and opens the production MerchantHall scene at 1280x720/1920x1080. Services use real approach paths, modal state and economy; rest confirmation uses mouse input. Invalid save directories inject purchase/departure failures. Retries are checked against exact committed inventory, health, gold and receipts. Player save fingerprint is unchanged. Shader/occlusion validation remains the dedicated Hall probes' responsibility."}
	var file := FileAccess.open(OUTPUT_DIR.path_join("verification.json"), FileAccess.WRITE)
	if file == null:
		_failures.append("Cannot write verification.json")
		return
	file.store_string(JSON.stringify(report, "\t"))
