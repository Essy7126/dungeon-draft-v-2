extends Node

## Production Catabase traversal. This runner owns no map and changes no resource.
## Movement/guard are verified in all three rooms; only rooms I and II end by QA force.
var _run_data: RunData
const REGISTERED_SCENE := "res://battle/painted/registered_terrain/RegisteredTerrainBattle.tscn"
const GEOMETRY := preload("res://tools/registered_terrain_validation/geometry_checks.gd")
const SUPPORT := preload("res://tools/registered_terrain_validation/terrain_support_checks.gd")
const MATERIAL := preload("res://tools/registered_terrain_validation/terrain_material_checks.gd")
const BAND := preload("res://tools/registered_terrain_validation/combat_band_checks.gd")
const DECOR := preload("res://tools/registered_terrain_validation/quiet_center_checks.gd")
const INTERACTIONS := preload("res://tools/registered_terrain_validation/interaction_checks.gd")
const PATHS := preload("res://tools/registered_terrain_validation/validation_paths.gd")
const EXPECTED_PLANS := [
	"res://data/arenas/greek_drawn_courtyard_v1/terrain_plan.json",
	"res://data/arenas/ashen_hell_courtyard_v1/terrain_plan.json",
	"res://data/arenas/silent_judgment_courtyard_v1/terrain_plan.json",
]
const EXPECTED_ENCOUNTERS := [
	"res://data/encounters/catabase_frail_hellspawn_encounter.tres",
	"res://data/encounters/odyssey_room_02_encounter.tres",
	"res://data/encounters/odyssey_room_03_encounter.tres",
]
# The run definition is fixed; room I/II bytes are instead observed at run start/end.
const PRESERVED_FILES := {
	"res://data/runs/odyssey.tres": "901232e1c07062fc1eb62ab2483f4cc6fdf29e4397458eefe3a018b94b41b992",
}
const STABLE_ROOM_FILES := [
	"res://data/rooms/odyssey/room_01.tres",
	"res://data/rooms/odyssey/room_02.tres",
]
# Informational only: concurrent content work added encounter fields and the room-II spectre.
# Live rosters and paths are asserted; encounter bytes must remain stable during this run.
const HISTORICAL_ENCOUNTER_BASELINES := {
	"res://data/encounters/catabase_frail_hellspawn_encounter.tres": "e81995004126ad0017cce23deab19bb7e729bb886cf07940678c531498bc6eba",
	"res://data/encounters/odyssey_room_02_encounter.tres": "b144cbb805764ed1e9b50f6a38447bb2552536e69ff1bf8596ddd10d28cf06bd",
	"res://data/encounters/odyssey_room_03_encounter.tres": "2dc1f7f799d16e5bac0b3bb809d43127db7b0ad83974609c08c3a728b3c059fe",
}

