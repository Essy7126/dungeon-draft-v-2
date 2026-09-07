class_name ExpeditionEquipmentCatalog
extends RefCounted

## Twelve deterministic Achilles items. They are equipped through EquipmentService
## and share its source removal, forging and save reconstruction contracts.
var _items: Array[ItemDefinition] = []


func _init() -> void:
	var item := _item("levier", "Levier des Myrmidons", ItemDefinition.EquipmentSlot.WEAPON, ["briseur"],
		"+1 Force. Vos dégâts physiques gagnent 25 % contre une cible déjà déplacée ou entrée en collision pendant cette activation. Crochet prépare Frappe ou Fauchage.")
	_stat(item, &"force", 1)
	var mod := _damage(item, 0.25, Spell.DamageType.PHYSICAL)
	mod.require_target_moved_or_collided = true
	item = _item("lame_sang", "Lame du talon", ItemDefinition.EquipmentSlot.WEAPON, ["sang", "serment"],
		"-12 armure. À 40 % PV ou moins, vos techniques infligeant des dégâts gagnent 30 %. Les sacrifices peuvent ouvrir cette fenêtre, sans rembourser leur coût.")
	_stat(item, &"armure", -12)
	var special := ExpeditionEquipmentSpellModifier.new()
	special.caster_hp_at_or_below = 0.40
	special.damage_percent = 0.30
	item.spell_modifiers.append(special)
	item = _item("javeline", "Javeline des longues vues", ItemDefinition.EquipmentSlot.WEAPON, ["chasseur"],
		"Tir du Pélion, Tir de guet, Trait de rupture et Marque (toutes formes) : +1 portée, distance minimale portée à 3 ; +30 % dégâts à au moins 4 cases. Votre zone morte s'agrandit.")
	for id in ["achilles_pelion_shot", "exp_tir_de_guet", "exp_rupture", "exp_rupture_mutation", "exp_rupture_legend", "exp_marque", "exp_marque_signature"]:
		mod = _damage(item, 0.30)
		mod.target_spell_id = StringName(id)
		mod.target_distance_at_least = 4
		mod.range_bonus = 1
		mod.minimum_range_override = 3
	item = _item("xiphos_danse", "Xiphos des deux appuis", ItemDefinition.EquipmentSlot.WEAPON, ["danseur"],
		"+2 initiative. Vos dégâts physiques gagnent 25 % après avoir parcouru au moins 2 cases pendant cette activation. Les déplacements sont comptés par le combat.")
	_stat(item, &"initiative", 2)
	mod = _damage(item, 0.25, Spell.DamageType.PHYSICAL)
	mod.minimum_prior_moved_cells = 2
	item = _item("masse_airain", "Masse du rempart", ItemDefinition.EquipmentSlot.WEAPON, ["airain", "briseur"],
		"+15 armure, -2 initiative. Heurt et ses formes ajoutent 10 % de votre armure effective en dégâts physiques, au plus 8 par cible. Posture peut préparer la frappe.")
	_stat(item, &"armure", 15)
	_stat(item, &"initiative", -2)
	special = ExpeditionEquipmentSpellModifier.new()
	special.valid_spell_ids.assign([&"exp_heurt", &"exp_heurt_mutation", &"exp_heurt_legend"])
	special.armor_damage_ratio = 0.10
	item.spell_modifiers.append(special)
	item = _item("fer_braise", "Fer de la fournaise", ItemDefinition.EquipmentSlot.WEAPON, ["elements", "serment"],
		"+30 % dégâts magiques élémentaires des impacts de sorts ; -15 % dégâts physiques. Les braises au sol gardent leur valeur propre.")
	mod = _damage(item, 0.30, Spell.DamageType.MAGICAL)
	mod.require_elemental_damage = true
	_damage(item, -0.15, Spell.DamageType.PHYSICAL)
	item = _item("cuirasse", "Cuirasse d'Éaque", ItemDefinition.EquipmentSlot.ARMOR, ["airain"],
		"+30 armure, -1 PM par activation. Les boucliers de vos sorts gagnent 25 %. Armure pour tenir le contact, au prix des changements de position.")
	_stat(item, &"armure", 30)
	_stat(item, &"max_mp", -1)
	mod = ItemSpellModifierData.new()
	mod.healing_and_shield_percent = 0.25
	# Filter shield families so the description promises no unsupported heal bonus.
	for id in ["achilles_bronze_guard", "exp_garde_eaque", "exp_posture", "exp_posture_signature", "exp_souffle_legend", "exp_serment_rempart"]:
		var shield_mod := mod.duplicate() as ItemSpellModifierData
		shield_mod.target_spell_id = StringName(id)
		item.spell_modifiers.append(shield_mod)
	item = _item("lin_survivant", "Lin du survivant", ItemDefinition.EquipmentSlot.ARMOR, ["endurance", "sang"],
		"+15 % PV maximum (ne soigne pas). Second souffle et ses formes soignent 25 % de plus, arrondis à l'entier inférieur, sans dépasser leur réserve commune. Les coûts de sacrifice grandissent avec les PV max.")
	_stat(item, &"max_hp", 0.15, true)
	special = ExpeditionEquipmentSpellModifier.new()
	special.heal_percent = 0.25
	special.valid_spell_ids.assign([&"exp_souffle", &"exp_souffle_mutation", &"exp_souffle_legend"])
	item.spell_modifiers.append(special)
	item = _item("sandales", "Sandales du détour", ItemDefinition.EquipmentSlot.ARMOR, ["danseur", "chasseur"],
		"+1 PM, +8 points d'esquive, -10 armure. Favorise les changements de ligne et le Xiphos des deux appuis. L'esquive conserve son plafond commun de 50 %.")
	_stat(item, &"max_mp", 1)
	_stat(item, &"esquive", 0.08)
	_stat(item, &"armure", -10)
	item = _item("sceau_chasse", "Sceau de la dernière chasse", ItemDefinition.EquipmentSlot.ACCESSORY, ["chasseur", "sang"],
		"-10 % PV maximum. +25 % dégâts de vos sorts contre une cible à 30 % PV ou moins. Le bonus est évalué avant chaque impact ; il ne finance pas de soin sur les dégâts excédentaires.")
	_stat(item, &"max_hp", -0.10, true)
	mod = _damage(item, 0.25)
	mod.target_hp_at_or_below = 0.30
	item = _item("prisme", "Prisme de Chiron", ItemDefinition.EquipmentSlot.ACCESSORY, ["elements", "chasseur"],
		"+1 portée aux sorts magiques élémentaires ayant déjà une portée. -8 résistance magique. Élargit vos zones de contrôle sans changer les cases des braises déjà posées.")
	_stat(item, &"resist_magique", -8)
	mod = ItemSpellModifierData.new()
	mod.require_elemental_damage = true
	mod.damage_type_filter = Spell.DamageType.MAGICAL
	mod.range_bonus = 1
	item.spell_modifiers.append(mod)
	item = _item("agrafe", "Agrafe du serment", ItemDefinition.EquipmentSlot.ACCESSORY, ["airain", "serment"],
		"+20 % dégâts de vos sorts tant qu'un bouclier reste actif sur vous. La protection doit tenir jusqu'à votre attaque ; l'agrafe ne crée ni ne recharge de bouclier.")
	special = ExpeditionEquipmentSpellModifier.new()
	special.require_guard = true
	special.damage_percent = 0.20
	item.spell_modifiers.append(special)


