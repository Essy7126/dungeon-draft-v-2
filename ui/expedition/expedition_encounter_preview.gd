class_name ExpeditionEncounterPreview
extends RefCounted
## A read-only projection of the exact seeded encounter, respecting route knowledge.
const ENCOUNTERS := preload("res://core/expedition/catabase_monster_encounter_catalog.gd")


static func describe(node: Dictionary, seed_value: int = 0) -> Dictionary:
	if node.is_empty() or str(node.get("knowledge", "unknown")) not in ["near", "revealed"]:
		return {}
	if not ExpeditionRouteCatalog.is_combat(str(node.get("kind", "unknown"))):
		return {}
	var preview: Dictionary = ENCOUNTERS.encounter_preview(node).duplicate(true)
	if preview.is_empty():
		return {}
	# Route presentation deliberately hides room_index. Reconstruct the canonical
	# depth mapping rather than accidentally inspecting the opening arena (-1).
	var room_node := node.duplicate(true)
	room_node["room_index"] = int(ExpeditionRouteCatalog.MAP_BY_DEPTH.get(int(node.depth), 0))
	var room := ExpeditionRunFactory.make_room(room_node, seed_value)
	if room == null:
		return {}
	var counts := {}
	var units := {}
	for data: UnitData in room.enemies:
		var id := str(data.unit_id)
		counts[id] = int(counts.get(id, 0)) + 1
		units[id] = data
	var lines: Array[String] = []
	for id in units:
		var data: UnitData = units[id]
		lines.append("%s × %d" % [data.unit_name, int(counts[id])])
		if not data.progression_summary.is_empty():
			lines.append(data.progression_summary)
		lines.append("%d PV · %d PA · %d PM · initiative %d" % [data.max_hp, data.max_ap, data.max_mp, data.initiative])
		if data.armure > 0 or data.resist_magique > 0:
			lines.append("Armure %d · résistance magique %d" % [data.armure, data.resist_magique])
		for spell: Spell in data.spells:
			if spell != null:
				lines.append("• %s — %s" % [spell.spell_name, _spell_values(spell, data)])
				lines.append("  " + spell.description)
		lines.append("")
	preview["count"] = room.enemies.size()
	preview["details"] = "\n".join(lines).strip_edges()
	return preview


static func _spell_values(spell: Spell, unit: UnitData) -> String:
	var values: Array[String] = ["%d PA" % spell.ap_cost]
	values.append("sur soi" if spell.is_self_only() else "portée %d–%d" % [spell.minimum_range, spell.spell_range])
	if spell.deals_damage():
		var damage := SpellScalingResolver.resolve_from_values(spell.damage_scaling, unit.attack_power, unit.max_hp, 1, spell.damage)
		values.append("%d dégâts avant défenses" % damage)
	if spell.heal > 0:
		values.append("soin %d PV" % spell.heal)
	var shield := SpellScalingResolver.resolve_from_values(spell.shield_scaling, unit.attack_power, unit.max_hp, 1, spell.shield_grant)
	if shield > 0:
		values.append("bouclier %d" % shield)
	if spell.max_uses_per_combat > 0:
		values.append("%d usage%s/combat" % [spell.max_uses_per_combat, "s" if spell.max_uses_per_combat > 1 else ""])
	return " · ".join(values)
