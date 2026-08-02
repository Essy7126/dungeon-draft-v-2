class_name TradePanel
extends Control

signal closed

@onready var message_label: Label = %Message


func _ready() -> void:
	%CloseButton.pressed.connect(close_panel)


func open_panel(data: LanternboundArchivistData) -> void:
	message_label.text = data.trade_prototype_text if data != null else ""
	visible = true


func close_panel() -> void:
	visible = false
	closed.emit()


func close_silently() -> void:
	visible = false
