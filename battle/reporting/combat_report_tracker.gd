class_name CombatReportTracker
extends RefCounted

var _report: CombatReport = null
var _active := false
var _unit_to_character: Dictionary = {}
var _before_snapshots: Dictionary = {}
var _movement_connections: Array[Dictionary] = []


func begin(character_states: Array, room_index: int, room_name: String) -> CombatReport:
	discard()
	_report = CombatReport.new()
	_report.room_index = room_index
	_report.room_name = room_name if room_name != "" else "Salle %d" % (room_index + 1)
	_report.report_id = StringName("combat_%03d_%010d" % [
		maxi(room_index, 0),
		Time.get_ticks_msec(),
	])
	_report.started_at_msec = Time.get_ticks_msec()
	for value in character_states:
		var state := value as CharacterRunState
		if state == null or state.unit == null:
			continue
		var character := CharacterCombatReport.new()
		character.character_id = state.character_id
		character.display_name = state.unit.unit_name
		_report.character_reports.append(character)
		_unit_to_character[state.unit.get_instance_id()] = state.character_id
		_before_snapshots[state.character_id] = _capture_progression_snapshot(state)
		var moved_callback := Callable(self, "_on_unit_moved").bind(state.unit)
		state.unit.moved.connect(moved_callback)
		_movement_connections.append({
			"unit": state.unit,
			"callback": moved_callback,
		})
	_connect_events()
	_active = true
	return _report


func finalize(character_states: Array, victory: bool) -> CombatReport:
	if _report == null:
		return null
	_disconnect_events()
	for value in character_states:
		var state := value as CharacterRunState
		if state != null:
			_finalize_character_progression(state)
	_report.victory = victory
	_report.finalized = true
	_report.completed_at_msec = Time.get_ticks_msec()
	_active = false
	return _report


func discard() -> void:
	_disconnect_events()
	_report = null
	_active = false
	_unit_to_character.clear()
	_before_snapshots.clear()


func is_active() -> bool:
	return _active


func get_report() -> CombatReport:
	return _report


func _connect_events() -> void:
	_connect_once(EventBus.damage_dealt, _on_damage_dealt)
	_connect_once(EventBus.health_damage_taken, _on_health_damage_taken)
	_connect_once(EventBus.healing_applied, _on_healing_applied)
	_connect_once(EventBus.shield_applied, _on_shield_applied)
	_connect_once(EventBus.unit_killed, _on_unit_killed)
	_connect_once(EventBus.spell_cast, _on_spell_cast)


func _connect_once(signal_value: Signal, callback: Callable) -> void:
	if not signal_value.is_connected(callback):
		signal_value.connect(callback)


func _disconnect_events() -> void:
	for entry in [
		[EventBus.damage_dealt, Callable(self, "_on_damage_dealt")],
		[EventBus.health_damage_taken, Callable(self, "_on_health_damage_taken")],
		[EventBus.healing_applied, Callable(self, "_on_healing_applied")],
		[EventBus.shield_applied, Callable(self, "_on_shield_applied")],
		[EventBus.unit_killed, Callable(self, "_on_unit_killed")],
		[EventBus.spell_cast, Callable(self, "_on_spell_cast")],
	]:
		var signal_value: Signal = entry[0]
		var callback: Callable = entry[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)
	for entry in _movement_connections:
		var unit := entry.get("unit") as Unit
		var callback := entry.get("callback") as Callable
		if unit != null and unit.moved.is_connected(callback):
			unit.moved.disconnect(callback)
	_movement_connections.clear()


func _character_for_unit(unit: Unit) -> CharacterCombatReport:
	if not _active or unit == null or _report == null:
		return null
	var character_id := StringName(_unit_to_character.get(unit.get_instance_id(), &""))
	return _report.get_character_report(character_id) if character_id != &"" else null


func _on_damage_dealt(
		_target: Unit,
		attacker: Unit,
		amount: int,
		_category: int,
		_element: int,
		_is_crit: bool
	) -> void:
	var character := _character_for_unit(attacker)
	if character != null:
		character.damage_dealt += maxi(amount, 0)


