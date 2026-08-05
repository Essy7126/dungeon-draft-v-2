@tool
class_name NativeStudioWindowHost
extends Window

signal reintegrate_requested

const DEFAULT_SIZE := Vector2i(1600, 950)
const MINIMUM_SIZE := Vector2i(1280, 720)

var workspace: StudioWorkspace = null


func _init() -> void:
	visible = false
	force_native = true


func _ready() -> void:
	title = "Dungeon Draft Studio"
	min_size = MINIMUM_SIZE
	size = DEFAULT_SIZE
	unresizable = false
	exclusive = false
	transient = false
	close_requested.connect(_on_close_requested)
	hide()


func attach_workspace(value: StudioWorkspace) -> void:
	workspace = value
	if workspace == null:
		return
	if workspace.get_parent() != null:
		workspace.get_parent().remove_child(workspace)
	add_child(workspace)
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace.show()
	_update_title()


func detach_workspace() -> StudioWorkspace:
	var value := workspace
	if value != null and value.get_parent() == self:
		remove_child(value)
	workspace = null
	return value


func bring_to_front() -> void:
	show()
	grab_focus()


func capture_window_state() -> Dictionary:
	return {
		"screen": current_screen,
		"position": [position.x, position.y],
		"size": [size.x, size.y],
		"maximized": mode == Window.MODE_MAXIMIZED,
	}


func apply_window_state(state: Dictionary) -> void:
	var screen_count := DisplayServer.get_screen_count()
	current_screen = clampi(int(state.get("screen", current_screen)), 0, maxi(0, screen_count - 1))
	var stored_size: Array = state.get("size", [DEFAULT_SIZE.x, DEFAULT_SIZE.y])
	size = Vector2i(
		maxi(MINIMUM_SIZE.x, int(stored_size[0])),
		maxi(MINIMUM_SIZE.y, int(stored_size[1]))
	)
	var usable := DisplayServer.screen_get_usable_rect(current_screen)
	var stored_position: Array = state.get(
		"position", [usable.position.x + 40, usable.position.y + 40]
	)
	position = Vector2i(
		clampi(int(stored_position[0]), usable.position.x, usable.end.x - 120),
		clampi(int(stored_position[1]), usable.position.y, usable.end.y - 80)
	)
	mode = Window.MODE_MAXIMIZED if bool(state.get("maximized", false)) else Window.MODE_WINDOWED


func _update_title() -> void:
	var document_name := "Nouvelle arene"
	if workspace != null and workspace.arena_studio != null \
			and workspace.arena_studio.arena != null:
		document_name = workspace.arena_studio.arena.display_name
	title = "Dungeon Draft Studio — %s" % document_name


func _on_close_requested() -> void:
	hide()
	reintegrate_requested.emit()
