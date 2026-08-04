class_name ForestTestUnit
extends Node2D

var logical_cell := Vector2i(-1, -1)
var team := 0


func configure(cell: Vector2i, unit_team: int, display_name: String) -> void:
	logical_cell = cell
	team = unit_team
	name = display_name
	var body_color := Color("4fb2ff") if team == 0 else Color("ff665c")
	($Body as Polygon2D).color = body_color
	($Core as Polygon2D).color = body_color.lightened(0.34)
	($Name as Label).text = display_name


func set_logical_cell(cell: Vector2i) -> void:
	logical_cell = cell


func get_logical_foot_position() -> Vector2:
	return global_position

