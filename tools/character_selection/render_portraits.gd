extends SceneTree
## Bake roster portraits from the same character models used by the preview.
## Run with a graphical renderer; --headless does not produce these textures.

const OUTPUT := "res://asset/ui/character_selection/portraits/"
const PORTRAIT_SIZE := Vector2i(464, 504)


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var catalog = load("res://ui/selection/character_selection_catalog.gd")
	var entries = catalog.get_entries()
	var preview_scene = load("res://ui/characters/CharacterPreview3D.tscn")
	for entry in entries:
		if entry["id"] == &"achilles":
			continue
		var preview = preview_scene.instantiate()
		preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
		preview.size = Vector2(PORTRAIT_SIZE)
		root.add_child(preview)
		preview.configure(entry["unit"])
		var camera: Camera3D = preview.camera
		var is_mage: bool = entry["id"] == &"mage"
		var target_height := 1.56 if is_mage else 1.11
		camera.position = Vector3(0.45, target_height + 0.25, 3.0)
		camera.look_at(Vector3(0.0, target_height, 0.0), Vector3.UP)
		camera.size = 1.04 if is_mage else 0.94
		preview.preview_viewport.transparent_bg = true
		var portrait_light := OmniLight3D.new()
		portrait_light.position = Vector3(0.0, 2.0, 3.0)
		portrait_light.light_color = Color(1.0, 0.93, 0.82)
		portrait_light.light_energy = 3.0
		portrait_light.omni_range = 8.0
		preview.visual_root.get_parent().add_child(portrait_light)
		for frame_index in range(45):
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = preview.preview_viewport.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Portrait framebuffer empty: %s" % entry["id"])
			quit(1)
			return
		var path: String = OUTPUT + str(entry["id"]) + ".png"
		var error: Error = image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Cannot save portrait %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("CHARACTER_PORTRAIT=", path, " size=", image.get_size(), " bounds=", image.get_used_rect())
		preview.queue_free()
		await process_frame
		await process_frame
	quit()
