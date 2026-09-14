extends GutTest
const Soundtrack := preload("res://core/audio/title_soundtrack.gd")
const Catalog := preload("res://core/audio/title_music_catalog.gd")
var _settings_path := ""


func before_each() -> void:
	_settings_path = "user://title-music-test-%d.cfg" % Time.get_ticks_usec()


func after_each() -> void:
	if FileAccess.file_exists(_settings_path):
		DirAccess.remove_absolute(_settings_path)


func _player() -> AudioStreamPlayer:
	var music := Soundtrack.new()
	music.settings_path = _settings_path
	music.fade_seconds = 0.0
	add_child_autofree(music)
	return music


func test_all_eight_local_tracks_load_and_default_is_quiet_loop() -> void:
	assert_eq(Catalog.TRACKS.size(), 8)
	for index in Catalog.TRACKS.size():
		var track := load(Catalog.resource_path(index)) as AudioStreamOggVorbis
		assert_not_null(track)
		assert_gt(track.get_length(), 120.0)
		assert_true(str(Catalog.TRACKS[index].source).begins_with("https://"))
	var music := _player()
	assert_eq(music.selected_index, 0)
	assert_true(music.playing)
	assert_true(music.stream.loop)
	assert_eq(music.bus, &"Music")
	assert_almost_eq(music.volume_db, -6.0206, 0.01)


func test_selected_track_and_silence_survive_player_recreation() -> void:
	var first := _player()
	first.select_track(7)
	first.set_level(0.0)
	var saved := ConfigFile.new()
	assert_eq(saved.load(_settings_path), OK)
	assert_eq(saved.get_value("music", "track"), "summoning")
	first.free()
	var resumed := _player()
	assert_eq(resumed.selected_index, 7)
	assert_eq(resumed.level, 0.0)
	assert_lte(resumed.volume_db, -80.0)
	assert_almost_eq(resumed.stream.get_length(), load(Catalog.resource_path(7)).get_length(), 0.01)


func test_fast_selection_changes_cancel_old_fades_and_exit_releases_stream() -> void:
	var music := _player()
	music.fade_seconds = 0.12
	music.select_track(1)
	music.select_track(3)
	music.set_level(0.2)
	music.select_track(2)
	await get_tree().create_timer(0.25).timeout
	assert_eq(music.selected_index, 2)
	assert_true(music.playing)
	assert_almost_eq(music.stream.get_length(), load(Catalog.resource_path(2)).get_length(), 0.01)
	assert_almost_eq(music.volume_db, linear_to_db(0.2), 0.01)
	remove_child(music)
	assert_false(music.playing)
	assert_null(music.stream)
	music.free()


func test_title_controls_select_volume_and_expose_all_credits() -> void:
	var title := load("res://ui/TitreEcran.tscn").instantiate() as Node
	var music := title.get_node("AudioStreamPlayer")
	music.settings_path = _settings_path
	music.fade_seconds = 0.0
	# Headless GUT uses a 64 px root; render the title at a supported game size.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	viewport.add_child(title)
	await get_tree().process_frame
	await get_tree().process_frame
	var controls := title.get_node("UI/TitleMusicControls")
	assert_eq(controls.selector.item_count, 8)
	controls.selector.item_selected.emit(4)
	assert_eq(music.selected_index, 4)
	assert_eq(controls.selector.selected, 4)
	controls.volume.value = 31
	assert_almost_eq(music.level, 0.31, 0.001)
	assert_true(
		title.get_viewport_rect().encloses(controls.get_global_rect()),
		"viewport=%s panel=%s" % [title.get_viewport_rect(), controls.get_global_rect()],
	)
	var credits: RichTextLabel = controls.get_node("TitleMusicCredits").find_children(
		"*",
		"RichTextLabel",
		false,
		false,
	)[0]
	for track in Catalog.TRACKS:
		assert_true(credits.text.contains(track.title))
		assert_true(credits.text.contains(track.author))
	assert_true(credits.text.contains("https://creativecommons.org/licenses/by/4.0/"))
