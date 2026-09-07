@tool
class_name ItemReactiveConditionData
extends Resource

@export var condition_id: StringName = &"trigger_team"
@export var comparison: StringName = &"equal"
@export var value := 0.0
@export var team := 0
@export var string_name_value: StringName = &""


func is_valid() -> bool:
	return condition_id != &"" \
		and comparison in [&"equal", &"less", &"less_or_equal", &"greater", &"greater_or_equal"] \
		and is_finite(value)
