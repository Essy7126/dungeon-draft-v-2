extends Node

## Capture the real playable scene with its distance-driven walk animation.
const SCENE := preload("res://tools/labs/apothecary_living_map/PlayableHall.tscn")
const OUTPUT := "res://artifacts/hall_walk/preview_frames"
const FPS := 24.0
const FRAME_COUNT := 288
const STOPS := [Vector2(646, 628), Vector2(647, 478), Vector2(938, 490)]


func _ready() -> void:
	_record.call_deferred()


func _record() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A rendered viewport is required for the walk recording.")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var hall := SCENE.instantiate()
	add_child(hall)
	for attempt: int in 180:
		if hall.is_ready_for_play():
			break
		await get_tree().process_frame
	if not hall.is_ready_for_play():
		push_error("The playable hall did not initialize for recording.")
		get_tree().quit(1)
		return
	hall.set_process(false)
	hall.set_chrome_visible(false)
	hall.set_effect_time(0.0)
	var next_stop := 0
	var idle_frames := 0
	for frame_index: int in FRAME_COUNT:
		if not hall.is_player_moving() and next_stop < STOPS.size():
			idle_frames += 1
			if idle_frames >= 12:
				if not hall.request_move(STOPS[next_stop]):
					push_error("Recording route was rejected.")
					get_tree().quit(1)
					return
				next_stop += 1
				idle_frames = 0
		hall.advance_world(1.0 / FPS)
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		var output_path := OUTPUT.path_join("frame_%04d.jpg" % frame_index)
		if frame.save_jpg(ProjectSettings.globalize_path(output_path), 0.95) != OK:
			push_error("Unable to write recording frame.")
			get_tree().quit(1)
			return
	if next_stop != STOPS.size() or hall.is_player_moving():
		push_error("Recording ended before the final destination.")
		get_tree().quit(1)
		return
	print("HALL_WALK_RECORDING: 288 rendered frames, 1920x1080, 24 FPS; bridge, fountain detour and arcane stall reached.")
	get_tree().quit()
