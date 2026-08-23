class_name CharacterRunState
extends RefCounted

var character_id: StringName = &""
var unit: Unit = null
var loadout: SpellLoadoutState = null
var equipment_loadout: EquipmentLoadout = null
var _spells_with_trees: Array[Spell] = []
var _spell_progressions: Dictionary = {}
var _dormant_progression_snapshots: Dictionary = {}
var last_restore_report: Dictionary = {}

var discipline_progressions: Dictionary:
	get:
		return _spell_progressions.duplicate()


func initialize(p_unit: Unit, unit_data: UnitData, slot_count: int = SpellLoadoutState.DEFAULT_ACTIVE_SLOT_COUNT) -> bool:
	if p_unit == null or unit_data == null:
		return false
	character_id = unit_data.get_effective_unit_id()
	unit = p_unit
	_spells_with_trees.clear()
	_spell_progressions.clear()
	_dormant_progression_snapshots.clear()
	last_restore_report.clear()
	for spell in unit_data.spells:
		if spell == null:
			continue
		var tree := _resolve_tree(spell, unit_data.disciplines)
		if tree == null:
			continue
		var owner_id := spell.get_effective_spell_id()
		if _spell_progressions.has(owner_id):
			return false
		var progress := DisciplineProgressState.new()
		if not progress.initialize(tree, owner_id):
			return false
		_spells_with_trees.append(spell)
		_spell_progressions[owner_id] = progress
	loadout = SpellLoadoutState.new()
	loadout.changed.connect(sync_loadout_to_unit)
	loadout.initialize(unit_data.spells, slot_count)
	equipment_loadout = EquipmentLoadout.new()
	if not equipment_loadout.initialize(character_id):
		dispose()
		return false
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
	if equipment_loadout != null:
		equipment_loadout.clear(false)
	equipment_loadout = null
	_spells_with_trees.clear()
	_spell_progressions.clear()
	_dormant_progression_snapshots.clear()
	last_restore_report.clear()


func sync_loadout_to_unit() -> void:
	if unit != null and loadout != null:
		unit.spells = loadout.get_equipped_spells()


func get_spells_with_skill_trees() -> Array[Spell]:
	return _spells_with_trees.duplicate()


func get_skill_trees() -> Array[DisciplineData]:
	var trees: Array[DisciplineData] = []
	for progress_value in _spell_progressions.values():
		var progress := progress_value as DisciplineProgressState
		if progress != null and not trees.has(progress.get_skill_tree()):
			trees.append(progress.get_skill_tree())
	return trees


func get_disciplines() -> Array[DisciplineData]:
	return get_skill_trees()


func get_spell_progress(spell_id: StringName) -> DisciplineProgressState:
	return _spell_progressions.get(spell_id) as DisciplineProgressState


func get_discipline_progress(identifier: StringName) -> DisciplineProgressState:
	var direct := get_spell_progress(identifier)
	if direct != null:
		return direct
	for progress_value in _spell_progressions.values():
		var progress := progress_value as DisciplineProgressState
		if progress != null and progress.get_skill_tree().discipline_id == identifier:
			return progress
	return null


func get_spell_progressions() -> Dictionary:
	return _spell_progressions.duplicate()


func get_discipline_progressions() -> Dictionary:
	return get_spell_progressions()


func get_spell_progress_snapshot(spell_id: StringName) -> Dictionary:
	var progress := get_spell_progress(spell_id)
	return progress.get_snapshot() if progress != null else {}


func get_discipline_progress_snapshot(identifier: StringName) -> Dictionary:
	var progress := get_discipline_progress(identifier)
	return progress.get_snapshot() if progress != null else {}


func get_progression_snapshot() -> Dictionary:
	var progression := _dormant_progression_snapshots.duplicate(true)
	for spell_id_value in _spell_progressions:
		progression[str(spell_id_value)] = get_spell_progress_snapshot(spell_id_value)
	return {
		"version": ProgressionSnapshotMigrationService.CURRENT_VERSION,
		"character_id": character_id,
		"spell_progressions": progression,
		"unresolved_legacy_progressions": {},
	}


func restore_progression_snapshot(snapshot: Dictionary) -> bool:
	last_restore_report = ProgressionSnapshotMigrationService.migrate(snapshot, loadout.get_known_spells() if loadout != null else [])
	if not last_restore_report.get("ok", false):
		return false
	var migrated := last_restore_report.get("snapshot", {}) as Dictionary
	if StringName(migrated.get("character_id", &"")) != character_id:
		last_restore_report = {"ok": false, "diagnostics": PackedStringArray(["Le personnage du snapshot ne correspond pas."]), "snapshot": migrated}
		return false
	var serialized := migrated.get("spell_progressions", {}) as Dictionary
	var candidates := {}
	var dormant := {}
	for key_value in serialized:
		var spell_id := StringName(key_value)
		var current := get_spell_progress(spell_id)
		if current == null:
			dormant[str(spell_id)] = (serialized[key_value] as Dictionary).duplicate(true)
			continue
		var candidate := DisciplineProgressState.new()
		if not candidate.initialize(current.get_skill_tree(), spell_id) or not candidate.restore_snapshot(serialized[key_value] as Dictionary):
			last_restore_report = {"ok": false, "diagnostics": PackedStringArray(["Progression invalide pour le sort %s." % spell_id]), "snapshot": migrated}
			return false
		candidates[spell_id] = candidate
	for spell_id_value in _spell_progressions:
		if not candidates.has(spell_id_value):
			candidates[spell_id_value] = _spell_progressions[spell_id_value]
	_spell_progressions = candidates
	_dormant_progression_snapshots = dormant
	_sync_progression_modifiers_to_unit()
	return true