func _on_health_damage_taken(
		target: Unit,
		_attacker: Unit,
		amount: int,
		_category: int,
		_element: int,
		_is_crit: bool
	) -> void:
	var character := _character_for_unit(target)
	if character != null:
		character.damage_taken += maxi(amount, 0)


func _on_healing_applied(_target: Unit, source: Unit, amount: int) -> void:
	var character := _character_for_unit(source)
	if character != null:
		character.healing_done += maxi(amount, 0)


func _on_shield_applied(_target: Unit, source: Unit, amount: int) -> void:
	var character := _character_for_unit(source)
	if character != null:
		character.shield_applied += maxi(amount, 0)


func _on_unit_killed(_victim: Unit, killer: Unit) -> void:
	var character := _character_for_unit(killer)
	if character != null:
		character.kills += 1


func _on_spell_cast(caster: Unit, spell: Spell, report: Dictionary) -> void:
	if report.get("failed", false):
		return
	var character := _character_for_unit(caster)
	if character != null and spell != null:
		character.record_spell(spell.get_effective_spell_id())


func _on_unit_moved(from_pos: Vector2i, to_pos: Vector2i, unit: Unit) -> void:
	var character := _character_for_unit(unit)
	if character != null:
		character.cells_moved += int(
			abs(to_pos.x - from_pos.x) + abs(to_pos.y - from_pos.y)
		)


func _capture_progression_snapshot(state: CharacterRunState) -> Dictionary:
	var disciplines := {}
	for discipline in state.get_disciplines():
		if discipline == null:
			continue
		var progress := state.get_discipline_progress(discipline.discipline_id)
		if progress == null:
			continue
		disciplines[str(discipline.discipline_id)] = {
			"xp": progress.xp,
			"rank": progress.rank,
			"selected_upgrade_ids": progress.get_selected_upgrade_ids(),
		}
	return {
		"character_id": state.character_id,
		"disciplines": disciplines,
	}


func _finalize_character_progression(state: CharacterRunState) -> void:
	var character := _report.get_character_report(state.character_id)
	if character == null:
		return
	var before := _before_snapshots.get(state.character_id, {}) as Dictionary
	var before_disciplines := before.get("disciplines", {}) as Dictionary
	for discipline in state.get_disciplines():
		if discipline == null:
			continue
		var progress := state.get_discipline_progress(discipline.discipline_id)
		if progress == null:
			continue
		var key := str(discipline.discipline_id)
		var before_entry := before_disciplines.get(key, {}) as Dictionary
		var delta := DisciplineProgressDelta.new()
		delta.character_id = state.character_id
		delta.discipline_id = discipline.discipline_id
		delta.display_name = discipline.display_name
		delta.icon = discipline.icon
		delta.xp_before = int(before_entry.get("xp", 0))
		delta.xp_after = progress.xp
		delta.rank_before = int(before_entry.get("rank", 1))
		delta.rank_after = progress.rank
		var next_rank := progress.get_next_rank_data()
		delta.next_threshold_after = (
			next_rank.required_total_xp if next_rank != null else -1
		)
		for rank_value in range(delta.rank_before + 1, delta.rank_after + 1):
			delta.reached_ranks.append(rank_value)
		for rank_data in discipline.ranks:
			if rank_data != null:
				delta.thresholds.append({
					"rank": rank_data.rank,
					"required_total_xp": rank_data.required_total_xp,
				})
		var selected_before: Array = before_entry.get("selected_upgrade_ids", [])
		for upgrade in progress.get_selected_upgrades():
			if upgrade == null or selected_before.has(upgrade.upgrade_id):
				continue
			var acquired := {
				"upgrade_id": upgrade.upgrade_id,
				"display_name": upgrade.display_name,
				"description": upgrade.description,
				"rank": upgrade.rank,
			}
			delta.acquired_nodes.append(acquired)
			character.selected_nodes_during_combat.append(acquired.duplicate(true))
		character.discipline_xp_before[key] = delta.xp_before
		character.discipline_xp_after[key] = delta.xp_after
		character.discipline_deltas.append(delta)
