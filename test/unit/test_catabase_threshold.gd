extends GutTest
const RUN := preload("res://data/runs/odyssey.tres")
const INTRO := preload("res://cinematics/intro/intro_cinematic.tscn")
const ThresholdNavigation := preload("res://hub/catabase_threshold/threshold_navigation.gd")
const ThresholdInteractions := preload("res://hub/catabase_threshold/threshold_interactions.gd")
const ENTRY := preload("res://hub/catabase_threshold/CatabaseThreshold.tscn")
var manager: EntryManager
var _source_variants: Dictionary
var _source_exit_fade: float


class EntryManager extends "res://core/game_manager.gd":
	var scenes: Array[String] = []
	var battles := 0
	var fail_writes := false


	func _request_scene_change(
		path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		scenes.append(path)


	func start_next_battle() -> void:
		battles += 1


	func save_expedition(path: String = ExpeditionSaveService.SAVE_PATH) -> bool:
		if fail_writes:
			_set_expedition_save_status(false, "start_combat")
			return false
		return super.save_expedition(path)


func before_each() -> void:
	_source_variants = RUN.hero_visual_variants.duplicate(true)
	_source_exit_fade = RUN.intro_sequence.exit_fade_seconds
	manager = EntryManager.new()
	manager.expedition_save_path = "user://catabase_threshold_tests/entry_%d.json" % Time.get_ticks_usec()
	add_child_autofree(manager)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://catabase_threshold_tests")
	)


func after_each() -> void:
	manager.cleanup_run_state()
	# Retire queued persistent UI/windows before another scene is exercised.
	await wait_process_frames(2)
	assert_false(get_tree().paused, "Threshold tests must not leave the shared tree paused")
	assert_eq(
		RUN.hero_visual_variants,
		_source_variants,
		"The canonical run appearance stays untouched",
	)
	assert_eq(
		RUN.intro_sequence.exit_fade_seconds,
		_source_exit_fade,
		"The canonical cinematic stays untouched",
	)
	if FileAccess.file_exists(manager.expedition_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.expedition_save_path))


func _configure(painted := false, protect_existing := false) -> RunData:
	if protect_existing:
		var file := FileAccess.open(manager.expedition_save_path, FileAccess.WRITE)
		file.store_string("{\"protected_previous_save\":true}")
		file.close()
		var guard: Dictionary = manager.get_expedition_replacement_guard()
		assert_true(manager.confirm_expedition_replacement(str(guard.token)))
	var selected := RUN.duplicate(false) as RunData
	assert_not_same(selected, RUN)
	selected.set_path_cache("")
	selected.hero_visual_variants = { "achilles": "painted_g" } if painted else { }
	assert_true(manager.configure_next_run(selected, 0))
	return selected


func test_intro_handoff_preserves_selection_and_previous_save_until_the_gate() -> void:
	var selected := _configure(true, true)
	var before := FileAccess.get_sha256(manager.expedition_save_path)
	assert_true(manager.continue_after_intro())
	assert_true(manager.continue_after_intro(), "A repeated handoff never opens a second entry")
	assert_eq(manager.scenes, [manager.CATABASE_THRESHOLD_SCREEN_PATH])
	assert_same(manager.peek_next_run_data(), selected)
	assert_true(manager.has_catabase_threshold_configuration())
	assert_false(manager.run_active)
	assert_null(manager.expedition)
	assert_eq(manager.battles, 0)
	assert_eq(FileAccess.get_sha256(manager.expedition_save_path), before)
	assert_true(manager.finish_catabase_threshold().success)
	assert_eq(manager.battles, 1)
	assert_eq(manager.expedition.route.current_node_id, "d01_0")
	assert_eq(manager.get_active_run_data().hero_visual_variants, { "achilles": "painted_g" })
	assert_ne(FileAccess.get_sha256(manager.expedition_save_path), before)
	assert_false(manager.finish_catabase_threshold().success)
	assert_eq(manager.battles, 1)
	assert_null(manager.peek_next_run_data())


func test_cancelling_the_entry_preserves_the_save_and_invalidates_the_departure() -> void:
	_configure(false, true)
	var before := FileAccess.get_sha256(manager.expedition_save_path)
	assert_true(manager.continue_after_intro())
	manager.cancel_catabase_threshold()
	assert_false(manager.finish_catabase_threshold().success)
	assert_false(manager.has_next_run_configuration())
	assert_eq(FileAccess.get_sha256(manager.expedition_save_path), before)
	assert_eq(manager.battles, 0)


func test_a_changed_save_during_the_visit_requires_new_consent() -> void:
	var selected := _configure(false, true)
	assert_true(manager.continue_after_intro())
	var file := FileAccess.open(manager.expedition_save_path, FileAccess.WRITE)
	file.store_string("{\"external_writer\":true}")
	file.close()
	var before := FileAccess.get_sha256(manager.expedition_save_path)
	var result: Dictionary = manager.finish_catabase_threshold()
	assert_false(result.success)
	assert_false(result.pending)
	assert_same(manager.peek_next_run_data(), selected)
	assert_eq(manager.battles, 0)
	assert_eq(FileAccess.get_sha256(manager.expedition_save_path), before)