var _output := ""
var _requested_resolution := Vector2i.ZERO
var _finished := false
var _report: Dictionary = {
	"ok": true,
	"scope": "Catabase real production scenes, movement/guard and guarded room transitions",
	"combat_completion": "QA-forced Battle._end_battle(true) in rooms I and II only; room III remains in combat after its actions. No complete combat or balancing claim",
	"input_scope": "Actual GridView hover/click endpoints and Battle controllers; no OS pointer injection",
	"run_path": "res://data/runs/odyssey.tres",
	"rooms": [], "transitions": [], "captures": [], "errors": [],
	"window_resolution_checks": [], "rejected_captures": [],
}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_output = _argument("--output=")
	var size_text := _argument("--resolution=")
	var parts := size_text.to_lower().split("x")
	if _output.is_empty() or parts.size() != 2 or int(parts[0]) < 640 or int(parts[1]) < 480:
		push_error("Registered terrain QA requires --output=ABSOLUTE_DIRECTORY --resolution=WIDTHxHEIGHT")
		get_tree().quit(2)
		return
	_output = ProjectSettings.globalize_path(_output)
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		push_error("Registered terrain QA cannot create output directory: " + _output)
		get_tree().quit(2)
		return
	if DisplayServer.get_name() == "headless":
		_fail("GPU renderer required for production screenshots and live materials")
		_finish()
		return
	_requested_resolution = Vector2i(int(parts[0]), int(parts[1]))
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = _requested_resolution
	_report["requested_resolution"] = [_requested_resolution.x, _requested_resolution.y]
	_report["started_at_utc"] = Time.get_datetime_string_from_system(true)
	_report["preserved_resources"] = _preserved_resources()
	_report["encounter_resources"] = _observe_encounter_resources()
	_report["stable_room_resources"] = _observe_room_resources()
	get_tree().create_timer(180.0).timeout.connect(_on_timeout)
	# Keep this observer attached to root while GameManager replaces current_scene.
	get_tree().current_scene = null
	_run_data = load("res://data/runs/odyssey.tres") as RunData
	if _run_data == null:
		_fail("Catabase resource or a referenced dependency could not load")
		_finish()
		return
	GameManager.cleanup_run_state()
	if _run_data.rooms.size() != 3 or not GameManager.configure_next_run(_run_data, 0) or not GameManager.start_configured_run():
		_fail("Catabase could not start through the normal GameManager pipeline")
		_finish()
		return
	await _settle(12)
	_report["seed"] = GameManager.get_run_seed()
	_report["initial_room_index"] = GameManager.current_room_index
	if GameManager.current_room_index != 0:
		_fail("Catabase did not begin in room I")
		_finish()
		return
	for room_index in range(3):
		if _finished:
			return
		if GameManager.current_room_index != room_index:
			_fail("Progression index mismatch before room %d" % (room_index + 1))
			break
		GameManager.start_next_battle()
		var battle: Node = await _wait_for_battle(room_index)
		if battle == null:
			_fail("Production room %d did not become ready" % (room_index + 1))
			break
		if not await _deploy_and_settle(battle):
			_fail("Deployment/player controls not ready in room %d" % (room_index + 1))
			break
		if not await _enforce_requested_resolution(room_index):
			break
		var room_result: Dictionary = _room_contract(battle, room_index)
		_report.rooms.append(room_result)
		_validate_registered_room(battle, room_index, room_result)
		if not await _capture("room_%02d_combat" % (room_index + 1)):
			break
		var hero: Unit = _first_hero(battle)
		var assembly: Dictionary = battle.get("arena_assembly")
		var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
		if hero == null or renderer == null:
			_fail("Movement/guard runtime dependencies missing")
			break
		var probe := INTERACTIONS.new()
		add_child(probe)
		var interaction: Dictionary = await probe.run(
			battle, hero, battle.get("grid") as GridData,
			battle.get("pathfinder") as Pathfinder,
			battle.get("grid_view") as Node2D, renderer)
		room_result["interactions"] = interaction
		_merge_errors(interaction, "room_%d_interactions" % (room_index + 1))
		probe.queue_free()
		if not await _capture("room_%02d_after_move_guard" % (room_index + 1)):
			break
		_write_report()
		if not bool(interaction.get("ok", false)):
			break
		if room_index < 2:
			if not await _advance_room(battle, room_index):
				break
		else:
			room_result["left_in_live_combat"] = get_tree().current_scene == battle and GameManager.current_room_index == room_index and bool(battle.call("_can_accept_player_intent"))
			if not bool(room_result["left_in_live_combat"]):
				_fail("Room III did not remain in live combat after movement and guard")
		_write_report()
	_finish()

func _wait_for_battle(room_index: int) -> Node:
	var expected: String = _run_data.rooms[room_index].battle_scene.resource_path
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline and not _finished:
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if candidate == null or candidate.scene_file_path != expected or not candidate.has_method("_can_accept_player_intent"):
			continue
		if not bool(candidate.get("runtime_ready_state")):
			continue
		if not bool(candidate.get("registered_terrain_ready")):
			continue
		return candidate
	return null

