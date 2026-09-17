class_name CatabaseMonsterEncounterCatalog
extends RefCounted
## Authored packs budget numbers, access and spell economy independently.
const Evolution = preload("res://core/expedition/catabase_monster_evolution_catalog.gd")
const EarlyEncounters = preload("res://core/expedition/catabase_early_encounters.gd")
const UNIT_PATHS := {
	&"sentinelle": "res://data/units/enemies/catabase_sentinelle_airain.tres",
	&"rejeton": "res://data/units/enemies/catabase_rejeton_braise.tres",
	&"molosse": "res://data/units/enemies/catabase_molosse_styx.tres",
	&"lamie": "res://data/units/enemies/catabase_lamie_lethe.tres",
}
const RECOVERY_DEPTHS := [5, 9, 13, 17]
const BALANCE_REVISION := 1
const ROUTE_FAMILIES: Array[StringName] = [&"airain", &"styx", &"lethe"]
const V1_GRADES := { 1: 1, 2: 1, 3: 1, 5: 1, 6: 1, 8: 2, 10: 2, 12: 2, 13: 3, 15: 3, 17: 3, 20: 3 }
const V1_KINDS := {
	1: "normal",
	2: "normal",
	3: "normal",
	5: "normal",
	6: "elite",
	8: "normal",
	10: "elite",
	12: "normal",
	13: "normal",
	15: "elite",
	17: "normal",
	20: "boss",
}
const V1_REFERENCES := {
	2: [135, 22],
	3: [165, 27],
	5: [200, 33],
	6: [240, 40],
	8: [290, 48],
	10: [350, 57],
	12: [420, 68],
	13: [500, 82],
	15: [600, 100],
	17: [635, 106],
}
const V1_ROLES_BY_DEPTH := {
	2: {
		&"airain": [&"brute", &"archer"],
		&"styx": [&"brute", &"molosse", &"archer"],
		&"lethe": [&"brute", &"lamie", &"archer"],
	},
	3: {
		&"airain": [&"archer", &"brute", &"brute"],
		&"styx": [&"archer", &"molosse", &"molosse"],
		&"lethe": [&"lamie", &"molosse", &"molosse"],
	},
	5: {
		&"airain": [&"rejeton", &"brute", &"molosse"],
		&"styx": [&"archer", &"molosse", &"molosse"],
		&"lethe": [&"lamie", &"brute", &"molosse"],
	},
	6: { &"shared": [&"brute", &"archer", &"molosse", &"officiant"] },
	8: {
		&"airain": [&"conducteur", &"molosse", &"brute"],
		&"styx": [&"conducteur", &"molosse", &"molosse"],
		&"lethe": [&"conducteur", &"molosse", &"lamie"],
	},
	10: { &"shared": [&"rabatteur", &"executeur"] },
	12: {
		&"airain": [&"collecteur", &"porteur", &"porteur", &"brute"],
		&"styx": [&"collecteur", &"porteur", &"porteur", &"molosse"],
		&"lethe": [&"collecteur", &"porteur", &"porteur", &"lamie"],
	},
	13: {
		&"airain": [&"fondeur", &"deplaceur", &"deplaceur"],
		&"styx": [&"fondeur", &"deplaceur", &"deplaceur"],
		&"lethe": [&"fondeur", &"deplaceur", &"lamie"],
	},
	15: { &"shared": [&"porte_egide", &"guetteur", &"deplaceur", &"protecteur"] },
	17: {
		&"airain": [&"artilleur", &"deplaceur", &"tisseuse"],
		&"styx": [&"fondeur", &"deplaceur", &"tisseuse"],
		&"lethe": [&"artilleur", &"deplaceur", &"tisseuse"],
	},
}
# Total pack durability in multiples of the fixed reference prowess. Individual
# role weights are normalized back to this total, so a three-body opening does
# not become stronger than its two-body sibling merely by adding a target.
const V1_PACK_HP_WEIGHTS := {
	2: 4.2,
	3: 6.0,
	5: 6.0,
	6: 8.4,
	8: 6.6,
	10: 6.8,
	12: 6.6,
	13: 6.0,
	15: 8.4,
	17: 5.4,
}
const V1_HP_WEIGHTS := {
	&"archer": 1.2,
	&"rejeton": 1.2,
	&"fondeur": 1.2,
	&"artilleur": 1.2,
	&"guetteur": 1.2,
	&"porteur": 1.2,
	&"serviteur": 1.2,
	&"officiant": 1.8,
	&"collecteur": 1.8,
	&"conducteur": 1.8,
	&"lamie": 1.8,
	&"tisseuse": 1.8,
	&"protecteur": 1.8,
	&"molosse": 2.4,
	&"deplaceur": 2.4,
	&"rabatteur": 2.4,
	&"brute": 3.0,
	&"executeur": 3.0,
	&"porte_egide": 3.0,
}
const V1_ATTACK_RATIOS := {
	&"officiant": 0.06,
	&"collecteur": 0.06,
	&"conducteur": 0.06,
	&"porteur": 0.06,
	&"serviteur": 0.06,
	&"protecteur": 0.06,
	&"lamie": 0.08,
	&"tisseuse": 0.08,
	&"porte_egide": 0.08,
	&"fondeur": 0.12,
	&"artilleur": 0.12,
	&"executeur": 0.12,
}
const V1_FORMATIONS := {
	&"airain": [&"double_line"],
	&"styx": [&"left_flank"],
	&"lethe": [&"split"],
}
const PARIS_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"
const SPECTRE_PATH := "res://data/units/enemies/spectre_greatsword.tres"
const V1_PARIS_DAMAGE := {
	&"paris_spectral_arrow": 80,
	&"paris_fire_arrow": 65,
	&"paris_ice_arrow": 55,
	&"paris_vortex_arrow": 45,
	&"paris_vortex_step": 0,
	&"paris_infernal_whip": 100,
	&"paris_infernal_sweep": 75,
	&"paris_infernal_pull": 60,
}


