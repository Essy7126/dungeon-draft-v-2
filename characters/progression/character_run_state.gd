class_name CharacterRunState
extends RefCounted

var character_id: StringName = &""
var unit: Unit = null
var loadout: SpellLoadoutState = null
var disciplines: Array[DisciplineData] = []
var _discipline_progressions: Dictionary = {} # StringName -> DisciplineProgressState

var discipline_progressions: Dictionary:
	get:
		return _discipline_progressions.duplicate()


func initialize(
		p_unit: Unit,
		unit_data: UnitData,
		slot_count: int = SpellLoadoutState.DEFAULT_ACTIVE_SLOT_COUNT
	) -> bool:
	if p_unit == null or unit_data == null:
		return false
	character_id = unit_data.get_effective_unit_id()
	unit = p_unit
	disciplines = unit_data.disciplines.duplicate()
	_discipline_progressions.clear()
	for discipline in disciplines:
		if discipline == null or _discipline_progressions.has(discipline.discipline_id):
			continue
		var progress := DisciplineProgressState.new()
		if progress.initialize(discipline):
			_discipline_progressions[discipline.discipline_id] = progress
	loadout = SpellLoadoutState.new()
	loadout.changed.connect(sync_loadout_to_unit)
	loadout.initialize(unit_data.spells, slot_count)
	sync_loadout_to_unit()
	_sync_progression_modifiers_to_unit()
	return true


func dispose() -> void:
	if loadout != null:
		var callback := Callable(self, "sync_loadout_to_unit")
		if loadout.changed.is_connected(callback):
			loadout.changed.disconnect(callback)
	if unit != null:
		unit.clear_progression_spell_modifiers()
	character_id = &""
	unit = null
	loadout = null
	disciplines.clear()
	_discipline_progressions.clear()


func sync_loadout_to_unit() -> void:
	if unit == null or loadout == null:
		return
	unit.spells = loadout.get_equipped_spells()


func get_disciplines() -> Array[DisciplineData]:
	return disciplines.duplicate()


func get_discipline_progress(
		discipline_id: StringName
	) -> DisciplineProgressState:
	return _discipline_progressions.get(discipline_id) as DisciplineProgressState


func get_discipline_progressions() -> Dictionary:
	return _discipline_progressions.duplicate()


func get_discipline_progress_snapshot(discipline_id: StringName) -> Dictionary:
	var progress := get_discipline_progress(discipline_id)
	return progress.get_snapshot() if progress != null else {}


func add_discipline_xp(discipline_id: StringName, amount: int) -> Dictionary:
	var progress := get_discipline_progress(discipline_id)
	if progress == null or amount <= 0:
		return {}
	var rank_before := progress.rank
	var reached_ranks := progress.add_xp(amount)
	var result := progress.get_snapshot()
	result["gained_xp"] = amount
	result["rank_before"] = rank_before
	result["reached_ranks"] = reached_ranks.duplicate()
	result["discipline_display_name"] = get_discipline_display_name(discipline_id)
	return result


func select_upgrade(
		discipline_id: StringName,
		choice_rank: int,
		upgrade_id: StringName
	) -> bool:
	var progress := get_discipline_progress(discipline_id)
	if progress == null:
		return false
	var selected := progress.select_upgrade(upgrade_id, choice_rank)
	if selected == null:
		return false
	_sync_progression_modifiers_to_unit()
	return true


func get_pending_progression_choices() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for discipline in disciplines:
		if discipline == null:
			continue
		var progress := get_discipline_progress(discipline.discipline_id)
		if progress == null:
			continue
		for pending_rank in progress.get_pending_rank_choices():
			var rank_data := progress.get_rank_data(pending_rank)
			if rank_data == null or rank_data.choices.is_empty():
				continue
			pending.append({
				"character_id": character_id,
				"character_name": unit.unit_name if unit != null else str(character_id),
				"discipline_id": discipline.discipline_id,
				"discipline_name": discipline.display_name,
				"rank": pending_rank,
				"xp": progress.xp,
				"required_total_xp": rank_data.required_total_xp,
				"choices": rank_data.choices.duplicate(),
			})
	return pending


func get_active_progression_spell_modifiers() -> Array[SpellModifier]:
	var modifiers: Array[SpellModifier] = []
	for progress_value in _discipline_progressions.values():
		var progress := progress_value as DisciplineProgressState
		if progress == null:
			continue
		for upgrade in progress.get_selected_upgrades():
			for modifier in upgrade.get_spell_modifiers():
				if modifier != null and not modifiers.has(modifier):
					modifiers.append(modifier)
	return modifiers


func get_discipline_display_name(discipline_id: StringName) -> String:
	for discipline in disciplines:
		if discipline != null and discipline.discipline_id == discipline_id:
			return discipline.display_name
	return str(discipline_id)


func _sync_progression_modifiers_to_unit() -> void:
	if unit != null:
		unit.set_progression_spell_modifiers(get_active_progression_spell_modifiers())