func _deploy_and_settle(battle: Node) -> bool:
	var deployment := battle.get("_deployment") as DeploymentController
	var room: RoomData = GameManager.get_current_room()
	var grid := battle.get("grid") as GridData
	if room == null or grid == null:
		return false
	if deployment != null and deployment.is_active():
		for cell: Vector2i in room.hero_spawn_zone:
			if not deployment.is_active():
				break
			if grid.is_walkable(cell) and not grid.has_unit(cell):
				deployment.on_cell_clicked(cell)
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if deployment != null and deployment.is_active():
			continue
		if bool(battle.call("_can_accept_player_intent")):
			await get_tree().create_timer(2.5).timeout
			return true
	return false

func _room_contract(battle: Node, room_index: int) -> Dictionary:
	var room: RoomData = GameManager.get_current_room()
	var encounter: EncounterDefinition = room.encounter_definition
	var expected_ids: Array[String] = []
	if encounter != null:
		for index in range(encounter.roster_units.size()):
			var source: UnitData = encounter.roster_units[index]
			var count: int = int(encounter.roster_counts[index]) if index < encounter.roster_counts.size() else 1
			for _copy in range(count):
				expected_ids.append(str(source.get_effective_unit_id()))
	var actual_ids: Array[String] = []
	var hero_ids: Array[String] = []
	var grid := battle.get("grid") as GridData
	var views: Dictionary = battle.get("_unit_views")
	var invalid_anchors: Array = []
	var units: Array = battle.get("units")
	for value: Variant in units:
		var unit := value as Unit
		if unit == null:
			continue
		if unit.team == 0:
			hero_ids.append(str(unit.unit_id))
		else:
			actual_ids.append(str(unit.unit_id))
		var unit_view := views.get(unit) as Node2D
		if grid.find_unit(unit) != unit.grid_pos or not grid.is_walkable(unit.grid_pos, unit) or unit_view == null or not unit_view.is_visible_in_tree() or not get_viewport().get_visible_rect().has_point(unit_view.get_global_transform_with_canvas().origin):
			invalid_anchors.append(str(unit.unit_id))
	expected_ids.sort()
	actual_ids.sort()
	var encounter_path: String = encounter.resource_path if encounter != null else ""
	var passed: bool = expected_ids == actual_ids and not hero_ids.is_empty() and invalid_anchors.is_empty() and encounter_path == EXPECTED_ENCOUNTERS[room_index]
	passed = passed and battle.scene_file_path == REGISTERED_SCENE
	if not passed:
		_fail("Room %d production scene/encounter/deployment contract failed" % (room_index + 1))
	return {
		"room_number": room_index + 1, "room_name": room.room_name,
		"room_resource_path": room.resource_path, "scene_path": battle.scene_file_path,
		"encounter_path": encounter_path, "expected_enemy_ids": expected_ids,
		"actual_enemy_ids": actual_ids, "enemy_count": actual_ids.size(),
		"hero_ids": hero_ids, "invalid_unit_anchors": invalid_anchors,
		"encounter_and_scene_ok": passed,
	}

