class_name EquipmentStatService
extends RefCounted


func apply_item(
		unit: Unit,
		instance: ItemInstance,
		definition: ItemDefinition
	) -> bool:
	if not _can_apply(unit, instance, definition):
		return false
	var previous_max_hp := unit.max_hp.get_int()
	for modifier in definition.stat_modifiers:
		var stat := _get_stat(unit, modifier.stat_id)
		if stat == null:
			remove_item(unit, instance, definition)
			return false
		var source := _source(instance, modifier.stat_id)
		stat.remove_modifiers_from(source)
		stat.add_modifier(
			modifier.value * (1.0 + 0.2 * instance.forge_level) if modifier.value > 0.0 else modifier.value,
			Stat.ModType.FLAT
				if modifier.modifier_type == ItemStatModifierData.ModifierType.FLAT
				else Stat.ModType.PERCENT,
			source,
		)
	unit.set_equipment_spell_modifiers(instance.instance_id, definition.spell_modifiers)
	unit.set_equipment_guard_effectiveness(
		instance.instance_id,
		definition.guard_effectiveness_melee,
		definition.guard_effectiveness_projectile,
	)
	_clamp_runtime_resources(unit, previous_max_hp)
	unit.stats_changed.emit(unit)
	return true


func remove_item(
		unit: Unit,
		instance: ItemInstance,
		definition: ItemDefinition
	) -> void:
	if unit == null or instance == null or definition == null:
		return
	var previous_max_hp := unit.max_hp.get_int()
	for modifier in definition.stat_modifiers:
		var stat := _get_stat(unit, modifier.stat_id)
		if stat != null:
			stat.remove_modifiers_from(_source(instance, modifier.stat_id))
	unit.clear_equipment_spell_modifiers(instance.instance_id)
	unit.clear_equipment_guard_effectiveness(instance.instance_id)
	_clamp_runtime_resources(unit, previous_max_hp)
	unit.stats_changed.emit(unit)


func rebuild_loadout(
		state: CharacterRunState,
		catalog: ItemCatalog
	) -> bool:
	if state == null \
			or state.unit == null \
			or state.equipment_loadout == null \
			or catalog == null:
		return false
	for instance in state.equipment_loadout.get_equipped_items():
		var definition := catalog.get_definition(instance.definition_id)
		if definition == null or not apply_item(state.unit, instance, definition):
			return false
	return true


func clear_loadout(
		state: CharacterRunState,
		catalog: ItemCatalog
	) -> void:
	if state == null \
			or state.unit == null \
			or state.equipment_loadout == null \
			or catalog == null:
		return
	for instance in state.equipment_loadout.get_equipped_items():
		var definition := catalog.get_definition(instance.definition_id)
		if definition != null:
			remove_item(state.unit, instance, definition)


func _can_apply(
		unit: Unit,
		instance: ItemInstance,
		definition: ItemDefinition
	) -> bool:
	if unit == null or instance == null or definition == null:
		return false
	if instance.definition_id != definition.item_id or instance.forge_level < 0 or instance.forge_level > 2:
		return false
	for modifier in definition.stat_modifiers:
		if modifier == null \
				or not modifier.is_valid() \
				or _get_stat(unit, modifier.stat_id) == null:
			return false
	return true


func _get_stat(unit: Unit, stat_id: StringName) -> Stat:
	match stat_id:
		&"max_hp":
			return unit.max_hp
		&"initiative":
			return unit.initiative
		&"max_ap":
			return unit.max_ap
		&"max_mp":
			return unit.max_mp
		&"attack_power":
			return unit.attack_power
		&"armure":
			return unit.armure
		&"resist_magique":
			return unit.resist_magique
		&"esquive":
			return unit.esquive
		&"crit_chance":
			return unit.crit_chance
		&"crit_multi":
			return unit.crit_multi
		&"force":
			return unit.force
		&"resistance_ice":
			return unit.get_resistance(Spell.Element.ICE)
		_:
			return null


func _source(instance: ItemInstance, stat_id: StringName) -> String:
	return "equipment:%s:%s" % [instance.instance_id, stat_id]


func _clamp_runtime_resources(unit: Unit, _previous_max_hp: int) -> void:
	unit.current_hp = clampi(unit.current_hp, 0, unit.max_hp.get_int())
	unit.current_ap = clampi(unit.current_ap, 0, unit.max_ap.get_int())
	unit.current_mp = clampi(unit.current_mp, 0, unit.max_mp.get_int())
