extends RefCounted
const Catalog := preload("res://core/expedition/class_card_catalog.gd")


static func has_id(id: String) -> bool:
	var parts := id.split("_")
	if parts.size() != 5 or parts[0] != "class" or parts[1] != "gear":
		return false
	for index in [2, 3, 4]:
		if not parts[index].is_valid_int():
			return false
	var tier := int(parts[2])
	var slot := int(parts[3])
	var affinity := int(parts[4])
	return (
		tier >= 1 and tier <= 3 and slot >= 0 and slot < 6 and affinity >= 0
		and affinity < 4 and id == "class_gear_%d_%d_%d" % [tier, slot, affinity]
	)


static func definitions() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	var titles := [
		["Dague", "Masse", "Arc", "Bâton"],
		["Cuir", "Cuirasse", "Veste", "Robe"],
		["Anneau", "Sceau", "Broche", "Prisme"],
		["Capuche", "Casque", "Chapeau", "Diadème"],
		["Ceinture", "Baudrier", "Sangle", "Cordon"],
		["Bottes", "Solerets", "Sandales", "Souliers"],
	]
	for tier in range(1, 4):
		for slot in 6:
			for affinity in 4:
				var item := ItemDefinition.new()
				item.item_id = StringName("class_gear_%d_%d_%d" % [tier, slot, affinity])
				item.display_name = "%s %s" % [
					titles[slot][affinity],
					["des rives", "des profondeurs", "du carrefour"][tier - 1],
				]
				item.equipment_slot = slot
				item.category = (
					ItemDefinition.Category.WEAPON
					if slot == 0
					else (
						ItemDefinition \
								.Category \
								.ARMOR
						if slot in [1, 3, 5]
						else ItemDefinition.Category.ACCESSORY
					)
				)
				item.icon = Catalog.icon("gear_%d_%d" % [slot, affinity])
				item.rarity = [&"common", &"uncommon", &"rare"][tier - 1]
				item.tags.assign([&"class_loot", StringName(Catalog.CLASSES.keys()[affinity])])
				item.description = "Palier %d · utilisable par toutes les classes.\n" % tier
				var stat: StringName = [
					&"attack_power",
					&"armure",
					&"resist_magique",
					&"initiative",
					&"max_hp",
					&"esquive",
				][slot]
				var value: float = [3., 8., 6., 1., 15., .02][slot] * tier
				_stat(item, stat, value)
				item.description += "+%d %s.\n" % [
					roundi(value * (100 if slot == 5 else 1)),
					[
						"Prouesse",
						"armure",
						"résistance magique",
						"initiative",
						"PV maximum",
						"points d'esquive",
					][slot],
				]
				var mod := ItemSpellModifierData.new()
				mod.damage_percent = .04 * tier
				match affinity:
					0:
						mod.target_distance_at_most = 1
						item.description += "+%d %% dégâts au contact." % (tier * 4)
					1:
						mod.damage_percent = 0.
						mod.healing_and_shield_percent = .05 * tier
						item.description += "+%d %% garde et soins." % (tier * 5)
					2:
						mod.target_distance_at_least = 3
						item.description += "+%d %% dégâts à 3 cases ou plus." % (tier * 4)
					3:
						mod.damage_type_filter = Spell.DamageType.MAGICAL
						item.description += "+%d %% dégâts magiques directs." % (tier * 4)
				item.spell_modifiers.append(mod)
				result.append(item)
	return result


static func _stat(item: ItemDefinition, id: StringName, value: float) -> void:
	var mod := ItemStatModifierData.new()
	mod.stat_id = id
	mod.value = value
	item.stat_modifiers.append(mod)
