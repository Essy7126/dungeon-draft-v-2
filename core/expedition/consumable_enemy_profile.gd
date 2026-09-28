extends RefCounted
## Immutable projection shared by public previews, Battle and checkpoint validation.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Rules := preload("res://core/expedition/consumable_enemy_rules.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
const Modifier := preload("res://core/expedition/consumable_enemy_spell_modifier.gd")
const DEPTHS := [1, 2, 3, 5, 6, 8, 10, 12, 13, 15, 17, 20]
# Source, Cartes archetype, HP weight, reference-hero HP damage fraction, PA, PM.
const NATIVE := {
	"skeleton_melee": ["res://data/units/ennemie/skeleton_melee.tres", "brute", 2.4, .065, 4, 3],
	"skeleton_ranged": ["res://data/units/ennemie/skeleton_ranged.tres", "archer", 1.2, .065, 2, 2],
	"skeleton_chief": ["res://data/units/ennemie/skeleton_chief.tres", "guard", 3.0, .09, 6, 2],
	"skeleton_snow_centurion": [
		"res://data/units/ennemie/skeleton_snow_centurion.tres",
		"mage",
		1.8,
		.07,
		6,
		2,
	],
	"philosopher_mage": [
		"res://data/units/enemies/philosopher_mage.tres",
		"priest",
		1.5,
		.055,
		4,
		2,
	],
}


static func enabled(node: Dictionary) -> bool:
	return int(node.get("consumable_bestiary_revision", 0)) == 1 and int(node.depth) in DEPTHS


static func definition(node: Dictionary) -> Dictionary:
	var result: Dictionary = Catalog.data().route[DEPTHS.find(int(node.depth))].duplicate(true)
	result.kind = node.kind
	return result


static func hint(node: Dictionary) -> String:
	match int(node.depth):
		2:
			return "Patrouille osseuse : séparez les squelettes pour briser leur formation, puis approchez l’archer."
		6:
			return "Légion de glace : sortez du contact du chef avant sa Sentence. Bloquez les cases d’invocation du centurion ; abattez-le pour effacer sa marque. Deux invocations au maximum, sans butin."
		8, 17:
			return "Le Dialecticien soigne et protège ses alliés, ralentit à distance et repousse au contact. Isolez-le de ses protégés."
	return ""


static func configure(encounter: EncounterDefinition, node: Dictionary) -> void:
	if not enabled(node):
		return
	var roster := encounter.expanded_roster()
	match int(node.depth):
		2:
			if roster.size() == 3:
				roster[2] = roster[1]
			roster[0] = load(NATIVE.skeleton_melee[0])
			roster[1] = load(NATIVE.skeleton_ranged[0])
		6:
			roster.clear()
			for id in [
				"skeleton_snow_centurion",
				"skeleton_chief",
				"skeleton_melee",
				"skeleton_ranged",
			]:
				roster.append(load(NATIVE[id][0]))
			encounter.shared_normal_summon_budget = 1
			encounter.shared_chief_summon_budget = 1
			encounter.disabled_ability_ids = []
			encounter.formation_profiles.assign([&"centurion_rear"])
		8, 17:
			roster[0] = load(NATIVE.philosopher_mage[0])
	encounter.living_enemy_cap = roster.size() + encounter.shared_normal_summon_budget + encounter.shared_chief_summon_budget
	encounter.roster_units = []
	encounter.roster_counts = PackedInt32Array()
	for data in roster:
		var index := encounter.roster_units.find(data)
		if index >= 0:
			encounter.roster_counts[index] += 1
		else:
			encounter.roster_units.append(data)
			encounter.roster_counts.append(1)