func _validate_registered_room(battle: Node, room_index: int, result: Dictionary) -> void:
	var arena := battle.get("room_data") as ArenaDefinition
	var grid := battle.get("grid") as GridData
	var view := battle.get("grid_view") as Node2D
	var assembly: Dictionary = battle.get("arena_assembly")
	var renderer := assembly.get("renderer") as ArenaTerrainVisualRenderer
	if arena == null or grid == null or view == null or renderer == null:
		_fail("Room %d has no complete registered terrain runtime" % (room_index + 1))
		return
	var effective_plan: String = PATHS.plan_path(arena, battle)
	result["registered_plan_path"] = effective_plan
	result["registered_terrain_ready"] = bool(battle.get("registered_terrain_ready"))
	if effective_plan != EXPECTED_PLANS[room_index]:
		_fail("Room %d uses the wrong registered terrain plan" % (room_index + 1))
	var report := assembly.get("report") as ArenaVisualAssemblyReport
	if report == null or not report.valid:
		_fail("Room %d visual assembly invalid" % (room_index + 1))
	var geometry: Dictionary = GEOMETRY.run(battle, arena, grid, view, renderer)
	var support: Dictionary = SUPPORT.run(battle, arena, view, renderer)
	var material: Dictionary = MATERIAL.run(battle, arena, renderer)
	var band: Dictionary = BAND.run(battle, arena, renderer)
	result["geometry"] = geometry
	result["terrain_support"] = support
	result["terrain_material"] = material
	result["combat_ground_band"] = band
	for key: String in ["geometry", "terrain_support", "terrain_material", "combat_ground_band"]:
		_merge_errors(result[key], "room_%d_%s" % [room_index + 1, key])
	if int(geometry.get("floor_cells", -1)) != 217 or int(geometry.get("platform", {}).get("expected_annotation_groups", -1)) != 5:
		_fail("Room %d does not preserve the 217-floor/five-pit template" % (room_index + 1))
	if bool(band.get("skipped", false)) or not bool(battle.get("combat_band_active")):
		_fail("Room %d requires a visible combat ground band" % (room_index + 1))
	var terrain := battle.get_node_or_null("GreekTerrainComposition")
	var plan: Dictionary = terrain.get("plan") if terrain != null else {}
	result["land_texture_path"] = str(plan.get("land", {}).get("texture_path", ""))
	result["water_texture_path"] = str(plan.get("water", {}).get("texture_path", ""))
	result["world_decor_count"] = plan.get("world_decor", []).size()
	result["manifest_path"] = PATHS.manifest_path(arena, battle)
	if room_index == 2:
		var quiet_center: Dictionary = DECOR.run(battle, arena, grid, renderer)
		result["quiet_center_layers"] = quiet_center
		_merge_errors(quiet_center, "room_3_quiet_center_layers")

func _advance_room(battle: Node, from_index: int) -> bool:
	var transition: Dictionary = {
		"from_room": from_index + 1, "to_room": from_index + 2,
		"completion_mode": "explicit QA-forced Battle._end_battle(true), after real movement/guard",
		"outcome_api": "Battle._end_battle -> GameManager.schedule_battle_outcome -> on_battle_won",
		"reward_api": "GameManager.confirm_post_combat_equipment",
		"progression_api": "GameManager.complete_post_combat_transition -> transition screen",
		"room_index_written_by_runner": false, "ok": false,
	}
	_report.transitions.append(transition)
	battle.call("_end_battle", true)
	var deadline := Time.get_ticks_msec() + 18000
	var combat_report: CombatReport = null
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var candidate: CombatReport = GameManager.get_current_combat_report()
		var screen := get_tree().current_scene
		if candidate != null and candidate.room_index == from_index and candidate.finalized and screen != null and screen.has_method("get_phase_name"):
			combat_report = candidate
			transition["post_combat_scene"] = screen.scene_file_path
			break
	if combat_report == null:
		_fail("Room %d did not produce a finalized post-combat report" % (from_index + 1))
		return false
	transition["report_id"] = str(combat_report.report_id)
	transition["transition_blocked_before_reward"] = not GameManager.complete_post_combat_transition(combat_report.report_id)
	if not bool(transition.transition_blocked_before_reward):
		_fail("Room progression bypassed its equipment reward guard")
		return false
	var options: Array[Dictionary] = GameManager.get_post_combat_reward_options()
	transition["reward_options_count"] = options.size()
	var applied := false
	for option: Dictionary in options:
		var definition := option.get("definition") as ItemDefinition
		var compatible: Array = option.get("compatible_character_ids", [])
		var recipient: StringName = &""
		if definition != null and not definition.is_relic() and not compatible.is_empty():
			recipient = StringName(compatible[0])
		var item_id := StringName(option.get("item_id", &""))
		var reward: Dictionary = GameManager.confirm_post_combat_equipment(item_id, recipient)
		if bool(reward.get("success", false)):
			applied = true
			transition["reward_item_id"] = str(item_id)
			transition["reward_recipient"] = str(recipient)
			transition["reward_applied"] = true
			break
	if not applied or GameManager.can_claim_post_combat_equipment(combat_report.report_id):
		_fail("Room %d reward could not be claimed through GameManager" % (from_index + 1))
		return false
	if not GameManager.complete_post_combat_transition(combat_report.report_id):
		_fail("Room %d guarded transition refused after reward" % (from_index + 1))
		return false
	await _settle(12)
	transition["actual_next_room_index"] = GameManager.current_room_index
	transition["next_room_path"] = GameManager.get_current_room().resource_path
	transition["ok"] = GameManager.current_room_index == from_index + 1
	if not bool(transition.ok):
		_fail("GameManager did not advance to the expected next room")
	return bool(transition.ok)

