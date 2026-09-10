extends Node
## Real singleton, real scene changes and PersistentRunUI; isolated by the launcher.
var output := ""
var kind := "merchant"
var checks: Array[Dictionary] = []
var captures: Array[String] = []
var transitions: Array[String] = []
var manager: Node
var hall: Node2D
var node_id := ""


class FixtureManager extends "res://core/game_manager.gd":
	func start_next_battle() -> void:
		_room_outcome_resolved = false


	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--production-output="):
			output = argument.trim_prefix("--production-output=").replace("\\", "/").trim_suffix(
				"/"
			)
		if argument.begins_with("--production-kind="):
			kind = argument.trim_prefix("--production-kind=")
	# Refuse a casual F6 run: both artifacts and all user:// writes must be isolated.
	var artifacts: String = ProjectSettings.globalize_path("res://artifacts/dev/")
	artifacts = artifacts.replace("\\", "/").to_lower()
	var user_data := OS.get_user_data_dir().replace("\\", "/").to_lower()
	var isolated: bool = (
		not output.is_empty() and output.to_lower().begins_with(artifacts)
		and user_data.begins_with(output.to_lower() + "/userdata/")
	)
	if not isolated or kind not in ["merchant", "sanctuary"]:
		push_error("Production probe requires its isolated launcher and supported halt kind.")
		get_tree().quit(2)
		return
	_check("isolated_user_data", isolated, user_data)
	_check("rendered_backend", DisplayServer.get_name() != "headless")
	get_window().size = Vector2i(1920, 1080)
	manager = get_tree().root.get_node("GameManager")
	_check(
		"singleton_starts_without_live_run",
		not manager.run_active and manager.expedition == null,
	)
	if manager.run_active or manager.expedition != null:
		_finish()
		return
	var snapshot := _fixture_snapshot()
	_check("fixture_snapshot_complete", not snapshot.is_empty())
	if snapshot.is_empty():
		_finish()
		return
	manager.expedition_save_path = output.path_join("production_checkpoint.json")
	_check("restore_real_singleton", manager.restore_expedition_snapshot(snapshot))
	if manager.expedition == null:
		_finish()
		return
	node_id = manager.expedition.route.current_node_id
	_check(
		"real_route_depth_kind",
		int(manager.expedition.route.get_current_node().depth) == 8
		and str(manager.expedition.route.get_current_node().kind) == kind,
	)
	_check("real_route_binding", manager.is_painted_halt_active())
	manager.scene_change_requested.connect(_scene_requested)
	# Keep this small runner as a root sibling while actual current scenes change.
	get_tree().current_scene = null
	_check("open_production_halt", manager.open_painted_halt())
	if not await _wait_scene(str(manager.PAINTED_HALT_SCREEN_PATH)):
		_finish()
		return
	hall = get_tree().current_scene as Node2D
	if not await _wait_hall():
		_finish()
		return
	hall.set_process(false)
	_check("production_not_preview", not hall.preview_mode and not hall.interactions.bridge.preview)
	_check("production_manifest_binding", hall.manifest_path == manager.get_painted_halt_manifest())
	var persistent: PersistentRunUI = manager.get_persistent_run_ui()
	_check(
		"persistent_ui_real_non_combat",
		persistent != null and manager.get_run_ui_mode() == PersistentRunUI.RunUIMode.NON_COMBAT,
	)
	await _capture("production_hud")
	get_window().size = Vector2i(1280, 720)
	for frame in 2:
		await get_tree().process_frame
	_check_hud_in_view()
	await _capture("production_hud_720p")
	get_window().size = Vector2i(1920, 1080)
	for frame in 2:
		await get_tree().process_frame
	_check("request_production_service", hall.interactions.request(0))
	_advance_to_interaction()
	_check("production_modal_on_arrival", hall.interactions.active)
	var context: Dictionary = hall.interactions.bridge.context()
	_check(
		"production_services_preserved",
		context.services.size() == manager.get_sanctuary_context().services.size()
		and context.services.size() >= 4,
	)
	await _capture("production_services")
	var before_gold: int = manager.expedition.gold
	await _press(_button(hall, "Service_lore"), "real_lore_service")
	_check(
		"real_lore_applied_once",
		int(manager.expedition.gold) == before_gold + 20
		and manager.expedition.hub_used_ids[node_id].has("lore"),
	)
	var checkpoint: Dictionary = ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
	var saved_session: Dictionary = checkpoint.get("session", { })
	var saved_receipts: Dictionary = saved_session.get("hub_used_ids", { })
	_check("real_lore_checkpoint", saved_receipts.get(node_id, []).has("lore"))
	await _capture("production_receipt")
	if persistent != null:
		_check("production_inventory_opens", persistent.open_inventory_screen(&"achilles"))
		await get_tree().process_frame
		_check(
			"inventory_owns_modal",
			persistent.is_inventory_open() and persistent.has_active_modal(),
		)
		await _capture("production_inventory")
		await _escape()
		_check(
			"escape_closes_inventory_first",
			not persistent.is_inventory_open() and hall.interactions.active,
		)
	await _press(_button(hall, "CloseHaltInteraction"), "close_real_service")
	_check("production_modal_closed", not hall.interactions.active)
	await _press(_button(hall, "Parchemin", true), "open_parchment")
	if not await _wait_scene(str(manager.EXPEDITION_SCREEN_PATH)):
		_finish()
		return
	await _capture("production_parchment")
	await _press(_button(get_tree().current_scene, "EnterPaintedHalt"), "return_from_parchment")
	if not await _wait_scene(str(manager.PAINTED_HALT_SCREEN_PATH)):
		_finish()
		return
	hall = get_tree().current_scene as Node2D
	if not await _wait_hall():
		_finish()
		return
	hall.set_process(false)
	_check(
		"roundtrip_keeps_route_and_receipt",
		manager.expedition.route.current_node_id == node_id
		and manager.expedition.hub_used_ids[node_id].has("lore"),
	)
	_check("roundtrip_keeps_real_bridge", not hall.interactions.bridge.preview)
	await _capture("production_returned")
	var exit_index := -1
	for index in hall.definition.landmarks.size():
		if str(hall.definition.landmarks[index].get("action", "")) == "exit":
			exit_index = index
	_check("production_exit_authored", exit_index >= 0)
	if exit_index >= 0:
		_check("request_production_exit", hall.interactions.request(exit_index))
		_advance_to_interaction()
		await _press(_button(hall, "LeavePaintedHalt"), "leave_production_halt")
		await _wait_scene(str(manager.EXPEDITION_SCREEN_PATH))
		for frame in 4:
			await get_tree().process_frame
		checkpoint = ExpeditionSaveService.read_snapshot(manager.expedition_save_path)
		saved_session = checkpoint.get("session", { })
		var saved_route: Dictionary = saved_session.get("route", { })
		_check(
			"production_departure_saved",
			manager.expedition.route.phase == "map" and saved_route.get("phase", "") == "map",
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
	_finish()


func _fixture_snapshot() -> Dictionary:
	var fixture := FixtureManager.new()
	fixture.expedition_save_path = output.path_join("fixture_checkpoint.json")
	add_child(fixture)
	var valid: bool = fixture.start_expedition(2401)
	if not valid:
		fixture.cleanup_run_state()
		fixture.queue_free()
		return { }
	for depth in range(1, 9):
		if not valid:
			break
		if depth > 1:
			var choices: Array = fixture.expedition.route.get_available_nodes()
			var selected: Dictionary = choices[0]
			if depth == 8:
				for choice: Dictionary in choices:
					if str(choice.kind) == kind:
						selected = choice
			valid = fixture.choose_expedition_node(str(selected.id))
		if fixture.expedition.route.phase == "combat":
			fixture.begin_combat_report()
			fixture.on_battle_won()
		if depth < 8:
			var options: Array = fixture.expedition.reward_options(fixture.item_catalog)
			valid = valid and bool(fixture.claim_expedition_reward(str(options.back().id)).success)
	var progression: ChampionProgressionState = fixture.expedition.character.champion_progression
	while valid and progression.unspent_attribute_points > 0:
		var before: int = progression.unspent_attribute_points
		valid = (
			fixture.spend_champion_attribute(&"achilles", &"vitality")
			and progression.unspent_attribute_points < before
		)
	var snapshot: Dictionary = fixture.get_expedition_snapshot() if valid else { }
	fixture.cleanup_run_state()
	fixture.queue_free()
	return snapshot


func _scene_requested(path: String) -> void:
	transitions.append(path)


func _wait_scene(path: String) -> bool:
	for frame in 300:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path:
			await get_tree().process_frame
			return true
	_check("scene_arrival_" + path.get_file(), false)
	return false


func _wait_hall() -> bool:
	for frame in 180:
		if is_instance_valid(hall) and hall.is_ready_for_play():
			_check("production_ready", true)
			return true
		await get_tree().process_frame
	_check("production_ready", false)
	return false


func _advance_to_interaction() -> void:
	for step in 3600:
		hall.advance_world(1.0 / 60.0)
		if hall.interactions.active:
			return
	_check("production_interaction_arrives", false)


func _check_hud_in_view() -> void:
	var hud: Node = hall._interface
	var bounds := get_viewport().get_visible_rect()
	var count := 0
	for candidate: Node in hud.find_children("*", "Button", true, false):
		var button := candidate as Button
		if not button.is_visible_in_tree():
			continue
		count += 1
		var rect := button.get_global_rect()
		var contained := true
		for corner: Vector2 in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]:
			contained = (
				contained and corner.x >= bounds.position.x and corner.y >= bounds.position.y
				and corner.x <= bounds.end.x and corner.y <= bounds.end.y
			)
		_check(
			"production_hud_720p_button_" + str(button.name),
			contained and rect.has_area(),
			{ "text": button.text, "rect": str(rect), "viewport": str(bounds) },
		)
	_check("production_hud_720p_buttons_present", count > 0, count)


