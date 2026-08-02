extends Node

const CINEMATIC_PATH := "res://cinematics/intro/intro_cinematic.tscn"
const STORYBOARD_PATH := "res://cinematics/intro/source/intro_storyboard.png"
const NARRATION_PATH := "res://cinematics/intro/audio/intro_narration.mp3"
const MUSIC_PATH := "res://cinematics/intro/audio/The Heart of Dawn.mp3"
const RUN_PATH := "res://data/runs/first_run.tres"
const SPY_SCRIPT := preload("res://test/unit/helpers/intro_run_manager_spy.gd")
const GAME_MANAGER_SCRIPT := preload("res://core/game_manager.gd")

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

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var debug_overlay := get_node_or_null("/root/DebugOverlay") as CanvasLayer
	if debug_overlay != null:
		debug_overlay.visible = false
	var packed := load(CINEMATIC_PATH) as PackedScene
	_check(packed != null, "La scène de cinématique ne se charge pas.")
	if packed == null:
		_finish()
		return

	var cinematic := packed.instantiate() as IntroCinematic
	_check(cinematic != null, "La racine n’est pas un IntroCinematic.")
	if cinematic == null:
		_finish()
		return
	cinematic.autoplay = false
	get_tree().root.add_child(cinematic)
	await get_tree().process_frame
	await get_tree().process_frame

	_verify_tree_and_buses(cinematic)
	_verify_sources(cinematic)
	_verify_timeline(cinematic)
	await _verify_resolutions(cinematic)
	await _verify_skip_and_normal_exit(packed, cinematic)
	_verify_game_manager_contract()

	_finish()


func _verify_tree_and_buses(cinematic: IntroCinematic) -> void:
	for path in [
		"Background",
		"IllustrationFrame",
		"IllustrationFrame/ImageA",
		"IllustrationFrame/ImageB",
		"Vignette",
		"SubtitlePanel/Subtitle",
		"BlackFade",
		"SkipButton",
		"VoicePlayer",
		"MusicPlayer",
		"SfxPlayer",
	]:
		_check(cinematic.get_node_or_null(path) != null, "Nœud manquant : %s" % path)
	_check(cinematic.voice_player.bus == &"Voice", "VoicePlayer n’utilise pas Voice.")
	_check(cinematic.music_player.bus == &"Music", "MusicPlayer n’utilise pas Music.")
	_check(cinematic.sfx_player.bus == &"SFX", "SfxPlayer n’utilise pas SFX.")
	for bus_name in [&"Voice", &"Music", &"SFX"]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "Bus absent : %s" % bus_name)


func _verify_sources(cinematic: IntroCinematic) -> void:
	_check(cinematic.music_path == MUSIC_PATH, "Source musicale configuree incorrecte.")
	_check(absf(cinematic.music_volume_db + 18.0) <= 0.001, "Volume musique local != -18 dB.")
	_check(absf(cinematic.music_fade_in_duration - 1.5) <= 0.001, "Fondu musical entrant != 1,5 s.")
	_check(absf(cinematic.music_fade_out_duration - 1.0) <= 0.001, "Fondu musical sortant != 1 s.")
	var music := load(MUSIC_PATH) as AudioStream
	_check(music != null, "Musique d'introduction absente ou invalide.")
	if music != null:
		_check(music.get_length() > 94.46, "La musique se termine avant la narration.")
	var storyboard := load(STORYBOARD_PATH) as Texture2D
	_check(storyboard != null, "Planche source absente.")
	if storyboard != null:
		_check(
			storyboard.get_size() == Vector2(1672.0, 941.0),
			"Dimensions inattendues : %s" % storyboard.get_size()
		)
	var narration := load(NARRATION_PATH) as AudioStream
	_check(narration != null, "Narration absente.")
	if narration != null:
		_check(
			absf(narration.get_length() - 94.46) <= 0.06,
			"Durée narration inattendue : %.3f" % narration.get_length()
		)

	_check(cinematic.illustration_paths.size() == 9, "Il faut neuf atlas.")
	for index in range(mini(9, cinematic.illustration_paths.size())):
		var atlas := load(cinematic.illustration_paths[index]) as AtlasTexture
		_check(atlas != null, "Atlas %d absent." % (index + 1))
		if atlas == null:
			continue
		_check(atlas.region == EXPECTED_REGIONS[index], "Région %d incorrecte." % (index + 1))
		_check(atlas.filter_clip, "filter_clip doit être actif sur l’atlas %d." % (index + 1))
		_check(atlas.atlas.resource_path == STORYBOARD_PATH, "Atlas source incorrecte.")


func _verify_timeline(cinematic: IntroCinematic) -> void:
	var starts := [0.0, 13.0, 25.0, 34.0, 42.0, 51.0, 59.0, 67.0, 84.0]
	for index in range(starts.size()):
		cinematic.synchronize_to_time(starts[index])
		_check(cinematic.get_current_plan_index() == index, "Plan %d non activé." % (index + 1))
	cinematic.synchronize_to_time(13.0)
	_check(cinematic.get_current_plan_index() == 8, "L’horloge est revenue en arrière.")

	var crossfade := _new_cinematic(cinematic.scene_file_path)
	crossfade.synchronize_to_time(13.0)
	crossfade.synchronize_to_time(13.45)
	_check(absf(crossfade.image_a.modulate.a - 0.5) <= 0.02, "Fondu sortant != 50 %.")
	_check(absf(crossfade.image_b.modulate.a - 0.5) <= 0.02, "Fondu entrant != 50 %.")
	crossfade.synchronize_to_time(13.9)
	_check(crossfade.image_b.scale.x <= 1.04, "Zoom Ken Burns supérieur à 1.04.")
	crossfade.queue_free()


