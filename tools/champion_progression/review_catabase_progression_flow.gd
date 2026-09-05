extends SceneTree

const OUTPUT := "res://artifacts/achilles_theorycraft_integration"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager = root.get_node("GameManager")
	var run = load("res://data/runs/odyssey.tres")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	manager.set_reduced_motion_enabled(true)
	if not manager._prepare_preconfigured_run(run, manager.resolve_run_hero_data(run).heroes):
		quit(2)
		return
	manager.current_room_index = 0
	var state = manager.get_ordered_character_states()[0]
	manager.set_current_glory_challenge_accepted(true)
	manager.begin_combat_report()
	state.unit.current_hp = 72
	manager.on_battle_won()
	for _frame in 15:
		await process_frame
	var screen = current_scene
	if screen == null or not screen.has_method("get_champion_summary_snapshots"):
		push_error("POST_COMBAT_SCENE_NOT_OPENED")
		quit(2)
		return
	screen._enter_phase(3)
	await _capture("catabase_1280x720_bilan.png")
	print("CHAMPION_SUMMARY ", JSON.stringify(screen.get_champion_summary_snapshots()))
	screen._open_champion_preparation(state.character_id)
	for _frame in 3:
		await process_frame
	var host = screen._champion_codex_screen
	host.get_champion_codex().select_section(&"attributes")
	await _capture("catabase_1280x720_investissement.png")
	host.close_screen()
	for _frame in 3:
		await process_frame
	screen._open_champion_camp()
	await _capture("catabase_1280x720_chiron.png")
	print("CHAMPION_FLOW_REVIEW_OK")
	manager.cleanup_run_state()
	screen.queue_free()
	for _frame in 4:
		await process_frame
	quit(0)


func _capture(file_name: String) -> void:
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var error := capture.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(file_name)))
	print("CHAMPION_FLOW_CAPTURE ", file_name, " ", error)
