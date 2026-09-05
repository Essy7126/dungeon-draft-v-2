extends Node

const PROBE := preload("res://tools/achilles_sprite_validation/courtyard_sprite_probe.gd")


func _ready() -> void:
	_launch.call_deferred()


func _launch() -> void:
	var probe := PROBE.new()
	get_tree().root.add_child(probe)
	get_tree().change_scene_to_file("res://tools/labs/greek_drawn_arena/GreekDrawnCourtyard.tscn")
