extends Node

const OUTPUT_DIR := "res://artifacts/run_flow_isolation_v1"
const MAIN_RUN: RunData = preload("res://data/runs/first_run.tres")
const WAVE_RUN: RunData = preload("res://data/runs/fixed_trio_prototype_run.tres")

var _failures: Array[String] = []
var _results := {
	"mission_id": "RUN_FLOW_ISOLATION_V1",
	"viewport": [1920, 1080],
	"main_run": {},
	"wave_run": {},
	"mode_switch": {},
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1920, 1080)
	# Keep this runner alive while GameManager replaces the actual current scene.
	get_tree().current_scene = null
	await _settle(2)
	if not await _run_main_flow():
		await _finish()
		return
	if not await _run_wave_flow():
		await _finish()
		return
	if not _verify_mode_switch_back_to_main():
		await _finish()
		return
	await _finish()


func _run_main_flow() -> bool:
	if not _prepare_victory(MAIN_RUN, 0, 0):
		return _fail("main_prepare_failed")
	GameManager.on_battle_won()
	var screen := await _wait_for_post_combat()
	if screen == null:
		return _fail("main_post_combat_not_loaded")
	var snapshot := GameManager.get_post_combat_decision_snapshot()
	if snapshot.get("waves_enabled", true):
		return _fail("main_snapshot_exposes_waves")
	if snapshot.get("room_flow_mode", &"") != &"SINGLE_ENCOUNTER":
		return _fail("main_snapshot_mode_mismatch")
	if GameManager.can_continue_current_room():
		return _fail("main_can_continue")
	var phases := await _advance_to_phase(screen, &"COMBAT_STATS")
	if phases.has(&"ROOM_DECISION"):
		return _fail("main_entered_room_decision")
	if screen.get_phase_name() != &"COMBAT_STATS":
		return _fail("main_combat_stats_unreachable")
	if not await _capture("main_single_encounter_post_combat"):
		return false
	phases.append_array(await _advance_to_phase(screen, &"REWARD_SELECTION"))
	if screen.get_phase_name() != &"REWARD_SELECTION":
		return _fail("main_reward_unreachable")
	if screen.get_reward_card_count() != 2:
		return _fail("main_reward_card_count")
	if not await _capture("main_single_encounter_reward"):
		return false
	_results.main_run = {
		"room_flow_mode": str(GameManager.get_active_room_flow_mode_name()),
		"waves_enabled": snapshot.get("waves_enabled", true),
		"room_decision_seen": phases.has(&"ROOM_DECISION"),
		"reward_card_count": screen.get_reward_card_count(),
		"reward_multiplier": GameManager.get_current_room_reward_multiplier(),
		"ultimate_reward_chance": GameManager.get_current_room_ultimate_reward_chance(),
		"report_segments": GameManager.get_current_combat_report().combat_segments_included,
	}
	await _detach_current_scene()
	return true


func _run_wave_flow() -> bool:
	if not _prepare_victory(WAVE_RUN, 0, 0):
		return _fail("wave_prepare_failed")
	GameManager.on_battle_won()
	var screen := await _wait_for_post_combat()
	if screen == null:
		return _fail("wave_post_combat_not_loaded")
	var snapshot := GameManager.get_post_combat_decision_snapshot()
	if not snapshot.get("waves_enabled", false):
		return _fail("wave_snapshot_hides_waves")
	if snapshot.get("room_flow_mode", &"") != &"WAVE_CHAIN":
		return _fail("wave_snapshot_mode_mismatch")
	var phases := await _advance_to_phase(screen, &"ROOM_DECISION")
	if screen.get_phase_name() != &"ROOM_DECISION":
		return _fail("wave_room_decision_unreachable")
	if not phases.has(&"ROOM_DECISION"):
		return _fail("wave_room_decision_not_observed")
	if not await _capture("test_wave_chain_room_decision"):
		return false
	var deck_before := GameManager.get_equipment_reward_deck_snapshot()
	var previous_scene_path := screen.scene_file_path
	if not await screen.choose_continue_room():
		return _fail("wave_continue_rejected")
	var battle_scene := await _wait_for_scene_change(previous_scene_path)
	if battle_scene == null:
		return _fail("wave_next_battle_not_loaded")
	if GameManager.current_wave_index != 1:
		return _fail("wave_index_not_incremented")
	if GameManager.get_equipment_reward_deck_snapshot() != deck_before:
		return _fail("wave_continue_mutated_reward_deck")
	var next_battle_scene_path := battle_scene.scene_file_path
	await _settle(4)
	var next_report := GameManager.begin_combat_report()
	if next_report == null or next_report.finalized:
		return _fail("wave_next_combat_report_not_started")
	GameManager.on_battle_won()
	var second_screen := await _wait_for_post_combat()
	if second_screen == null:
		return _fail("wave_second_post_combat_not_loaded")
	var accumulated_report := GameManager.get_current_combat_report()
	if accumulated_report == null or accumulated_report.combat_segments_included != 2:
		return _fail("wave_report_not_accumulated")
	_results.wave_run = {
		"room_flow_mode": str(GameManager.get_active_room_flow_mode_name()),
		"waves_enabled": snapshot.get("waves_enabled", false),
		"room_decision_seen": true,
		"next_battle_scene": next_battle_scene_path,
		"wave_index_after_continue": GameManager.current_wave_index,
		"reward_deck_unchanged": GameManager.get_equipment_reward_deck_snapshot() == deck_before,
		"report_segments": accumulated_report.combat_segments_included,
	}
	await _detach_current_scene()
	return true


