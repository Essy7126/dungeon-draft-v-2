@tool
class_name ShieldInstance
extends Resource

enum ExpiryPolicy {
	NEVER,
	START_OF_NEXT_ACTIVATION,
}

@export var source_id: StringName = &""
@export_range(0, 1000000, 1) var value: int = 0
@export_range(0, 1000000, 1) var initial_value: int = 0
@export_range(0, 1000000, 1) var created_activation: int = 0
@export var expiry_policy: ExpiryPolicy = ExpiryPolicy.NEVER
@export_range(-1000, 1000, 1) var priority: int = 0
@export var tags: Array[StringName] = []


func configure(
		p_source_id: StringName,
		p_value: int,
		p_created_activation: int,
		p_expiry_policy: int = ExpiryPolicy.NEVER,
		p_priority: int = 0,
		p_tags: Array[StringName] = []
	) -> bool:
	if p_source_id == &"" or p_value <= 0 or p_created_activation < 0:
		return false
	source_id = p_source_id
	value = p_value
	initial_value = p_value
	created_activation = p_created_activation
	expiry_policy = p_expiry_policy
	priority = p_priority
	tags.assign(p_tags)
	return true


func is_valid() -> bool:
	return source_id != &"" \
		and value > 0 \
		and initial_value >= value \
		and created_activation >= 0


func should_expire_at_activation_start(current_activation: int) -> bool:
	match expiry_policy:
		ExpiryPolicy.START_OF_NEXT_ACTIVATION:
			return current_activation > created_activation
		_:
			return false


func to_snapshot() -> Dictionary:
	return {
		"source_id": str(source_id),
		"value": value,
		"initial_value": initial_value,
		"created_activation": created_activation,
		"expiry_policy": expiry_policy,
		"priority": priority,
		"tags": tags.map(func(tag: StringName) -> String: return str(tag)),
	}
