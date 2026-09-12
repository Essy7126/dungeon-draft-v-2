extends "res://tools/run_explorer/run_explorer_preview.gd"
## Isolated audio audition: the production battle and rules remain unchanged.
const AUDIO_FOLDER := "res://artifacts/audio/soft_v5/"
const MUSIC_PATH := "res://artifacts/audio/music_mystery_v1/mysterious_harp.wav"
const SPELL_AUDIO := {
	&"achilles_peleid_strike": &"strike",
	&"achilles_fulminant_dash": &"dash",
	&"achilles_pelion_shot": &"shot",
	&"achilles_bronze_guard": &"guard",
}
var sounds: Dictionary = { }
var voices: Array[AudioStreamPlayer] = []
var audio_enabled := true
var audio_volume := 0.9
var music_volume := 0.5
var _music_stream: AudioStreamWAV
var _music_player: AudioStreamPlayer
var played_count := 0
var last_cue: StringName = &""
var _last_play_ms := -1000
var _bound_view: Node
var _audio_status: Label
var _last_mix_peak_db := -200.0
var _audio_capture: AudioEffectCapture


func _ready() -> void:
	_music_stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(MUSIC_PATH))
	if _music_stream == null:
		_fail("Musique absente : lancer build_mysterious_music.py avant cet essai.")
		return
	_music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_stream.loop_end = _music_stream.data.size() / 4
	for key: StringName in SPELL_AUDIO.values():
		var path := AUDIO_FOLDER.path_join(str(key) + ".wav")
		if not FileAccess.file_exists(path):
			_fail("Sons absents : lancer build_soft_trial.py avant cet essai.")
			return
		var stream := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
		if stream == null:
			_fail("Son illisible : " + path)
			return
		sounds[key] = stream
	for index in 3:
		var voice := AudioStreamPlayer.new()
		voice.name = "TrialVoice%d" % index
		voice.bus = &"SFX"
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		voices.append(voice)
	_audio_capture = AudioEffectCapture.new()
	_audio_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"SFX"), _audio_capture)
	EventBus.spell_cast.connect(_on_audio_spell)
	EventBus.battle_view_ready.connect(_bind_audio_view)
	super._ready()
	print(
		"AUDIO_START "
		+ JSON.stringify(
			{
				"driver": AudioServer.get_driver_name(),
				"device": AudioServer.output_device,
				"pid": OS.get_process_id(),
			}
		)
	)
	if "--audio-verify" in OS.get_cmdline_user_args():
		_verify_audio.call_deferred()


func _bind_audio_view(view: Node) -> void:
	_bound_view = view
	view.tree_exiting.connect(_stop_audio)
	# The map player autoplays on Master. Replace that exact player so the two
	# soundtracks cannot overlap, and route the candidate through Music.
	var production_audio := view.get_parent().get_node_or_null("CombatAudio")
	if production_audio != null:
		production_audio.dispose()
		_music_player = production_audio.music
	else:
		_music_player = view.get_parent().get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	if _music_player == null:
		_fail("Lecteur de musique du combat introuvable.")
		return
	_music_player.stop()
	_music_player.stream = _music_stream
	_music_player.bus = &"Music"
	_set_music_volume(music_volume)
	_music_player.play()


func _set_music_volume(value: float) -> void:
	music_volume = value
	if is_instance_valid(_music_player):
		_music_player.volume_db = linear_to_db(maxf(value, 0.0001))
		_music_player.stream_paused = value <= 0.0


func _on_audio_spell(caster: Unit, spell: Spell, report: Dictionary) -> void:
	if closing or not is_instance_valid(_bound_view) or not _bound_view.is_inside_tree():
		return
	if caster == null or caster.team != 0 or spell == null or report.get("failed", false):
		return
	var key: StringName = SPELL_AUDIO.get(spell.get_effective_spell_id(), &"")
	if key == &"guard" and int(report.get("shield_increase_total", 0)) <= 0:
		return
	if key == &"dash" and int(report.get("movement_count", 0)) <= 0:
		return
	if key in [&"strike", &"shot"] and report.get("damaged_enemies", []).is_empty():
		return
	play_cue(key)


func play_cue(key: StringName) -> bool:
	if closing or not audio_enabled or audio_volume <= 0.0 or not sounds.has(key):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_play_ms < 90:
		return false
	for voice in voices:
		if not voice.playing:
			_audio_capture.clear_buffer()
			voice.stream = sounds[key]
			voice.volume_db = linear_to_db(audio_volume)
			voice.play()
			_last_play_ms = now
			played_count += 1
			last_cue = key
			_measure_output.call_deferred(key, played_count)
			return true
	return false


