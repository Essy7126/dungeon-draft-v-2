class_name VFXExecutionContext
extends RefCounted

const SUPPORTED_FIELDS := [
	&"source", &"targets", &"origin_cell", &"target_cell", &"ordered_path_cells",
	&"affected_cells", &"impact_cells", &"origin_world", &"target_world",
	&"path_world_points", &"impact_world_points", &"impact_timings", &"seed",
	&"speed_scale", &"quality_tier", &"preview_mode", &"target_layer",
	&"magnitude", &"path_valid", &"consumer_kind", &"cell_visual_size",
]

var _values: Dictionary = {}
var _target_layer_ref: WeakRef


static func create(values: Dictionary) -> VFXExecutionContext:
	var context := VFXExecutionContext.new()
	context._initialize(values)
	return context


func _initialize(values: Dictionary) -> void:
	for key in values:
		var normalized := StringName(key)
		if normalized not in SUPPORTED_FIELDS:
			continue
		if normalized == &"target_layer":
			var layer = values[key]
			if layer is Node:
				_target_layer_ref = weakref(layer)
			continue
		_values[normalized] = _safe_copy(values[key])
	if not _values.has(&"seed"):
		_values[&"seed"] = 0
	if not _values.has(&"speed_scale"):
		_values[&"speed_scale"] = 1.0
	if not _values.has(&"quality_tier"):
		_values[&"quality_tier"] = 2


func has(requirement: StringName) -> bool:
	if requirement == &"target_layer":
		return get_target_layer() != null
	if not _values.has(requirement):
		return false
	var value = _values[requirement]
	if value == null:
		return false
	if value is Array or value is PackedVector2Array or value is PackedInt32Array:
		return not value.is_empty()
	if value is String or value is StringName:
		return not str(value).is_empty()
	return true


func get_value(key: StringName, default_value = null):
	if not _values.has(key):
		return _safe_copy(default_value)
	return _safe_copy(_values[key])


func get_seed() -> int:
	return int(_values.get(&"seed", 0))


func get_speed_scale() -> float:
	return maxf(float(_values.get(&"speed_scale", 1.0)), 0.01)


func get_quality_tier() -> int:
	return clampi(int(_values.get(&"quality_tier", 2)), 0, 2)


func get_target_layer() -> Node:
	return _target_layer_ref.get_ref() if _target_layer_ref != null else null


func snapshot() -> Dictionary:
	var result := _values.duplicate(true)
	result[&"target_layer_valid"] = get_target_layer() != null
	return result


static func _safe_copy(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	if value is PackedVector2Array or value is PackedInt32Array or value is PackedFloat32Array:
		return value.duplicate()
	return value
