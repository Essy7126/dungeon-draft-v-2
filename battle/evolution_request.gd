class_name EvolutionRequest
extends RefCounted

var character_id: StringName = &""
var discipline_id: StringName = &""
var pending_rank: int = 0
var source_spell_id: StringName = &""
var trigger_sequence: int = 0
var request_id: StringName = &""


static func create(
		wanted_character_id: StringName,
		wanted_discipline_id: StringName,
		wanted_pending_rank: int,
		wanted_source_spell_id: StringName,
		wanted_trigger_sequence: int,
		wanted_request_id: StringName
	) -> EvolutionRequest:
	var request := EvolutionRequest.new()
	request.character_id = wanted_character_id
	request.discipline_id = wanted_discipline_id
	request.pending_rank = wanted_pending_rank
	request.source_spell_id = wanted_source_spell_id
	request.trigger_sequence = wanted_trigger_sequence
	request.request_id = wanted_request_id
	return request


func get_deduplication_key() -> String:
	return "%s:%s:%d" % [character_id, discipline_id, pending_rank]


func is_valid() -> bool:
	return character_id != &"" \
		and discipline_id != &"" \
		and pending_rank >= 2 \
		and request_id != &""


func to_dictionary() -> Dictionary:
	return {
		"character_id": character_id,
		"discipline_id": discipline_id,
		"pending_rank": pending_rank,
		"source_spell_id": source_spell_id,
		"trigger_sequence": trigger_sequence,
		"request_id": request_id,
	}