func _verify_mode_switch_back_to_main() -> bool:
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(
		MAIN_RUN, GameManager.PRODUCTION_HERO_DATA_PATHS
	):
		return _fail("mode_switch_main_prepare_failed")
	GameManager.current_room_index = 0
	_results.mode_switch = {
		"active_mode": str(GameManager.get_active_room_flow_mode_name()),
		"wave_index": GameManager.get_current_wave_index(),
		"room_combat_count": GameManager.get_current_room_wave_count(),
		"can_continue": GameManager.can_continue_current_room(),
	}
	return not GameManager.is_wave_chain_active() \
		and GameManager.get_current_wave_index() == 0 \
		and GameManager.get_current_room_wave_count() == 1 \
		and not GameManager.can_continue_current_room() \
		or _fail("mode_switch_leaked_wave_state")


func _prepare_victory(run: RunData, room_index: int, wave_index: int) -> bool:
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(
		run, GameManager.PRODUCTION_HERO_DATA_PATHS
	):
		return false
	GameManager.current_room_index = room_index
	GameManager.current_wave_index = wave_index
	return GameManager.begin_combat_report() != null


func _wait_for_post_combat() -> PostCombatScreen:
	for _index in 180:
		await get_tree().process_frame
		if get_tree().current_scene is PostCombatScreen:
			return get_tree().current_scene as PostCombatScreen
	return null


func _wait_for_scene_change(previous_path: String) -> Node:
	for _index in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current.scene_file_path != previous_path:
			return current
	return null


func _advance_to_phase(screen: PostCombatScreen, target: StringName) -> Array[StringName]:
	var phases: Array[StringName] = [screen.get_phase_name()]
	var guard := 0
	while screen.get_phase_name() != target and guard < 24:
		guard += 1
		screen.advance_or_skip()
		await _settle(2)
		if not phases.has(screen.get_phase_name()):
			phases.append(screen.get_phase_name())
	return phases


func _capture(file_name: String) -> bool:
	await get_tree().create_timer(0.75).timeout
	await _settle(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return _fail("capture_empty_%s" % file_name)
	var output_path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		return _fail("capture_failed_%s_%d" % [file_name, error])
	print("RUN_FLOW_CAPTURED=%s" % output_path)
	return true


func _detach_current_scene() -> void:
	var current := get_tree().current_scene
	if current != null:
		get_tree().current_scene = null
		current.queue_free()
	await _settle(3)


func _settle(frame_count: int) -> void:
	for _index in frame_count:
		await get_tree().process_frame


func _fail(code: String) -> bool:
	_failures.append(code)
	push_error("RUN_FLOW_RUNTIME_SMOKE: %s" % code)
	return false


func _finish() -> void:
	_results["failures"] = _failures.duplicate()
	_results["passed"] = _failures.is_empty()
	var report_path := "%s/runtime_smoke.json" % OUTPUT_DIR
	var file := FileAccess.open(
		ProjectSettings.globalize_path(report_path), FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(_results, "  "))
		file.close()
	else:
		_failures.append("runtime_report_write_failed")
	GameManager.cleanup_run_state()
	print("RUN_FLOW_RUNTIME_SMOKE=%s" % (
		"PASS" if _failures.is_empty() else "FAIL"
	))
	get_tree().quit(0 if _failures.is_empty() else 1)
