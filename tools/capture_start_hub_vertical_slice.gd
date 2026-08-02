extends Node

const DEBUG_OUTPUT := (
	"res://artifacts/start_hub/start_hub_archivist_after_debug_1920x1080.png"
)
const PLAYABLE_OUTPUT := (
	"res://artifacts/start_hub/start_hub_archivist_after_playable_1920x1080.png"
)
const BEFORE_CLOSEUP_OUTPUT := (
	"res://artifacts/start_hub/start_hub_archivist_before_yaw_minus_35_closeup.png"
)
const AFTER_CLOSEUP_OUTPUT := (
	"res://artifacts/start_hub/start_hub_archivist_after_yaw_55_closeup.png"
)

@onready var hub: Node = $StartHub


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	_capture.call_deferred()


func _capture() -> void:
	for _frame in range(30):
		await get_tree().process_frame

	var overlay: HubGridOverlay = hub.get_node("WorldRoot/GridOverlay")
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	overlay.update_hover_at_world(
		overlay.cell_to_world(archivist.occupied_cell),
		Vector2(760.0, 610.0)
	)
	for _frame in range(4):
		await get_tree().process_frame
	if not _save_viewport(DEBUG_OUTPUT):
		get_tree().quit(1)
		return

	overlay.set_debug_visible(false)
	hub.get_node("HubUI/DebugPanel").visible = false
	for _frame in range(4):
		await get_tree().process_frame
	if not _save_viewport(PLAYABLE_OUTPUT):
		get_tree().quit(1)
		return

	archivist.model_pivot.rotation_degrees.y = -35.0
	for _frame in range(4):
		await get_tree().process_frame
	if not _save_archivist_viewport(archivist, BEFORE_CLOSEUP_OUTPUT):
		get_tree().quit(1)
		return
	archivist.model_pivot.rotation_degrees.y = archivist.facing_yaw_degrees
	for _frame in range(4):
		await get_tree().process_frame
	if not _save_archivist_viewport(archivist, AFTER_CLOSEUP_OUTPUT):
		get_tree().quit(1)
		return
	print("START_HUB_DEBUG_CAPTURE=%s" % ProjectSettings.globalize_path(DEBUG_OUTPUT))
	print("START_HUB_PLAYABLE_CAPTURE=%s" % ProjectSettings.globalize_path(PLAYABLE_OUTPUT))
	print("START_HUB_BEFORE_CLOSEUP=%s" % ProjectSettings.globalize_path(BEFORE_CLOSEUP_OUTPUT))
	print("START_HUB_AFTER_CLOSEUP=%s" % ProjectSettings.globalize_path(AFTER_CLOSEUP_OUTPUT))
	get_tree().quit()


func _save_viewport(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Capture StartHub impossible: framebuffer vide")
		return false
	var error := image.save_png(absolute)
	if error != OK:
		push_error("Capture StartHub impossible: %s" % error_string(error))
		return false
	return true


func _save_archivist_viewport(archivist: HubArchivist, path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := archivist.character_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png(absolute) == OK
