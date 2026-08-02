extends SceneTree

const OUTPUT_PATH := "res://artifacts/start_hub/start_hub_debug_1920x1080.png"
const START_HUB_SCENE: PackedScene = preload("res://hub/StartHub.tscn")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1920, 1080)
	var hub := START_HUB_SCENE.instantiate()
	root.add_child(hub)
	for _frame in range(18):
		await process_frame
	var overlay: HubGridOverlay = hub.get_node("WorldRoot/GridOverlay")
	var hover_cell := Vector2i(8, 8)
	overlay.update_hover_at_world(
		overlay.cell_to_world(hover_cell),
		Vector2(960.0, 540.0)
	)
	for _frame in range(4):
		await process_frame
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var error := image.save_png(output_absolute)
	if error != OK:
		push_error("Capture StartHub impossible: %s" % error_string(error))
		quit(1)
		return
	print("START_HUB_CAPTURE=%s" % output_absolute)
	quit()
