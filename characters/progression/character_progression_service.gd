class_name CharacterProgressionService
extends RefCounted

const MAX_DISCIPLINE_XP_PER_COMBAT := 5

var _combat_xp_by_key: Dictionary = {}
var _awarded_spell_activation_keys: Dictionary = {}


func reset_run() -> void:
	begin_combat()


func begin_combat() -> void:
	_combat_xp_by_key.clear()
	_awarded_spell_activation_keys.clear()


func grant_cast_xp(
		character_states: Dictionary,
		caster: Unit,
		spell: Spell,
		report: Dictionary
	) -> Dictionary:
	if caster == null or spell == null:
		return _refusal(&"invalid_cast", caster, spell)
	if report.get("failed", false):
		return _refusal(&"failed", caster, spell)
	if not bool(report.get("effective_cast", false)):
		return _refusal(&"no_combat_state_change", caster, spell)
	if spell.discipline_id == &"":
		return _refusal(&"no_discipline", caster, spell)

	var character_state := _find_state_for_unit(character_states, caster)
	if character_state == null:
		return _refusal(&"character_state_missing", caster, spell)
	var combat_key := _combat_key(
		character_state.character_id,
		spell.discipline_id,
	)
	var combat_xp := int(_combat_xp_by_key.get(combat_key, 0))
	if combat_xp >= MAX_DISCIPLINE_XP_PER_COMBAT:
		return _refusal(
			&"combat_cap_reached",
			caster,
			spell,
			character_state.character_id,
			combat_xp,
		)
	var activation_key := _activation_key(caster, spell)
	if _awarded_spell_activation_keys.has(activation_key):
		return _refusal(
			&"same_spell_already_awarded_this_activation",
			caster,
			spell,
			character_state.character_id,
			combat_xp,
		)

	var progress_result := character_state.add_discipline_xp(spell.discipline_id, 1)
	if progress_result.is_empty():
		return _refusal(
			&"discipline_progress_missing",
			caster,
			spell,
			character_state.character_id,
			combat_xp,
		)
	_awarded_spell_activation_keys[activation_key] = true
	combat_xp += 1
	_combat_xp_by_key[combat_key] = combat_xp
	progress_result["granted"] = true
	progress_result["gained_xp"] = 1
	progress_result["refusal_reason"] = &""
	progress_result["character_id"] = character_state.character_id
	progress_result["caster"] = caster
	progress_result["spell_id"] = spell.get_effective_spell_id()
	progress_result["activation_index"] = caster.activation_index
	progress_result["activation_xp"] = 1
	progress_result["combat_xp"] = combat_xp
	progress_result["combat_cap"] = MAX_DISCIPLINE_XP_PER_COMBAT
	progress_result["combat_cap_reached"] = (
		combat_xp >= MAX_DISCIPLINE_XP_PER_COMBAT
	)
	return progress_result


func get_combat_xp(character_id: StringName, discipline_id: StringName) -> int:
	return int(_combat_xp_by_key.get(_combat_key(character_id, discipline_id), 0))


func _combat_key(character_id: StringName, discipline_id: StringName) -> String:
	return "%s|%s" % [str(character_id), str(discipline_id)]


func _activation_key(caster: Unit, spell: Spell) -> String:
	return "%s|%d|%s" % [
		caster.get_runtime_stable_id(),
		caster.activation_index,
		str(spell.get_effective_spell_id()),
	]


func _refusal(
		reason: StringName,
		caster: Unit,
		spell: Spell,
		character_id: StringName = &"",
		combat_xp: int = 0
	) -> Dictionary:
	return {
		"granted": false,
		"gained_xp": 0,
		"refusal_reason": reason,
		"character_id": character_id,
		"discipline_id": spell.discipline_id if spell != null else &"",
		"caster": caster,
		"spell_id": spell.get_effective_spell_id() if spell != null else &"",
		"activation_index": caster.activation_index if caster != null else -1,
		"activation_xp": 0,
		"combat_xp": combat_xp,
		"combat_cap": MAX_DISCIPLINE_XP_PER_COMBAT,
		"combat_cap_reached": combat_xp >= MAX_DISCIPLINE_XP_PER_COMBAT,
	}


func _find_state_for_unit(
		character_states: Dictionary,
		caster: Unit
	) -> CharacterRunState:
	for candidate in character_states.values():
		var state := candidate as CharacterRunState
		if state != null and state.unit == caster:
			return state
	return null
