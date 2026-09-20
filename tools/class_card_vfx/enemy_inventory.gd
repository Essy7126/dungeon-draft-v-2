extends RefCounted
## Read-only inventory of actual encounter kits, every grade, forms and summons.
const Evolution := preload("res://core/expedition/catabase_monster_evolution_catalog.gd")
const Ecosystem := preload("res://core/expedition/card_enemy_ecosystem.gd")


static func spells() -> Dictionary:
	var found := { }
	var visited := { }
	for grade in [1, 2, 3]:
		var node := {
			"depth": [3, 8, 17][grade - 1],
			"encounter_grade": grade,
			"balance_revision": 1,
		}
		for role in Evolution.roles():
			var unit := Evolution.build_unit(role, node)
			Ecosystem.apply(unit, node)
			_collect(unit, found, visited)
	# Actual route includes the opening roster, final boss and its second form.
	for node in ExpeditionRouteCatalog.create_nodes(2401):
		if not ExpeditionRouteCatalog.is_combat(str(node.kind)):
			continue
		var room := ExpeditionRunFactory.make_room(node, 2401, true)
		for unit in room.enemies:
			_collect(unit, found, visited)
	return found


static func _collect(unit: UnitData, found: Dictionary, visited: Dictionary) -> void:
	if unit == null or visited.has(unit.get_instance_id()):
		return
	visited[unit.get_instance_id()] = true
	var kit: Array = unit.spells.duplicate()
	if unit.combat_form_change != null:
		kit.append_array(unit.combat_form_change.spells)
	for spell: Spell in kit:
		found[str(spell.get_effective_spell_id())] = spell
		if spell.summon_unit_data != null:
			_collect(spell.summon_unit_data, found, visited)
