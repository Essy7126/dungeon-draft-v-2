@tool
class_name ArenaProductionPlan
extends Resource

@export var ok := false
@export var can_produce := false
@export var destination := ""
@export var source_fingerprint := ""
@export var creates := PackedStringArray()
@export var modifies := PackedStringArray()
@export var conflicts := PackedStringArray()
@export var bundle_state: StringName = &"UNKNOWN"
@export var bundle_resolution := {}
@export var compatibility_outputs := false


static func from_dict(data: Dictionary) -> ArenaProductionPlan:
	var plan := ArenaProductionPlan.new()
	plan.ok = bool(data.get("ok", false))
	plan.can_produce = bool(data.get("can_produce", false))
	plan.destination = str(data.get("destination", ""))
	plan.source_fingerprint = str(data.get("source_fingerprint", ""))
	plan.creates.assign(data.get("creates", []))
	plan.modifies.assign(data.get("modifies", []))
	plan.conflicts.assign(data.get("conflicts", []))
	plan.bundle_state = StringName(data.get("bundle_state", "UNKNOWN"))
	plan.bundle_resolution = (data.get("bundle_resolution", {}) as Dictionary).duplicate(true)
	plan.compatibility_outputs = bool(data.get("compatibility_outputs", false))
	return plan


func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"can_produce": can_produce,
		"destination": destination,
		"source_fingerprint": source_fingerprint,
		"creates": Array(creates),
		"modifies": Array(modifies),
		"conflicts": Array(conflicts),
		"bundle_state": str(bundle_state),
		"bundle_resolution": bundle_resolution.duplicate(true),
		"compatibility_outputs": compatibility_outputs,
	}
