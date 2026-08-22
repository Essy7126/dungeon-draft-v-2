@tool
class_name SkillTreeEditorValidator
extends RefCounted

const DEFAULT_CHARACTERIZATION_PROFILE_PATH := "res://addons/dungeon_draft_arena_studio/skill_tree/profiles/production_2026_08_05.tres"

static func validate_unit(
		unit: UnitData,
		production_profile := false,
		project_heroes: Array[Dictionary] = [],
		allowed_storage_roots := PackedStringArray(["res://data/"])
	) -> Array[SkillTreeValidationMessage]:
	var messages: Array[SkillTreeValidationMessage] = []
	if unit == null:
		messages.append(_error(
			&"unit_missing", "Personnage introuvable",
			"Le Studio ne peut pas travailler sans une unité de référence.",
			"Choisissez un personnage dans le catalogue."
		))
		return messages
	_validate_character_stats(unit, messages)
	_validate_storage_paths(unit, messages, {}, allowed_storage_roots)
	var discipline_ids := {}
	var node_ids := {}
	for discipline in unit.disciplines:
		if discipline == null:
			messages.append(_error(
				&"discipline_null", "Discipline manquante",
				"Une entrée du personnage ne référence aucune discipline.",
				"Supprimez l’entrée vide ou choisissez une DisciplineData."
			))
			continue
		if discipline_ids.has(discipline.discipline_id):
			messages.append(_error(
				&"discipline_duplicate", "Identifiant de discipline dupliqué",
				"Deux disciplines de ce personnage utilisent « %s »." % discipline.discipline_id,
				"Attribuez un identifiant stable différent à l’une des disciplines.",
				discipline.discipline_id, &"discipline_id"
			))
		discipline_ids[discipline.discipline_id] = true
		_validate_discipline(unit, discipline, messages, node_ids, production_profile)
	_validate_shared_modifiers(unit, messages)
	_validate_project_discipline_ids(unit, project_heroes, messages)
	return messages


static func has_errors(messages: Array[SkillTreeValidationMessage]) -> bool:
	return messages.any(func(message: SkillTreeValidationMessage) -> bool:
		return message.is_error()
	)


static func summary(messages: Array[SkillTreeValidationMessage]) -> Dictionary:
	var result := {"errors": 0, "warnings": 0, "information": 0}
	for message in messages:
		match message.severity:
			SkillTreeValidationMessage.Severity.ERROR:
				result.errors += 1
			SkillTreeValidationMessage.Severity.WARNING:
				result.warnings += 1
			_:
				result.information += 1
	return result


static func _validate_character_stats(
		unit: UnitData,
		messages: Array[SkillTreeValidationMessage]
	) -> void:
	for property_name in [&"max_hp", &"max_ap", &"max_mp", &"initiative"]:
		if int(unit.get(property_name)) < 0:
			messages.append(_error(
				&"negative_character_stat", "Caractéristique négative",
				"La valeur « %s » ne peut pas être négative." % property_name,
				"Saisissez une valeur égale ou supérieure à zéro.",
				unit.get_effective_unit_id(), property_name
			))
	if unit.get_effective_unit_id() == &"unit_data:unassigned":
		messages.append(_error(
			&"unit_id_empty", "Identifiant du personnage manquant",
			"Les sauvegardés ont besoin d’un identifiant stable pour reconnaître le personnage.",
			"Renseignez un identifiant court, par exemple « warrior ».",
			&"", &"unit_id"
		))


static func _validate_storage_paths(
		resource: Resource,
		messages: Array[SkillTreeValidationMessage],
		visited: Dictionary,
		allowed_storage_roots: PackedStringArray
	) -> void:
	if resource == null or visited.has(resource.get_instance_id()):
		return
	visited[resource.get_instance_id()] = true
	var allowed_path := resource.resource_path.is_empty()
	for allowed_root in allowed_storage_roots:
		allowed_path = allowed_path or resource.resource_path.begins_with(allowed_root)
	if not resource.resource_path.is_empty() and not resource.is_built_in() \
			and (not allowed_path \
			or resource.resource_path.get_extension().to_lower() not in ["tres", "res"] \
			or resource.resource_path.contains("..")):
		messages.append(_error(
			&"unsafe_resource_path", "Chemin de sauvegarde non autorisé",
			"La Resource utilise un emplacement que le Studio ne peut pas écrire : %s" % resource.resource_path,
			"Placez les données sous res://data/ avec l’extension .tres ou .res."
		))
	if resource is UnitData:
		for spell in resource.spells:
			_validate_storage_paths(spell, messages, visited, allowed_storage_roots)
		for discipline in resource.disciplines:
			_validate_storage_paths(discipline, messages, visited, allowed_storage_roots)
	elif resource is DisciplineData:
		for rank_data in resource.ranks:
			_validate_storage_paths(rank_data, messages, visited, allowed_storage_roots)
	elif resource is DisciplineRankData:
		for node in resource.choices:
			_validate_storage_paths(node, messages, visited, allowed_storage_roots)
	elif resource is SkillUpgradeData:
		for modifier in resource.spell_modifiers:
			_validate_storage_paths(modifier, messages, visited, allowed_storage_roots)
	elif resource is Spell:
		for modifier in resource.modifiers:
			_validate_storage_paths(modifier, messages, visited, allowed_storage_roots)


static func _validate_discipline(
		unit: UnitData,
		discipline: DisciplineData,
		messages: Array[SkillTreeValidationMessage],
		node_ids: Dictionary,
		production_profile: bool
	) -> void:
	for diagnostic in SkillTreeResolver.validate_discipline(discipline):
		messages.append(_runtime_diagnostic(str(diagnostic), discipline.discipline_id))
	if discipline.display_name.strip_edges().is_empty():
		messages.append(_warning(
			&"discipline_name_empty", "Nom de discipline manquant",
			"Le joueur ne verra aucun nom compréhensible pour cette discipline.",
			"Ajoutez un nom affiché.", discipline.discipline_id, &"display_name"
		))
	var spell := SkillTreeCatalogService.spell_for_discipline(unit, discipline.discipline_id)
	if spell == null:
		messages.append(_error(
			&"base_spell_missing", "Sort de base introuvable",
			"Aucun sort du personnage n’utilise l’identifiant de cette discipline.",
			"Associez un sort dont la discipline correspond à « %s »." % discipline.discipline_id,
			discipline.discipline_id, &"discipline_id"
		))
	var previous_threshold: int = -1
	var previous_delta: int = -1
	var sorted_ranks := discipline.ranks.duplicate()
	sorted_ranks.sort_custom(func(a, b):
		return a != null and (b == null or a.rank < b.rank)
	)
	for rank_data in sorted_ranks:
		if rank_data == null:
			continue
		if rank_data.required_total_xp < 0:
			messages.append(_error(
				&"xp_negative", "Seuil d’XP négatif",
				"Le rang %d demande %d XP, ce qui est impossible." % [rank_data.rank, rank_data.required_total_xp],
				"Utilisez un seuil cumulé positif ou nul.",
				discipline.discipline_id, &"required_total_xp", rank_data.rank
			))
		var delta: int = rank_data.required_total_xp - previous_threshold \
			if previous_threshold >= 0 else rank_data.required_total_xp
		if previous_delta > 0 and delta > previous_delta * 3:
			messages.append(_warning(
				&"xp_large_gap", "Fort écart dans la courbe d’XP",
				"Le rang %d demande %d XP supplémentaires, beaucoup plus que le rang précédent." % [rank_data.rank, delta],
				"Vérifiez que ce ralentissement est volontaire.",
				discipline.discipline_id, &"required_total_xp", rank_data.rank
			))
		previous_threshold = rank_data.required_total_xp
		previous_delta = delta
		if rank_data.rank == 1 and not rank_data.choices.is_empty():
			messages.append(_warning(
				&"rank_one_choices", "Choix présents au rang 1",
				"Le rang 1 représente normalement le sort de base et ne demande aucun choix.",
				"Déplacez ces améliorations au rang 2 ou conservez-les volontairement.",
				discipline.discipline_id, &"choices", 1
			))
		for node in rank_data.choices:
			if node == null:
				continue
			if node_ids.has(node.upgrade_id):
				messages.append(_error(
					&"project_node_duplicate", "Identifiant d’amélioration dupliqué",
					"L’identifiant « %s » est déjà utilisé dans un autre arbre du personnage." % node.upgrade_id,
					"Générez un nouvel identifiant stable.", node.upgrade_id, &"upgrade_id", node.rank
				))
			node_ids[node.upgrade_id] = true
			_validate_node(unit, discipline, node, messages)
	_validate_reachability(discipline, messages)
	if production_profile:
		_validate_production_profile(discipline, messages)


static func _validate_node(
		unit: UnitData,
		discipline: DisciplineData,
		node: SkillUpgradeData,
		messages: Array[SkillTreeValidationMessage]
	) -> void:
	if node.display_name.strip_edges().is_empty():
		messages.append(_warning(
			&"node_name_empty", "Nom d’amélioration manquant",
			"Ce nœud sera difficile à reconnaître dans le jeu.",
			"Ajoutez un nom court décrivant son rôle.", node.upgrade_id, &"display_name", node.rank
		))
	if node.description.strip_edges().is_empty():
		messages.append(_warning(
			&"node_description_empty", "Description manquante",
			"Le joueur ne saura pas ce que cette amélioration change.",
			"Décrivez l’effet avec une phrase simple.", node.upgrade_id, &"description", node.rank
		))
	var target_spell := _find_spell(unit, node.target_spell_id)
	if target_spell == null:
		messages.append(_error(
			&"target_spell_missing", "Sort ciblé introuvable",
			"L’amélioration « %s » cible un sort inexistant : « %s »." % [node.display_name, node.target_spell_id],
			"Choisissez un sort du personnage.", node.upgrade_id, &"target_spell_id", node.rank
		))
	elif target_spell.discipline_id != discipline.discipline_id:
		messages.append(_warning(
			&"target_spell_other_discipline", "Sort d’une autre discipline",
			"Cette amélioration transforme un sort associé à une autre discipline.",
			"Vérifiez que ce croisement est volontaire.", node.upgrade_id, &"target_spell_id", node.rank
		))
	if node.spell_modifiers.is_empty():
		messages.append(_warning(
			&"node_without_effect", "Amélioration sans effet",
			"Ce nœud peut être acheté mais ne modifiera aucun sort.",
			"Ajoutez au moins un modificateur.", node.upgrade_id, &"spell_modifiers", node.rank
		))
	for modifier in node.spell_modifiers:
		if modifier == null:
			messages.append(_error(
				&"modifier_null", "Modificateur manquant",
				"Une entrée d’effet est vide et ne peut pas être exécutée.",
				"Supprimez l’entrée vide ou choisissez un SpellModifier.",
				node.upgrade_id, &"spell_modifiers", node.rank
			))
		else:
			var descriptor: SkillEffectEditorDescriptor = (
				SkillEffectEditorRegistry.new().descriptor_for(modifier)
			)
			if descriptor == null:
				messages.append(_error(
					&"modifier_descriptor_missing", "Descripteur métier manquant",
					"Le type de modificateur ne peut pas être authoré sans édition technique.",
					"Ajoutez son descripteur au registre 2.0 avant sauvegarde.",
					node.upgrade_id, &"spell_modifiers", node.rank
				))
			else:
				for descriptor_error in descriptor.validate(modifier):
					messages.append(_error(
						&"modifier_descriptor_invalid", "Effet métier incomplet",
						descriptor_error, "Corrigez le champ guidé indiqué.",
						node.upgrade_id, &"spell_modifiers", node.rank
					))
			if modifier is SpellModSkillTreeEffect:
				_validate_skill_effect(node, modifier, target_spell, messages)
	if node is SkillTreeNodeData:
		var tree_node := node as SkillTreeNodeData
		for excluded_id in tree_node.excluded_node_ids:
			var other := _find_node(discipline, excluded_id) as SkillTreeNodeData
			if other != null and not other.excluded_node_ids.has(node.upgrade_id):
				messages.append(_warning(
					&"exclusion_asymmetric", "Exclusion non symétrique",
					"« %s » exclut « %s », mais l’inverse n’est pas déclaré." % [node.display_name, other.display_name],
					"Utilisez le bouton « Rendre symétrique ».", node.upgrade_id, &"excluded_node_ids", node.rank
				))


static func _validate_skill_effect(
		node: SkillUpgradeData,
		modifier: SpellModSkillTreeEffect,
		target_spell: Spell,
		messages: Array[SkillTreeValidationMessage]
	) -> void:
	if modifier.amount == 0 and modifier.ratio == 0.0 \
			and modifier.effect_type not in [
				SpellModSkillTreeEffect.EffectType.ALLOW_FREE_CELL_TARGET,
				SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET,
			]:
		messages.append(_warning(
			&"modifier_zero", "Effet réglé sur zéro",
			"Le modificateur « %s » risque de ne produire aucun changement." % modifier.modifier_name,
			"Renseignez une quantité adaptée à l’effet.", node.upgrade_id, &"amount", node.rank
		))
	if modifier.effect_type in [
		SpellModSkillTreeEffect.EffectType.DAMAGE_LOW_HP,
		SpellModSkillTreeEffect.EffectType.DAMAGE_BACKSTAB_OR_LOW_HP,
		SpellModSkillTreeEffect.EffectType.HEAL_LOW_HP,
	] and modifier.threshold_ratio <= 0.0:
		messages.append(_warning(
			&"condition_without_threshold", "Seuil de PV manquant",
			"Cet effet conditionnel ne peut pas savoir quand la cible est affaiblie.",
			"Définissez un seuil, par exemple 0,30 pour 30 %.",
			node.upgrade_id, &"threshold_ratio", node.rank
		))
	if modifier.effect_type in [
		SpellModSkillTreeEffect.EffectType.STATUS_DOT,
		SpellModSkillTreeEffect.EffectType.STATUS_SLOW,
		SpellModSkillTreeEffect.EffectType.STATUS_REGEN,
		SpellModSkillTreeEffect.EffectType.STATUS_VULNERABILITY,
		SpellModSkillTreeEffect.EffectType.STATUS_OUTGOING_DAMAGE,
	]:
		if modifier.duration <= 0:
			messages.append(_warning(
				&"status_without_duration", "Statut sans durée",
				"Le statut « %s » ne possède aucun tour actif." % modifier.status_name,
				"Définissez au moins un tour.", node.upgrade_id, &"duration", node.rank
			))
		if modifier.status_group == &"":
			messages.append(_warning(
				&"status_without_group", "Statut sans groupe stable",
				"Le runtime ne peut pas fusionner ou remplacer ce statut de façon fiable.",
				"Renseignez un groupe, par exemple « burning ».", node.upgrade_id, &"status_group", node.rank
			))
	if target_spell != null:
		var enemy_scope := modifier.target_scope in [
			SpellModSkillTreeEffect.TargetScope.PRIMARY_ENEMY,
			SpellModSkillTreeEffect.TargetScope.AFFECTED_ENEMIES,
		]
		var ally_scope := modifier.target_scope in [
			SpellModSkillTreeEffect.TargetScope.PRIMARY_ALLY,
			SpellModSkillTreeEffect.TargetScope.AFFECTED_ALLIES,
		]
		if enemy_scope and not target_spell.can_target_enemy \
				or ally_scope and not (target_spell.can_target_ally or target_spell.can_target_self):
			messages.append(_warning(
				&"effect_target_incompatible", "Cible d’effet inhabituelle",
				"L’effet vise une catégorie que le sort de base n’autorise pas directement.",
				"Vérifiez la cible de l’effet ou les cibles autorisées du sort.",
				node.upgrade_id, &"target_scope", node.rank
			))


static func _validate_shared_modifiers(
		unit: UnitData,
		messages: Array[SkillTreeValidationMessage]
	) -> void:
	var first_owner := {}
	for discipline in unit.disciplines:
		if discipline == null:
			continue
		for rank_data in discipline.ranks:
			if rank_data == null:
				continue
			for node in rank_data.choices:
				if node == null:
					continue
				for modifier in node.spell_modifiers:
					if modifier == null:
						continue
					if first_owner.has(modifier):
						var owner := first_owner[modifier] as SkillUpgradeData
						messages.append(_warning(
							&"shared_modifier", "Effet partagé entre plusieurs améliorations",
							"Modifier cet effet changera aussi « %s » dans la version en cours." % owner.display_name,
							"Utilisez « Unique » pour séparer les deux effets.",
							node.upgrade_id, &"spell_modifiers", node.rank
						))
					else:
						first_owner[modifier] = node


static func _validate_reachability(
		discipline: DisciplineData,
		messages: Array[SkillTreeValidationMessage]
	) -> void:
	if not SkillTreeResolver.validate_discipline(discipline).is_empty():
		return
	var configurations := SkillTreePathService.final_configurations(discipline)
	if configurations.is_empty():
		messages.append(_warning(
			&"no_final_path", "Aucun chemin final possible",
			"Les prérequis ou exclusions empêchent d’atteindre la fin de l’arbre.",
			"Examinez les relations signalées sur le graphe.", discipline.discipline_id
		))
		return
	var reachable := SkillTreePathService.reachable_node_ids(discipline)
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null and not reachable.has(node.upgrade_id):
				messages.append(_warning(
					&"node_unreachable", "Amélioration inaccessible",
					"Aucun chemin valide ne permet d’acheter « %s »." % node.display_name,
					"Corrigez ses prérequis ou ses exclusions.", node.upgrade_id, &"prerequisite_node_ids", node.rank
				))


static func _validate_production_profile(
		discipline: DisciplineData,
		messages: Array[SkillTreeValidationMessage]
	) -> void:
	var profile := ResourceLoader.load(
		DEFAULT_CHARACTERIZATION_PROFILE_PATH,
		"",
		ResourceLoader.CACHE_MODE_REUSE
	) as SkillTreeCharacterizationProfile
	if profile == null:
		messages.append(_warning(
			&"characterization_profile_missing", "Profil de caractérisation absent",
			"Le contrôle optionnel demandé ne peut pas être chargé.",
			"Vérifiez la Resource du profil ; les invariants runtime restent actifs.",
			discipline.discipline_id
		))
		return
	if discipline.ranks.size() != profile.expected_rank_count:
		messages.append(_warning(
			&"production_rank_count", "%s : nombre de rangs différent" % profile.display_name,
			"Cet arbre possède %d rang(s). Il reste techniquement autorisé." % discipline.ranks.size(),
			"Ignorez cet avertissement si cette topologie est volontaire.", discipline.discipline_id
		))
	for rank_data in discipline.ranks:
		if rank_data == null or rank_data.rank < 1 \
				or rank_data.rank > profile.expected_choices.size() \
				or rank_data.rank > profile.expected_thresholds.size():
			continue
		var expected_choice_count := profile.expected_choices[rank_data.rank - 1]
		var expected_threshold := profile.expected_thresholds[rank_data.rank - 1]
		if rank_data.choices.size() != expected_choice_count \
				or rank_data.required_total_xp != expected_threshold:
			messages.append(_warning(
				&"production_rank_contract", "Contrat de production différent au rang %d" % rank_data.rank,
				"Le profil « %s » attend %d choix et %d XP cumulés." % [profile.display_name, expected_choice_count, expected_threshold],
				"Appliquez le preset uniquement si cet arbre doit suivre le contrat actuel.",
				discipline.discipline_id, &"required_total_xp", rank_data.rank
			))
	var enumeration := SkillTreePathService.enumeration_result(discipline)
	if not bool(enumeration.get("truncated", false)) \
			and int(enumeration.get("count", 0)) \
			!= profile.expected_final_configuration_count:
		messages.append(_warning(
			&"production_path_count", "%s : nombre de chemins différent" % profile.display_name,
			"L’arbre possède %d configuration(s) finale(s), contre %d observées par le profil." % [enumeration.get("count", 0), profile.expected_final_configuration_count],
			"Ce contrôle est facultatif et ne bloque pas une autre topologie.", discipline.discipline_id
		))


static func _runtime_diagnostic(
		diagnostic: String,
		discipline_id: StringName
	) -> SkillTreeValidationMessage:
	var code := diagnostic.get_slice(":", 0)
	var detail := diagnostic.substr(code.length() + 1).strip_edges()
	var translations := {
		"INVALID_DISCIPLINE": ["Discipline invalide", "L’identifiant de la discipline est absent."],
		"DUPLICATE_RANK": ["Rang dupliqué", "Deux rangs utilisent le même numéro."],
		"NON_CONTIGUOUS_RANKS": ["Rangs non continus", "Il manque un rang dans la progression."],
		"NON_INCREASING_XP_THRESHOLD": ["Seuil d’XP non croissant", "Chaque rang doit demander davantage d’XP total que le précédent."],
		"NULL_CHOICE": ["Amélioration manquante", "Une entrée de choix est vide."],
		"EMPTY_UPGRADE_ID": ["Identifiant d’amélioration manquant", "Une amélioration ne possède aucun identifiant stable."],
		"DUPLICATE_UPGRADE_ID": ["Identifiant d’amélioration dupliqué", "Deux améliorations utilisent le même identifiant stable."],
		"DISCIPLINE_MISMATCH": ["Discipline incohérente", "Une amélioration déclare une autre discipline que son arbre."],
		"RANK_MISMATCH": ["Rang incohérent", "Le rang déclaré par une amélioration ne correspond pas à son emplacement."],
		"SELF_PREREQUISITE": ["Auto-prérequis interdit", "Une amélioration se demande elle-même comme prérequis."],
		"UNKNOWN_PREREQUISITE": ["Prérequis introuvable", "Une relation pointe vers une amélioration inexistante."],
		"PREREQUISITE_NOT_IN_LOWER_RANK": ["Prérequis placé trop haut", "Un prérequis doit appartenir à un rang inférieur."],
		"SELF_EXCLUSION": ["Auto-exclusion interdite", "Une amélioration s’exclut elle-même."],
		"UNKNOWN_EXCLUSION": ["Exclusion introuvable", "Une exclusion pointe vers une amélioration inexistante."],
		"PREREQUISITE_CYCLE": ["Cycle de prérequis", "Plusieurs améliorations se demandent mutuellement."],
	}
	var translated: Array = translations.get(code, ["Arbre invalide", diagnostic])
	return _error(
		StringName(code.to_lower()), translated[0],
		"%s Détail technique : %s" % [translated[1], detail],
		"Sélectionnez l’élément concerné et corrigez sa relation.", discipline_id
	)


static func _validate_project_discipline_ids(
		unit: UnitData,
		project_heroes: Array[Dictionary],
		messages: Array[SkillTreeValidationMessage]
	) -> void:
	if project_heroes.is_empty():
		return
	for own_discipline in unit.disciplines:
		if own_discipline == null:
			continue
		for hero_entry in project_heroes:
			var other := hero_entry.get("resource") as UnitData
			if other == null or other.resource_path == unit.resource_path \
					or other.get_effective_unit_id() == unit.get_effective_unit_id():
				continue
			for other_discipline in other.disciplines:
				if other_discipline != null \
						and other_discipline.discipline_id == own_discipline.discipline_id:
					messages.append(_error(
						&"project_discipline_duplicate", "Identifiant utilisé par un autre personnage",
						"La discipline « %s » de %s utilise déjà cet identifiant." % [other_discipline.display_name, other.unit_name],
						"Choisissez un identifiant unique dans tout le projet.",
						own_discipline.discipline_id, &"discipline_id"
					))


static func _find_spell(unit: UnitData, spell_id: StringName) -> Spell:
	if unit == null:
		return null
	for spell in unit.spells:
		if spell != null and spell.get_effective_spell_id() == spell_id:
			return spell
	return null


static func _find_node(
		discipline: DisciplineData,
		node_id: StringName
	) -> SkillUpgradeData:
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null and node.upgrade_id == node_id:
				return node
	return null


static func _error(
		code: StringName, title: String, explanation: String, suggestion := "",
		subject_id: StringName = &"", property_name: StringName = &"", rank := -1
	) -> SkillTreeValidationMessage:
	return SkillTreeValidationMessage.create(
		SkillTreeValidationMessage.Severity.ERROR, code, title, explanation,
		suggestion, subject_id, property_name, rank
	)


static func _warning(
		code: StringName, title: String, explanation: String, suggestion := "",
		subject_id: StringName = &"", property_name: StringName = &"", rank := -1
	) -> SkillTreeValidationMessage:
	return SkillTreeValidationMessage.create(
		SkillTreeValidationMessage.Severity.WARNING, code, title, explanation,
		suggestion, subject_id, property_name, rank
	)
