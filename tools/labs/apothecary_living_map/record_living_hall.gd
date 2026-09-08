extends Node

## Records the actual viewport after a controlled resize, independent of the
## project's default movie viewport. Frames are review artifacts, not game assets.
const SCENE := preload("res://tools/labs/apothecary_living_map/LivingHall.tscn")
const OUTPUT := "res://artifacts/living_hall/preview_frames"
const FPS := 24.0
const FRAME_COUNT := 144


func _ready() -> void:
	_record.call_deferred()


func _record() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A rendered viewport is required for the preview recording.")
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene := SCENE.instantiate()
	add_child(scene)
	scene.set_animation_paused(true)
	scene.set_chrome_visible(false)
	await get_tree().process_frame
	await get_tree().process_frame
	for frame_index: int in FRAME_COUNT:
		scene.set_effect_time(float(frame_index) / FPS)
		if frame_index == 48:
			scene.trigger_ripple(Vector2(592, 487))
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var output_path := OUTPUT.path_join("frame_%04d.jpg" % frame_index)
		if image.save_jpg(ProjectSettings.globalize_path(output_path), 0.95) != OK:
			push_error("Unable to write recording frame.")
			get_tree().quit(1)
			return
	print("LIVING_HALL_RECORDING: 144 rendered frames, 1920x1080, 24 FPS, ripple at 2 seconds.")
	get_tree().quit()