func definitions() -> Array[ItemDefinition]:
	return _items.duplicate()


static func item_ids(axis: String = "") -> Array[StringName]:
	var result: Array[StringName] = []
	for item in ExpeditionEquipmentCatalog.new().definitions():
		if axis.is_empty() or StringName(axis) in item.tags:
			result.append(item.item_id)
	return result


static func merge_into(source: ItemCatalog) -> ItemCatalog:
	var merged := ItemCatalog.new()
	if source != null:
		merged.definitions.assign(source.get_definitions())
	for definition in ExpeditionEquipmentCatalog.new().definitions():
		var exists := false
		for original in merged.definitions:
			if original.item_id == definition.item_id:
				exists = true
				break
		if not exists:
			merged.definitions.append(definition)
	merged.rebuild_index()
	return merged


func _item(id: String, title: String, slot: int, axes: Array, description: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.item_id = StringName("catabase_" + id)
	item.icon = CatabasePaintedIconCatalog.item_icon(String(item.item_id), item.icon)
	item.display_name = title
	item.description = description
	item.equipment_slot = slot
	item.category = [ItemDefinition.Category.WEAPON, ItemDefinition.Category.ARMOR, ItemDefinition.Category.ACCESSORY][slot]
	item.compatible_character_ids.assign([&"achilles"])
	item.tags.assign([&"catabase_build"])
	for axis in axes:
		item.tags.append(StringName(axis))
	item.rarity = &"rare"
	_items.append(item)
	return item


func _stat(item: ItemDefinition, id: StringName, value: float, percent := false) -> void:
	var mod := ItemStatModifierData.new()
	mod.stat_id = id
	mod.value = value
	mod.modifier_type = ItemStatModifierData.ModifierType.PERCENT if percent else ItemStatModifierData.ModifierType.FLAT
	item.stat_modifiers.append(mod)


func _damage(item: ItemDefinition, percent: float, type := -1) -> ItemSpellModifierData:
	var mod := ItemSpellModifierData.new()
	mod.damage_percent = percent
	mod.damage_type_filter = type
	item.spell_modifiers.append(mod)
	return mod
