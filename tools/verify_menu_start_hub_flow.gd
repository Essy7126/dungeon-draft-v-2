extends Node

const OBSERVER_SCRIPT := preload("res://tools/menu_start_hub_flow_observer.gd")

@onready var title: Node = $Title


func _ready() -> void:
	var observer := OBSERVER_SCRIPT.new()
	get_tree().root.add_child.call_deferred(observer)
	observer.start.call_deferred(title)
