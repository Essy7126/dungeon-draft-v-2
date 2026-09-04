class_name TradePanel
extends Control

signal closed

@onready var message_label: Label = %Message


func _ready() -> void:
	PremiumUI.apply(self)
	%CloseButton.pressed.connect(close_panel)


func open_panel(data: LanternboundArchivistData) -> void:
	message_label.text = data.trade_prototype_text if data != null else ""
	visible = true
	%CloseButton.grab_focus.call_deferred()


func close_panel() -> void:
	visible = false
	closed.emit()


func close_silently() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
