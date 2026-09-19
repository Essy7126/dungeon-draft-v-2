extends RefCounted
const ROWS := {
	"class_rune_edge": ["Rune du tranchant", &"attack_power", 4., "Prouesse", "a_pierce"],
	"class_rune_stone": ["Rune de pierre", &"armure", 10., "armure", "g_guard"],
	"class_rune_veil": ["Rune du voile", &"resist_magique", 10., "résistance magique", "t_guard"],
	"class_rune_blood": ["Rune de vigueur", &"max_hp", 25., "PV maximum", "a_cut"],
}


static func definition(id: String) -> ItemDefinition:
	if not ROWS.has(id):
		return null
	var row: Array = ROWS[id]
	var item := ItemDefinition.new()
	item.item_id = StringName(id)
	item.display_name = row[0]
	item.category = ItemDefinition.Category.RUNE
	item.stack_limit = 1
	item.icon = preload("res://core/expedition/class_card_catalog.gd").icon(row[4])
	item.tags.assign([&"class_loot", &"rune"])
	item.description = "+%d %s sur un équipement. Une rune par objet ; sertissage permanent, hors combat. La rune est consommée. Le bonus ne s'applique que si l'objet est équipé." % [
		int(row[2]),
		row[3],
	]
	var mod := ItemStatModifierData.new()
	mod.stat_id = row[1]
	mod.value = row[2]
	item.stat_modifiers.append(mod)
	return item


static func definitions() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for id in ROWS:
		result.append(definition(id))
	return result