static func kind(data: UnitData, boss := false) -> String:
	var id := str(data.unit_id)
	if NATIVE.has(id):
		return NATIVE[id][1]
	# Keep revision-zero archetype assignments for the remaining authored actors.
	var label := (id + " " + data.unit_name).to_lower()
	var result := "brute"
	if "molosse" in label or "hound" in label:
		result = "hound"
	if data.maximum_range > 1 or data.preferred_range > 1:
		result = "archer"
	if "mage" in label or "lamie" in label or "givre" in label or "braise" in label:
		result = "mage"
	if (
		"garde" in label or "guard" in label or "bouclier" in label
		or "sentinelle" in label or "egide" in label or "égide" in label
	):
		result = "guard"
	if "priest" in label or "prêtre" in label or "collecteur" in label or "officiant" in label:
		result = "priest"
	return "boss" if boss else result


static func project(encounter: EncounterDefinition, node: Dictionary) -> void:
	if not enabled(node):
		return
	var row := definition(node)
	var original := encounter.expanded_roster()
	row.roster = []
	var weight := 0.0
	for index in original.size():
		var data: UnitData = original[index]
		var archetype := kind(data, node.kind == "boss" and index == 0)
		row.roster.append(archetype)
		weight += (
			float(NATIVE[str(data.unit_id)][2])
			if NATIVE.has(str(data.unit_id))
			else float(Catalog.data().enemyTypes[archetype].weight)
		)
	var models := Rules.build(row)
	var power := float(Catalog.data().rules.prowess[int(row.level) - 1])
	# Reserve the two finite summons inside the existing fight's HP budget.
	var budget := float(row.hpBudget) - (1.8 if int(node.depth) == 6 else 0.0)
	var roster: Array[UnitData] = []
	for data in encounter.roster_units:
		var index := original.find(data)
		var enemy := data.duplicate(false) as UnitData
		var id := str(data.unit_id)
		var archetype: String = row.roster[index]
		var share := (
			float(NATIVE[id][2])
			if NATIVE.has(id)
			else float(Catalog.data().enemyTypes[archetype].weight)
		)
		var hp := Math.rounded(power * budget * share / weight)
		if NATIVE.has(id):
			_native(enemy, node, hp)
		else:
			var model: Unit = models[index]
			for key in [
				"max_ap",
				"max_mp",
				"attack_power",
				"armure",
				"resist_magique",
				"initiative",
				"crit_chance",
				"esquive",
			]:
				enemy.set(key, model.get(key).get_int())
			enemy.max_hp = hp
			for key in [
				"ai_behavior",
				"preferred_range",
				"minimum_range",
				"maximum_range",
				"keep_distance",
			]:
				enemy.set(key, model.get(key))
			enemy.spells = []
			enemy.spells.assign(model.spells)
			enemy.ai_profile = null
			enemy.combat_form_change = null
			enemy.proximity_armor_source = &""
			enemy.proximity_armor_per_living_neighbor = 0
			enemy.proximity_armor_max_neighbors = 0
			enemy.first_forced_movement_reduction_per_activation = 0
			if node.get("consumable_difficulty") == "easy":
				enemy.max_hp = Math.rounded(enemy.max_hp * .9)
				enemy.attack_power = Math.rounded(enemy.attack_power * .8)
				enemy.spells[0].damage = enemy.attack_power
			enemy.spells[0].description = "Une attaque par activation."
		enemy.basic_attack_enabled = false
		enemy.progression_summary = hint(node) if NATIVE.has(id) else ""
		roster.append(enemy)
	encounter.roster_units = roster


static func summon_data(id: String, node: Dictionary) -> UnitData:
	if id not in ["skeleton_melee", "skeleton_chief"]:
		return null
	var enemy := (load(NATIVE[id][0]) as UnitData).duplicate(false) as UnitData
	var power := float(Catalog.data().rules.prowess[int(definition(node).level) - 1])
	_native(enemy, node, Math.rounded(power * (.7 if id == "skeleton_melee" else 1.1)))
	return enemy


