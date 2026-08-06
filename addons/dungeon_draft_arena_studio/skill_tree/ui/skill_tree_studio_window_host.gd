@tool
class_name SkillTreeStudioWindowHost
extends Window

signal studio_closed

const DEFAULT_SIZE := Vector2i(1680, 960)
const MINIMUM_SIZE := Vector2i(1280, 720)

var editor_interface = null
var editor_undo_redo = null
var studio: SkillTreeStudioMain = null
var project_context: StudioProjectContext = null
var reference_graph: StudioReferenceGraphService = null


func _init() -> void:
	visible = false
	force_native = true


func setup(
		host_editor_interface,
		undo_manager,
		shared_context: StudioProjectContext = null,
		shared_reference_graph: StudioReferenceGraphService = null
	) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager
	project_context = shared_context
	reference_graph = shared_reference_graph


func _ready() -> void:
	title = "Dungeon Draft — Studio des personnages et compétences"
	min_size = MINIMUM_SIZE
	size = DEFAULT_SIZE
	unresizable = false
	exclusive = false
	transient = false
	close_requested.connect(_request_close)
	hide()


func open_studio() -> void:
	if studio == null:
		_create_studio()
	_apply_window_state(SkillTreeUiStateService.load_state())
	show()
	grab_focus()


func close_studio_immediately() -> void:
	if studio != null:
		studio.prepare_for_close()
		_store_state()
		studio.dispose_document()
		remove_child(studio)
		studio.queue_free()
		studio = null
	hide()


func _create_studio() -> void:
	studio = SkillTreeStudioMain.new()
	studio.name = "SkillTreeStudioMain"
	studio.setup(editor_interface, editor_undo_redo, project_context, reference_graph)
	studio.close_confirmed.connect(_finalize_close)
	add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _request_close() -> void:
	if studio == null:
		hide()
		studio_closed.emit()
		return
	studio.request_close()


func _finalize_close() -> void:
	_store_state()
	if studio != null:
		studio.dispose_document()
		remove_child(studio)
		studio.queue_free()
		studio = null
	hide()
	studio_closed.emit()


func _store_state() -> void:
	var state := studio.get_state_snapshot() if studio != null else \
		SkillTreeUiStateService.load_state()
	state["window_screen"] = current_screen
	state["window_position"] = position
	state["window_size"] = size
	state["window_maximized"] = mode == Window.MODE_MAXIMIZED
	SkillTreeUiStateService.save_state(state)


func _apply_window_state(state: Dictionary) -> void:
	var screen_count := DisplayServer.get_screen_count()
	current_screen = clampi(
		int(state.get("window_screen", current_screen)),
		0,
		maxi(0, screen_count - 1)
	)
	var stored_size := _as_vector2i(state.get("window_size", DEFAULT_SIZE), DEFAULT_SIZE)
	size = Vector2i(
		maxi(MINIMUM_SIZE.x, stored_size.x),
		maxi(MINIMUM_SIZE.y, stored_size.y)
	)
	var usable := DisplayServer.screen_get_usable_rect(current_screen)
	var stored_position := _as_vector2i(
		state.get("window_position", usable.position + Vector2i(40, 40)),
		usable.position + Vector2i(40, 40)
	)
	position = Vector2i(
		clampi(stored_position.x, usable.position.x, usable.end.x - 120),
		clampi(stored_position.y, usable.position.y, usable.end.y - 80)
	)
	mode = Window.MODE_MAXIMIZED \
		if bool(state.get("window_maximized", false)) else Window.MODE_WINDOWED


func _as_vector2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback
