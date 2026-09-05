extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Gameplay-only export: no dependency on an in-progress terrain/sprite import.
	var economy = load("res://data/runs/economy/odyssey_economy_profile.tres")
	var progression = load("res://data/runs/progression/odyssey/achilles_progression_profile.tres")
	var data = load("res://data/units/allies/achilles.tres").duplicate()
	data.spells = progression.spells
	var state = load("res://characters/progression/character_run_state.gd").new()
	state.initialize(load("res://units/unit.gd").from_data(data), data, 4, progression)
	var champion = state.champion_progression
	var profile = champion.profile
	var report := {"version": 2, "status": "Équilibrage V0", "run": "Catabase", "levels": [], "masteries": [], "items": []}
	report["progression_rules"] = _export_data(profile)
	report["techniques"] = []
	for spell in data.spells:
		report.techniques.append(_export_fields(spell, ["spell_id", "spell_name", "description", "ap_cost", "minimum_range", "spell_range", "needs_line_of_sight", "once_per_activation", "damage_type", "damage_scaling", "shield_scaling", "shield_duration_activations", "shield_tags", "caster_movement", "movement_requires_clear_path"]))
	report["economy"] = {"starting_currency": economy.starting_currency,
		"victory_currency_reward": economy.victory_currency_reward, "merchant": _export_data(economy.merchant_profile)}
	var lines: Array[String] = [
		"# Achille — statistiques et maîtrises de la Catabase",
		"", "Valeurs V0 générées depuis les ressources et le resolver utilisés en combat. Document actualisé par `tools/champion_progression/export_champion_statistics.gd`.",
		"", "## Progression du champion",
		"", "La Catabase conserve ses trois rencontres actuelles : 100, 120 et 140 XP après victoire. Sans Sagesse ni Gloire, Achille termine au niveau 4. Les niveaux 5–14 et les spécialisations restent définis et vérifiés dans les fixtures de simulation ; aucune nouvelle run n’est créée.",
		"", "L’XP n’est jamais attribuée à un sort. Chaque victoire est comptée une seule fois par identifiant de rencontre. La Sagesse est figée au début du combat. Le Serment du Pélion est accepté avant le combat ; la victoire sans consommable accorde ensuite le multiplicateur de Gloire ×1,30.",
		"", "`XP = arrondi(XP de base × (1 + 0,10 × Sagesse au départ) × Gloire)`",
		"", "Chaque niveau 2–14 accorde 1 maîtrise. Chaque niveau 2–10 accorde aussi 1 caractéristique. Les points peuvent être conservés ; leur dépense est disponible entre les combats.",
		"", "| Niveau | XP cumulée | PV de base | Prouesse | Frappe | Tir | Garde |", "|---|---|---|---|---|---|---|",
	]
	for level in range(1, profile.level_cap + 1):
		var delta: int = profile.xp_for_level(level) - champion.current_xp
		if delta > 0:
			state.begin_encounter()
			state.award_encounter_xp(StringName("statistics_fixture_%d" % level), delta, true)
		var row := {"level": level, "xp": champion.current_xp, "hp": state.unit.max_hp.get_int(), "prowess": state.unit.attack_power.get_int(),
			"strike": data.spells[0].get_scaled_damage(state.unit), "shot": data.spells[2].get_scaled_damage(state.unit), "guard": data.spells[3].get_scaled_shield(state.unit)}
		report.levels.append(row)
		lines.append("| %d | %d | %d | %d | %d | %d | %d |" % [row.level, row.xp, row.hp, row.prowess, row.strike, row.shot, row.guard])
	lines.append_array([
		"", "Valeurs sans équipement ni maîtrise. 6 PA, 3 PM, initiative 14 et quatre emplacements restent constants. L’équipement demeure passif ; il ne crée ni attaque de base ni arme visible.",
		"", "## Quatre techniques",
		"", "| Technique | PA | Portée | Règle |", "|---|---|---|---|",
		"| Frappe du Péléide | 3 | 1 | 55 % Prouesse ; une utilisation par activation. |",
		"| Percée fulgurante | 1 | 1–3 | Déplacement cardinal vers une case libre, sans traverser les obstacles ni les unités. |",
		"| Tir du Pélion | 3 | 2–6 | 50 % Prouesse ; ligne de vue ; une utilisation par activation. |",
		"| Garde d’airain | 2 | Soi | 5 % PV max + 25 % Prouesse ; une utilisation ; expire au début de l’activation suivante. |",
		"", "La Garde est une source indépendante. Une garde plus faible ne remplace pas la garde restante ; ses effets ne consomment pas les autres boucliers. Les attaques automatiques n’utilisent ni PA ni quota manuel et ne donnent aucune XP.",
		"", "## Caractéristiques",
		"", "| Caractéristique | Effet par point |", "|---|---|",
		"| Vitalité | +6 % des PV de base du niveau, sous forme de bonus plat. |",
		"| Puissance | +5 % de Prouesse. |",
		"| Résolution | +4 armure ; +5 % à la création des boucliers. |",
		"| Sagesse | +10 % à l’XP des combats futurs, maximum 5 points. |",
		"", "Les montées de niveau et la Vitalité ajoutent seulement le gain de PV max aux PV actuels, en conservant les blessures. L’équipement et la forge ne soignent jamais. Le codex calcule les aperçus avec les mêmes stats et les mêmes règles que le combat.",
		"", "## Doctrines et destin héroïque",
		"", "Chaque racine coûte 1 maîtrise ; les paliers II–IV coûtent 1 par choix. Au moins un choix du palier précédent suffit. Les deux choix majeurs d’une doctrine sont exclusifs et coûtent 2 chacun. Premier choix majeur au niveau 10, second au niveau 13. Sommet au niveau 13 ; jonction et apothéose au niveau 14.",
		"", "Précision du mandat : Allonge et Tir rapproché sont exclusifs. La doctrine de Chiron est donc complète à 8 points légaux, contre 9 pour les deux autres. Le resolver considère le choix exclu comme couvert pour l’accès à une doctrine complète.",
		"", "| Maîtrise | Coût | Niveau min. | Effet |", "|---|---|---|---|",
	])
	for node in state.get_mastery_nodes():
		var row := {"id": str(node.upgrade_id), "name": node.display_name, "cost": node.mastery_cost, "minimum_level": node.required_champion_level,
			"doctrine": str(node.doctrine_id), "description": node.description, "prerequisites_any": node.requires_any_node_ids,
			"prerequisites_all": node.prerequisite_node_ids, "exclusions": node.excluded_node_ids}
		row["mechanics"] = _export_fields(node, ["node_type", "tier", "exclusive_group", "targeted_spell_modifiers", "reactive_effects", "requires_completed_tree_ids", "doctrine_point_requirements", "effect_axis", "reaction_group", "stackable", "priority", "affected_spell_ids"])
		report.masteries.append(row)
		lines.append("| %s | %d | %d | %s |" % [row.name, row.cost, row.minimum_level, str(row.description).replace("\n", " ").replace("|", "/")])
	lines.append_array(["", "## Équipements, reliques et préparation", "", "Le catalogue de Catabase contient 16 équipements, 8 reliques et les 2 consommables de départ déjà présents. Il est séparé du catalogue des autres personnages. Achille conserve ses 2 potions et son parchemin initiaux.",
		"", "Économie V0 de la Catabase : 120 drachmes au départ, puis 60 par victoire. L’étape de Chiron est accessible dans le bilan des deux premières salles. La forge augmente de 20 % par palier les bonus de caractéristiques positifs d’une pièce, jusqu’à +2, sans modifier ses malus ni les PV actuels. Les trois leçons au maximum n’ignorent jamais les prérequis de niveau.",
		"", "| Objet | Type | Effet |", "|---|---|---|"])
	for item in economy.item_catalog.get_definitions():
		var row := {"id": str(item.item_id), "name": item.display_name, "type": "Relique" if item.is_relic() else ("Équipement" if item.is_equippable() else "Consommable"), "description": item.description}
		row["mechanics"] = _export_fields(item, ["equipment_slot", "stat_modifiers", "spell_modifiers", "guard_effectiveness_melee", "guard_effectiveness_projectile", "reactive_effects", "use_effect", "use_value"])
		report.items.append(row)
		lines.append("| %s | %s | %s |" % [row.name, row.type, str(row.description).replace("\n", " ").replace("|", "/")])
	lines.append_array(["", "## Persistance et intégration", "", "Le snapshot d’inventaire et d’équipement est en version 5. Il conserve progression du champion, points non dépensés, choix de maîtrises, PV, Gloire, tirages de récompenses et de marchand, achats, forge, drachmes et priorités de réactions. Un ancien snapshot d’XP de sorts est refusé explicitement pour un champion ; les progressions historiques des autres personnages restent prises en charge.",
		"", "Les cartes, sprites, cinématique et le parcours actuel de trois salles restent les ressources de production. Les écrans utilisent les données runtime ; les options de déplacement facultatif restent des choix explicites sur les cases légales. Les barrières temporaires n’altèrent pas les terrains authored.",
		"", "Les chiffres constituent un réglage V0, pas une conclusion d’équilibrage définitif. Les tests vérifient les règles, les interactions et les transactions ; le ressenti de difficulté doit être affiné en jouant la Catabase."])
	var base := "res://docs/design/achilles/champion_catabase_statistics_v0"
	var markdown := FileAccess.open(base + ".md", FileAccess.WRITE)
	markdown.store_string("\n".join(lines) + "\n")
	var json := FileAccess.open(base + ".json", FileAccess.WRITE)
	json.store_string(JSON.stringify(report, "\t") + "\n")
	print("CHAMPION_STATISTICS_EXPORTED ", report.levels.size(), " levels, ", report.masteries.size(), " masteries, ", report.items.size(), " items")
	state.dispose()
	quit(0)


func _export_fields(resource: Resource, fields: Array) -> Dictionary:
	var result := {}
	for field in fields:
		result[str(field)] = _export_data(resource.get(str(field)))
	return result


func _export_data(value: Variant, depth: int = 0) -> Variant:
	if value is Resource:
		if depth >= 8 or value is Texture2D or value is PackedScene or value is AudioStream:
			return value.resource_path
		var result := {"resource": value.resource_path}
		for property in value.get_property_list():
			var usage := int(property.usage)
			if usage & PROPERTY_USAGE_STORAGE and usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				result[str(property.name)] = _export_data(value.get(property.name), depth + 1)
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_export_data(entry, depth + 1))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _export_data(value[key], depth + 1)
		return result
	if value is StringName:
		return str(value)
	return value
