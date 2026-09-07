class_name CharacterRunState
extends RefCounted

var character_id: StringName = &""
var unit: Unit = null
var loadout: SpellLoadoutState = null
var equipment_loadout: EquipmentLoadout = null
var progression_profile: CharacterProgressionProfile = null
var progression_model: int = (
	CharacterProgressionProfile.ProgressionModel.LEGACY_CAST_XP
)
var champion_progression: ChampionProgressionState = null
var mastery_runtime: MasteryReactiveRuntimeService = null
signal champion_changed
var _spells_with_trees: Array[Spell] = []
var _spell_progressions: Dictionary = {}
var _dormant_progression_snapshots: Dictionary = {}
var last_restore_report: Dictionary = {}

var discipline_progressions: Dictionary:
	get:
		return _spell_progressions.duplicate()


func initialize(
		p_unit: Unit,
		unit_data: UnitData,
		slot_count: int = SpellLoadoutState.DEFAULT_ACTIVE_SLOT_COUNT,
		p_progression_profile: CharacterProgressionProfile = null
	) -> bool:
	if p_unit == null or unit_data == null:
		return false
	if p_progression_profile == null:
		p_progression_profile = unit_data.progression_profile
	character_id = unit_data.get_effective_unit_id()
	if p_progression_profile != null and (
			p_progression_profile.character_id != character_id
			or not p_progression_profile.is_valid()
		):
		return false
	unit = p_unit
	progression_profile = p_progression_profile
	progression_model = (
		p_progression_profile.progression_model
		if p_progression_profile != null
		else CharacterProgressionProfile.ProgressionModel.LEGACY_CAST_XP
	)
	champion_progression = null
	_spells_with_trees.clear()
	_spell_progressions.clear()
	_dormant_progression_snapshots.clear()
	last_restore_report.clear()
	if uses_legacy_cast_xp():
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
	if uses_champion_progression():
		champion_progression = ChampionProgressionState.new()
		if not champion_progression.initialize(
				progression_profile.champion_progression_profile,
				unit,
				progression_profile.mastery_catalog,
			):
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
		unit.mastery_nodes.clear()
		unit.mastery_runtime = null
	if mastery_runtime != null:
		mastery_runtime.reset_run()
	mastery_runtime = null
	if champion_progression != null:
		champion_progression.dispose()
	character_id = &""
	unit = null
	progression_profile = null
	progression_model = CharacterProgressionProfile.ProgressionModel.LEGACY_CAST_XP
	champion_progression = null
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


func uses_champion_progression() -> bool:
	return progression_model \
		== CharacterProgressionProfile.ProgressionModel.CHAMPION_LEVEL_AND_MASTERY


func uses_legacy_cast_xp() -> bool:
	return progression_model \
		== CharacterProgressionProfile.ProgressionModel.LEGACY_CAST_XP


func begin_encounter() -> void:
	if champion_progression != null:
		champion_progression.begin_encounter()


func award_encounter_xp(
		encounter_id: StringName,
		base_xp: int,
		victory: bool,
		glory_accepted: bool = false,
		glory_succeeded: bool = false
	) -> Dictionary:
	if champion_progression == null:
		return {
			"granted": false,
			"refusal_reason": &"LEGACY_CAST_XP_POLICY",
			"gained_xp": 0,
			"character_id": character_id,
		}
	var result := champion_progression.award_encounter_xp(
		encounter_id,
		base_xp,
		victory,
		glory_accepted,
		glory_succeeded,
	)
	result["character_id"] = character_id
	result["progression_snapshot"] = champion_progression.to_snapshot()
	if bool(result.get("granted", false)):
		champion_changed.emit()
	return result


func spend_champion_attribute(attribute_id: StringName) -> bool:
	if champion_progression == null or not champion_progression.spend_attribute(attribute_id):
		return false
	champion_changed.emit()
	return true


func get_spell_progress_snapshot(spell_id: StringName) -> Dictionary:
	var progress := get_spell_progress(spell_id)
	return progress.get_snapshot() if progress != null else {}


func get_discipline_progress_snapshot(identifier: StringName) -> Dictionary:
	var progress := get_discipline_progress(identifier)
	return progress.get_snapshot() if progress != null else {}


func get_progression_snapshot() -> Dictionary:
	if uses_champion_progression():
		return {
			"version": ProgressionSnapshotMigrationService.CURRENT_VERSION,
			"progression_model": progression_model,
			"character_id": character_id,
			"champion_progression": (
				champion_progression.to_snapshot()
				if champion_progression != null else {}
			),
		}
	var progression := _dormant_progression_snapshots.duplicate(true)
	for spell_id_value in _spell_progressions:
		progression[str(spell_id_value)] = get_spell_progress_snapshot(spell_id_value)
	return {
		"version": ProgressionSnapshotMigrationService.CURRENT_VERSION,
		"progression_model": progression_model,
		"character_id": character_id,
		"spell_progressions": progression,
		"unresolved_legacy_progressions": {},
	}


