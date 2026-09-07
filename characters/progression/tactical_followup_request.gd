class_name TacticalFollowupRequest
extends RefCounted

const TYPE_FREE_MOVE: StringName = &"free_move"
const TYPE_ORTHOGONAL_STEP: StringName = &"orthogonal_step"
const TYPE_PROJECTILE_ORIGIN: StringName = &"projectile_origin"
const TYPE_SHIELD_CONVERSION: StringName = &"shield_conversion"

var request_id: StringName = &""
var source_id: StringName = &""
var request_type: StringName = &""
var valid_cells: Array[Vector2i] = []
var valid_targets: Array = []
var valid_option_ids: Array[StringName] = []
var optional: bool = false
var expiry_scope: StringName = &"ACTIVATION"
var expiry_token: StringName = &""
var created_event_serial: int = 0
var priority: int = 0
var requires_preview: bool = true


func is_structurally_valid() -> bool:
	if request_id == &"" or source_id == &"" or request_type == &"" \
			or expiry_scope == &"" or created_event_serial < 0:
		return false
	return not valid_cells.is_empty() \
		or not valid_targets.is_empty() \
		or not valid_option_ids.is_empty()


func accepts_cell(cell: Vector2i) -> bool:
	return valid_cells.has(cell)


func accepts_target(target: Variant) -> bool:
	return valid_targets.has(target)


func accepts_option(option_id: StringName) -> bool:
	return valid_option_ids.has(option_id)


func to_summary() -> Dictionary:
	return {
		"request_id": request_id,
		"source_id": source_id,
		"request_type": request_type,
		"valid_cells": valid_cells.duplicate(),
		"valid_target_count": valid_targets.size(),
		"valid_option_ids": valid_option_ids.duplicate(),
		"optional": optional,
		"expiry_scope": expiry_scope,
		"expiry_token": expiry_token,
		"created_event_serial": created_event_serial,
		"priority": priority,
		"requires_preview": requires_preview,
	}
