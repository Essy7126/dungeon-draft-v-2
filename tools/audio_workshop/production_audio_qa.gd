extends "res://tests/cinematics/catabase_threshold_flow_qa.gd"
## Extends the real title -> selection -> cinematic -> gate journey. No audio injection.
var _audio_check_started := false
var _heard: Dictionary = { }
var _context_cues: Dictionary = { }
var _sound_capture: AudioEffectCapture
var _sound_bus := -1
var _title_music: WeakRef


func _verify_title(title: Node) -> void:
	# Keep popup windows in the captured viewport while the harness runs offscreen.
	get_tree().root.gui_embed_subwindows = true
	var music := title.get_node("AudioStreamPlayer") as AudioStreamPlayer
	_title_music = weakref(music)
	var controls := title.get_node("UI/TitleMusicControls")
	var catalog = load("res://core/audio/title_music_catalog.gd")
	var bus_index := AudioServer.get_bus_index(&"Music")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus_index, capture)
	var peaks := { }
	for index in catalog.TRACKS.size():
		controls.selector.show_popup()
		var popup := controls.selector.get_popup() as PopupMenu
		_check(popup.visible, "title selector popup opens: " + str(index))
		# Dispatch the popup selection signal; OS-native popup key routing is external
		# to the root viewport used by this offscreen harness.
		popup.index_pressed.emit(index)
		popup.hide()
		await get_tree().create_timer(1.0).timeout
		if not _check(music.selected_index == index, "title popup selection: " + str(index)):
			break
		music.seek(30.0)
		await get_tree().create_timer(0.1).timeout
		capture.clear_buffer()
		await get_tree().create_timer(0.6).timeout
		var peak := _peak(capture)
		peaks[catalog.TRACKS[index].id] = peak
		_check(music.playing and music.stream.loop, "title looping track: " + str(index))
		_check(peak > 0.0001 and peak < 0.3, "title audible restrained signal: " + str(index))
	controls.volume.value = 0
	await get_tree().create_timer(0.1).timeout
	capture.clear_buffer()
	await get_tree().create_timer(0.4).timeout
	_check(_peak(capture) < 0.0001, "title slider silences music")
	AudioServer.remove_bus_effect(bus_index, AudioServer.get_bus_effect_count(bus_index) - 1)
	controls.volume.value = 50
	music.select_track(0)
	_check(title.get_viewport_rect().encloses(controls.get_global_rect()), "title music panel within viewport")
	await _click(controls.credits_button)
	var credits := controls.get_node("TitleMusicCredits") as AcceptDialog
	_check(credits.visible, "title credits open by pointer")
	await _capture("00-title-credits.png")
	credits.hide()
	_report["title_music_peaks"] = peaks


