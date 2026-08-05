extends GutTest

const CINEMATIC_SCENE := preload("res://cinematics/intro/intro_cinematic.tscn")
const RunManagerSpyScript := preload("res://test/unit/helpers/intro_run_manager_spy.gd")
const MUSIC_PATH := "res://cinematics/intro/audio/The Heart of Dawn.mp3"

const EXPECTED_REGIONS := [
	Rect2(0, 0, 554, 311),
	Rect2(559, 0, 554, 311),
	Rect2(1118, 0, 554, 311),
	Rect2(0, 316, 554, 309),
	Rect2(559, 316, 554, 309),
	Rect2(1118, 316, 554, 309),
	Rect2(0, 630, 554, 311),
	Rect2(559, 630, 554, 311),
	Rect2(1118, 630, 554, 311),
]

var cinematic: IntroCinematic


func before_each() -> void:
	cinematic = CINEMATIC_SCENE.instantiate() as IntroCinematic
	cinematic.autoplay = false
	add_child_autofree(cinematic)
	await wait_process_frames(2)


func test_scene_has_required_tree_and_audio_buses() -> void:
	for path in [
		"Background",
		"IllustrationFrame",
		"IllustrationFrame/ImageA",
		"IllustrationFrame/ImageB",
		"Vignette",
		"SubtitlePanel",
		"SubtitlePanel/Subtitle",
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
	assert_eq(cinematic.music_path, MUSIC_PATH)
	assert_almost_eq(cinematic.music_volume_db, -18.0, 0.001)
	assert_almost_eq(cinematic.music_fade_in_duration, 1.5, 0.001)
	assert_almost_eq(cinematic.music_fade_out_duration, 1.0, 0.001)
	assert_almost_eq(cinematic.music_player.volume_db, -40.0, 0.001)
	assert_gte(AudioServer.get_bus_index(&"Voice"), 0)
	assert_gte(AudioServer.get_bus_index(&"Music"), 0)
	assert_gte(AudioServer.get_bus_index(&"SFX"), 0)


func test_storyboard_and_narration_keep_their_real_source_properties() -> void:
	var storyboard := load(
		"res://cinematics/intro/source/intro_storyboard.png"
	) as Texture2D
	var narration := load(
		"res://cinematics/intro/audio/intro_narration.mp3"
	) as AudioStream
	assert_not_null(storyboard)
	assert_eq(storyboard.get_size(), Vector2(1672.0, 941.0))
	assert_not_null(narration)
	assert_almost_eq(narration.get_length(), 94.46, 0.06)
	assert_true(ResourceLoader.exists(MUSIC_PATH), "le chemin MP3 avec espace est importé")
	var music := load(MUSIC_PATH) as AudioStream
	assert_not_null(music)
	assert_true(music is AudioStreamMP3)
	assert_gt(music.get_length(), narration.get_length())


func test_run_configuree_dans_le_hub_remplace_le_parcours_par_defaut() -> void:
	var spy := RunManagerSpyScript.new()
	spy.next_run_data = load(
		"res://data/runs/fixed_trio_prototype_run.tres"
	) as RunData
	add_child_autofree(spy)
	cinematic.run_manager_override = spy
	var configuration := cinematic._resolve_run_configuration()
	assert_false(configuration.is_empty())
	assert_eq(configuration["run_data"].run_name, "Run de test")
	assert_null(spy.next_run_data)


func test_music_and_voice_start_once_on_separate_players_and_buses() -> void:
	cinematic.music_fade_in_duration = 0.0
	cinematic._begin_playback()
	await wait_process_frames(2)
	assert_true(cinematic.voice_player.playing)
	assert_true(cinematic.music_player.playing)
	assert_ne(cinematic.voice_player.stream, cinematic.music_player.stream)
	assert_eq(cinematic.voice_player.bus, &"Voice")
	assert_eq(cinematic.music_player.bus, &"Music")
	assert_eq(cinematic.music_player.stream.resource_path, MUSIC_PATH)
	assert_almost_eq(cinematic.music_player.volume_db, -18.0, 0.001)
	var stream := cinematic.music_player.stream
	cinematic.music_player.volume_db = -21.0
	cinematic._load_and_play_optional_music()
	assert_eq(cinematic.music_player.stream, stream)
	assert_almost_eq(
		cinematic.music_player.volume_db,
		-21.0,
		0.001,
		"un second appel ne redémarre ni ne recalibre la musique",
	)


func test_music_fade_in_is_local_and_preserves_player_bus_settings() -> void:
	var music_bus := AudioServer.get_bus_index(&"Music")
	var voice_bus := AudioServer.get_bus_index(&"Voice")
	var original_music_db := AudioServer.get_bus_volume_db(music_bus)
	var original_voice_db := AudioServer.get_bus_volume_db(voice_bus)
	AudioServer.set_bus_volume_db(music_bus, -7.0)
	AudioServer.set_bus_volume_db(voice_bus, -3.0)
	cinematic.music_volume_db = -22.0
	cinematic.music_fade_in_duration = 0.0
	cinematic._begin_playback()
	await wait_process_frames(2)
	assert_almost_eq(cinematic.music_player.volume_db, -22.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(music_bus), -7.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(voice_bus), -3.0, 0.001)
	AudioServer.set_bus_volume_db(music_bus, original_music_db)
	AudioServer.set_bus_volume_db(voice_bus, original_voice_db)


func test_music_fade_in_reaches_exported_local_target() -> void:
	cinematic.music_fade_in_duration = 0.05
	cinematic._begin_playback()
	assert_true(cinematic.music_player.playing)
	assert_almost_eq(cinematic.music_player.volume_db, -40.0, 0.01)
	await wait_seconds(0.1)
	assert_almost_eq(cinematic.music_player.volume_db, -18.0, 0.05)


func test_nine_plan_changes_never_restart_or_cut_music() -> void:
	cinematic.music_fade_in_duration = 0.0
	cinematic._begin_playback()
	await wait_process_frames(2)
	var stream := cinematic.music_player.stream
	cinematic.music_player.volume_db = -19.5
	for start_time in [0.0, 13.0, 25.0, 34.0, 42.0, 51.0, 59.0, 67.0, 84.0]:
		cinematic.synchronize_to_time(start_time)
		assert_true(cinematic.music_player.playing)
		assert_eq(cinematic.music_player.stream, stream)
		assert_almost_eq(cinematic.music_player.volume_db, -19.5, 0.001)


func test_natural_voice_finish_fades_and_stops_music_before_run_start() -> void:
	var spy := RunManagerSpyScript.new()
	add_child_autofree(spy)
	cinematic.run_manager_override = spy
	cinematic.music_fade_in_duration = 0.0
	cinematic.music_fade_out_duration = 0.0
	cinematic.exit_fade_duration = 0.0
	cinematic._begin_playback()
	await wait_process_frames(2)
	assert_true(cinematic.music_player.playing)
	cinematic.voice_player.finished.emit()
	await wait_process_frames(3)
	assert_false(cinematic.music_player.playing)
	assert_false(cinematic.voice_player.playing)
	assert_eq(spy.start_call_count, 1)


func test_skip_immediate_uses_guard_and_stops_music_once() -> void:
	var spy := RunManagerSpyScript.new()
	add_child_autofree(spy)
	cinematic.run_manager_override = spy
	cinematic.music_fade_out_duration = 0.0
	cinematic.exit_fade_duration = 0.0
	cinematic._begin_playback()
	assert_true(cinematic.music_player.playing)
	cinematic.skip_button.pressed.emit()
	cinematic.skip_button.pressed.emit()
	await wait_process_frames(3)
	assert_false(cinematic.music_player.playing)
	assert_true(cinematic.is_exit_requested())
	assert_eq(spy.start_call_count, 1)


func test_skip_during_music_fade_in_replaces_it_with_same_exit_fade() -> void:
	var spy := RunManagerSpyScript.new()
	add_child_autofree(spy)
	cinematic.run_manager_override = spy
	cinematic.music_fade_in_duration = 1.5
	cinematic.music_fade_out_duration = 0.05
	cinematic.exit_fade_duration = 0.0
	cinematic._begin_playback()
	await wait_process_frames(2)
	assert_true(cinematic.music_player.playing)
	assert_not_null(cinematic._music_fade_tween)
	assert_true(cinematic._music_fade_tween.is_running())
	cinematic.request_skip()
	await wait_seconds(0.1)
	assert_false(cinematic.music_player.playing)
	assert_almost_eq(cinematic.music_player.volume_db, -40.0, 0.01)
	assert_eq(spy.start_call_count, 1)


func test_missing_and_invalid_music_warn_without_blocking_cinematic() -> void:
	cinematic.music_path = "res://cinematics/intro/audio/missing_music.mp3"
	cinematic._begin_playback()
	await wait_process_frames(2)
	assert_push_warning("musique absente")
	assert_false(cinematic.music_player.playing)
	assert_true(cinematic.voice_player.playing)

	var invalid := CINEMATIC_SCENE.instantiate() as IntroCinematic
	invalid.autoplay = false
	invalid.music_path = "res://data/runs/first_run.tres"
	add_child_autofree(invalid)
	await wait_process_frames(2)
	invalid._begin_playback()
	await wait_process_frames(2)
	assert_push_warning("musique illisible")
	assert_false(invalid.music_player.playing)
	assert_true(invalid.voice_player.playing)


func test_destroying_cinematic_destroys_its_playing_music_player() -> void:
	cinematic.music_fade_in_duration = 0.0
	cinematic._begin_playback()
	await wait_process_frames(2)
	assert_true(cinematic.music_player.playing)
	var music_player_ref: WeakRef = weakref(cinematic.music_player)
	cinematic.queue_free()
	await wait_process_frames(2)
	assert_null(music_player_ref.get_ref())


func test_nine_atlas_regions_exclude_the_separator_lines() -> void:
	assert_eq(cinematic.illustration_paths.size(), 9)
	for index in range(cinematic.illustration_paths.size()):
		var texture := load(cinematic.illustration_paths[index]) as AtlasTexture
		assert_not_null(texture, cinematic.illustration_paths[index])
		assert_eq(texture.region, EXPECTED_REGIONS[index])
		assert_true(texture.filter_clip)
		assert_eq(
			texture.atlas.resource_path,
			"res://cinematics/intro/source/intro_storyboard.png"
		)
	assert_eq(cinematic.get_loaded_illustration_count(), 9)


func test_timeline_is_monotone_and_uses_requested_plan_starts() -> void:
	var starts := [0.0, 13.0, 25.0, 34.0, 42.0, 51.0, 59.0, 67.0, 84.0]
	for index in range(starts.size()):
		cinematic.synchronize_to_time(starts[index])
		assert_eq(cinematic.get_current_plan_index(), index)
	cinematic.synchronize_to_time(13.0)
	assert_eq(
		cinematic.get_current_plan_index(),
		8,
		"L’horloge calculée ne peut pas revenir en arrière."
	)


func test_crossfade_and_ken_burns_remain_subtle() -> void:
	cinematic.synchronize_to_time(13.0)
	var incoming := cinematic.image_b
	var outgoing := cinematic.image_a
	assert_almost_eq(incoming.modulate.a, 0.0, 0.001)
	assert_almost_eq(outgoing.modulate.a, 1.0, 0.001)
	cinematic.synchronize_to_time(13.45)
	assert_almost_eq(incoming.modulate.a, 0.5, 0.02)
	assert_almost_eq(outgoing.modulate.a, 0.5, 0.02)
	cinematic.synchronize_to_time(13.9)
	assert_almost_eq(incoming.modulate.a, 1.0, 0.001)
	assert_lte(incoming.scale.x, 1.04)
	assert_gte(incoming.scale.x, 1.0)
	assert_eq(incoming.scale.x, incoming.scale.y)


func test_skip_during_crossfade_starts_the_fixed_trio_once() -> void:
	var spy := RunManagerSpyScript.new()
	add_child_autofree(spy)
	cinematic.run_manager_override = spy
	cinematic.exit_fade_duration = 0.0
	cinematic.synchronize_to_time(13.45)
	cinematic.request_skip()
	cinematic.request_skip()
	await wait_process_frames(3)
	assert_true(cinematic.is_exit_requested())
	assert_true(cinematic.has_started_run())
	assert_true(cinematic.run_start_committed)
	assert_eq(spy.start_call_count, 1)
	assert_eq(
		spy.received_hero_sources.map(func(hero): return hero.unit_name),
		["Elfe", "Mage", "Guerrier"]
	)


func test_normal_finish_and_skip_share_the_same_guarded_exit() -> void:
	var spy := RunManagerSpyScript.new()
	add_child_autofree(spy)
	cinematic.run_manager_override = spy
	cinematic.exit_fade_duration = 0.0
	cinematic.finish_cinematic()
	cinematic.request_skip()
	await wait_process_frames(3)
	assert_eq(spy.start_call_count, 1)


func test_missing_visual_asset_keeps_subtitles_and_safe_exit() -> void:
	var missing := CINEMATIC_SCENE.instantiate() as IntroCinematic
	missing.autoplay = false
	missing.illustration_paths = ["res://cinematics/intro/atlas/missing.tres"]
	add_child_autofree(missing)
	await wait_process_frames(2)
	assert_eq(missing.get_loaded_illustration_count(), 0)
	assert_false(missing.subtitle.text.is_empty())
	var spy := RunManagerSpyScript.new()
	add_child_autofree(spy)
	missing.run_manager_override = spy
	missing.exit_fade_duration = 0.0
	missing.request_skip()
	await wait_process_frames(3)
	assert_eq(spy.start_call_count, 1)


func test_missing_run_configuration_never_calls_manager_twice_or_once() -> void:
	var spy := RunManagerSpyScript.new()
	add_child_autofree(spy)
	cinematic.run_manager_override = spy
	cinematic.run_data_path = "res://data/runs/missing_intro_run.tres"
	cinematic.fallback_scene_path = ""
	cinematic.exit_fade_duration = 0.0
	cinematic.request_skip()
	cinematic.finish_cinematic()
	await wait_process_frames(3)
	assert_push_error("Configuration de la première run indisponible")
	assert_eq(spy.start_call_count, 0)
	assert_false(cinematic.has_started_run())


func test_subtitles_can_be_disabled_without_touching_timeline() -> void:
	cinematic.set_subtitles_enabled(false)
	assert_false(cinematic.subtitle_panel.visible)
	cinematic.synchronize_to_time(42.0)
	assert_eq(cinematic.get_current_plan_index(), 4)
	cinematic.set_subtitles_enabled(true)
	assert_true(cinematic.subtitle_panel.visible)
	assert_false(cinematic.subtitle.text.is_empty())
