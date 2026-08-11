@tool
class_name VFXModuleData
extends Resource

@export var module_id: StringName = &"module"
@export var module_type: StringName = &""
@export var enabled := true
@export_range(0.0, 30.0, 0.01) var start_offset := 0.0
@export_range(0.01, 30.0, 0.01) var duration := 0.5
@export var anchor: StringName = &"WORLD"
@export var seed_offset := 0
@export_range(0, 2, 1) var minimum_quality := 0
@export var context_requirements: Array[StringName] = []
@export var primary_color := Color(0.35, 0.8, 1.0, 0.9)
@export var secondary_color := Color(0.9, 0.98, 1.0, 0.75)
@export_range(0.0, 4.0, 0.01) var intensity := 1.0
@export var response_curve: Curve
@export var color_gradient: Gradient
@export var parameters: Dictionary = {}


func end_time() -> float:
	return start_offset + maxf(duration, 0.01)