static func uses_monsters(node: Dictionary) -> bool:
	var depth := int(node.get("depth", 1))
	if uses_fixed_balance(node):
		return depth not in [1, 20] and str(node.get("kind", "")) in ["normal", "elite"]
	return depth > 1 and depth not in [7, 20] \
			and str(node.get("kind", "normal")) in ["normal", "elite"]


static func uses_fixed_balance(node: Dictionary) -> bool:
	return int(node.get("balance_revision", 0)) == BALANCE_REVISION \
			and str(node.get("kind", "")) in ["normal", "elite", "boss"]


static func profile_validation_error(node: Dictionary) -> String:
	if not uses_fixed_balance(node):
		return ""
	var depth := int(node.get("depth", 0))
	if not V1_KINDS.has(depth):
		return "profondeur sans profil fixe : %d" % depth
	var family := StringName(str(node.get("route_family", "")))
	var expected_family := &"common" if depth in [1, 20] else family
	if depth in [1, 20] and family != &"common":
		return "la profondeur %d exige route_family=common" % depth
	if depth not in [1, 20] and family not in ROUTE_FAMILIES:
		return "famille de route inconnue : %s" % family
	var expected_profile := StringName("catabase_r6_d%02d_%s" % [depth, expected_family])
	if StringName(str(node.get("encounter_profile_id", ""))) != expected_profile:
		return "profil attendu %s" % expected_profile
	if str(node.get("kind", "")) != str(V1_KINDS[depth]):
		return "type attendu %s pour %s" % [V1_KINDS[depth], expected_profile]
	if int(node.get("encounter_grade", 0)) != int(V1_GRADES[depth]):
		return "grade attendu %d pour %s" % [V1_GRADES[depth], expected_profile]
	if StringName(str(node.get("difficulty_id", ""))) not in [&"normal", &"easy"]:
		return "difficulté attendue : normal ou easy"
	if depth not in [1, 20] and _fixed_roles(depth, family).is_empty():
		return "composition absente pour %s" % expected_profile
	return ""


