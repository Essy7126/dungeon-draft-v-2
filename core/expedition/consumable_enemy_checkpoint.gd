extends RefCounted
## Version-three additions: bounded reinforcements and native delayed actions.
const Profile := preload("res://core/expedition/consumable_enemy_profile.gd")
const Numbers := preload("res://core/expedition/consumable_native_status_checkpoint.gd")


static func snapshot(unit: Unit) -> Dictionary:
	var pending := { }
	if not unit.pending_ability.is_empty():
		var value := unit.pending_ability
		pending = {
			"spell": str(value.spell.spell_id),
			"cell": [value.cell.x, value.cell.y],
			"target": str(value.target.unit_id) if value.target != null else "",
			"prepared_activation": value.prepared_activation,
		}
	return {
		"type": str(unit.content_unit_id),
		"order": unit.combat_order,
		"forced": unit._forced_movement_reduction_used,
		"facing": [unit.facing_dir.x, unit.facing_dir.y],
		"pending": pending,
	}


static func budgets(runtime: EncounterRuntimeState) -> Dictionary:
	return { "normal": runtime.normal_summons_committed, "chief": runtime.chief_summons_committed }


static func valid(value: Dictionary, room: RoomData, node: Dictionary, grid: GridData) -> bool:
	if not value.get("summon_budgets") is Dictionary:
		return false
	var budget: Dictionary = value.summon_budgets
	var definition := room.encounter_definition
	if (
		not Numbers.whole(budget.get("normal"), 0, definition.shared_normal_summon_budget)
		or not Numbers.whole(budget.get("chief"), 0, definition.shared_chief_summon_budget)
	):
		return false
	var extra := { "skeleton_melee": 0, "skeleton_chief": 0 }
	var pending_summons := { "normal": 0, "chief": 0 }
	var orders := { }
	var identities := { }
	for entry in value.units:
		identities[entry.id] = true
	if not value.get("turn_order") is Array or value.turn_order.size() != identities.size():
		return false
	var seen_order := { }
	for id in value.turn_order:
		if not id is String or not identities.has(id) or seen_order.has(id):
			return false
		seen_order[id] = true
	for index in value.units.size():
		var entry: Dictionary = value.units[index]
		var native: Variant = entry.get("native")
		if (
			not native is Dictionary or not native.get("type") is String
			or not native.get("forced") is bool or not native.get("pending") is Dictionary
		):
			return false
		if not Numbers.whole(native.get("order"), 0, 100000) or orders.has(int(native.order)):
			return false
		orders[int(native.order)] = true
		if not native.get("facing") is Array or native.facing.size() != 2:
			return false
		if (
			not Numbers.whole(native.facing[0], -1, 1) or not Numbers.whole(native.facing[1], -1, 1)
			or absf(native.facing[0]) + absf(native.facing[1]) != 1
		):
			return false
		var data: UnitData = null
		if index > 0:
			if not Numbers.whole(entry.metadata.get("cc2_spawn"), index - 1, index - 1):
				return false
			if index <= room.enemies.size():
				data = room.enemies[index - 1]
				if native.type != str(data.get_effective_unit_id()) or entry.metadata.get(
						"cc2_summoned"
					) != false:
					return false
			else:
				if native.type not in extra or int(node.depth) != 6 or entry.metadata.get(
						"cc2_summoned"
					) != true:
					return false
				extra[native.type] += 1
				data = Profile.summon_data(native.type, node)
			var expected := str(data.unit_id) if Profile.NATIVE.has(str(data.unit_id)) else ""
			if entry.metadata.get("cc2_native_type") != expected:
				return false
			# Generic room leaders can gain permanent HP from convoy deliveries.
			if not expected.is_empty() and entry.hp > data.max_hp:
				return false
		if native.pending.is_empty():
			continue
		if data == null or not entry.alive:
			return false
		var spell := find_spell(data.spells, str(native.pending.get("spell", "")))
		if spell == null or spell.delayed_resolution == Spell.DelayedResolution.NONE:
			return false
		var cell: Variant = native.pending.get("cell")
		if (
			not cell is Array or cell.size() != 2 or not Numbers.whole(cell[0], 0, grid.cols - 1)
			or not Numbers.whole(cell[1], 0, grid.rows - 1)
		):
			return false
		if not Numbers.whole(native.pending.get("prepared_activation"), 1, int(entry.activation)):
			return false
		if spell.is_summon():
			if native.pending.get("target") != "":
				return false
			pending_summons[str(spell.summon_type)] += 1
		elif native.pending.get("target") not in identities:
			return false
	for kind in ["normal", "chief"]:
		var count: int = extra["skeleton_melee" if kind == "normal" else "skeleton_chief"]
		if count + int(pending_summons[kind]) > int(budget[kind]):
			return false
	return true


static func find_spell(spells: Array, id: String) -> Spell:
	for spell: Spell in spells:
		if str(spell.spell_id) == id:
			return spell
	return null


static func restore_pending(
	unit: Unit,
	value: Dictionary,
	units: Dictionary,
	runtime: EncounterRuntimeState,
) -> void:
	unit.pending_ability.clear()
	unit._forced_movement_reduction_used = value.forced
	unit.facing_dir = Vector2i(value.facing[0], value.facing[1])
	if value.pending.is_empty():
		return
	var pending: Dictionary = value.pending
	var spell := find_spell(unit.spells, pending.spell)
	unit.pending_ability = {
		"spell": spell,
		"cell": Vector2i(pending.cell[0], pending.cell[1]),
		"target": units.get(pending.target),
		"prepared_activation": int(pending.prepared_activation),
		"source_ability_id": spell.spell_id,
	}
	if spell.is_summon():
		runtime._pending_by_caster[unit.get_runtime_stable_id()] = spell.summon_type


static func publish(unit: Unit) -> void:
	if not unit.is_alive or unit.pending_ability.is_empty():
		return
	var pending := unit.pending_ability
	var spell: Spell = pending.spell
	EventBus.ability_telegraphed.emit(
		unit,
		spell,
		{
			"cell": pending.cell,
			"target": pending.target,
			"label": spell.telegraph_label,
			"color": spell.telegraph_color,
			"resolution": spell.delayed_resolution,
		},
	)
	if spell.is_summon():
		EventBus.summon_telegraphed.emit(unit, spell, pending.cell)
