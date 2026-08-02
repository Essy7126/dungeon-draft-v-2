class_name CharacterCombatReport
extends RefCounted

var character_id: StringName = &""
var display_name := ""
var damage_dealt := 0
var damage_taken := 0
var healing_done := 0
var shield_applied := 0
var kills := 0
var spells_cast_total := 0
var spells_cast_by_id: Dictionary = {}
var cells_moved := 0
var discipline_xp_before: Dictionary = {}
var discipline_xp_after: Dictionary = {}
var selected_nodes_during_combat: Array[Dictionary] = []
var discipline_deltas: Array[DisciplineProgressDelta] = []


func record_spell(spell_id: StringName) -> void:
	spells_cast_total += 1
	var key := str(spell_id)
	spells_cast_by_id[key] = int(spells_cast_by_id.get(key, 0)) + 1


func to_dictionary() -> Dictionary:
	var deltas: Array[Dictionary] = []
	for delta in discipline_deltas:
		if delta != null:
			deltas.append(delta.to_dictionary())
	return {
		"character_id": character_id,
		"display_name": display_name,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"healing_done": healing_done,
		"shield_applied": shield_applied,
		"kills": kills,
		"spells_cast_total": spells_cast_total,
		"spells_cast_by_id": spells_cast_by_id.duplicate(true),
		"cells_moved": cells_moved,
		"discipline_xp_before": discipline_xp_before.duplicate(true),
		"discipline_xp_after": discipline_xp_after.duplicate(true),
		"selected_nodes_during_combat": selected_nodes_during_combat.duplicate(true),
		"discipline_deltas": deltas,
	}
