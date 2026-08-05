class_name ObservatoryAuditRules
extends RefCounted


static func run(snapshot: Dictionary) -> Array[Dictionary]:
	var audits: Array[Dictionary] = []
	_check_identity(snapshot.get("characters", []) as Array, "character", audits)
	_check_identity(snapshot.get("disciplines", []) as Array, "discipline", audits)
	_check_identity(snapshot.get("spells", []) as Array, "spell", audits)
	_check_identity(snapshot.get("items", []) as Array, "item", audits)
	_check_party(snapshot, audits)
	_check_character_contract(snapshot, audits)
	_check_spells(snapshot, audits)
	_check_items(snapshot, audits)
	_check_rewards(snapshot, audits)
	for check_value in snapshot.get("contract_checks", []) as Array:
		var check := check_value as Dictionary
		if str(check.get("status", "")) == "not_evaluated":
			audits.append(_audit(
				"CONTRACT.NOT_EVALUATED",
				"info",
				"contract",
				"contract_check",
				str(check.get("key", "")),
				"Cette cible du contrat n’est pas évaluée automatiquement.",
				"docs/observatory/design_contract.json",
				str(check.get("evidence", "")),
				"Ajouter une preuve statique autoritaire avant de conclure.",
			))
	_sort_audits(audits)
	return audits


static func _check_identity(
		entities: Array,
		entity_type: String,
		audits: Array[Dictionary]
	) -> void:
	var seen := {}
	for entity_value in entities:
		var entity := entity_value as Dictionary
		var entity_id := str(entity.get("id", "")).strip_edges()
		if entity_id.is_empty():
			audits.append(_audit(
				"IDENTITY.MISSING_EXPLICIT_ID", "blocking", entity_type + "s",
				entity_type, "", "Une entité exportée ne possède pas d’identifiant explicite.",
				str(entity.get("source_path", "")), "Champ id vide.",
				"Définir un identifiant explicite dans la Resource source.",
			))
		elif seen.has(entity_id):
			audits.append(_audit(
				"IDENTITY.DUPLICATE_ID", "blocking", entity_type + "s",
				entity_type, entity_id, "Un identifiant est utilisé plusieurs fois.",
				str(entity.get("source_path", "")), "Identifiant dupliqué : %s." % entity_id,
				"Attribuer des identifiants uniques.",
			))
		seen[entity_id] = true


static func _check_party(snapshot: Dictionary, audits: Array[Dictionary]) -> void:
	var present := {}
	for character_value in snapshot.get("characters", []) as Array:
		present[str((character_value as Dictionary).get("id", ""))] = true
	for required_id in ["elf", "mage", "warrior"]:
		if not present.has(required_id):
			audits.append(_audit(
				"PARTY.REQUIRED_HERO_MISSING", "blocking", "characters", "character",
				required_id, "Un héros requis par le contrat est absent de la production.",
				"docs/observatory/design_contract.json", "ID requis : %s." % required_id,
				"Rétablir la référence de production ou réviser explicitement le contrat.",
			))
	for character_id in present:
		if character_id not in ["elf", "mage", "warrior"]:
			audits.append(_audit(
				"PARTY.UNEXPECTED_PRODUCTION_HERO", "warning", "characters", "character",
				character_id, "Un héros de production n’appartient pas au trio cible.",
				"docs/observatory/data_source_manifest.json", "ID observé : %s." % character_id,
				"Vérifier le manifeste ou versionner la nouvelle cible.",
			))


static func _check_character_contract(
		snapshot: Dictionary,
		audits: Array[Dictionary]
	) -> void:
	for character_value in snapshot.get("characters", []) as Array:
		var character := character_value as Dictionary
		var source := str(character.get("source_path", ""))
		var character_id := str(character.get("id", ""))
		if int(character.get("max_ap", -1)) != 6:
			audits.append(_audit("PARTY.BASE_AP_MISMATCH", "warning", "characters", "character",
				character_id, "Le budget de PA observé diffère de la cible 6.", source,
				"PA observés : %s." % character.get("max_ap"), "Vérifier la Resource ou le contrat."))
		if int(character.get("max_mp", -1)) != 3:
			audits.append(_audit("PARTY.BASE_MP_MISMATCH", "warning", "characters", "character",
				character_id, "Le budget de PM observé diffère de la cible 3.", source,
				"PM observés : %s." % character.get("max_mp"), "Vérifier la Resource ou le contrat."))
		if int(character.get("active_spell_slots", -1)) != 4:
			audits.append(_audit("PARTY.ACTIVE_SPELL_SLOT_MISMATCH", "warning", "characters",
				"character", character_id, "Le nombre d’emplacements actifs diffère de la cible 4.",
				source, "Emplacements observés : %s." % character.get("active_spell_slots"),
				"Vérifier la Resource ou le contrat."))
		if (character.get("spell_ids", []) as Array).size() != 4:
			audits.append(_audit("PARTY.STARTING_SPELL_COUNT_MISMATCH", "warning", "characters",
				"character", character_id, "Le nombre de sorts de départ diffère de la cible 4.",
				source, "Sorts observés : %d." % (character.get("spell_ids", []) as Array).size(),
				"Vérifier les références du héros."))
		if (character.get("discipline_ids", []) as Array).size() != 4:
			audits.append(_audit("PARTY.DISCIPLINE_COUNT_MISMATCH", "warning", "characters",
				"character", character_id, "Le nombre de disciplines diffère de la cible 4.",
				source, "Disciplines observées : %d." % (
					character.get("discipline_ids", []) as Array
				).size(), "Vérifier les références du héros."))


