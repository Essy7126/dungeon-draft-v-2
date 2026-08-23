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


func merge_wave_report(wave_report: CharacterCombatReport) -> void:
	if wave_report == null or wave_report.character_id != character_id:
		return
	damage_dealt += wave_report.damage_dealt
	damage_taken += wave_report.damage_taken
	healing_done += wave_report.healing_done
	shield_applied += wave_report.shield_applied
	kills += wave_report.kills
	spells_cast_total += wave_report.spells_cast_total
	cells_moved += wave_report.cells_moved
	for spell_id in wave_report.spells_cast_by_id:
		spells_cast_by_id[spell_id] = (
			int(spells_cast_by_id.get(spell_id, 0))
			+ int(wave_report.spells_cast_by_id[spell_id])
		)
	for discipline_id in wave_report.discipline_xp_before:
		if not discipline_xp_before.has(discipline_id):
			discipline_xp_before[discipline_id] = (
				wave_report.discipline_xp_before[discipline_id]
			)
	for discipline_id in wave_report.discipline_xp_after:
		discipline_xp_after[discipline_id] = (
			wave_report.discipline_xp_after[discipline_id]
		)
	for acquired_node in wave_report.selected_nodes_during_combat:
		_append_unique_acquired_node(selected_nodes_during_combat, acquired_node)
	for wave_delta in wave_report.discipline_deltas:
		if wave_delta == null:
			continue
		var cumulative_delta := _get_progression_delta(
			wave_delta.spell_id,
			wave_delta.discipline_id,
		)
		if cumulative_delta == null:
			discipline_deltas.append(wave_delta)
			continue
		cumulative_delta.xp_after = wave_delta.xp_after
		cumulative_delta.rank_after = wave_delta.rank_after
		cumulative_delta.next_threshold_after = wave_delta.next_threshold_after
		for reached_rank in wave_delta.reached_ranks:
			if not cumulative_delta.reached_ranks.has(reached_rank):
				cumulative_delta.reached_ranks.append(reached_rank)
		cumulative_delta.reached_ranks.sort()
		for acquired_node in wave_delta.acquired_nodes:
			_append_unique_acquired_node(
				cumulative_delta.acquired_nodes,
				acquired_node,
			)


func _get_progression_delta(
		spell_id: StringName,
		discipline_id: StringName
	) -> DisciplineProgressDelta:
	for delta in discipline_deltas:
		if delta == null:
			continue
		if spell_id != &"" and delta.spell_id == spell_id:
			return delta
		if spell_id == &"" and delta.discipline_id == discipline_id:
			return delta
	return null


func _append_unique_acquired_node(
		target: Array[Dictionary],
		acquired_node: Dictionary
	) -> void:
	var upgrade_id := StringName(acquired_node.get("upgrade_id", &""))
	for existing in target:
		if upgrade_id != &"" \
				and StringName(existing.get("upgrade_id", &"")) == upgrade_id:
			return
	target.append(acquired_node.duplicate(true))


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