static func _native(enemy: UnitData, node: Dictionary, hp: int) -> void:
	var id := str(enemy.unit_id)
	var spec: Array = NATIVE[id]
	var level := int(definition(node).level) - 1
	var power := float(Catalog.data().rules.prowess[level])
	var easy: bool = node.get("consumable_difficulty") == "easy"
	enemy.max_hp = Math.rounded(hp * (.9 if easy else 1.0))
	enemy.attack_power = Math.rounded(
		float(Catalog.data().rules.hp[level]) * float(spec[3]) * (.8 if easy else 1.0)
	)
	enemy.max_ap = int(spec[4])
	enemy.max_mp = int(spec[5])
	enemy.initiative = 1
	enemy.crit_chance = 0
	enemy.esquive = 0
	enemy.armure = 10 if id == "skeleton_chief" else 0
	enemy.resist_magique = 10 if id == "skeleton_snow_centurion" else 0
	enemy.proximity_armor_per_living_neighbor = 8 if id == "skeleton_melee" else 0
	enemy.ai_profile = enemy.ai_profile.duplicate(true) if enemy.ai_profile != null else null
	if id == "skeleton_snow_centurion":
		enemy.ai_profile.commander_emergency_hp = maxi(1, enemy.max_hp / 2)
	var spells: Array[Spell] = []
	for source in enemy.spells:
		var spell := source.duplicate(false) as Spell
		spell.modifiers = source.modifiers.duplicate()
		spell.modifiers.append(Modifier.new())
		spell.damage_scaling = null
		spell.shield_scaling = null
		if source.damage > 0:
			spell.damage = enemy.attack_power
			spell.once_per_activation = true
		if source.applied_status != null:
			spell.applied_status = source.applied_status.duplicate(true)
		match str(spell.spell_id):
			"skeleton_bone_blade":
				spell.bonus_damage_if_marked = Math.rounded(enemy.attack_power * .3)
				spell.description = "Inflige %d dégâts physiques, +%d contre la marque du centurion lié. Formation : +8 armure par voisin vivant adjacent, allié ou ennemi, au plus deux." % [
					spell.damage,
					spell.bonus_damage_if_marked,
				]
			"scarlet_sentence":
				spell.damage = Math.rounded(enemy.attack_power * 1.65)
				spell.description = "Annonce %d dégâts et une poussée de 1 à la prochaine activation, qui est entièrement consommée. Échoue si la cible quitte le contact." % spell.damage
			"frost_aegis":
				spell.applied_status.stat_modifiers = { "resist_magique": 20.0 }
				spell.description = "Protège un allié : +20 résistance magique pendant une activation."
				spell.applied_status.description = "+20 résistance magique pendant une activation complète."
			"call_bones", "raise_chief":
				var summoned_id := "skeleton_melee" if str(spell.spell_id) == "call_bones" else "skeleton_chief"
				spell.summon_unit_data = summon_data(summoned_id, node)
				spell.summon_starting_hp = spell.summon_unit_data.max_hp
				spell.max_uses_per_combat = 1
				spell.condition_hp_at_or_below = enemy.max_hp / 2 if summoned_id == "skeleton_chief" else -1
				spell.description = "Annonce une invocation de %d PV, bloquée si sa case est occupée. Une tentative par combat, sans butin." % spell.summon_starting_hp
				if summoned_id == "skeleton_chief":
					spell.description += " Nécessite 50 % de PV ou moins et aucun chef vivant ou annoncé."
			"philosopher_mending":
				spell.heal = Math.rounded(.4 * power)
				spell.description = "Soigne %d PV à un allié ou à lui-même. Relance : deux activations." % spell.heal
			"philosopher_aegis":
				spell.shield_grant = Math.rounded(.45 * power)
				spell.description = "Accorde %d bouclier pendant deux activations. Relance : deux activations." % spell.shield_grant
			"philosopher_refutation":
				spell.damage = Math.rounded(enemy.attack_power * .6)
				spell.description = "Inflige %d dégâts magiques et repousse de 1 au contact." % spell.damage
			_:
				if source.damage > 0:
					spell.description = "Inflige %d dégâts %s%s." % [
						spell.damage,
						"physiques" if spell.damage_type == Spell.DamageType.PHYSICAL else "magiques",
						(
							" et retire 1 PM à la prochaine activation"
							if str(spell.spell_id) == "frost_lance"
							else ""
						),
					]
		spells.append(spell)
	enemy.spells = spells