func _preserved_resources() -> Array:
	var result: Array = []
	for path: String in PRESERVED_FILES:
		var actual := FileAccess.get_sha256(path).to_lower()
		var matches: bool = actual == PRESERVED_FILES[path]
		result.append({"path": path, "sha256": actual, "unchanged": matches})
		if not matches:
			_fail("Preserved Catabase resource changed: " + path)
	return result

func _observe_room_resources() -> Array:
	var result: Array = []
	for path: String in STABLE_ROOM_FILES:
		var actual: String = FileAccess.get_sha256(path).to_lower()
		if actual.is_empty():
			_fail("Cannot observe unchanged room resource at run start: " + path)
		result.append({"path": path, "observed_at_run_start": actual})
	return result

func _check_room_stability() -> void:
	for record: Dictionary in _report.get("stable_room_resources", []):
		var path: String = str(record.get("path", ""))
		var current: String = FileAccess.get_sha256(path).to_lower()
		var stable: bool = not current.is_empty() and current == str(record.get("observed_at_run_start", ""))
		record["observed_after_run"] = current
		record["stable_during_run"] = stable
		if not stable:
			_fail("Room I/II resource changed during the QA run: " + path)

func _observe_encounter_resources() -> Array:
	var result: Array = []
	for path: String in EXPECTED_ENCOUNTERS:
		var actual: String = FileAccess.get_sha256(path).to_lower()
		var historical: String = str(HISTORICAL_ENCOUNTER_BASELINES.get(path, ""))
		if actual.is_empty():
			_fail("Cannot observe encounter resource at run start: " + path)
		result.append({
			"path": path, "observed_at_run_start": actual,
			"historical_pre_promotion_sha256": historical,
			"historical_baseline_changed": actual != historical,
			"historical_change_scope": "Informational: concurrent progression fields and room-II spectre integration; current paths and rosters are verified against live units",
		})
	return result

func _check_encounter_stability() -> void:
	for record: Dictionary in _report.get("encounter_resources", []):
		var path: String = str(record.get("path", ""))
		var current: String = FileAccess.get_sha256(path).to_lower()
		var stable: bool = not current.is_empty() and current == str(record.get("observed_at_run_start", ""))
		record["observed_after_run"] = current
		record["stable_during_run"] = stable
		if not stable:
			_fail("Encounter resource changed during the QA run: " + path)

func _first_hero(battle: Node) -> Unit:
	var units: Array = battle.get("units")
	for value: Variant in units:
		var unit := value as Unit
		if unit != null and unit.team == 0:
			return unit
	return null

