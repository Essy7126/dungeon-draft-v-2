class_name CombatEventFact
extends RefCounted

## Immutable-by-convention description of one already-applied combat fact.
## Runtime Nodes are deliberately excluded from to_metadata(); only stable ids
## may cross a persistence or snapshot boundary.

static var _event_sequence: int = 0

var event_id: StringName = &""
var event_type: StringName = &""
var action_id: StringName = &""
var cast_id: StringName = &""
var impact_id: StringName = &""
var sequence_index: int = 0
var source = null
var target = null
var ability_id: StringName = &""
var status_id: StringName = &""
# Amount resolved by defenses before shield absorption and HP clamping.
# Used by analytics such as overkill-aware damage dealt, never by HP feedback.
var amount_resolved: int = 0
var amount_applied: int = 0
var amount_absorbed: int = 0
var overheal: int = 0
var is_critical: bool = false
var damage_type: int = 0
var element: int = 0
var is_periodic: bool = false
var logical_order: int = 0
var anchor_offset: Vector2 = Vector2(0.0, -72.0)


static func create(
		type: StringName,
		fact_target = null,
		fact_source = null,
		metadata: Dictionary = {}
	) -> CombatEventFact:
	_event_sequence += 1
	var fact := CombatEventFact.new()
	fact.event_id = StringName("combat_event_%010d" % _event_sequence)
	fact.event_type = type
	fact.target = fact_target
	fact.source = fact_source
	fact.action_id = StringName(metadata.get("action_id", &""))
	fact.cast_id = StringName(metadata.get("cast_id", &""))
	fact.impact_id = StringName(metadata.get("impact_id", &""))
	fact.sequence_index = maxi(0, int(metadata.get("sequence_index", 0)))
	fact.ability_id = StringName(metadata.get("ability_id", &""))
	fact.status_id = StringName(metadata.get("status_id", &""))
	fact.amount_resolved = maxi(0, int(metadata.get("amount_resolved", 0)))
	fact.amount_applied = maxi(0, int(metadata.get("amount_applied", 0)))
	fact.amount_absorbed = maxi(0, int(metadata.get("amount_absorbed", 0)))
	fact.overheal = maxi(0, int(metadata.get("overheal", 0)))
	fact.is_critical = bool(metadata.get("is_critical", false))
	fact.damage_type = int(metadata.get("damage_type", 0))
	fact.element = int(metadata.get("element", 0))
	fact.is_periodic = bool(metadata.get("is_periodic", false))
	fact.logical_order = _event_sequence
	if metadata.has("anchor_offset"):
		fact.anchor_offset = metadata["anchor_offset"] as Vector2
	return fact


func to_metadata() -> Dictionary:
	return {
		"event_id": String(event_id),
		"event_type": String(event_type),
		"action_id": String(action_id),
		"cast_id": String(cast_id),
		"impact_id": String(impact_id),
		"sequence_index": sequence_index,
		"source_id": _stable_node_id(source),
		"target_id": _stable_node_id(target),
		"ability_id": String(ability_id),
		"status_id": String(status_id),
		"amount_resolved": amount_resolved,
		"amount_applied": amount_applied,
		"amount_absorbed": amount_absorbed,
		"overheal": overheal,
		"is_critical": is_critical,
		"damage_type": damage_type,
		"element": element,
		"is_periodic": is_periodic,
		"logical_order": logical_order,
	}


func _stable_node_id(value) -> String:
	if value == null:
		return ""
	if value.has_method("get_runtime_stable_id"):
		return str(value.get_runtime_stable_id())
	if value.get("unit_id") != null:
		return str(value.get("unit_id"))
	return ""
