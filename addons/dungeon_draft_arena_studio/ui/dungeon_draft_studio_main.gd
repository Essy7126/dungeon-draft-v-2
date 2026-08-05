@tool
class_name DungeonDraftStudioMain
extends Control

var editor_interface = null
var editor_undo_redo = null
var tabs: TabContainer
var arena_studio: ArenaStudioMain
var encounter_studio: EncounterStudioMain
var _pending_state := {}


func setup(host_editor_interface, undo_manager) -> void:
	editor_interface = host_editor_interface
	editor_undo_redo = undo_manager


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs = TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tabs)

	arena_studio = ArenaStudioMain.new()
	arena_studio.name = "Arenes"
	arena_studio.setup(editor_interface, editor_undo_redo)
	tabs.add_child(arena_studio)
	tabs.set_tab_title(tabs.get_tab_count() - 1, "ARENES")

	encounter_studio = EncounterStudioMain.new()
	encounter_studio.name = "Rencontres"
	encounter_studio.setup(editor_interface, editor_undo_redo)
	encounter_studio.open_arena_requested.connect(_open_arena_tab)
	tabs.add_child(encounter_studio)
	tabs.set_tab_title(tabs.get_tab_count() - 1, "RENCONTRES")

	if not _pending_state.is_empty():
		apply_state_snapshot(_pending_state)
		_pending_state.clear()


func ensure_initial_content_loaded() -> void:
	if arena_studio != null:
		arena_studio.ensure_initial_arena_loaded()


func get_state_snapshot() -> Dictionary:
	return {
		"tab": tabs.current_tab if tabs != null else 0,
		"encounter": encounter_studio.get_state_snapshot() \
			if encounter_studio != null else {},
	}


func apply_state_snapshot(state: Dictionary) -> void:
	if not is_node_ready() or tabs == null or encounter_studio == null:
		_pending_state = state.duplicate(true)
		return
	tabs.current_tab = clampi(int(state.get("tab", 0)), 0, tabs.get_tab_count() - 1)
	var encounter_state = state.get("encounter", {})
	if encounter_state is Dictionary:
		encounter_studio.apply_state_snapshot(encounter_state)


func _open_arena_tab() -> void:
	if tabs != null:
		tabs.current_tab = 0