func _enforce_requested_resolution(room_index: int) -> bool:
	var window := get_window()
	var record: Dictionary = {
		"room_number": room_index + 1, "ok": false,
		"mode_before": int(window.mode),
		"window_size_before": [window.size.x, window.size.y],
		"requested_resolution": [_requested_resolution.x, _requested_resolution.y],
	}
	_report.window_resolution_checks.append(record)
	# Native maximization can override size; restore windowed mode first and let
	# the OS acknowledge it before sizing. Camera/GridView then receive resize.
	window.mode = Window.MODE_WINDOWED
	await _settle(2)
	window.size = _requested_resolution
	var deadline: int = Time.get_ticks_msec() + 3000
	var stable_frames := 0
	var actual_viewport := Vector2i.ZERO
	while Time.get_ticks_msec() < deadline and not _finished:
		await get_tree().process_frame
		actual_viewport = Vector2i(get_viewport().get_texture().get_size())
		var matches: bool = window.mode == Window.MODE_WINDOWED and window.size == _requested_resolution and actual_viewport == _requested_resolution
		stable_frames = stable_frames + 1 if matches else 0
		if stable_frames >= 3:
			record["ok"] = true
			break
	record["mode_after"] = int(window.mode)
	record["window_size_after"] = [window.size.x, window.size.y]
	record["viewport_size_after"] = [actual_viewport.x, actual_viewport.y]
	record["consecutive_matching_frames"] = stable_frames
	if not bool(record["ok"]):
		_fail("Room %d did not settle at requested windowed resolution %s; window %s, viewport %s, mode %d" % [room_index + 1, _requested_resolution, window.size, actual_viewport, int(window.mode)])
	return bool(record["ok"])

func _capture(label: String) -> bool:
	await _settle(2)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("GPU capture empty: " + label)
		return false
	var actual_resolution := Vector2i(image.get_width(), image.get_height())
	if actual_resolution != _requested_resolution or get_window().mode != Window.MODE_WINDOWED:
		_report.rejected_captures.append({
			"label": label, "actual_resolution": [actual_resolution.x, actual_resolution.y],
			"requested_resolution": [_requested_resolution.x, _requested_resolution.y],
			"window_mode": int(get_window().mode),
		})
		_fail("GPU capture refused: %s is %s in mode %d, expected windowed %s" % [label, actual_resolution, int(get_window().mode), _requested_resolution])
		return false
	var file_name := "%s_%dx%d.png" % [label, image.get_width(), image.get_height()]
	var path := _output.path_join(file_name)
	if image.save_png(path) != OK:
		_fail("Could not write capture: " + path)
		return false
	_report.captures.append({"label": label, "path": path, "actual_resolution": [image.get_width(), image.get_height()], "matches_requested_resolution": true})
	return true

func _merge_errors(result: Dictionary, prefix: String) -> void:
	for error: Variant in result.get("errors", []):
		_fail(prefix + ": " + str(error))
	if not bool(result.get("ok", true)) and result.get("errors", []).is_empty():
		_fail(prefix + ": validation returned false")

func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame

func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _fail(message: String) -> void:
	_report.ok = false
	_report.errors.append(message)
	push_error("REGISTERED_TERRAIN_QA: " + message)

func _write_report() -> void:
	if _output.is_empty():
		return
	var file := FileAccess.open(_output.path_join("registered_terrain_report.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write registered_terrain_report.json")
		return
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()

func _on_timeout() -> void:
	if not _finished:
		_fail("Global QA timeout after 180 seconds")
		_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _report.rooms.size() != 3 or _report.transitions.size() != 2:
		_fail("Incomplete traversal: expected three loaded rooms and two guarded transitions")
	if _report.captures.size() != 6:
		_fail("Incomplete GPU captures: expected combat and after-move/guard images in each of three rooms")
	var successful_action_rooms := 0
	for room_result: Dictionary in _report.rooms:
		var interactions: Dictionary = room_result.get("interactions", {})
		if bool(interactions.get("ok", false)):
			successful_action_rooms += 1
	_report["rooms_with_successful_movement_and_guard"] = successful_action_rooms
	if successful_action_rooms != 3:
		_fail("Movement and guard must succeed independently in all three rooms")
	_check_encounter_stability()
	_check_room_stability()
	_report["preserved_resources_after_run"] = _preserved_resources()
	_report["finished_at_utc"] = Time.get_datetime_string_from_system(true)
	_write_report()
	print("REGISTERED_TERRAIN_QA=" + JSON.stringify(_report))
	get_tree().quit(0 if bool(_report.ok) else 1)
