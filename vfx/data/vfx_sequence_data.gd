@tool
class_name VFXSequenceData
extends Resource

@export var sequence_id: StringName = &"play"
@export var display_name := "Play"
@export var modules: Array[VFXModuleData] = []


func duration() -> float:
	var result := 0.0
	for module in modules:
		if module != null and module.enabled:
			result = maxf(result, module.end_time())
	return result