func _verify_resolutions(cinematic: IntroCinematic) -> void:
	var original_size := get_tree().root.size
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		get_tree().root.size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		var frame_size := cinematic.illustration_frame.size
		var source_size := Vector2(554.0, 311.0)
		var fit := minf(frame_size.x / source_size.x, frame_size.y / source_size.y)
		var rendered_size := source_size * fit
		var width_ratio := rendered_size.x / float(resolution.x)
		_check(width_ratio >= 0.70 and width_ratio <= 0.80, "%s : largeur %.3f" % [resolution, width_ratio])
		_check(
			absf(rendered_size.aspect() - source_size.aspect()) < 0.001,
			"%s : ratio d’illustration déformé." % resolution
		)
		_check(
			cinematic.subtitle_panel.position.y
			>= cinematic.illustration_frame.position.y + cinematic.illustration_frame.size.y,
			"%s : les sous-titres chevauchent l’illustration." % resolution
		)
	get_tree().root.size = original_size
	await get_tree().process_frame


func _verify_skip_and_normal_exit(packed: PackedScene, cinematic: IntroCinematic) -> void:
	var skip_spy := SPY_SCRIPT.new()
	get_tree().root.add_child(skip_spy)
	cinematic.run_manager_override = skip_spy
	cinematic.exit_fade_duration = 0.0
	cinematic.request_skip()
	cinematic.request_skip()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(skip_spy.start_call_count == 1, "Le skip a initialisé la run plusieurs fois.")
	_check(
		skip_spy.received_hero_sources.map(func(hero): return hero.unit_name)
		== ["Elfe", "Mage", "Guerrier"],
		"Le trio de la première run est incorrect."
	)

	var normal := packed.instantiate() as IntroCinematic
	normal.autoplay = false
	normal.exit_fade_duration = 0.0
	var normal_spy := SPY_SCRIPT.new()
	get_tree().root.add_child(normal_spy)
	normal.run_manager_override = normal_spy
	get_tree().root.add_child(normal)
	await get_tree().process_frame
	normal.finish_cinematic()
	normal.request_skip()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(normal_spy.start_call_count == 1, "La fin normale n’utilise pas la garde commune.")

	var missing := packed.instantiate() as IntroCinematic
	missing.autoplay = false
	missing.illustration_paths = ["res://cinematics/intro/atlas/missing.tres"]
	get_tree().root.add_child(missing)
	await get_tree().process_frame
	_check(missing.get_loaded_illustration_count() == 0, "L’asset visuel manquant n’est pas toléré.")
	_check(not missing.subtitle.text.is_empty(), "Le fallback visuel a perdu le sous-titre.")

	var invalid := packed.instantiate() as IntroCinematic
	invalid.autoplay = false
	invalid.exit_fade_duration = 0.0
	invalid.run_data_path = "res://data/runs/missing_intro_run.tres"
	invalid.fallback_scene_path = ""
	var invalid_spy := SPY_SCRIPT.new()
	get_tree().root.add_child(invalid_spy)
	invalid.run_manager_override = invalid_spy
	get_tree().root.add_child(invalid)
	await get_tree().process_frame
	invalid.request_skip()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(invalid_spy.start_call_count == 0, "Une configuration invalide a démarré une run.")


func _verify_game_manager_contract() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	var requested_paths: Array[String] = []
	manager.scene_change_requested.connect(func(path): requested_paths.append(path))
	var run_data := load(RUN_PATH) as RunData
	manager.start_preconfigured_run(run_data, [
		"res://data/units/alliés/elfe.tres",
		"res://data/units/alliés/mage.tres",
		"res://data/units/alliés/Guerrier.tres",
	])
	_check(manager.run_active, "start_preconfigured_run n’active pas la run.")
	_check(manager.current_room_index == 0, "La première salle n’est pas sélectionnée.")
	_check(requested_paths == ["res://ui/Transitionsalle.tscn"], "La transition initiale est incorrecte.")
	_check(
		manager.get_current_room().battle_scene.resource_path
		== "res://data/rooms/maps/battle_salle1_iso.tscn",
		"La battle_scene réelle de la première salle est incorrecte."
	)
	_check(
		manager.get_ordered_heroes().map(func(hero): return hero.unit_name)
		== ["Elfe", "Mage", "Guerrier"],
		"GameManager n’a pas construit le trio attendu."
	)
	manager.cleanup_run_state()
	manager.free()


func _new_cinematic(path: String) -> IntroCinematic:
	var instance := (load(path) as PackedScene).instantiate() as IntroCinematic
	instance.autoplay = false
	get_tree().root.add_child(instance)
	return instance


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("INTRO_CINEMATIC_VERIFY: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("INTRO_CINEMATIC_VERIFY: %s" % failure)
	print("INTRO_CINEMATIC_VERIFY: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
