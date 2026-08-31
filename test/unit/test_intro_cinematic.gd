extends GutTest

const CINEMATIC_SCENE := preload("res://cinematics/intro/intro_cinematic.tscn")
const CATABASE_SEQUENCE: CinematicSequenceData = preload(
	"res://cinematics/catabase/catabase_intro_v4.tres"
)
const LEGACY_SEQUENCE: CinematicSequenceData = preload(
	"res://cinematics/intro/sequences/legacy_intro_sequence.tres"
)
const CATABASE_RUN: RunData = preload("res://data/runs/odyssey.tres")
const RunManagerSpyScript := preload("res://test/unit/helpers/intro_run_manager_spy.gd")


func test_scene_has_required_tree_and_audio_buses() -> void:
	var cinematic := await _spawn(LEGACY_SEQUENCE)
	for path in [
		"Background",
		"IllustrationFrame",
		"IllustrationFrame/ImageA",
		"IllustrationFrame/ImageB",
		"TextLayer",
		"BlackFade",
		"SkipButton",
		"VoicePlayer",
		"MusicPlayer",
		"SfxPlayer",
	]:
		assert_not_null(cinematic.get_node_or_null(path), path)
	assert_eq(cinematic.voice_player.bus, &"Voice")
	assert_eq(cinematic.music_player.bus, &"Music")
	assert_eq(cinematic.sfx_player.bus, &"SFX")
	assert_eq(cinematic.sequence.sequence_id, &"legacy_intro")
	assert_eq(cinematic.get_loaded_illustration_count(), 9)


func test_configured_catabase_selects_its_data_driven_sequence() -> void:
	var spy := RunManagerSpyScript.new()
	spy.next_run_data = CATABASE_RUN
	add_child_autofree(spy)
	var cinematic := await _spawn(null, spy)
	assert_eq(cinematic.sequence, CATABASE_SEQUENCE)
	assert_eq(cinematic.get_loaded_illustration_count(), 10)


func test_catabase_music_is_not_the_timeline_clock() -> void:
	assert_almost_eq(CATABASE_SEQUENCE.duration_seconds, 72.0, 0.0001)
	assert_not_null(CATABASE_SEQUENCE.music_stream)
	assert_gt(CATABASE_SEQUENCE.music_stream.get_length(), 80.0)
	assert_lt(CATABASE_SEQUENCE.music_stream.get_length(), 80.2)
	assert_ne(
		CATABASE_SEQUENCE.music_stream.get_length(),
		CATABASE_SEQUENCE.duration_seconds,
	)
	var cinematic := await _spawn(CATABASE_SEQUENCE)
	assert_false(cinematic.voice_player.finished.is_connected(cinematic.finish_cinematic))


func test_missing_optional_music_does_not_block_sequence() -> void:
	var silent := CATABASE_SEQUENCE.duplicate(true) as CinematicSequenceData
	silent.music_stream = null
	silent.exit_fade_seconds = 0.0
	var spy := RunManagerSpyScript.new()
	spy.next_run_data = CATABASE_RUN
	add_child_autofree(spy)
	var cinematic := await _spawn(silent, spy)
	cinematic._begin_playback()
	await wait_process_frames(2)
	assert_push_warning("musique optionnelle absente")
	assert_false(cinematic.music_player.playing)
	cinematic.finish_cinematic()
	await wait_process_frames(2)
	assert_eq(spy.start_call_count, 1)


func test_missing_required_frame_fails_validation() -> void:
	var invalid := CATABASE_SEQUENCE.duplicate(true) as CinematicSequenceData
	var frames: Array[CinematicFrameData] = []
	frames.assign(invalid.frames)
	var missing := frames[0].duplicate(true) as CinematicFrameData
	missing.texture = null
	frames[0] = missing
	invalid.frames = frames
	assert_false(invalid.is_valid())
	assert_string_contains(str(invalid.validation_errors()), "texture")


