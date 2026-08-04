extends Node

const EDITOR_SCENE := preload("res://tools/arena_map_editor/ArenaMapEditor.tscn")
const OUTPUT_DIR := "res://artifacts/labs/arena_map_editor"
const PACK_DIR := OUTPUT_DIR + "/reference_arena_pack"
const VIEWPORT_SIZE := Vector2i(1600, 900)


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	get_window().size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var editor := EDITOR_SCENE.instantiate() as ArenaMapEditor
	add_child(editor)
	for _frame in range(8):
		await get_tree().process_frame
	editor._center_camera()
	for _frame in range(4):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var screenshot_error := image.save_png(ProjectSettings.globalize_path(
		OUTPUT_DIR + "/arena_map_editor_overview.png"
	))
	if screenshot_error != OK:
		push_error("Capture editeur impossible : %s" % error_string(screenshot_error))
		get_tree().quit(1)
		return
	var exporter := ArenaMapExporter.new()
	var result: Dictionary = await exporter.export_pack(self, editor.document, PACK_DIR)
	print("ARENA_EDITOR_CAPTURE=%s" % ("OK" if screenshot_error == OK else "FAIL"))
	print("ARENA_EDITOR_EXPORT=%s" % JSON.stringify(result))
	get_tree().quit(0 if bool(result.ok) else 1)