static func configure_encounter(encounter: EncounterDefinition, node: Dictionary) -> bool:
	if encounter == null:
		push_error("Catabase : rencontre absente")
		return false
	if uses_fixed_balance(node):
		var error := profile_validation_error(node)
		if not error.is_empty():
			_clear_roster(encounter)
			push_error("Catabase r6 : %s" % error)
			return false
		if int(node.depth) == 20:
			return _configure_paris(encounter, node)
		if int(node.depth) == 1:
			return _configure_opening(encounter, node)
	if not uses_monsters(node):
		return true
	var pack := encounter_preview(node)
	var roles := composition_for(node)
	if roles.is_empty():
		_clear_roster(encounter)
		push_error(
			"Catabase : composition vide pour %s"
			% node.get("encounter_profile_id", node.get("id", ""))
		)
		return false
	_clear_roster(encounter)
	encounter.formation_profiles = formations_for(node)
	var counts := { }
	for role in roles:
		counts[role] = int(counts.get(role, 0)) + 1
	for role: StringName in counts:
		var unit := Evolution.build_unit(role, node)
		if unit == null:
			_clear_roster(encounter)
			push_error("Catabase : rôle invalide %s" % role)
			return false
		if uses_fixed_balance(node):
			var targets := _fixed_targets(role, roles, node)
			Evolution.apply_fixed_balance(unit, int(targets.hp), int(targets.attack))
		else:
			EarlyEncounters.tune(unit, role, node)
		# Five colosses deliberately trade access for numbers.
		if int(pack.get("mp_cap", 0)) > 0:
			unit.max_mp = mini(unit.max_mp, int(pack.mp_cap))
		encounter.roster_units.append(unit)
		encounter.roster_counts.append(int(counts[role]))
		var minimum_distance := 5 if uses_fixed_balance(node) else maxi(5, unit.max_mp + 3)
		if not uses_fixed_balance(node) and unit.combat_style == 1:
			minimum_distance = maxi(minimum_distance, unit.maximum_range + 1)
		encounter.minimum_path_distance_by_role[unit.tactical_role_id] = minimum_distance
		encounter.maximum_path_distance_by_role[unit.tactical_role_id] = (
			7 if uses_fixed_balance(node) else minimum_distance + 8
		)
	encounter.living_enemy_cap = roles.size()
	return true


