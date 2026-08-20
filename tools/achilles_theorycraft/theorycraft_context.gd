class_name TheorycraftContext
extends RefCounted

var context_id := "abstract"
var room_resource := ""
var enemy_resources: Array[String] = []
var turn_horizon := 1
var starting_state := {}
var consumables: Array = []
var assumptions: Array = []
var provenance := {}


func to_dict() -> Dictionary:
	var complete_provenance := provenance.duplicate(true)
	if not complete_provenance.has("context_id"):
		complete_provenance["context_id"] = AchillesTheorycraftProvenance.derived(
			"Explicit theorycraft context identifier"
		)
	if not complete_provenance.has("room_resource"):
		complete_provenance["room_resource"] = (
			AchillesTheorycraftProvenance.observed(room_resource)
			if not room_resource.is_empty()
			else AchillesTheorycraftProvenance.not_measured(
				"No room Resource is attached to this context."
			)
		)
	if not complete_provenance.has("enemy_resources"):
		complete_provenance["enemy_resources"] = (
			AchillesTheorycraftProvenance.derived(
				"Enemy roster derived from the selected room", [room_resource]
			)
			if not room_resource.is_empty()
			else AchillesTheorycraftProvenance.not_measured(
				"No room roster is attached to this context."
			)
		)
	if not complete_provenance.has("turn_horizon"):
		complete_provenance["turn_horizon"] = AchillesTheorycraftProvenance.assumption(
			"Single-turn analysis horizon until an owner supplies another scenario."
		)
	if not complete_provenance.has("starting_state"):
		complete_provenance["starting_state"] = (
			AchillesTheorycraftProvenance.assumption(
				"Manually supplied partial turn state; not reconstructed from a live battle."
			)
			if not starting_state.is_empty()
			else AchillesTheorycraftProvenance.not_measured(
				"No exact live turn state was supplied."
			)
		)
	if not complete_provenance.has("consumables"):
		complete_provenance["consumables"] = (
			AchillesTheorycraftProvenance.assumption(
				"Manually supplied consumables for this theorycraft context."
			)
			if not consumables.is_empty()
			else AchillesTheorycraftProvenance.not_measured(
				"No exact consumable state was supplied."
			)
		)
	if not complete_provenance.has("assumptions"):
		complete_provenance["assumptions"] = (
			AchillesTheorycraftProvenance.assumption(
				"Explicit owner-entered context assumptions."
			)
			if not assumptions.is_empty()
			else AchillesTheorycraftProvenance.derived(
				"No additional context assumptions are recorded."
			)
		)
	return {
		"context_id": context_id,
		"room_resource": room_resource,
		"enemy_resources": enemy_resources.duplicate(),
		"turn_horizon": turn_horizon,
		"starting_state": starting_state.duplicate(true),
		"consumables": consumables.duplicate(true),
		"assumptions": assumptions.duplicate(true),
		"provenance": complete_provenance,
	}


static func abstract_context() -> TheorycraftContext:
	var context := TheorycraftContext.new()
	context.context_id = "abstract"
	context.provenance["context_id"] = AchillesTheorycraftProvenance.derived(
		"Explicit map-free context"
	)
	context.provenance["room_resource"] = AchillesTheorycraftProvenance.derived(
		"Room Resource intentionally absent in the explicit map-free context."
	)
	context.provenance["enemy_resources"] = AchillesTheorycraftProvenance.derived(
		"Enemy roster intentionally absent in the explicit map-free context."
	)
	return context


static func from_room(room: RoomData, index: int) -> TheorycraftContext:
	var context := TheorycraftContext.new()
	context.context_id = "odyssey_room_%02d" % (index + 1)
	context.room_resource = room.resource_path if room != null else ""
	if room != null and room.encounter_definition != null:
		for enemy in room.encounter_definition.expanded_roster():
			if enemy != null:
				context.enemy_resources.append(enemy.resource_path)
	context.provenance["room_resource"] = AchillesTheorycraftProvenance.observed(
		context.room_resource
	)
	context.provenance["context_id"] = AchillesTheorycraftProvenance.derived(
		"Ordered Odyssey room index", [context.room_resource]
	)
	context.provenance["enemy_resources"] = AchillesTheorycraftProvenance.observed(
		"%s#encounter_definition.expanded_roster" % context.room_resource
	)
	return context
