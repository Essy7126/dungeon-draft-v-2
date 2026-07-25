class_name CharacterProgressionService
extends RefCounted


func grant_cast_xp(
		character_states: Dictionary,
		caster: Unit,
		spell: Spell,
		report: Dictionary
	) -> Dictionary:
	if caster == null or spell == null or report.get("failed", false):
		return {}
	if spell.discipline_id == &"":
		return {}

	var character_state := _find_state_for_unit(character_states, caster)
	if character_state == null:
		return {}
	var progress_result := character_state.add_discipline_xp(spell.discipline_id, 1)
	if progress_result.is_empty():
		return {}
	progress_result["character_id"] = character_state.character_id
	progress_result["caster"] = caster
	progress_result["spell_id"] = spell.get_effective_spell_id()
	return progress_result


func _find_state_for_unit(
		character_states: Dictionary,
		caster: Unit
	) -> CharacterRunState:
	for candidate in character_states.values():
		var state := candidate as CharacterRunState
		if state != null and state.unit == caster:
			return state
	return null