func _finish(exit_code: int) -> void:
	if exit_code != 0 or _audio_check_started:
		await super._finish(exit_code)
		return
	_audio_check_started = true
	_check(
		_title_music != null and _title_music.get_ref() == null,
		"title player released before battle",
	)
	_report["ok"] = false
	var main_scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	_check(
		main_scene.resource_path == "res://ui/TitreEcran.tscn",
		"journey starts at configured game entry",
	)
	var battle := get_tree().current_scene
	if not await _until(
		func():
			return battle.get("runtime_ready_state") == true,
		25,
		"normal battle ready for audio",
	):
		return
	var audio := battle.get_node_or_null("CombatAudio")
	if not _check(audio != null, "production scene owns audio without audition toolbar"):
		return
	_check(get_tree().root.find_child("AudioCombatTrial", true, false) == null, "no audio trial scene")
	_check(audio.music.playing and audio.music.bus == &"Music", "production harp on Music bus")
	_check(audio.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "production harp loops")
	_check(audio.music.volume_db < -6.0, "production music kept behind effects")
	var music_bus := AudioServer.get_bus_index(&"Music")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(music_bus, capture)
	await get_tree().create_timer(0.8).timeout
	var music_peak := _peak(capture)
	_report["music_peak"] = music_peak
	_check(music_peak > 0.0001 and music_peak < 0.08, "real quiet music signal")
	AudioServer.remove_bus_effect(music_bus, AudioServer.get_bus_effect_count(music_bus) - 1)
	_sound_bus = AudioServer.get_bus_index(&"SFX")
	_sound_capture = AudioEffectCapture.new()
	_sound_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(_sound_bus, _sound_capture)
	audio.cue_played.connect(_on_cue)
	audio.feedback.played.connect(
		func(cue: StringName) -> void:
			_context_cues[cue] = int(_context_cues.get(cue, 0)) + 1,
	)
	var deployment: DeploymentController = battle.get("_deployment")
	if deployment != null and deployment.is_active():
		deployment.on_cell_clicked(battle.room_data.hero_spawn_zone[0])
	var start := Time.get_ticks_msec()
	while (
		not _failed and (_heard.size() < 4 or not _has_impact_feedback())
		and Time.get_ticks_msec() - start < 120000
	):
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(battle) or get_tree().current_scene != battle:
			break
		if not battle.call("_can_accept_player_intent"):
			continue
		var hero: Unit = battle.call("get_active_unit")
		if hero == null or hero.team != 0:
			continue
		if await _try_missing_spell(battle, hero):
			continue
		# Once signatures are checked, hold position so a ranged enemy can attack
		# instead of forcing it to retreat again every turn by chasing into melee.
		if _heard.size() < 4 and _move_closer(battle, hero):
			continue
		battle.set("_skip_end_turn_confirmation", true)
		battle.call("_on_end_turn_pressed")
	_report["production_cues"] = _heard
	_report["context_cues"] = _context_cues
	_check(int(_context_cues.get(&"step", 0)) > 0, "real walking produces contextual footsteps")
	_check(_has_impact_feedback(), "real enemy attack has impact or shield feedback")
	AudioServer.remove_bus_effect(_sound_bus, AudioServer.get_bus_effect_count(_sound_bus) - 1)
	_sound_capture = null
	if not _check(_heard.size() == 4, "all four opening techniques sounded through player intents"):
		return
	for id in _heard:
		if not _check(_heard[id].peak > 0.001, "real effect samples: " + str(id)):
			return
	await _capture("06-production-audio.png")
	_report["ok"] = not _failed
	_write_report()
	await super._finish(0)


func _has_impact_feedback() -> bool:
	return (
		int(_context_cues.get(&"hit", 0)) + int(_context_cues.get(&"magic_hit", 0))
		+ int(_context_cues.get(&"block", 0))
		> 0
	)


func _on_cue(id: StringName) -> void:
	_heard[id] = { "peak": 0.0 }


func _peak(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample: Vector2 in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak


func _try_missing_spell(battle: Node, hero: Unit) -> bool:
	var caster: SpellCaster = battle.get("spell_caster")
	var enemies: Array = battle.get("units").filter(
		func(unit: Unit):
			return unit.team != 0 and unit.is_alive,
	)
	for id in [
		&"achilles_bronze_guard",
		&"achilles_fulminant_dash",
		&"achilles_pelion_shot",
		&"achilles_peleid_strike",
	]:
		if _heard.has(id):
			continue
		for spell: Spell in hero.spells:
			if spell.get_effective_spell_id() != id:
				continue
			var cells: Array = caster.get_targetable_cells(hero, spell)
			if id == &"achilles_fulminant_dash":
				cells.sort_custom(
					func(a, b):
						return _distance(a, enemies) < _distance(b, enemies),
				)
			for cell: Vector2i in cells:
				if id in [&"achilles_pelion_shot", &"achilles_peleid_strike"]:
					var target: Unit = battle.grid.get_unit(cell)
					if target == null or target.team == 0:
						continue
				if not caster.can_cast(hero, spell, cell):
					continue
				_sound_capture.clear_buffer()
				battle.call("_on_spell_pressed", spell)
				battle.call("_on_cell_clicked", cell)
				await get_tree().create_timer(1.1).timeout
				if _heard.has(id):
					_heard[id].peak = _peak(_sound_capture)
					return true
	return false


func _move_closer(battle: Node, hero: Unit) -> bool:
	if hero.current_mp <= 0:
		return false
	var enemies: Array = battle.get("units").filter(
		func(unit: Unit):
			return unit.team != 0 and unit.is_alive,
	)
	var best := hero.grid_pos
	for cell: Vector2i in battle.pathfinder.get_reachable(hero.grid_pos, hero.current_mp, hero):
		if _distance(cell, enemies) < _distance(best, enemies):
			best = cell
	if best == hero.grid_pos:
		return false
	battle.call("_on_move_pressed")
	battle.call("_on_cell_clicked", best)
	return true


func _distance(cell: Vector2i, enemies: Array) -> int:
	var distance := 10000
	for enemy: Unit in enemies:
		distance = mini(distance, absi(cell.x - enemy.grid_pos.x) + absi(cell.y - enemy.grid_pos.y))
	return distance
