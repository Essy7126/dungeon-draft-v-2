extends GutTest

const Audio := preload("res://battle/audio/catabase_battle_audio.gd")
const GUARD := preload("res://data/spells/achilles/bronze_guard.tres")
const STRIKE := preload("res://data/spells/achilles/peleid_strike.tres")


class Encounter extends Node:
	var units: Array[Unit] = []


func test_only_successful_effects_from_own_encounter_play() -> void:
	var battle := Encounter.new()
	add_child_autofree(battle)
	var hero := Unit.new("Hero", 0, 100, 20)
	var other := Unit.new("Other encounter", 0, 100, 20)
	var enemy := Unit.new("Enemy", 1, 100, 20)
	battle.units.assign([hero, enemy])
	var audio := Audio.new()
	battle.add_child(audio)
	watch_signals(audio)
	EventBus.spell_cast.emit(other, GUARD, { "shield_increase_total": 10 })
	EventBus.spell_cast.emit(enemy, GUARD, { "shield_increase_total": 10 })
	EventBus.spell_cast.emit(hero, GUARD, { "failed": true, "shield_increase_total": 10 })
	EventBus.spell_cast.emit(hero, STRIKE, { "damaged_enemies": [] })
	EventBus.spell_cast.emit(hero, GUARD, { "shield_increase_total": 0 })
	assert_signal_not_emitted(audio, "cue_played")
	EventBus.spell_cast.emit(hero, GUARD, { "shield_increase_total": 10 })
	assert_signal_emit_count(audio, "cue_played", 1)
	assert_true(audio.voices[0].playing)
	assert_eq(audio.voices[0].bus, &"SFX")
	assert_true(audio.music.playing)
	assert_eq(audio.music.bus, &"Music")
	assert_almost_eq(audio.music.volume_db, -6.0206, 0.01)
	audio.dispose()


func test_repeated_scene_exit_releases_audio_and_disconnects_events() -> void:
	var connections := EventBus.spell_cast.get_connections().size()
	for cycle in 2:
		var battle := Encounter.new()
		add_child(battle)
		var hero := Unit.new("Hero", 0, 100, 20)
		battle.units.append(hero)
		var audio := Audio.new()
		battle.add_child(audio)
		EventBus.spell_cast.emit(hero, GUARD, { "shield_increase_total": 10 })
		var music_ref: WeakRef = weakref(audio.music.stream)
		if cycle == 0:
			audio.dispose()
			audio.dispose()
			assert_null(audio.music.stream)
			for voice in audio.voices:
				assert_false(voice.playing)
				assert_null(voice.stream)
		# Second cycle leaves active audio for _exit_tree to release itself.
		battle.free()
		# AudioServer releases stopped playbacks on its own mix thread.
		for attempt in 30:
			if music_ref.get_ref() == null:
				break
			await get_tree().create_timer(0.05).timeout
		assert_null(music_ref.get_ref())
		assert_eq(EventBus.spell_cast.get_connections().size(), connections)


func test_production_scene_owns_soundtrack_without_legacy_autoplay() -> void:
	var scene: Node = load("res://data/rooms/maps/painted_battle.tscn").instantiate()
	assert_not_null(scene.get_node_or_null("CombatAudio"))
	assert_null(scene.get_node_or_null("AudioStreamPlayer"))
	scene.free()