func test_cinematic_skip_completes_once() -> void:
	var fixture := await _completion_fixture()
	var cinematic: IntroCinematic = fixture.cinematic
	var spy = fixture.spy
	cinematic.request_skip()
	cinematic.request_skip()
	await wait_seconds(0.35)
	assert_true(cinematic.completion_committed)
	assert_true(cinematic.is_exit_requested())
	assert_eq(spy.start_call_count, 1)
	assert_null(spy.next_run_data)


func test_cinematic_timeout_completes_once() -> void:
	var fixture := await _completion_fixture()
	var cinematic: IntroCinematic = fixture.cinematic
	var spy = fixture.spy
	cinematic.finish_cinematic()
	cinematic.finish_cinematic()
	await wait_process_frames(2)
	assert_eq(spy.start_call_count, 1)
	assert_true(cinematic.has_started_run())


func test_skip_and_timeout_cannot_double_start_run() -> void:
	var fixture := await _completion_fixture()
	var cinematic: IntroCinematic = fixture.cinematic
	var spy = fixture.spy
	cinematic.request_skip()
	cinematic.finish_cinematic()
	cinematic._process(999.0)
	await wait_seconds(0.35)
	assert_eq(spy.start_call_count, 1)


func test_audio_is_stopped_on_skip_and_scene_exit() -> void:
	var sequence := CATABASE_SEQUENCE.duplicate(true) as CinematicSequenceData
	sequence.exit_fade_seconds = 0.0
	var spy := RunManagerSpyScript.new()
	spy.next_run_data = CATABASE_RUN
	add_child_autofree(spy)
	var cinematic := await _spawn(sequence, spy)
	cinematic._begin_playback()
	await wait_process_frames(2)
	assert_true(cinematic.music_player.playing)
	cinematic.request_skip()
	await wait_seconds(0.35)
	assert_false(cinematic.music_player.playing)
	assert_false(cinematic.voice_player.playing)


func test_catabase_progressive_context_and_title_cues_render_at_runtime() -> void:
	var cinematic := await _spawn(CATABASE_SEQUENCE)
	cinematic.synchronize_to_time(0.6)
	assert_eq(cinematic.get_active_texts(), PackedStringArray(["TROIE"]))
	cinematic.synchronize_to_time(4.2)
	assert_eq(cinematic.get_active_texts().size(), 4)
	assert_has(cinematic.get_active_texts(), "DIXIÈME ANNÉE DU SIÈGE")
	cinematic.synchronize_to_time(68.7)
	assert_has(cinematic.get_active_texts(), "CATABASE")
	assert_has(cinematic.get_active_texts(), "I — L’OMBRE DE PARIS")


func test_frame_crossfade_never_loads_texture_during_transition() -> void:
	var cinematic := await _spawn(CATABASE_SEQUENCE)
	cinematic.synchronize_to_time(10.8)
	assert_eq(cinematic.image_a.texture, CATABASE_SEQUENCE.frames[2].texture)
	assert_eq(cinematic.image_b.texture, CATABASE_SEQUENCE.frames[1].texture)
	assert_gt(cinematic.image_a.modulate.a, 0.0)
	assert_lt(cinematic.image_a.modulate.a, 1.0)
	assert_lte(cinematic.image_a.scale.x, 1.04)


func _spawn(
		requested_sequence: CinematicSequenceData,
		manager: Node = null,
	) -> IntroCinematic:
	var cinematic := CINEMATIC_SCENE.instantiate() as IntroCinematic
	cinematic.autoplay = false
	cinematic.sequence_override = requested_sequence
	cinematic.run_manager_override = manager
	add_child_autofree(cinematic)
	await wait_process_frames(2)
	return cinematic


func _completion_fixture() -> Dictionary:
	var sequence := CATABASE_SEQUENCE.duplicate(true) as CinematicSequenceData
	sequence.exit_fade_seconds = 0.0
	var spy := RunManagerSpyScript.new()
	spy.next_run_data = CATABASE_RUN
	add_child_autofree(spy)
	var cinematic := await _spawn(sequence, spy)
	return {"cinematic": cinematic, "spy": spy}