func restore_progression_snapshot(snapshot: Dictionary) -> bool:
	last_restore_report = ProgressionSnapshotMigrationService.migrate(
		snapshot,
		loadout.get_known_spells() if loadout != null else [],
		progression_model,
	)
	if not last_restore_report.get("ok", false):
		return false
	var migrated := last_restore_report.get("snapshot", {}) as Dictionary
	if StringName(migrated.get("character_id", &"")) != character_id:
		last_restore_report = {"ok": false, "diagnostics": PackedStringArray(["Le personnage du snapshot ne correspond pas."]), "snapshot": migrated}
		return false
	if uses_champion_progression():
		var champion_snapshot: Variant = migrated.get(
			"champion_progression", null
		)
		if champion_progression == null \
				or not champion_snapshot is Dictionary \
				or not champion_progression.restore_snapshot(
					champion_snapshot as Dictionary
				):
			last_restore_report = {
				"ok": false,
				"diagnostics": PackedStringArray([
					"Le snapshot Champion est absent ou incompatible.",
				]),
				"snapshot": migrated,
			}
			return false
		_sync_progression_modifiers_to_unit()
		champion_changed.emit()
		return true
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
	if not uses_legacy_cast_xp():
		return {}
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
	if not uses_legacy_cast_xp():
		return false
	var progress := get_spell_progress(spell_id)
	if progress == null:
		progress = get_discipline_progress(spell_id)
	if progress == null or progress.select_upgrade(upgrade_id, choice_rank) == null:
		return false
	_sync_progression_modifiers_to_unit()
	return true


func get_pending_progression_choices() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	if not uses_legacy_cast_xp():
		return pending
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
	if uses_champion_progression():
		return MasteryStaticModifierResolver.modifiers_by_spell(get_selected_mastery_nodes())
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
		if uses_champion_progression():
			var preserve_state := mastery_runtime != null
			if mastery_runtime == null:
				mastery_runtime = MasteryReactiveRuntimeService.new()
			unit.mastery_nodes = get_selected_mastery_nodes()
			mastery_runtime.configure_from_nodes(unit.mastery_nodes, preserve_state)
			unit.mastery_runtime = mastery_runtime


static func _resolve_tree(spell: Spell, legacy_trees: Array[DisciplineData]) -> DisciplineData:
	if spell == null:
		return null
	if spell.skill_tree != null:
		return spell.skill_tree
	for tree in legacy_trees:
		if tree != null and tree.discipline_id == spell.discipline_id:
			return tree
	return null


func get_mastery_nodes() -> Array[SkillTreeNodeData]:
	var result: Array[SkillTreeNodeData] = []
	if progression_profile == null or progression_profile.mastery_catalog == null:
		return result
	for value in progression_profile.mastery_catalog.node_catalog().values():
		var node := value as SkillTreeNodeData
		if node != null:
			result.append(node)
	return result


func get_selected_mastery_nodes() -> Array[SkillTreeNodeData]:
	var result: Array[SkillTreeNodeData] = []
	if champion_progression == null:
		return result
	for node in get_mastery_nodes():
		if champion_progression.selected_node_ids.has(node.upgrade_id):
			result.append(node)
	return result


func evaluate_mastery_node(node_id: StringName) -> Dictionary:
	if champion_progression == null or progression_profile.mastery_catalog == null:
		return {"allowed": false, "reason_id": "WRONG_PROGRESSION_MODE"}
	var catalog := progression_profile.mastery_catalog
	return SkillTreeResolver.evaluate_mastery_purchase(
		catalog.node_catalog().get(node_id) as SkillTreeNodeData,
		catalog.doctrines, catalog.get_advanced_nodes(),
		champion_progression.current_level,
		champion_progression.unspent_mastery_points,
		champion_progression.selected_node_ids,
		champion_progression.profile,
	)


func purchase_mastery_node(node_id: StringName) -> Dictionary:
	var decision := evaluate_mastery_node(node_id)
	if not bool(decision.get("allowed", false)):
		return decision
	var catalog := progression_profile.mastery_catalog
	decision = champion_progression.purchase_mastery_node(
		catalog.node_catalog().get(node_id) as SkillTreeNodeData,
		catalog.doctrines, catalog.get_advanced_nodes(),
	)
	if bool(decision.get("purchased", false)):
		_sync_progression_modifiers_to_unit()
		champion_changed.emit()
	return decision


func refresh_mastery_effects() -> void:
	_sync_progression_modifiers_to_unit()