static func composition_for(node: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(encounter_preview(node).get("roles", []))
	return result


static func formations_for(node: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(encounter_preview(node).get("formations", [&"split", &"double_line"]))
	return result


static func hp_factor(node: Dictionary) -> float:
	return float(encounter_preview(node).get("hp_factor", 1.0))


static func attack_factor(node: Dictionary) -> float:
	return float(encounter_preview(node).get("attack_factor", 1.0))


static func encounter_preview(node: Dictionary) -> Dictionary:
	if not uses_monsters(node):
		return { }
	if uses_fixed_balance(node):
		if not profile_validation_error(node).is_empty():
			return { }
		var roles := _fixed_roles(int(node.depth), StringName(str(node.route_family)))
		var formation: Array = V1_FORMATIONS.get(StringName(str(node.route_family)), [&"split"])
		return _pack(
			str(node.get("title", node.encounter_profile_id)),
			roles,
			str(node.get("hint", "Menaces combinées à résoudre.")),
			"Deux réponses tactiques doivent rester viables avec chaque arme.",
			1.0,
			1.0,
			str(formation[0]),
		)
	var early := EarlyEncounters.preview(node)
	if not early.is_empty():
		return early
	var reward := str(node.get("reward", "melee"))
	match int(node.get("depth", 2)):
		2:
			if reward == "ranged":
				return _pack(
					"Les trois angles",
					[&"archer", &"archer", &"archer"],
					"Trois tireurs fragiles occupent des lignes différentes.",
					"Fermez une ligne avec le couvert, puis engagez un tireur.",
					0.90,
					0.85,
					"split",
				)
			return _pack(
				"Les porteurs de bronze",
				[&"brute", &"brute"],
				"Deux brutes à 2 PM, une seule attaque de contact.",
				"Contournez leur approche lente et concentrez vos frappes.",
				1.0,
				1.0,
				"line",
			)
		3:
			if reward == "mobility":
				return _pack(
					"La première chasse",
					[&"archer", &"molosse", &"molosse"],
					"Deux prédateurs approchent sous la couverture d'un tireur.",
					"Utilisez un goulet pour éviter les deux morsures ensemble.",
					0.90,
					0.85,
					"left_flank",
				)
			return _pack(
				"Le tribut de bronze",
				[&"brute", &"brute"],
				"Deux gardiens plus résistants tiennent le passage.",
				"Leur lenteur permet de les séparer avant le contact.",
				1.05,
				1.0,
				"double_line",
			)
		5:
			if reward == "ranged":
				return _pack(
					"Les roseaux sifflants",
					[&"archer", &"archer", &"archer"],
					"Trois tireurs gardent les traversées.",
					"Changez de ligne derrière les obstacles ; menacez le flanc.",
					0.80,
					0.80,
					"split",
				)
			return _pack(
				"La gardienne du gué",
				[&"lamie", &"brute"],
				"La magie du Léthé accompagne un défenseur lent.",
				"Approchez la mage en gardant une issue hors du contact.",
				1.0,
				0.90,
				"double_line",
			)
		6:
			if reward == "elemental":
				return _pack(
					"La meute des braises",
					[&"conducteur", &"molosse", &"molosse", &"molosse"],
					"Un conducteur marque sa proie pour trois molosses.",
					"Brisez la ligne du conducteur ou éliminez-le avant l'encerclement.",
					0.85,
					0.70,
					"left_flank",
				)
			return _pack(
				"La procession des cinq",
				[&"brute", &"brute", &"brute", &"brute", &"brute"],
				"Cinq lourds vétérans avancent à 2 PM.",
				"Faites-les converger dans vos zones ; conservez une sortie.",
				0.65,
				0.65,
				"double_line",
				2,
			)
		9:
			if reward == "mobility":
				return _pack(
					"La nuée du Styx",
					[
						&"serviteur",
						&"serviteur",
						&"serviteur",
						&"serviteur",
						&"serviteur",
						&"serviteur",
					],
					"Six petites bêtes rapides et fragiles chassent ensemble.",
					"Les zones et les passages étroits réduisent vite leur nombre.",
					0.90,
					0.65,
					"split",
				)
			return _pack(
				"Le premier officiant",
				[&"officiant", &"brute", &"porteur", &"porteur"],
				"Un soigneur à réserve limitée soutient un garde et deux porteurs.",
				"Forcez ses soins sur les petites cibles ou atteignez le soutien.",
				0.85,
				0.80,
				"double_line",
			)
		10:
			if reward == "control":
				return _pack(
					"L'aimant et l'enclume",
					[&"rabatteur", &"executeur"],
					"Une chaîne attire vers le grand coup préparé de l'exécuteur.",
					"Séparez le duo, quittez le contact de l’exécuteur et bloquez la chaîne par le couvert.",
					1.15,
					0.85,
					"line",
				)
			return _pack(
				"Les lignes de chasse",
				[&"archer", &"archer", &"archer", &"molosse", &"molosse", &"lamie"],
				"Trois tireurs, deux poursuivants et une mage menacent plusieurs fronts.",
				"Cassez les lignes de tir et supprimez un flanc avant de traverser.",
				0.65,
				0.55,
				"split",
			)
		11:
			if reward == "discovery":
				return _pack(
					"La garde des mémoires",
					[&"officiant", &"brute", &"brute", &"archer", &"archer"],
					"Un soutien soigne les défenseurs sous couverture des tireurs.",
					"Contournez la garde ou épuisez les soins sur une cible isolée.",
					0.70,
					0.65,
					"double_line",
				)
			return _pack(
				"Les deux piliers",
				[
					&"brute",
					&"brute",
					&"serviteur",
					&"serviteur",
					&"serviteur",
					&"serviteur",
					&"serviteur",
				],
				"Deux lourds tiennent le centre ; cinq serviteurs remplissent les intervalles.",
				"Ouvrez de l'espace avec une zone avant d'affronter les piliers.",
				0.85,
				0.60,
				"double_line",
			)
		13:
			if reward == "armor":
				return _pack(
					"La batterie d'airain",
					[&"porte_egide", &"porte_egide", &"archer", &"archer"],
					"Deux porteurs d'égide protègent les tireurs proches.",
					"Déplacez un protecteur ou attaquez hors de sa couverture.",
					0.65,
					0.65,
					"double_line",
				)
			return _pack(
				"La fournaise vivante",
				[&"fondeur", &"deplaceur", &"deplaceur"],
				"Un fondeur crée des braises ; deux molosses cherchent à vous y pousser.",
				"Éliminez un pousseur et conservez une sortie hors du feu.",
				0.90,
				0.75,
				"left_flank",
			)
		14:
			if reward == "melee":
				return _pack(
					"Les cinq colosses",
					[&"brute", &"brute", &"brute", &"porte_egide", &"porte_egide"],
					"Cinq colosses à 2 PM, dont deux boucliers de groupe.",
					"Rassemblez-les pour les zones, puis séparez les protecteurs de leurs alliés.",
					0.62,
					0.60,
					"double_line",
					2,
				)
			return _pack(
				"La chasse blanche",
				[&"guetteur", &"guetteur", &"traqueur", &"chasseur", &"chasseur", &"tisseuse"],
				"Les ralentissements préparent les tirs et la poursuite sur les ponts.",
				"Quittez le givre et les lignes de visée ; attaquez une aile à la fois.",
				0.65,
				0.55,
				"split",
			)
		15:
			return _pack(
				"Le serment de l'enclume",
				[&"rabatteur", &"executeur"],
				"Le rabatteur mobile attire vers l'exécuteur et ses coups préparés.",
				"Rompez leur alignement et exploitez le tour de préparation.",
				1.10,
				0.85,
				"line",
			)
		16:
			return _pack(
				"Le champion sans repos",
				[&"champion"],
				"Un seul champion alterne chaîne, frappes et garde avec ses 6 PA.",
				"Exploitez le délai de sa chaîne et évitez son contact lorsque le revers est disponible.",
				1.40,
				0.90,
				"line",
			)
		17:
			if reward == "armor":
				return _pack(
					"Le dernier rempart",
					[&"porte_egide", &"guetteur", &"protecteur"],
					"Un bouclier et un officiant soutiennent le tir du guetteur.",
					"La garde est courte : isolez le tireur ou atteignez le soutien.",
					0.75,
					0.70,
					"double_line",
				)
			return _pack(
				"Le hurlement du jardin",
				[&"alpha", &"serviteur", &"serviteur", &"serviteur", &"serviteur"],
				"Un alpha renforce quatre petits chasseurs.",
				"Frappez la meute groupée ou éliminez l'alpha qui la renforce.",
				0.85,
				0.65,
				"left_flank",
			)
		18:
			if reward == "melee":
				return _pack(
					"La phalange des damnés",
					[
						&"rabatteur",
						&"executeur",
						&"artilleur",
						&"deplaceur",
						&"deplaceur",
						&"oracle",
					],
					"Attraction, poussées, bombardement et soutien composent le dernier assaut.",
					"Brisez d'abord une combinaison : oracle, artilleur ou rabatteur selon votre angle.",
					0.62,
					0.55,
					"split",
				)
			return _pack(
				"Le convoi des âmes",
				[
					&"collecteur",
					&"brute",
					&"brute",
					&"brute",
					&"porteur",
					&"porteur",
					&"porteur",
					&"porteur",
				],
				"Trois gardes protègent un collecteur dont les soins exigent un porteur proche.",
				"Interceptez les quatre porteurs fragiles ou éloignez-les du collecteur.",
				0.68,
				0.55,
				"double_line",
			)
	return _pack(
		"La garde errante",
		[&"brute", &"archer"],
		"Un défenseur et un tireur tiennent la salle.",
		"Séparez leur ligne de défense.",
		1.0,
		0.85,
		"split",
	)


static func _fixed_roles(depth: int, family: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var by_family: Dictionary = V1_ROLES_BY_DEPTH.get(depth, { })
	var source: Array = by_family.get(family, by_family.get(&"shared", []))
	result.assign(source)
	return result


static func _fixed_targets(
	role: StringName,
	roles: Array[StringName],
	node: Dictionary,
) -> Dictionary:
	var depth := int(node.depth)
	var reference: Array = V1_REFERENCES[depth]
	var sum_weights := 0.0
	for entry: StringName in roles:
		sum_weights += _hp_weight(entry, depth)
	var target_pack_hp := float(reference[1]) * float(V1_PACK_HP_WEIGHTS[depth]) * difficulty_hp_factor(
		node
	)
	var target_hp := roundi(target_pack_hp * _hp_weight(role, depth) / maxf(0.01, sum_weights))
	var attack_ratio := float(V1_ATTACK_RATIOS.get(role, 0.10))
	var target_attack := roundi(float(reference[0]) * attack_ratio * difficulty_damage_factor(node))
	return { "hp": maxi(1, target_hp), "attack": maxi(1, target_attack) }


static func _hp_weight(role: StringName, depth: int) -> float:
	if depth == 10:
		return 3.4
	return float(V1_HP_WEIGHTS.get(role, 1.8))


static func difficulty_hp_factor(node: Dictionary) -> float:
	return 0.90 if str(node.get("difficulty_id", "normal")) == "easy" else 1.0


static func difficulty_damage_factor(node: Dictionary) -> float:
	return 0.80 if str(node.get("difficulty_id", "normal")) == "easy" else 1.0


static func _configure_opening(encounter: EncounterDefinition, node: Dictionary) -> bool:
	if encounter.roster_units.is_empty():
		push_error("Catabase r6 : profil d’ouverture sans ennemi")
		return false
	var hp_factor := difficulty_hp_factor(node)
	var damage_factor := difficulty_damage_factor(node)
	var source_units := encounter.roster_units.duplicate()
	encounter.roster_units = []
	for source: UnitData in source_units:
		var unit := Evolution.clone_unit(source)
		if unit == null:
			_clear_roster(encounter)
			push_error("Catabase r6 : ennemi d’ouverture invalide")
			return false
		Evolution.apply_fixed_balance(
			unit,
			roundi(float(source.max_hp) * hp_factor),
			roundi(float(source.attack_power) * damage_factor),
		)
		for spell: Spell in unit.spells:
			spell.damage = roundi(float(spell.damage) * damage_factor)
		encounter.roster_units.append(unit)
	return true


static func _configure_paris(encounter: EncounterDefinition, node: Dictionary) -> bool:
	var paris := Evolution.clone_unit(load(PARIS_PATH) as UnitData)
	var spectre := Evolution.clone_unit(load(SPECTRE_PATH) as UnitData)
	if paris == null or spectre == null or paris.combat_form_change == null:
		_clear_roster(encounter)
		push_error("Catabase r6 : ressources de Pâris incomplètes")
		return false
	var hp_factor := difficulty_hp_factor(node)
	var damage_factor := difficulty_damage_factor(node)
	paris.max_hp = roundi(560.0 * hp_factor)
	paris.max_ap = 4
	paris.max_mp = 3
	paris.combat_form_change.below_hp_percent = 20
	paris.combat_form_change.restore_full_hp = true
	paris.combat_form_change.shield_grant = 30
	for spell: Spell in paris.spells:
		_tune_paris_spell(spell, damage_factor)
	for spell: Spell in paris.combat_form_change.spells:
		_tune_paris_spell(spell, damage_factor)
	spectre.max_hp = roundi(150.0 * hp_factor)
	spectre.max_ap = 2
	spectre.max_mp = 3
	for spell: Spell in spectre.spells:
		if spell.get_effective_spell_id() == &"spectre_heavy_cleave":
			spell.damage = roundi(70.0 * damage_factor)
			spell.description = "%d dégâts physiques au contact." % spell.damage
	_clear_roster(encounter)
	encounter.roster_units.assign([paris, spectre])
	encounter.roster_counts = PackedInt32Array([1, 2])
	encounter.formation_profiles.assign([&"split", &"double_line"])
	encounter.minimum_path_distance_by_role = { }
	encounter.minimum_path_distance_by_role[paris.tactical_role_id] = 5
	encounter.minimum_path_distance_by_role[spectre.tactical_role_id] = 5
	encounter.maximum_path_distance_by_role = { }
	encounter.maximum_path_distance_by_role[paris.tactical_role_id] = 8
	encounter.maximum_path_distance_by_role[spectre.tactical_role_id] = 8
	encounter.living_enemy_cap = 3
	return true


static func _tune_paris_spell(spell: Spell, damage_factor: float) -> void:
	if spell == null:
		return
	var spell_id := spell.get_effective_spell_id()
	if V1_PARIS_DAMAGE.has(spell_id):
		spell.damage = roundi(float(V1_PARIS_DAMAGE[spell_id]) * damage_factor)
	if spell.applied_status != null and spell.applied_status.get_effective_status_id() == &"burn":
		spell.applied_status.damage_per_turn = roundi(12.0 * damage_factor)
	if spell.terrain_effect != null and spell.terrain_effect.surface_id == &"fire":
		spell.terrain_effect.damage = roundi(20.0 * damage_factor)
		if spell.terrain_effect.applied_status != null:
			spell.terrain_effect.applied_status.damage_per_turn = roundi(12.0 * damage_factor)
	match spell_id:
		&"paris_spectral_arrow":
			spell.description = "%d dégâts spectraux à longue portée." % spell.damage
		&"paris_fire_arrow":
			spell.description = "%d dégâts de feu, Brûlure et feu au sol à %d dégâts." % [
				spell.damage,
				spell.terrain_effect.damage,
			]
		&"paris_ice_arrow":
			spell.description = "%d dégâts de glace et −1 PM à la prochaine activation." % spell.damage
		&"paris_vortex_arrow":
			spell.description = "%d dégâts spectraux et attire d’une case." % spell.damage
		&"paris_infernal_whip":
			spell.description = "%d dégâts de feu à portée courte." % spell.damage
		&"paris_infernal_sweep":
			spell.description = "%d dégâts de feu en croix et feu au sol à %d dégâts." % [
				spell.damage,
				spell.terrain_effect.damage,
			]
		&"paris_infernal_pull":
			spell.description = "%d dégâts de feu et attire d’une case." % spell.damage


static func _clear_roster(encounter: EncounterDefinition) -> void:
	encounter.roster_units = []
	encounter.roster_counts = PackedInt32Array()
	encounter.minimum_path_distance_by_role = { }
	encounter.maximum_path_distance_by_role = { }
	encounter.shared_normal_summon_budget = 0
	encounter.shared_chief_summon_budget = 0
	encounter.disabled_ability_ids = []
	encounter.living_enemy_cap = 0


static func _pack(
	title: String,
	roles: Array,
	summary: String,
	counterplay: String,
	hp: float,
	attack: float,
	formation: String,
	mp_cap: int = 0,
) -> Dictionary:
	return {
		"name": title,
		"count": roles.size(),
		"roles": roles,
		"summary": summary,
		"counterplay": counterplay,
		"hp_factor": hp,
		"attack_factor": attack,
		"formations": [StringName(formation)],
		"mp_cap": mp_cap,
	}
