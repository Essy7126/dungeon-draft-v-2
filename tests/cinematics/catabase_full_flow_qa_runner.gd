extends Node

const CATABASE_RUN: RunData = preload("res://data/runs/odyssey.tres")
const CINEMATIC_SCENE := preload("res://cinematics/intro/intro_cinematic.tscn")
const MAXIMUM_RUNTIME_SECONDS := 78.0


func _ready() -> void:
	get_tree().current_scene = null
	GameManager.cleanup_run_state()
	if not GameManager.configure_next_run(CATABASE_RUN, 2):
		_fail("configuration du run refusee")
		return
	var cinematic := CINEMATIC_SCENE.instantiate() as IntroCinematic
	get_tree().root.add_child.call_deferred(cinematic)
	await get_tree().process_frame
	get_tree().current_scene = cinematic
	var started_at := Time.get_ticks_msec()
	var music_started := false
	while _elapsed_seconds(started_at) < MAXIMUM_RUNTIME_SECONDS:
		await get_tree().create_timer(0.25).timeout
		if is_instance_valid(cinematic):
			music_started = music_started or cinematic.music_player.playing
		if (
			GameManager.run_active
			and GameManager.current_room_index == 0
			and not GameManager.has_next_run_configuration()
		):
			var elapsed := _elapsed_seconds(started_at)
			var music_stopped := (
				not is_instance_valid(cinematic)
				or not cinematic.music_player.playing
			)
			print(
				"CATABASE_FULL_FLOW_QA_PASS elapsed=%.3f music_started=%s music_stopped=%s room_index=%d run=%s"
				% [
					elapsed,
					music_started,
					music_stopped,
					GameManager.current_room_index,
					GameManager.get_active_run_data().run_name,
				]
			)
			get_tree().quit()
			return
	_fail("timeout apres %.1f secondes" % MAXIMUM_RUNTIME_SECONDS)


func _elapsed_seconds(started_at: int) -> float:
	return float(Time.get_ticks_msec() - started_at) / 1000.0


func _fail(reason: String) -> void:
	push_error("Catabase full-flow QA : %s." % reason)
	get_tree().quit(2)
