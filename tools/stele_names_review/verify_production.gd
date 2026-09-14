extends "res://tools/halt_workshop/verify_production_halt.gd"
## The common production harness supplies scene waits, captures and HUD checks.
## This route-specific probe uses the real singleton and never grants its own reward.
const RouteFixture := preload("res://tools/run_explorer/route_explorer_fixture.gd")
const TARGET := "d04_2"
const TARGET_TITLE := "La stèle des noms"
const MANIFEST := "res://data/halts/stele_names_v1.json"
var journeys: Array[Dictionary] = []
var resolutions: Array[String] = []
var _finishing := false
var _baseline_gold := 0
var _baseline_hp := 0
var _baseline_completed := 0
var _before_secrets: Array = []
var _after_secrets: Array = []


func _run() -> void:
	kind = "lore"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--production-output="):
			output = argument.trim_prefix("--production-output=").replace("\\", "/").trim_suffix(
				"/"
			)
	var artifacts := ProjectSettings \
			.globalize_path("res://artifacts/dev/") \
			.replace("\\", "/") \
			.to_lower()
	var user_data := OS.get_user_data_dir().replace("\\", "/").to_lower()
	var isolated := (
		not output.is_empty() and output.to_lower().begins_with(artifacts)
		and user_data.begins_with(output.to_lower() + "/userdata/")
	)
	if not isolated:
		push_error("Stele probe requires verify.ps1 and isolated user data below artifacts/dev.")
		get_tree().quit(2)
		return
	_check("isolated_user_data", isolated, user_data)
	_check("rendered_backend", DisplayServer.get_name() != "headless")
	manager = get_tree().root.get_node("GameManager")
	_check(
		"singleton_starts_without_live_run",
		not manager.run_active and manager.expedition == null,
	)
	if manager.run_active or manager.expedition != null:
		await _finish()
		return
	var snapshot := _fixture_snapshot()
	_check("fixture_snapshot_complete", not snapshot.is_empty())
	if snapshot.is_empty():
		await _finish()
		return
	manager.expedition_save_path = output.path_join("production_checkpoint.json")
	var restored: bool = manager.restore_expedition_snapshot(snapshot)
	_check("restore_real_singleton", restored)
	if not restored or manager.expedition == null:
		await _finish()
		return
	node_id = manager.expedition.route.current_node_id
	var current: Dictionary = manager.expedition.route.get_current_node()
	_check(
		"real_route_identity",
		node_id == TARGET and str(current.get("title", "")) == TARGET_TITLE
		and int(current.get("depth", -1)) == 4 and str(current.get("kind", "")) == "lore",
		current,
	)
	_check("real_route_reward_phase", manager.expedition.route.phase == "reward")
	_check("dedicated_manifest_binding", manager.get_painted_halt_manifest() == MANIFEST)
	_baseline_gold = manager.expedition.gold
	_baseline_hp = manager.expedition.character.unit.current_hp
	_baseline_completed = manager.expedition.route.completed_node_ids.size()
	_before_secrets = manager.expedition.route.revealed_node_ids.duplicate()
	_check("lore_initially_unused", _receipt_count() == 0)
	manager.scene_change_requested.connect(_scene_requested)
	# Preserve this runner as a sibling while GameManager replaces actual scenes.
	get_tree().current_scene = null
	_check("open_production_halt", manager.open_painted_halt())
	if not await _enter_hall():
		await _finish()
		return
	_check("production_not_preview", not hall.preview_mode and not hall.interactions.bridge.preview)
	_check("production_manifest_binding", hall.manifest_path == MANIFEST)
	var landmarks: Array = hall.definition.get("landmarks", [])
	_check("two_authored_landmarks", landmarks.size() == 2, landmarks)
	if landmarks.size() != 2:
		await _finish()
		return
	_check("stele_is_lore_landmark", str(landmarks[0].get("action", "")) == "dialogue")
	_check(
		"stele_has_lore_description",
		not str(landmarks[0].get("description", "")).strip_edges().is_empty(),
	)
	_check("boat_is_exit_landmark", str(landmarks[1].get("action", "")) == "exit")
	var persistent: PersistentRunUI = manager.get_persistent_run_ui()
	_check(
		"persistent_ui_real_non_combat",
		persistent != null and manager.get_run_ui_mode() == PersistentRunUI.RunUIMode.NON_COMBAT,
	)
	await _resize(Vector2i(1920, 1080))
	await _capture("production_1080p")
	await _resize(Vector2i(1280, 720))
	_check_hud_in_view()
	await _capture("production_720p")
	if not _travel(0, "spawn_to_stele"):
		await _finish()
		return
	_check(
		"production_services_preserved",
		hall.interactions.bridge.context().services == manager.get_sanctuary_context().services,
	)
	var lore := _button(hall, "Service_lore")
	_check("lore_available_on_arrival", lore != null and not lore.disabled)
	await _capture("stele_dialogue_720p")
	await _resize(Vector2i(1920, 1080))
	await _capture("stele_dialogue_1080p")
	await _press(_button(hall, "Service_lore"), "read_names")
	_after_secrets = manager.expedition.route.revealed_node_ids.duplicate()
	_check("lore_grants_exactly_twenty_oboles", int(manager.expedition.gold) == _baseline_gold + 20)
	_check("lore_preserves_hp", int(manager.expedition.character.unit.current_hp) == _baseline_hp)
	_check("lore_records_one_receipt", _receipt_count() == 1)
	_check_secret_reveal()
	var checkpoint: Dictionary = ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
	_check_checkpoint(checkpoint, "after_reading", "reward")
	await _capture("stele_lore_receipt")
	await _press(_button(hall, "CloseHaltInteraction"), "close_stele")
	_check("modal_closed", not hall.interactions.active)
	if not _travel(0, "reopen_stele"):
		await _finish()
		return
	await _check_used_lore("reopen")
	await _press(_button(hall, "CloseHaltInteraction"), "close_before_checkpoint_reload")
	await _press(_button(hall, "Parchemin", true), "open_parchment")
	if not await _wait_scene(str(manager.EXPEDITION_SCREEN_PATH)):
		await _finish()
		return
	# Read the saved transaction through the actual resume boundary. No snapshot edits.
	_check("resume_saved_halt", manager.resume_expedition(manager.expedition_save_path))
	if not await _enter_hall():
		await _finish()
		return
	_check(
		"restored_route_and_manifest",
		manager.expedition.route.current_node_id == TARGET and hall.manifest_path == MANIFEST,
	)
	_check("restored_real_bridge", not hall.interactions.bridge.preview)
	_check(
		"restored_reward_once",
		int(manager.expedition.gold) == _baseline_gold + 20 and _receipt_count() == 1,
	)
	_check("restored_secret", manager.expedition.route.revealed_node_ids == _after_secrets)
	await _capture("production_resumed")
	if not _travel(0, "resumed_spawn_to_stele"):
		await _finish()
		return
	await _check_used_lore("checkpoint_reload")
	await _press(_button(hall, "CloseHaltInteraction"), "close_before_boat")
	if not _travel(1, "stele_to_boat"):
		await _finish()
		return
	await _capture("boat_departure_dialogue")
	await _press(_button(hall, "LeavePaintedHalt"), "board_boat")
	if not await _wait_scene(str(manager.EXPEDITION_SCREEN_PATH)):
		await _finish()
		return
	for frame in 4:
		await get_tree().process_frame
	checkpoint = ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
	_check_checkpoint(checkpoint, "after_departure", "map")
	_check("departure_enters_map_phase", manager.expedition.route.phase == "map")
	_check(
		"halt_completed_exactly_once",
		manager.expedition.route.completed_node_ids.count(TARGET) == 1
		and manager.expedition.route.completed_node_ids.size() == _baseline_completed + 1,
	)
	_check(
		"no_duplicate_scene_transition",
		transitions
		== [
			str(manager.PAINTED_HALT_SCREEN_PATH),
			str(manager.EXPEDITION_SCREEN_PATH),
			str(manager.PAINTED_HALT_SCREEN_PATH),
			str(manager.EXPEDITION_SCREEN_PATH),
		],
		transitions,
	)
	await _capture("production_departed")
	await _finish()