func _measure_output(key: StringName, sequence: int) -> void:
	# WASAPI may need several mixes to wake on the first sound. Wait for samples,
	# not a number of rendering frames, and do not attribute a later cue to this one.
	for attempt in 20:
		await get_tree().create_timer(0.05, true, false, true).timeout
		if closing or sequence != played_count:
			return
		if _audio_capture.get_frames_available() >= 2048:
			break
	var samples := _audio_capture.get_buffer(_audio_capture.get_frames_available())
	var amplitude := 0.0
	for sample: Vector2 in samples:
		amplitude = maxf(amplitude, maxf(absf(sample.x), absf(sample.y)))
	var peak := linear_to_db(maxf(amplitude, 0.0000000001))
	_last_mix_peak_db = peak
	var diagnostic := {
		"cue": key,
		"peak_db": peak,
		"driver": AudioServer.get_driver_name(),
		"device": AudioServer.output_device,
		"pid": OS.get_process_id(),
		"paused": get_tree().paused,
		"enabled": audio_enabled,
		"volume": audio_volume,
		"master_mute": AudioServer.is_bus_mute(0),
		"sfx_mute": AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),
	}
	diagnostic["frames"] = samples.size()
	diagnostic["voices"] = []
	for voice in voices:
		diagnostic.voices.append(
			{
				"path": str(voice.get_path()),
				"playing": voice.playing,
				"stream_paused": voice.stream_paused,
				"can_process": voice.can_process(),
				"position": voice.get_playback_position(),
				"bus": voice.bus,
			}
		)
	print("AUDIO_PLAY " + JSON.stringify(diagnostic))
	var file := FileAccess.open(output.path_join("audio-output.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(diagnostic, "\t"))
	if is_instance_valid(_audio_status):
		_audio_status.text = "Lecture : " + str(key) if peak > -75.0 else "Sortie silencieuse"


func _stop_audio() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null


func _add_toolbar() -> void:
	super._add_toolbar()
	get_window().title = "Essai SONORE Catabase — sons doux"
	var row := HBoxContainer.new()
	row.position = Vector2(8, 45)
	toolbar.add_child(row)
	var enabled := CheckButton.new()
	enabled.text = "Sons doux"
	enabled.button_pressed = true
	enabled.toggled.connect(
		func(value: bool) -> void:
			audio_enabled = value
			if not value:
				_stop_audio(),
	)
	row.add_child(enabled)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = audio_volume
	slider.custom_minimum_size.x = 140
	slider.tooltip_text = "Volume des sons de cet essai"
	slider.value_changed.connect(
		func(value: float) -> void:
			audio_volume = value
			for voice in voices:
				voice.volume_db = linear_to_db(maxf(value, 0.0001))
			if value <= 0.0:
				_stop_audio(),
	)
	row.add_child(slider)
	for entry in [[&"strike", "Frappe"], [&"dash", "Percée"], [&"shot", "Tir"], [&"guard", "Garde"]]:
		var button := Button.new()
		button.text = entry[1]
		button.pressed.connect(play_cue.bind(entry[0]))
		row.add_child(button)
	_audio_status = Label.new()
	_audio_status.text = "Cliquer sur Frappe pour tester"
	row.add_child(_audio_status)
	var music_row := HBoxContainer.new()
	music_row.position = Vector2(8, 83)
	toolbar.add_child(music_row)
	var music_label := Label.new()
	music_label.text = "Musique · harpe mystérieuse"
	music_row.add_child(music_label)
	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = music_volume
	music_slider.custom_minimum_size.x = 140
	music_slider.tooltip_text = "Volume de la musique ; tout à gauche pour la couper"
	music_slider.value_changed.connect(_set_music_volume)
	music_row.add_child(music_slider)
	var credit := LinkButton.new()
	credit.text = "VWolfdog · CC BY 3.0"
	credit.tooltip_text = "Soft Mysterious Harp Loop · ralenti, aigus atténués, volume ajusté"
	credit.pressed.connect(
		func() -> void:
			OS.shell_open("https://opengameart.org/content/soft-mysterious-harp-loop"),
	)
	music_row.add_child(credit)


func _exit_tree() -> void:
	_stop_audio()
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	_music_stream = null
	var bus := AudioServer.get_bus_index(&"SFX")
	if _audio_capture != null and bus >= 0:
		for index in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, index) == _audio_capture:
				AudioServer.remove_bus_effect(bus, index)
	_audio_capture = null
	if EventBus.spell_cast.is_connected(_on_audio_spell):
		EventBus.spell_cast.disconnect(_on_audio_spell)
	if EventBus.battle_view_ready.is_connected(_bind_audio_view):
		EventBus.battle_view_ready.disconnect(_bind_audio_view)
	sounds.clear()


func _verify_audio() -> void:
	var battle: Node = null
	for frame in 900:
		await get_tree().process_frame
		battle = get_tree().current_scene
		if is_instance_valid(battle) and battle.get("registered_terrain_ready") == true:
			break
	if not is_instance_valid(battle) or battle.get("registered_terrain_ready") != true:
		_fail("Audio verification: battle never became ready.")
		return
	var deployment: DeploymentController = battle.get("_deployment")
	if deployment != null and deployment.is_active():
		for cell: Vector2i in battle.room_data.hero_spawn_zone:
			if deployment.is_active() and not battle.grid.has_unit(cell):
				deployment.on_cell_clicked(cell)
				break
	await get_tree().process_frame
	var hero: Unit = null
	for unit: Unit in battle.units:
		if unit.team == 0:
			hero = unit
			break
	if hero == null:
		_fail("Audio verification: no player unit.")
		return
	var checks: Dictionary = { "four_wav_loaded": sounds.size() == 4, "first_combat_ready": true }
	checks["music_replaced_and_looping"] = (
		is_instance_valid(_music_player) and _music_player.stream == _music_stream
		and _music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and _music_player.playing
	)
	checks["music_uses_music_bus"] = (
		is_instance_valid(_music_player) and _music_player.bus == &"Music"
	)
	_set_music_volume(0.0)
	checks["music_mute"] = _music_player.stream_paused
	_set_music_volume(0.5)
	checks["music_resumes_quietly"] = (
		not _music_player.stream_paused and _music_player.volume_db < -6.0
	)
	var music_bus := AudioServer.get_bus_index(&"Music")
	var music_capture := AudioEffectCapture.new()
	music_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(music_bus, music_capture)
	_music_player.seek(_music_stream.get_length() - 0.15)
	var guard := load("res://data/spells/achilles/bronze_guard.tres") as Spell
	var before := played_count
	# Real gameplay resolution: proves that the existing event reaches the audio.
	var report: Dictionary = battle.spell_caster.cast(hero, guard, hero.grid_pos)
	checks["real_guard_cast"] = (
		not report.get("failed", false) and int(report.get("shield_increase_total", 0)) > 0
	)
	checks["guard_event_played_once"] = played_count == before + 1 and last_cue == &"guard"
	await get_tree().create_timer(1.1).timeout
	checks["music_wraps_loop"] = (
		_music_player.playing and _music_player.get_playback_position() < 2.0
	)
	if "--audio-real-output" in OS.get_cmdline_user_args():
		var music_peak := 0.0
		for sample: Vector2 in music_capture.get_buffer(music_capture.get_frames_available()):
			music_peak = maxf(music_peak, maxf(absf(sample.x), absf(sample.y)))
		checks["music_real_signal_quiet"] = music_peak > 0.0001 and music_peak < 0.08
		checks["real_driver"] = AudioServer.get_driver_name() != "Dummy"
		checks["real_guard_mix_signal"] = _last_mix_peak_db > -75.0
	AudioServer.remove_bus_effect(music_bus, AudioServer.get_bus_effect_count(music_bus) - 1)
	before = played_count
	_on_audio_spell(hero, guard, { "failed": true, "shield_increase_total": 10 })
	checks["failed_cast_silent"] = played_count == before
	var strike := load("res://data/spells/achilles/peleid_strike.tres") as Spell
	_on_audio_spell(hero, strike, { "damaged_enemies": [] })
	checks["miss_silent"] = played_count == before
	audio_enabled = false
	checks["mute_blocks_play"] = not play_cue(&"strike")
	audio_enabled = true
	for key: StringName in sounds:
		_stop_audio()
		await get_tree().create_timer(0.12).timeout
		checks["play_" + str(key)] = play_cue(key)
		checks["debounce_" + str(key)] = not play_cue(key)
		await get_tree().create_timer(0.35).timeout
		if "--audio-real-output" in OS.get_cmdline_user_args():
			checks["mix_" + str(key)] = _last_mix_peak_db > -75.0
	_stop_audio()
	checks["stop_releases_streams"] = true
	for voice in voices:
		checks["stop_releases_streams"] = (
			checks["stop_releases_streams"] and not voice.playing and voice.stream == null
		)
	var passed := not checks.values().has(false)
	var file := FileAccess.open(output.path_join("audio-verification.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({ "passed": passed, "checks": checks, "count": checks.size() }, "\t")
	)
	if not passed:
		_fail("Audio verification failed: " + JSON.stringify(checks))
		return
	await _capture()
	report.clear()
	hero = null
	battle = null
	deployment = null
	await _close()