func add_spell_xp(spell_id: StringName, amount: int) -> Dictionary:
	var progress := get_spell_progress(spell_id)
	if progress == null or amount <= 0:
		return {}
	var rank_before := progress.rank
	var reached_ranks := progress.add_xp(amount)
	var result := progress.get_snapshot()
	result["gained_xp"] = amount
	result["rank_before"] = rank_before
	result["reached_ranks"] = reached_ranks.duplicate()
	result["spell_display_name"] = get_spell_display_name(spell_id)
	result["tree_display_name"] = get_skill_tree_display_name(spell_id)
	result["tree_id"] = progress.get_skill_tree().discipline_id
	result["discipline_display_name"] = result["tree_display_name"]
	return result


func add_discipline_xp(identifier: StringName, amount: int) -> Dictionary:
	var progress := get_discipline_progress(identifier)
	return add_spell_xp(progress.spell_id, amount) if progress != null else {}


func select_upgrade(spell_id: StringName, choice_rank: int, upgrade_id: StringName) -> bool:
	var progress := get_spell_progress(spell_id)
	if progress == null:
		progress = get_discipline_progress(spell_id)
	if progress == null or progress.select_upgrade(upgrade_id, choice_rank) == null:
		return false
	_sync_progression_modifiers_to_unit()
	return true


func get_pending_progression_choices() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for spell in _spells_with_trees:
		var spell_id := spell.get_effective_spell_id()
		var progress := get_spell_progress(spell_id)
		if progress == null:
			continue
		var tree := progress.get_skill_tree()
		for pending_rank in progress.get_pending_rank_choices():
			var rank_data := progress.get_rank_data(pending_rank)
			if rank_data == null:
				continue
			var available_choices := SkillTreeResolver.get_available_nodes(tree, pending_rank, progress.rank, progress.get_pending_rank_choices(), progress.get_selected_upgrade_ids())
			pending.append({
				"character_id": character_id,
				"character_name": unit.unit_name if unit != null else str(character_id),
				"spell_id": spell_id,
				"spell_name": spell.spell_name,
				"tree_id": tree.discipline_id,
				"tree_name": tree.display_name,
				"discipline_id": tree.discipline_id,
				"discipline_name": tree.display_name,
				"rank": pending_rank,
				"xp": progress.xp,
				"required_total_xp": rank_data.required_total_xp,
				"choices": available_choices,
			})
	return pending


func get_active_progression_spell_modifiers_by_spell() -> Dictionary:
	var result := {}
	for progress_value in _spell_progressions.values():
		var progress := progress_value as DisciplineProgressState
		if progress == null:
			continue
		for upgrade in progress.get_selected_upgrades():
			var target_id := upgrade.target_spell_id if upgrade.target_spell_id != &"" else progress.spell_id
			var modifiers: Array[SpellModifier] = []
			modifiers.assign(result.get(target_id, []))
			for modifier in upgrade.get_spell_modifiers():
				if modifier != null and not modifiers.has(modifier):
					modifiers.append(modifier)
			result[target_id] = modifiers
	return result


func get_active_progression_spell_modifiers() -> Array[SpellModifier]:
	var flattened: Array[SpellModifier] = []
	for values in get_active_progression_spell_modifiers_by_spell().values():
		for modifier in values:
			if modifier != null and not flattened.has(modifier):
				flattened.append(modifier)
	return flattened


func get_spell_display_name(spell_id: StringName) -> String:
	for spell in _spells_with_trees:
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell.spell_name
	return str(spell_id)


func get_skill_tree_display_name(spell_id: StringName) -> String:
	var progress := get_spell_progress(spell_id)
	return progress.get_skill_tree().display_name if progress != null else str(spell_id)


func get_discipline_display_name(identifier: StringName) -> String:
	var progress := get_discipline_progress(identifier)
	return progress.get_skill_tree().display_name if progress != null else str(identifier)


func _sync_progression_modifiers_to_unit() -> void:
	if unit != null:
		unit.set_progression_spell_modifiers_by_spell(get_active_progression_spell_modifiers_by_spell())


static func _resolve_tree(spell: Spell, legacy_trees: Array[DisciplineData]) -> DisciplineData:
	if spell == null:
		return null
	if spell.skill_tree != null:
		return spell.skill_tree
	for tree in legacy_trees:
		if tree != null and tree.discipline_id == spell.discipline_id:
			return tree
	return null