func _fixture_snapshot() -> Dictionary:
	return RouteFixture.prepare(
		self,
		2401,
		TARGET,
		ProjectSettings.localize_path(output.path_join("fixture_checkpoint.json")),
	)


func _enter_hall() -> bool:
	if not await _wait_scene(str(manager.PAINTED_HALT_SCREEN_PATH)):
		return false
	hall = get_tree().current_scene as Node2D
	if not await _wait_hall():
		return false
	hall.set_process(false)
	return true


func _resize(size: Vector2i) -> void:
	get_window().size = size
	for frame in 3:
		await get_tree().process_frame
	var actual := get_viewport().get_visible_rect().size
	var label := "%dx%d" % [size.x, size.y]
	_check("viewport_" + label, actual == Vector2(size), str(actual))
	if label not in resolutions:
		resolutions.append(label)


func _travel(index: int, label: String) -> bool:
	var landmark: Dictionary = hall.definition.landmarks[index]
	var destination: Vector2 = hall.point(landmark.point)
	var focus: Vector2 = hall.point(landmark.get("focus", landmark.point))
	_check(label + "_click_target", hall.interactions.hit_test(focus) == index)
	var start: Vector2 = hall.player.position
	var accepted: bool = hall.interactions.request(index)
	_check(label + "_request", accepted)
	if not accepted:
		return false
	var travelled := 0.0
	var steps := 0
	var stayed_on_floor: bool = hall.nav.is_walkable(start)
	for step in 3600:
		var previous: Vector2 = hall.player.position
		hall.advance_world(1.0 / 60.0)
		travelled += previous.distance_to(hall.player.position)
		stayed_on_floor = stayed_on_floor and hall.nav.is_walkable(hall.player.position)
		steps += 1
		if hall.interactions.active:
			break
	var arrived: bool = (
		hall.interactions.active and hall.interactions.selected == index
		and hall.player.position.distance_to(destination) < 2.0
	)
	var journey := {
		"id": label,
		"landmark": str(landmark.id),
		"arrived": arrived,
		"start": [start.x, start.y],
		"destination": [destination.x, destination.y],
		"arrival": [hall.player.position.x, hall.player.position.y],
		"distance": travelled,
		"simulated_seconds": steps / 60.0,
		"stayed_on_floor": stayed_on_floor,
	}
	journeys.append(journey)
	_check(label + "_arrival", arrived, journey)
	_check(label + "_stays_on_authored_floor", stayed_on_floor)
	_check(label + "_movement_complete", not hall.is_player_moving())
	return arrived