func _button(parent: Node, id: String, by_text := false) -> Button:
	for candidate: Node in parent.find_children("*", "Button", true, false):
		var button := candidate as Button
		if (
			button.is_visible_in_tree()
			and (button.text == id if by_text else str(button.name) == id)
		):
			return button
	return null


func _press(button: Button, label: String) -> void:
	_check(label + "_button", button != null and not button.disabled)
	if button == null or button.disabled:
		return
	var parent := button.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent is ScrollContainer:
		(parent as ScrollContainer).ensure_control_visible(button)
	await get_tree().process_frame
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _escape() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(label + ".png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	_check("capture_" + label, result == OK)
	if result == OK:
		captures.append(path)


func _check(label: String, passed: bool, details: Variant = null) -> void:
	checks.append({ "id": label, "passed": passed, "details": details })
	if not passed:
		push_error("PRODUCTION_HALT_CHECK: " + label + " " + str(details))


func _finish() -> void:
	var passed := not checks.is_empty()
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	var report := {
		"passed": passed,
		"checks": checks,
		"check_count": checks.size(),
		"captures": captures,
		"transitions": transitions,
		"node_id": node_id,
		"kind": kind,
		"rendered": DisplayServer.get_name() != "headless",
		"user_data": OS.get_user_data_dir(),
	}
	var file := FileAccess.open(output.path_join("production_verification.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	else:
		passed = false
	print(
		"PRODUCTION_HALT_VERIFY: %s; %d checks; %d captures"
		% [passed, checks.size(), captures.size()]
	)
	if manager != null:
		manager.cleanup_run_state()
	get_tree().quit(0 if passed else 1)