func test_failed_first_checkpoint_retries_the_write_without_creating_another_run() -> void:
	_configure(true)
	assert_true(manager.continue_after_intro())
	manager.fail_writes = true
	var result: Dictionary = manager.finish_catabase_threshold()
	assert_false(result.success)
	assert_true(result.pending)
	assert_true(manager.run_active)
	assert_eq(manager.battles, 0)
	var prepared: ExpeditionSession = manager.expedition
	assert_false(manager.finish_catabase_threshold().success)
	assert_same(manager.expedition, prepared)
	manager.fail_writes = false
	assert_true(manager.retry_expedition_save())
	assert_same(manager.expedition, prepared)
	assert_eq(manager.battles, 1)
	assert_false(manager.has_next_run_configuration())


func test_resuming_a_checkpoint_bypasses_both_cinematic_and_threshold() -> void:
	_configure(true)
	assert_true(manager.start_configured_run())
	var saved_seed: int = manager.run_seed
	manager.cleanup_run_state()
	assert_true(manager.resume_expedition())
	assert_eq(manager.battles, 2)
	assert_eq(manager.run_seed, saved_seed)
	assert_eq(manager.get_active_run_data().hero_visual_variants, { "achilles": "painted_g" })
	assert_true(manager.scenes.is_empty())
	assert_false(manager.has_catabase_threshold_configuration())


func test_skip_and_natural_completion_each_handoff_once_without_starting_combat() -> void:
	for skipped in [false, true]:
		var ending := "skip" if skipped else "natural"
		print("THRESHOLD_HANDOFF_TEST: %s configure" % ending)
		_configure()
		manager.scenes.clear()
		print("THRESHOLD_HANDOFF_TEST: %s instantiate" % ending)
		var cinematic := INTRO.instantiate() as IntroCinematic
		cinematic.autoplay = false
		var local_sequence := RUN.intro_sequence.duplicate(false) as CinematicSequenceData
		assert_not_same(local_sequence, RUN.intro_sequence)
		local_sequence.exit_fade_seconds = 0
		cinematic.sequence_override = local_sequence
		cinematic.run_manager_override = manager
		add_child(cinematic)
		await wait_process_frames(2)
		print(
			"THRESHOLD_HANDOFF_TEST: %s ready paused=%s time_scale=%s"
			% [ending, get_tree().paused, Engine.time_scale]
		)
		watch_signals(cinematic)
		if skipped:
			cinematic.request_skip()
		else:
			cinematic.finish_cinematic()
		cinematic.finish_cinematic()
		cinematic.request_skip()
		# The real exit Tween still emits finished and executes continuation.
		# Drive its duration directly instead of waiting on GUT's physics clock.
		if skipped:
			var fade: Tween = cinematic._exit_tween
			assert_not_null(fade, "Skip keeps its actual fade transition")
			if fade != null:
				fade.pause()
				fade.custom_step(0.5)
		print("THRESHOLD_HANDOFF_TEST: %s continuation" % ending)
		await wait_process_frames(2)
		assert_eq(manager.scenes, [manager.CATABASE_THRESHOLD_SCREEN_PATH])
		assert_signal_emit_count(cinematic, "threshold_entry_requested", 1)
		assert_signal_not_emitted(cinematic, "run_start_requested")
		assert_true(cinematic.completion_committed)
		assert_false(cinematic.has_started_run())
		assert_eq(manager.battles, 0)
		assert_eq(RUN.intro_sequence.exit_fade_seconds, _source_exit_fade)
		clear_signal_watcher()
		cinematic.queue_free()
		await wait_process_frames(2)
		manager.cancel_catabase_threshold()
		print("THRESHOLD_HANDOFF_TEST: %s complete" % ending)


func test_direct_scene_visit_reads_memory_and_reaches_gate_without_creating_a_run() -> void:
	var hall = ENTRY.instantiate()
	hall.run_manager_override = manager
	hall.audio_enabled = false
	add_child_autofree(hall)
	for attempt in 180:
		if hall.is_ready_for_play():
			break
		await get_tree().physics_frame
	assert_true(hall.is_ready_for_play())
	if not hall.is_ready_for_play():
		return
	hall.set_process(false)
	assert_false(hall.get_entry_state().configured)
	assert_false(hall.depart().success)
	for id in ["statue_memory", "zeus_memory", "fallen_oath", "threshold_gate"]:
		var index: int = -1
		for candidate in hall.definition.landmarks.size():
			if str(hall.definition.landmarks[candidate].id) == id:
				index = candidate
		assert_gte(index, 0, id)
		if index < 0:
			continue
		var landmark: Dictionary = hall.definition.landmarks[index]
		var focus: Vector2 = hall.point(landmark.focus)
		assert_true(Geometry2D.is_point_in_polygon(focus, hall.polygon(landmark.hit_polygon)))
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = hall.world.to_global(focus)
		hall._unhandled_input(click)
		assert_eq(hall.interactions.pending, index, "The painted plaque or door owns its click")
		var route: PackedVector2Array = hall.get_movement_state().path
		var safe_route := true
		for segment in range(1, route.size()):
			safe_route = safe_route and hall.nav.segment_is_walkable(
					route[segment - 1],
					route[segment],
				)
		assert_true(safe_route, "The approach route preserves each statue: " + id)
		var stays_walkable := true
		for step in 7200:
			hall.advance_world([1.0 / 60.0, 0.05, 0.12][step % 3])
			stays_walkable = stays_walkable and hall.nav.is_walkable(hall.player.position)
			if hall.interactions.active:
				break
		assert_true(stays_walkable, "Variable frame times never cross a statue: " + id)
		assert_true(hall.interactions.active, "The walkable approach must reach " + id)
		if id == "threshold_gate":
			assert_not_null(hall.find_child("ChooseAppearance", true, false))
			assert_false(hall.depart().success, "F6 offers selection, never an arbitrary run")
		else:
			assert_not_null(hall.find_child("CloseMemory", true, false))
		hall.interactions.close()
	assert_false(manager.run_active)
	assert_eq(manager.battles, 0)
	assert_false(FileAccess.file_exists(manager.expedition_save_path))


