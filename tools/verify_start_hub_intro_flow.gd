extends Node

const OBSERVER_SCRIPT := preload("res://tools/start_hub_intro_flow_observer.gd")

@onready var hub: Node = $StartHub


func _ready() -> void:
	print("START_HUB_INTRO_FLOW_VERIFY: bootstrap")
	var observer := OBSERVER_SCRIPT.new()
	get_tree().root.add_child.call_deferred(observer)
	observer.start.call_deferred(hub)
