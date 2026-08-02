class_name ArchivistPanel
extends Control

signal trade_requested
signal run_requested
signal closed
signal dialogue_opened

@onready var title_label: Label = %Title
@onready var main_menu: VBoxContainer = %MainMenu
@onready var dialogue_view: VBoxContainer = %DialogueView
@onready var dialogue_label: Label = %DialogueText

var data: LanternboundArchivistData = null


func _ready() -> void:
	%TalkButton.pressed.connect(_show_dialogue)
	%TradeButton.pressed.connect(func(): trade_requested.emit())
	%RunButton.pressed.connect(func(): run_requested.emit())
	%LeaveButton.pressed.connect(close_panel)
	%DialogueBackButton.pressed.connect(show_menu)


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


func is_dialogue_open() -> bool:
	return visible and dialogue_view.visible


func _show_dialogue() -> void:
	main_menu.visible = false
	dialogue_view.visible = true
	dialogue_opened.emit()