func get_champion_attribute_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if champion_progression == null:
		return rows
	var champion := champion_progression
	var profile := champion.profile
	rows.append({
		"id": &"vitality", "name": "Vitalité", "points": champion.vitality_points,
		"effect": "+%s %% des PV de base par point" % (100.0 * profile.vitality_hp_percent_per_point),
		"current": unit.max_hp.get_int(),
		"next": _preview_stat_increment(unit.max_hp, profile.base_hp_for_level(champion_progression.current_level) * profile.vitality_hp_percent_per_point, Stat.ModType.FLAT).get_int(),
		"unit": "PV", "can_spend": champion.unspent_attribute_points > 0,
	})
	rows.append({
		"id": &"power", "name": "Puissance", "points": champion.power_points,
		"effect": "+%s %% de prouesse par point" % (100.0 * profile.power_prowess_percent_per_point),
		"current": unit.attack_power.get_int(),
		"next": _preview_stat_increment(unit.attack_power, profile.power_prowess_percent_per_point, Stat.ModType.PERCENT).get_int(),
		"unit": "prouesse", "can_spend": champion.unspent_attribute_points > 0,
	})
	rows.append({
		"id": &"resolve", "name": "Résolution", "points": champion.resolve_points,
		"effect": "+%d armure et +%s %% boucliers par point" % [profile.resolve_armor_per_point, 100.0 * profile.resolve_shield_percent_per_point],
		"current": unit.armure.get_int(),
		"next": _preview_stat_increment(unit.armure, profile.resolve_armor_per_point, Stat.ModType.FLAT).get_int(),
		"unit": "armure", "can_spend": champion.unspent_attribute_points > 0,
	})
	rows.append({
		"id": &"wisdom", "name": "Sagesse", "points": champion.wisdom_points,
		"effect": "+%s %% XP de rencontre par point ; plafond %d" % [100.0 * profile.wisdom_bonus_per_point, profile.wisdom_cap],
		"current": int(round(100.0 * profile.wisdom_bonus_per_point * champion.wisdom_points)),
		"next": int(round(100.0 * profile.wisdom_bonus_per_point * mini(champion.wisdom_points + 1, profile.wisdom_cap))),
		"unit": "% XP", "can_spend": champion.unspent_attribute_points > 0 and champion.wisdom_points < profile.wisdom_cap,
	})
	for row in rows:
		row["spell_impacts"] = preview_champion_attribute(StringName(row.id))
	return rows


func _preview_stat_increment(original: Stat, value: float, type: Stat.ModType) -> Stat:
	var preview := Stat.new(original.base_value)
	preview.min_value = original.min_value
	preview.max_value = original.max_value
	for mod in original.get_modifiers():
		preview.add_modifier(float(mod.value), int(mod.type) as Stat.ModType, str(mod.source), int(mod.duration))
	preview.add_modifier(value, type, "champion_attribute_preview")
	return preview


## Aperçu pur : les stats clonées conservent équipement, malus et bornes.
func preview_champion_attribute(attribute_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if champion_progression == null:
		return result
	var profile := champion_progression.profile
	var hp := unit.max_hp.get_value()
	var prowess := unit.attack_power.get_value()
	var shield_multiplier := unit.shield_creation_multiplier
	match attribute_id:
		&"vitality":
			hp = _preview_stat_increment(unit.max_hp, profile.base_hp_for_level(champion_progression.current_level) * profile.vitality_hp_percent_per_point, Stat.ModType.FLAT).get_value()
		&"power":
			prowess = _preview_stat_increment(unit.attack_power, profile.power_prowess_percent_per_point, Stat.ModType.PERCENT).get_value()
		&"resolve":
			shield_multiplier += profile.resolve_shield_percent_per_point
		_:
			return result
	for spell in progression_profile.spells:
		var static_profile := MasteryStaticModifierResolver.resolve_spell_profile(spell, get_selected_mastery_nodes())
		for kind in [&"damage", &"shield"]:
			var scaling := spell.damage_scaling if kind == &"damage" else spell.shield_scaling
			if scaling == null:
				continue
			var current := SpellScalingResolver.resolve(scaling, unit, 0, champion_progression.current_level)
			var next := SpellScalingResolver.resolve_from_values(scaling, prowess, hp, champion_progression.current_level)
			var current_targets := PackedInt32Array()
			var next_targets := PackedInt32Array()
			if kind == &"damage":
				for target_index in range(maxi(1, int(static_profile.get("maximum_targets", 1)))):
					current_targets.append(MasteryStaticModifierResolver.resolve_target_damage(current, static_profile, target_index))
					next_targets.append(MasteryStaticModifierResolver.resolve_target_damage(next, static_profile, target_index))
				current = current_targets[0]
				next = next_targets[0]
			else:
				current = MasteryStaticModifierResolver.resolve_shield_amount(current, static_profile, unit.shield_creation_multiplier)
				next = MasteryStaticModifierResolver.resolve_shield_amount(next, static_profile, shield_multiplier)
			if current != next or current_targets != next_targets:
				var impact := {"spell_id": spell.get_effective_spell_id(), "name": spell.spell_name, "kind": kind, "current": current, "next": next}
				if kind == &"damage":
					impact["current_targets"] = current_targets
					impact["next_targets"] = next_targets
				result.append(impact)
	return result
