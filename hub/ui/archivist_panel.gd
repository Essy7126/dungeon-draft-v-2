class_name ArchivistPanel
extends Control

signal trade_requested
signal run_requested(run_data: RunData, start_room_index: int)
signal closed
signal dialogue_opened

@onready var title_label: Label = %Title
@onready var main_menu: VBoxContainer = %MainMenu
@onready var dialogue_view: VBoxContainer = %DialogueView
@onready var dialogue_label: Label = %DialogueText
@onready var room_selection_view: VBoxContainer = %RoomSelectionView
@onready var run_selector: OptionButton = %RunSelector
@onready var room_selection_label: Label = %RoomSelectionLabel
@onready var room_selector: OptionButton = %RoomSelector

var data: LanternboundArchivistData = null
var _available_runs: Array[RunData] = []


func _ready() -> void:
	PremiumUI.apply(self)
	%TalkButton.pressed.connect(_show_dialogue)
	%TradeButton.pressed.connect(func(): trade_requested.emit())
	%RunButton.pressed.connect(_show_room_selection)
	%LeaveButton.pressed.connect(close_panel)
	%DialogueBackButton.pressed.connect(show_menu)
	%RoomBackButton.pressed.connect(show_menu)
	%ConfirmRunButton.pressed.connect(_confirm_run)
	run_selector.item_selected.connect(_on_run_selected)


func open_panel(p_data: LanternboundArchivistData) -> void:
	data = p_data
	title_label.text = data.display_name if data != null else "Lanternbound Archivist"
	dialogue_label.text = data.dialogue_text if data != null else ""
	show_menu()
	visible = true
	%TalkButton.grab_focus.call_deferred()


func close_panel() -> void:
	visible = false
	show_menu()
	closed.emit()


func close_silently() -> void:
	visible = false
	show_menu()


func show_menu() -> void:
	main_menu.visible = true
	dialogue_view.visible = false
	room_selection_view.visible = false
	if visible:
		%TalkButton.grab_focus.call_deferred()


func is_dialogue_open() -> bool:
	return visible and dialogue_view.visible


func _show_dialogue() -> void:
	main_menu.visible = false
	dialogue_view.visible = true
	room_selection_view.visible = false
	dialogue_opened.emit()
	%DialogueBackButton.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if dialogue_view.visible or room_selection_view.visible:
		show_menu()
	else:
		close_panel()


func _show_room_selection() -> void:
	_available_runs = data.get_available_runs() if data != null else []
	run_selector.clear()
	for run_index in range(_available_runs.size()):
		run_selector.add_item(_available_runs[run_index].run_name, run_index)
	if run_selector.item_count > 0:
		run_selector.select(0)
	_populate_room_selector(0)
	main_menu.visible = false
	dialogue_view.visible = false
	room_selection_view.visible = true
	_update_run_confirmation_state()
	if run_selector.item_count > 0:
		run_selector.grab_focus.call_deferred()


func _on_run_selected(item_index: int) -> void:
	_populate_room_selector(run_selector.get_item_id(item_index))
	_update_run_confirmation_state()


func _populate_room_selector(run_index: int) -> void:
	room_selector.clear()
	if run_index >= 0 and run_index < _available_runs.size():
		var run_data := _available_runs[run_index]
		room_selection_label.visible = run_data.hub_room_selection_enabled
		room_selector.visible = run_data.hub_room_selection_enabled
		if run_data.hub_room_selection_enabled:
			for index in range(run_data.rooms.size()):
				var room := run_data.rooms[index]
				var room_name := (
					room.room_name if room != null else "Salle %d" % (index + 1)
				)
				room_selector.add_item(room_name, index)
		else:
			var forced_index := run_data.hub_forced_start_room_index
			if forced_index >= 0 and forced_index < run_data.rooms.size():
				var forced_room := run_data.rooms[forced_index]
				var forced_name := (
					forced_room.room_name
					if forced_room != null else "Salle %d" % (forced_index + 1)
				)
				room_selector.add_item(forced_name, forced_index)
	else:
		room_selection_label.visible = true
		room_selector.visible = true
	if room_selector.item_count > 0:
		room_selector.select(0)


func _update_run_confirmation_state() -> void:
	var selected_run_index := run_selector.get_selected_id()
	%ConfirmRunButton.disabled = selected_run_index < 0 \
		or selected_run_index >= _available_runs.size() \
		or room_selector.item_count == 0


func _confirm_run() -> void:
	var selected_run_index := run_selector.get_selected_id()
	if selected_run_index < 0 or selected_run_index >= _available_runs.size():
		return
	var selected_run := _available_runs[selected_run_index]
	var selected_room_index := selected_run.get_hub_start_room_index(
		room_selector.get_selected_id()
	)
	if selected_room_index < 0 or selected_room_index >= selected_run.rooms.size():
		return
	%ConfirmRunButton.disabled = true
	run_requested.emit(selected_run, selected_room_index)