static func _check_spells(snapshot: Dictionary, audits: Array[Dictionary]) -> void:
	var disciplines := {}
	for discipline_value in snapshot.get("disciplines", []) as Array:
		var discipline := discipline_value as Dictionary
		disciplines[str(discipline.get("id", ""))] = str(discipline.get("character_id", ""))
	for spell_value in snapshot.get("spells", []) as Array:
		var spell := spell_value as Dictionary
		var spell_id := str(spell.get("id", ""))
		var discipline_id := str(spell.get("discipline_id", ""))
		if discipline_id.is_empty():
			audits.append(_audit("SPELL.DISCIPLINE_ID_MISSING", "warning", "spells", "spell",
				spell_id, "Le sort ne déclare aucune discipline.", str(spell.get("source_path", "")),
				"discipline_id vide.", "Renseigner une discipline explicite si le sort progresse."))
		elif disciplines.has(discipline_id):
			var owner := str(disciplines[discipline_id])
			for character_id in spell.get("referenced_by_character_ids", []) as Array:
				if str(character_id) != owner:
					audits.append(_audit("SPELL.DISCIPLINE_NOT_OWNED_BY_CHARACTER", "warning",
						"spells", "spell", spell_id,
						"Le sort référence une discipline appartenant à un autre héros.",
						str(spell.get("source_path", "")),
						"Discipline %s possédée par %s." % [discipline_id, owner],
						"Vérifier discipline_id ou la référence du héros."))


static func _check_items(snapshot: Dictionary, audits: Array[Dictionary]) -> void:
	var production_ids: Array[String] = []
	for character_value in snapshot.get("characters", []) as Array:
		production_ids.append(str((character_value as Dictionary).get("id", "")))
	for item_value in snapshot.get("items", []) as Array:
		var item := item_value as Dictionary
		if not bool(item.get("valid", false)):
			audits.append(_audit("ITEM.CATALOG_INVALID", "blocking", "items", "item",
				str(item.get("id", "")), "Une définition du catalogue est invalide.",
				str(item.get("source_path", "")), "ItemDefinition.is_valid() retourne false.",
				"Corriger la définition sans modifier l’exporteur."))
		var compatible := item.get("compatible_character_ids", []) as Array
		if not compatible.is_empty() and not compatible.any(func(value: Variant) -> bool:
			return str(value) in production_ids
		):
			audits.append(_audit("ITEM.NO_COMPATIBLE_PRODUCTION_HERO", "warning", "items",
				"item", str(item.get("id", "")),
				"Cet objet n’est compatible avec aucun héros de production.",
				str(item.get("source_path", "")), "Compatibilités : %s." % str(compatible),
				"Vérifier les IDs compatibles ou le catalogue."))


static func _check_rewards(snapshot: Dictionary, audits: Array[Dictionary]) -> void:
	var item_ids := {}
	for item_value in snapshot.get("items", []) as Array:
		item_ids[str((item_value as Dictionary).get("id", ""))] = true
	for pool_value in snapshot.get("reward_pools", []) as Array:
		var pool := pool_value as Dictionary
		if str(pool.get("kind", "")) == "generic_declared":
			for reward_value in pool.get("rewards", []) as Array:
				var reward := reward_value as Dictionary
				if not bool(reward.get("valid", false)):
					audits.append(_audit("REWARD.GENERIC_REWARD_INVALID", "blocking", "rewards",
						"reward", str(reward.get("id", "")), "Une récompense déclarée est invalide.",
						str(reward.get("source_path", "")), "is_valid() retourne false.",
						"Corriger la Resource de récompense."))
		if str(pool.get("kind", "")) == "equipment_first_run":
			var ids := pool.get("item_ids", []) as Array
			if ids.size() < int(pool.get("minimum_options", 2)):
				audits.append(_audit("REWARD.EQUIPMENT_POOL_TOO_SMALL", "blocking",
					"reward_pools", "reward_pool", str(pool.get("id", "")),
					"Le pool ne peut pas produire le minimum d’options demandé.",
					str(pool.get("source_path", "")), "Objets éligibles : %d." % ids.size(),
					"Ajouter des équipements compatibles au catalogue."))
			for item_id in ids:
				if not item_ids.has(str(item_id)):
					audits.append(_audit("REWARD.UNKNOWN_ITEM_REFERENCE", "blocking",
						"reward_pools", "item", str(item_id),
						"Le pool référence un objet absent du catalogue exporté.",
						str(pool.get("source_path", "")), "ID inconnu : %s." % item_id,
						"Réparer le catalogue ou la source du pool."))


static func _audit(
		rule_id: String,
		severity: String,
		domain: String,
		entity_type: String,
		entity_id: String,
		message: String,
		source_path: String,
		evidence: String,
		action: String
	) -> Dictionary:
	return {
		"rule_id": rule_id,
		"severity": severity,
		"status": "open",
		"domain": domain,
		"entity_type": entity_type,
		"entity_id": entity_id,
		"message": message,
		"source_path": source_path,
		"evidence": evidence,
		"suggested_action": action,
	}


static func _sort_audits(audits: Array[Dictionary]) -> void:
	var order := {"blocking": 0, "warning": 1, "info": 2}
	audits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%d|%s|%s|%s" % [order.get(a.get("severity"), 9),
			a.get("rule_id"), a.get("domain"), a.get("entity_id")]
		var b_key := "%d|%s|%s|%s" % [order.get(b.get("severity"), 9),
			b.get("rule_id"), b.get("domain"), b.get("entity_id")]
		return a_key < b_key
	)
