extends Node

const CINEMATIC_SCENE := preload("res://cinematics/intro/intro_cinematic.tscn")

var _failures: Array[String] = []
var _scene_requests: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameManager.cleanup_run_state()
	var callback := func(path): _scene_requests.append(path)
	GameManager.scene_change_requested.connect(callback)

	var cinematic := CINEMATIC_SCENE.instantiate() as IntroCinematic
	cinematic.autoplay = false
	cinematic.exit_fade_duration = 0.0
	cinematic.music_fade_in_duration = 0.0
	cinematic.music_fade_out_duration = 0.0
	get_tree().root.add_child(cinematic)
	get_tree().current_scene = cinematic
	await get_tree().process_frame
	cinematic._begin_playback()
	await get_tree().process_frame
	var music_player_ref: WeakRef = weakref(cinematic.music_player)
	_check(cinematic.music_player.playing, "La musique ne demarre pas avant le skip.")

	cinematic.request_skip()
	cinematic.request_skip()
	for _frame in range(12):
		await get_tree().process_frame

	_check(GameManager.run_active, "La run n’est pas active après le skip.")
	_check(GameManager.current_room_index == 0, "La première salle n’est pas sélectionnée.")
	_check(
		GameManager.get_ordered_heroes().map(func(hero): return hero.unit_name)
		== ["Elfe", "Mage", "Guerrier"],
		"Le trio réel après changement de scène est incorrect."
	)
	_check(music_player_ref.get_ref() == null, "MusicPlayer survit au changement de scene.")
	_check(
		_scene_requests == ["res://ui/Transitionsalle.tscn"],
		"Le changement de scène a été demandé plusieurs fois : %s" % _scene_requests
	)
	_check(get_tree().current_scene != null, "La scène courante est absente.")
	if get_tree().current_scene != null:
		_check(
			get_tree().current_scene.scene_file_path == "res://ui/Transitionsalle.tscn",
			"Scène courante inattendue : %s" % get_tree().current_scene.scene_file_path
		)

	if GameManager.scene_change_requested.is_connected(callback):
		GameManager.scene_change_requested.disconnect(callback)
	GameManager.cleanup_run_state()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("INTRO_SCENE_CHANGE_VERIFY: PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("INTRO_SCENE_CHANGE_VERIFY: %s" % failure)
	print("INTRO_SCENE_CHANGE_VERIFY: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
