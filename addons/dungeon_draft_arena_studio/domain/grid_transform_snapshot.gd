@tool
class_name GridTransformSnapshot
extends RefCounted

const SCHEMA_VERSION := 1

var origin := Vector2.ZERO
var axis_x := Vector2(48.0, 24.0)
var axis_y := Vector2(-48.0, 24.0)


func _init(
		value_origin := Vector2.ZERO,
		value_axis_x := Vector2(48.0, 24.0),
		value_axis_y := Vector2(-48.0, 24.0)
	) -> void:
	origin = value_origin
	axis_x = value_axis_x
	axis_y = value_axis_y


static func from_arena(arena: ArenaDefinition) -> GridTransformSnapshot:
	if arena == null:
		return GridTransformSnapshot.new()
	return GridTransformSnapshot.new(arena.grid_origin, arena.axis_x, arena.axis_y)


static func from_dictionary(data: Dictionary) -> GridTransformSnapshot:
	return GridTransformSnapshot.new(
		_vector2(data.get("origin", [0.0, 0.0])),
		_vector2(data.get("axis_x", [48.0, 24.0])),
		_vector2(data.get("axis_y", [-48.0, 24.0])),
	)


func copy() -> GridTransformSnapshot:
	return GridTransformSnapshot.new(origin, axis_x, axis_y)


func is_equal_to(other: GridTransformSnapshot, tolerance := 0.00001) -> bool:
	return other != null \
		and origin.distance_to(other.origin) <= tolerance \
		and axis_x.distance_to(other.axis_x) <= tolerance \
		and axis_y.distance_to(other.axis_y) <= tolerance


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"origin": [origin.x, origin.y],
		"axis_x": [axis_x.x, axis_x.y],
		"axis_y": [axis_y.x, axis_y.y],
	}


func fingerprint() -> String:
	return JSON.stringify(to_dictionary()).sha256_text()


func apply_to(arena: ArenaDefinition) -> void:
	if arena == null:
		return
	arena.grid_origin = origin
	arena.axis_x = axis_x
	arena.axis_y = axis_y


static func _vector2(value) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) \
		if value is Array and value.size() >= 2 else Vector2.ZERO