func test_selected_appearance_is_visible_before_a_run_exists() -> void:
	_configure(true)
	assert_true(manager.continue_after_intro())
	var hall = ENTRY.instantiate()
	hall.run_manager_override = manager
	hall.audio_enabled = false
	add_child_autofree(hall)
	for attempt in 180:
		if hall.is_ready_for_play():
			break
		await get_tree().physics_frame
	assert_true(hall.is_ready_for_play())
	if not hall.is_ready_for_play():
		return
	assert_eq(hall.get_entry_state().variant, "painted_g")
	assert_eq(
		hall.player.sprite_profile.sprite_frames_path,
		RunHeroVisualVariants.PAINTED_FRAMES_PATH,
	)
	assert_true(hall.player.is_visual_ready())
	assert_false(manager.run_active)
	assert_false(FileAccess.file_exists(manager.expedition_save_path))


func test_threshold_ground_assistance_preserves_clearance_and_refuses_distant_clicks() -> void:
	var navigation := ThresholdNavigation.new()
	navigation.foot_radius = 12.0
	var outer := PackedVector2Array(
		[Vector2(0, 0), Vector2(400, 0), Vector2(400, 400), Vector2(0, 400)]
	)
	var statue := PackedVector2Array(
		[Vector2(160, 100), Vector2(240, 100), Vector2(240, 300), Vector2(160, 300)]
	)
	var obstacles: Array[PackedVector2Array] = [statue]
	assert_true(await navigation.configure(outer, obstacles))
	var from := Vector2(40, 200)
	var nearby: Dictionary = navigation.resolve_destination(from, Vector2(-6, 200), 32.0)
	assert_true(nearby.ok, "A nearby missed click reaches the safe edge")
	if nearby.ok:
		assert_true(nearby.adjusted)
		assert_true(navigation.is_walkable(nearby.destination))
		assert_gt(nearby.destination.x, 0.0, "The actor keeps the baked foot clearance")
	assert_false(navigation.resolve_destination(from, Vector2(-80, 200), 32.0).ok)
	assert_false(navigation.resolve_destination(from, Vector2(INF, 200), 32.0).ok)
	var opposite := Vector2(360, 200)
	assert_false(
		navigation.segment_is_walkable(from, opposite),
		"Valid endpoints do not allow crossing the statue",
	)
	var around: Dictionary = navigation.resolve_destination(from, opposite, 32.0)
	assert_true(around.ok)
	if around.ok:
		assert_gt(around.path.size(), 2, "The route goes around the obstruction")
		var valid_segments := true
		for index in range(1, around.path.size()):
			valid_segments = (
				valid_segments
				and navigation.segment_is_walkable(around.path[index - 1], around.path[index])
			)
		assert_true(valid_segments)
	navigation.close()


func test_painted_plaque_shape_is_authoritative_with_legacy_focus_fallback() -> void:
	var hall = ENTRY.instantiate()
	autofree(hall)
	hall.world_size = Vector2(1000, 500)
	hall.definition = {
		"landmarks": [
			{
				"point": [0.25, 0.3],
				"focus": [0.25, 0.15],
				"radius": 0.005,
				"hit_polygon": [[0.1, 0.1], [0.4, 0.1], [0.4, 0.2], [0.1, 0.2]],
			},
			{ "point": [0.75, 0.7], "radius": 0.03 },
		],
	}
	var plaque := ThresholdInteractions.new()
	autofree(plaque)
	plaque.configure(hall, false)
	assert_eq(plaque.hit_test(Vector2(145, 75)), 0, "The plaque edge works beyond the old ellipse")
	assert_eq(
		plaque.hit_test(Vector2(250, 105)),
		-1,
		"An authored shape does not keep an invisible extra radius",
	)
	assert_eq(plaque.hit_test(Vector2(750, 350)), 1, "Older manifests retain their focus behavior")
	assert_eq(plaque.hit_test(Vector2(900, 50)), -1)
