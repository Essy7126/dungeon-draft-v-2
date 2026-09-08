extends GutTest
## Exercise production selection signals against an isolated, valid checkpoint.

class SelectionProbe:
	extends CharacterSelectionScreen
	var launch_requests := 0
	var launched_entries: Array[StringName] = []
	func _launch_adventure() -> void:
		launch_requests += 1
		launched_entries.append(StringName(get_selected_entry().id))

class SaveFixtureManager:
	extends "res://core/game_manager.gd"
	func start_next_battle() -> void:
		pass
	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null

var _screen: SelectionProbe
var _previous_path := ""
var _previous_reduced_motion := false
var _fixture_path := ""
var _fixture_hash := ""
var _player_hash := ""


func before_each() -> void:
	_previous_path = GameManager.expedition_save_path
	_previous_reduced_motion = GameManager.is_reduced_motion_enabled()
	_player_hash = _hash(ExpeditionSaveService.SAVE_PATH)
	var directory := "res://artifacts/project_audit/2026-09-08/selection-guard-%d" % Time.get_ticks_usec()
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	_fixture_path = directory.path_join("checkpoint.json")
	var manager := SaveFixtureManager.new()
	manager.expedition_save_path = _fixture_path
	assert_true(manager.start_expedition(2401))
	manager.cleanup_run_state()
	manager.free()
	_fixture_hash = _hash(_fixture_path)
	assert_ne(_fixture_hash, "absent")
	GameManager.expedition_save_path = _fixture_path
	GameManager.cancel_expedition_replacement()
	GameManager.set_reduced_motion_enabled(true)
	_screen = SelectionProbe.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	await wait_process_frames(3)


func after_each() -> void:
	GameManager.cancel_expedition_replacement()
	if is_instance_valid(_screen):
		_screen.queue_free()
	await wait_process_frames(2)
	GameManager.expedition_save_path = _previous_path
	GameManager.set_reduced_motion_enabled(_previous_reduced_motion)
	assert_eq(_hash(ExpeditionSaveService.SAVE_PATH), _player_hash, "The player checkpoint is never modified")


func test_both_catabase_appearances_ask_and_cancel_without_modifying_checkpoint() -> void:
	for index in [0, 1]:
		assert_true(_screen.select_character(index))
		assert_true((_screen.get_selected_entry().run as RunData).catabase_route_enabled)
		_screen.start_button.pressed.emit()
		await wait_process_frames(2)
		var dialog := _screen.get_node_or_null("ReplaceExpeditionConfirmation") as ConfirmationDialog
		assert_not_null(dialog)
		if dialog == null:
			return
		assert_true(dialog.visible)
		assert_true(dialog.get_cancel_button().has_focus())
		assert_eq(_screen.launch_requests, 0)
		assert_eq(_hash(_fixture_path), _fixture_hash)
		dialog.get_cancel_button().pressed.emit()
		await wait_process_frames(2)
		assert_false(dialog.visible)
		assert_true(_screen.start_button.has_focus())
		assert_eq(_screen.launch_requests, 0)
		assert_eq(_hash(_fixture_path), _fixture_hash)
		assert_false(GameManager.confirm_expedition_replacement(_screen._replacement_token))


func test_confirm_grants_a_single_launch_for_the_selected_painted_appearance() -> void:
	assert_true(_screen.select_character(1))
	_screen.start_button.pressed.emit()
	await wait_process_frames(2)
	var dialog := _screen.get_node_or_null("ReplaceExpeditionConfirmation") as ConfirmationDialog
	assert_not_null(dialog)
	if dialog == null:
		return
	var token := _screen._replacement_token
	assert_false(token.is_empty())
	dialog.get_ok_button().pressed.emit()
	await wait_process_frames(2)
	assert_false(dialog.visible)
	assert_eq(_screen.launch_requests, 1)
	assert_eq(_screen.launched_entries, [&"achilles_painted_g"])
	assert_eq(_hash(_fixture_path), _fixture_hash, "The actual new entry, not UI confirmation, replaces the file")
	assert_false(GameManager.confirm_expedition_replacement(token), "The same confirmation cannot be replayed")


func test_trial_and_all_trio_choices_launch_without_replacement_confirmation() -> void:
	for index in [2, 3, 4, 5]:
		assert_true(_screen.select_character(index))
		var run := _screen.get_selected_entry().run as RunData
		assert_false(run.catabase_route_enabled)
		_screen.start_button.pressed.emit()
		await wait_process_frames(2)
		assert_false(_screen._is_replacement_open())
		assert_eq(_screen.launch_requests, index - 1)
		assert_eq(_hash(_fixture_path), _fixture_hash)
	assert_eq((_screen.get_selected_entry().run as RunData).resource_path, "res://data/runs/philosopher_trial.tres")


func test_confirmation_rejects_a_checkpoint_changed_while_the_dialog_is_open() -> void:
	_screen.start_button.pressed.emit()
	await wait_process_frames(2)
	var dialog := _screen.get_node_or_null("ReplaceExpeditionConfirmation") as ConfirmationDialog
	assert_not_null(dialog)
	if dialog == null:
		return
	var checkpoint := ExpeditionSaveService.read_snapshot(_fixture_path)
	checkpoint["external_revision"] = 2
	assert_true(ExpeditionSaveService.write_snapshot(checkpoint, _fixture_path))
	var updated_hash := _hash(_fixture_path)
	dialog.get_ok_button().pressed.emit()
	await wait_process_frames(2)
	assert_eq(_screen.launch_requests, 0)
	assert_false(dialog.visible)
	assert_string_contains(_screen._status.text, "sauvegarde a changé")
	assert_true(_screen.start_button.has_focus())
	assert_eq(_hash(_fixture_path), updated_hash)


func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