func _receipt_count() -> int:
	var receipts: Array = manager.expedition.hub_used_ids.get(TARGET, [])
	return receipts.count("lore")


func _check_secret_reveal() -> void:
	var revealed: Array = []
	for id: String in _after_secrets:
		if id not in _before_secrets:
			revealed.append(id)
	_check("lore_reveals_one_new_secret", revealed.size() == 1, revealed)
	if revealed.size() != 1:
		return
	var actual: Dictionary = { }
	for node: Dictionary in manager.expedition.route.nodes:
		if str(node.id) == str(revealed[0]):
			actual = node
	_check(
		"revealed_secret_is_hidden_and_ahead",
		bool(actual.get("hidden", false)) and int(actual.get("depth", -1)) > 4,
		actual,
	)


func _check_checkpoint(checkpoint: Dictionary, label: String, phase: String) -> void:
	var saved: Dictionary = checkpoint.get("session", { })
	var route: Dictionary = saved.get("route", { })
	var receipts: Dictionary = saved.get("hub_used_ids", { })
	var used: Array = receipts.get(TARGET, [])
	_check(label + "_checkpoint_present", not checkpoint.is_empty())
	_check(label + "_checkpoint_phase", str(route.get("phase", "")) == phase)
	_check(label + "_checkpoint_gold", int(saved.get("gold", -1)) == _baseline_gold + 20)
	_check(label + "_checkpoint_receipt_once", used.count("lore") == 1)
	_check(label + "_checkpoint_secret", route.get("revealed_node_ids", []) == _after_secrets)


func _check_used_lore(label: String) -> void:
	var button := _button(hall, "Service_lore")
	_check(label + "_lore_disabled", button != null and button.disabled)
	if button != null:
		await _pointer_click(button)
	_check(
		label + "_disabled_click_no_reward",
		int(manager.expedition.gold) == _baseline_gold + 20 and _receipt_count() == 1,
	)
	# The bridge must also reject duplicate requests independently of button state.
	var refused: Dictionary = hall.interactions.activate("lore")
	_check(label + "_duplicate_service_refused", not bool(refused.get("success", false)), refused)
	_check(
		label + "_duplicate_no_reward",
		int(manager.expedition.gold) == _baseline_gold + 20 and _receipt_count() == 1,
	)
	_check(
		label + "_duplicate_no_secret",
		manager.expedition.route.revealed_node_ids == _after_secrets,
	)


func _press(button: Button, label: String) -> void:
	_check(label + "_button", button != null and not button.disabled)
	if button == null or button.disabled:
		return
	await _pointer_click(button)


func _pointer_click(button: Button) -> void:
	var parent := button.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent is ScrollContainer:
		(parent as ScrollContainer).ensure_control_visible(button)
	await get_tree().process_frame
	var screen_point := button.get_screen_transform() * (button.size * 0.5)
	var at := get_viewport().get_screen_transform().affine_inverse() * screen_point
	get_viewport().notify_mouse_entered()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	var passed := not checks.is_empty()
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	var report := {
		"passed": passed,
		"checks": checks,
		"check_count": checks.size(),
		"captures": captures,
		"transitions": transitions,
		"journeys": journeys,
		"resolutions": resolutions,
		"node_id": node_id,
		"kind": kind,
		"seed": 2401,
		"manifest": MANIFEST,
		"rendered": DisplayServer.get_name() != "headless",
		"user_data": OS.get_user_data_dir(),
		"manual_visual_review_required": true,
		"limits": [
			"Captures require human/agent visual inspection for painting quality and scale.",
			"Travel uses the production interaction request and simulated frame steps.",
			"The boat confirms the normal halt departure; there is no sailing simulation.",
		],
	}
	var file := FileAccess.open(output.path_join("production_verification.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	else:
		passed = false
	print(
		"STELE_NAMES_VERIFY: %s; %d checks; %d captures" % [passed, checks.size(), captures.size()]
	)
	var current := get_tree().current_scene
	if is_instance_valid(current) and current != self:
		get_tree().current_scene = null
		current.queue_free()
	if is_instance_valid(manager):
		manager.cleanup_run_state()
	for frame in 3:
		await get_tree().process_frame
	# Release stopped WAV playbacks after the scene's normal audio teardown.
	await get_tree().create_timer(0.20, true, false, true).timeout
	get_tree().quit(0 if passed else 1)
