class_name ArchivistPanel
extends Control

signal trade_requested
signal run_requested(start_room_index: int)
signal closed
signal dialogue_opened

@onready var title_label: Label = %Title
@onready var main_menu: VBoxContainer = %MainMenu
@onready var dialogue_view: VBoxContainer = %DialogueView
@onready var dialogue_label: Label = %DialogueText
@onready var room_selection_view: VBoxContainer = %RoomSelectionView
@onready var room_selector: OptionButton = %RoomSelector

var data: LanternboundArchivistData = null


func _ready() -> void:
	%TalkButton.pressed.connect(_show_dialogue)
	%TradeButton.pressed.connect(func(): trade_requested.emit())
	%RunButton.pressed.connect(_show_room_selection)
	%LeaveButton.pressed.connect(close_panel)
	%DialogueBackButton.pressed.connect(show_menu)
	%RoomBackButton.pressed.connect(show_menu)
	%ConfirmRunButton.pressed.connect(_confirm_run)


func open_panel(p_data: LanternboundArchivistData) -> void:
	data = p_data
	title_label.text = data.display_name if data != null else "Lanternbound Archivist"
	dialogue_label.text = data.dialogue_text if data != null else ""
	show_menu()
	visible = true


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


func is_dialogue_open() -> bool:
	return visible and dialogue_view.visible


func _show_dialogue() -> void:
	main_menu.visible = false
	dialogue_view.visible = true
	room_selection_view.visible = false
	dialogue_opened.emit()


func _show_room_selection() -> void:
	room_selector.clear()
	if data != null and data.run_data != null:
		for index in range(data.run_data.rooms.size()):
			var room := data.run_data.rooms[index]
			var room_name := room.room_name if room != null else "Salle %d" % (index + 1)
			room_selector.add_item(room_name, index)
	main_menu.visible = false
	dialogue_view.visible = false
	room_selection_view.visible = true
	%ConfirmRunButton.disabled = room_selector.item_count == 0
	if room_selector.item_count > 0:
		room_selector.select(0)
		room_selector.grab_focus.call_deferred()


func _confirm_run() -> void:
	var selected_item := room_selector.get_selected_id()
	if selected_item < 0:
		return
	%ConfirmRunButton.disabled = true
	run_requested.emit(selected_item)
