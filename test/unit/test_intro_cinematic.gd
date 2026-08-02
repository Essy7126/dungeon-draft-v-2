extends GutTest

const CINEMATIC_SCENE := preload("res://cinematics/intro/intro_cinematic.tscn")
const RunManagerSpyScript := preload("res://test/unit/helpers/intro_run_manager_spy.gd")

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
