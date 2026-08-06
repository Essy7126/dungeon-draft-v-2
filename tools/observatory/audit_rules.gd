class_name ObservatoryAuditRules
extends RefCounted


static func run(snapshot: Dictionary) -> Array[Dictionary]:
	var audits: Array[Dictionary] = []
	_check_identity(snapshot.get("characters", []) as Array, "character", audits)
	_check_identity(snapshot.get("disciplines", []) as Array, "discipline", audits)
	_check_identity(snapshot.get("spells", []) as Array, "spell", audits)
	_check_identity(snapshot.get("items", []) as Array, "item", audits)
	_check_identity(snapshot.get("runs", []) as Array, "run", audits)
	_check_identity(snapshot.get("rooms", []) as Array, "room", audits)
	_check_identity(snapshot.get("waves", []) as Array, "wave", audits)
	_check_identity(snapshot.get("encounters", []) as Array, "encounter", audits)
	_check_identity(snapshot.get("enemies", []) as Array, "enemy", audits)
	_check_identity(snapshot.get("enemy_spells", []) as Array, "enemy_spell", audits)
	_check_identity(snapshot.get("ai_profiles", []) as Array, "ai_profile", audits)
	_check_party(snapshot, audits)
	_check_character_contract(snapshot, audits)
	_check_spells(snapshot, audits)
	_check_items(snapshot, audits)
	_check_rewards(snapshot, audits)
	_check_run_data(snapshot, audits)
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


static func _check_run_data(snapshot: Dictionary, audits: Array[Dictionary]) -> void:
	var runs := snapshot.get("runs", []) as Array
	var rooms := snapshot.get("rooms", []) as Array
	var waves := snapshot.get("waves", []) as Array
	var encounters := snapshot.get("encounters", []) as Array
	var enemies := snapshot.get("enemies", []) as Array
	var enemy_spells := snapshot.get("enemy_spells", []) as Array
	if runs.is_empty():
		audits.append(_audit(
			"RUN.PRODUCTION_ROOT_MISSING", "blocking", "runs", "run", "first_run",
			"La run de production ne peut pas etre chargee.",
			"res://data/runs/first_run.tres", "La collection runs est vide.",
			"Retablir la racine de production.",
		))
	var seen_room_sources := {}
	for run_value in runs:
		var run := run_value as Dictionary
		if str(run.get("validation_status", "")) != "valid" \
				or not (run.get("validation_errors", []) as Array).is_empty():
			audits.append(_audit(
				"RUN.INVALID", "blocking", "runs", "run", str(run.get("id", "")),
				"La RunData de production est invalide.", str(run.get("source_path", "")),
				"RunData.validation_errors() : %s." % str(run.get("validation_errors", [])),
				"Corriger la Resource de production.",
			))
	for room_value in rooms:
		var room := room_value as Dictionary
		var room_id := str(room.get("id", ""))
		var source := str(room.get("source_path", ""))
		if not source.is_empty() and seen_room_sources.has(source):
			audits.append(_audit(
				"RUN.DUPLICATE_ROOM_REFERENCE", "warning", "rooms", "room", room_id,
				"La meme RoomData apparait plusieurs fois dans la run.", source,
				"Source deja exportee par %s." % seen_room_sources[source],
				"Documenter l'intention de repetition.",
			))
		seen_room_sources[source] = room_id
		if str(room.get("battle_scene_path", "")).is_empty():
			audits.append(_audit(
				"ROOM.MISSING_BATTLE_SCENE", "blocking", "rooms", "room", room_id,
				"Aucune scene de combat n'est declaree.", source,
				"battle_scene_path est vide.", "Declarer la scene de combat de la salle.",
			))
		if int(room.get("available_wave_count", 0)) <= 0:
			audits.append(_audit(
				"ROOM.NO_AVAILABLE_WAVE", "blocking", "rooms", "room", room_id,
				"La salle ne contient aucune vague disponible.", source,
				"RoomData.get_wave_count() retourne zero.",
				"Declarer une vague ou une rencontre historique.",
			))
		var minimum := int(room.get("minimum_wave_count", 0))
		var maximum := int(room.get("maximum_wave_count", 0))
		var available := int(room.get("available_wave_count", 0))
		if minimum <= 0 or maximum < minimum or maximum > available:
			audits.append(_audit(
				"ROOM.WAVE_RANGE_INVALID", "blocking", "rooms", "room", room_id,
				"La plage min/max de vagues est incoherente.", source,
				"minimum=%d, maximum=%d, disponible=%d." % [minimum, maximum, available],
				"Corriger la plage de vagues dans RoomData.",
			))
		if int(room.get("hero_spawn_cell_count", 0)) <= 0 \
				or int(room.get("enemy_spawn_cell_count", 0)) <= 0:
			audits.append(_audit(
				"ROOM.SPAWN_ZONE_EMPTY", "warning", "rooms", "room", room_id,
				"Une zone de deploiement requise est vide.", source,
				"heros=%s, ennemis=%s." % [room.get("hero_spawn_cell_count"),
					room.get("enemy_spawn_cell_count")],
				"Verifier les zones de spawn de la salle.",
			))
		if int(room.get("ultimate_reward_min_gain_per_wave", 0)) \
				> int(room.get("ultimate_reward_max_gain_per_wave", 0)):
			audits.append(_audit(
				"ROOM.ULTIMATE_REWARD_RANGE_INVALID", "blocking", "rooms", "room",
				room_id, "La plage de progression de recompense ultime est inversee.",
				source, "Le gain minimum depasse le gain maximum.",
				"Corriger la plage de gain dans RoomData.",
			))
	_check_waves(waves, audits)
	_check_encounters(encounters, enemies, enemy_spells, audits)
	_check_enemies(enemies, enemy_spells, audits)
	_check_summons(enemy_spells, audits)
	_check_derived_identities(runs, rooms, waves, audits)


static func _check_waves(waves: Array, audits: Array[Dictionary]) -> void:
	for wave_value in waves:
		var wave := wave_value as Dictionary
		var wave_id := str(wave.get("id", ""))
		var source := str(wave.get("source_path", ""))
		if str(wave.get("validation_status", "")) != "valid":
			audits.append(_audit(
				"WAVE.INVALID", "blocking", "waves", "wave", wave_id,
				"Le profil de vague est invalide.", source,
				"RoomWaveData.validation_errors() : %s." % str(wave.get("validation_errors", [])),
				"Corriger la Resource de vague.",
			))
		if str(wave.get("encounter_id", "")).is_empty():
			audits.append(_audit(
				"WAVE.MISSING_ENCOUNTER", "blocking", "waves", "wave", wave_id,
				"Aucune rencontre n'est resolue pour la vague.", source,
				"encounter_id est vide.", "Declarer une EncounterDefinition.",
			))
		if float(wave.get("enemy_health_multiplier", 0.0)) <= 0.0 \
				or float(wave.get("enemy_attack_multiplier", 0.0)) <= 0.0 \
				or float(wave.get("reward_multiplier", -1.0)) < 0.0:
			audits.append(_audit(
				"WAVE.NON_POSITIVE_MULTIPLIER", "blocking", "waves", "wave", wave_id,
				"Un multiplicateur de vague est hors limites.", source,
				"PV=%s, attack_power=%s, recompense=%s." % [
					wave.get("enemy_health_multiplier"), wave.get("enemy_attack_multiplier"),
					wave.get("reward_multiplier")], "Corriger les multiplicateurs declares.",
			))
		if str(wave.get("attack_multiplier_effect_status", "")) \
				== "no_active_source_detected" \
				and not is_equal_approx(float(wave.get("enemy_attack_multiplier", 1.0)), 1.0) \
				and not str(wave.get("attack_multiplier_effect_evidence", "")).is_empty():
			audits.append(_audit(
				"WAVE.ATTACK_MULTIPLIER_NO_ACTIVE_DAMAGE_SOURCE", "warning", "waves",
				"wave", wave_id,
				"Aucune source de degats active ne lit attack_power dans ce roster.", source,
				str(wave.get("attack_multiplier_effect_evidence", "")),
				"Verifier le gameplay sans le modifier depuis Observatory.",
			))


static func _check_encounters(
		encounters: Array,
		enemies: Array,
		enemy_spells: Array,
		audits: Array[Dictionary]
	) -> void:
	var enemy_ids := _entity_ids(enemies)
	var spell_ids := _entity_ids(enemy_spells)
	var formation_ids := ["line", "double_line", "left_flank", "right_flank",
		"chief_forward", "centurion_rear", "split"]
	for encounter_value in encounters:
		var encounter := encounter_value as Dictionary
		var encounter_id := str(encounter.get("id", ""))
		var source := str(encounter.get("source_path", ""))
		if str(encounter.get("validation_status", "")) != "valid":
			audits.append(_audit(
				"ENCOUNTER.INVALID", "blocking", "encounters", "encounter", encounter_id,
				"La rencontre ne passe pas sa validation interne.", source,
				"EncounterDefinition.validation_errors() : %s." % str(
					encounter.get("validation_errors", [])
				), "Corriger l'EncounterDefinition de production.",
			))
		if int(encounter.get("roster_unit_entry_count", 0)) \
				!= int(encounter.get("roster_count_entry_count", 0)):
			audits.append(_audit(
				"ENCOUNTER.ROSTER_SIZE_MISMATCH", "blocking", "encounters", "encounter",
				encounter_id, "Les unites et compteurs du roster ne sont pas paralleles.",
				source, "unites=%s, compteurs=%s." % [
					encounter.get("roster_unit_entry_count"),
					encounter.get("roster_count_entry_count")],
				"Aligner roster_units et roster_counts.",
			))
		if int(encounter.get("living_enemy_cap", 0)) \
				< int(encounter.get("initial_enemy_count", 0)):
			audits.append(_audit(
				"ENCOUNTER.LIVING_CAP_BELOW_INITIAL", "blocking", "encounters", "encounter",
				encounter_id, "Le plafond vivant est inferieur au roster initial.", source,
				"plafond=%s, initial=%s." % [encounter.get("living_enemy_cap"),
					encounter.get("initial_enemy_count")], "Augmenter le plafond ou reduire le roster.",
			))
		for formation_id in encounter.get("formation_profiles", []) as Array:
			if str(formation_id) not in formation_ids:
				audits.append(_audit(
					"ENCOUNTER.UNKNOWN_FORMATION", "blocking", "encounters", "encounter",
					encounter_id, "Une formation n'appartient pas au contrat de production.",
					source, "Formation inconnue : %s." % formation_id,
					"Utiliser un identifiant de formation declare.",
				))
		for roster_value in encounter.get("roster", []) as Array:
			var enemy_id := str((roster_value as Dictionary).get("enemy_id", ""))
			if enemy_id.is_empty() or not enemy_ids.has(enemy_id):
				audits.append(_audit(
					"ENCOUNTER.UNKNOWN_ENEMY_REFERENCE", "blocking", "encounters", "encounter",
					encounter_id, "Une UnitData du roster ne peut pas etre resolue.", source,
					"enemy_id inconnu : %s." % enemy_id, "Retablir la reference UnitData.",
				))
		for ability_id in encounter.get("disabled_ability_ids", []) as Array:
			if not spell_ids.has(str(ability_id)):
				audits.append(_audit(
					"ENCOUNTER.DISABLED_ABILITY_UNRESOLVED", "warning", "encounters",
					"encounter", encounter_id,
					"Une capacite desactivee ne correspond a aucun sort atteignable.", source,
					"ID non resolu : %s." % ability_id,
					"Verifier l'identifiant de capacite desactivee.",
				))
		_check_encounter_summon_budget(encounter, enemies, enemy_spells, audits)


static func _check_encounter_summon_budget(
		encounter: Dictionary,
		enemies: Array,
		enemy_spells: Array,
		audits: Array[Dictionary]
	) -> void:
	var enemy_map := _entity_map(enemies)
	var spell_map := _entity_map(enemy_spells)
	var compatible := {"normal": false, "chief": false}
	var disabled := encounter.get("disabled_ability_ids", []) as Array
	for enemy_id in encounter.get("expanded_initial_enemy_ids", []) as Array:
		var enemy := enemy_map.get(str(enemy_id), {}) as Dictionary
		for spell_id in enemy.get("spell_ids", []) as Array:
			if str(spell_id) in disabled:
				continue
			var spell := spell_map.get(str(spell_id), {}) as Dictionary
			var summon_type := str(spell.get("summon_type", ""))
			if compatible.has(summon_type) and not str(spell.get("summon_enemy_id", "")).is_empty():
				compatible[summon_type] = true
	for summon_type in ["normal", "chief"]:
		var budget_key := "shared_%s_summon_budget" % summon_type
		if int(encounter.get(budget_key, 0)) > 0 and not bool(compatible[summon_type]):
			audits.append(_audit(
				"SUMMON.BUDGET_WITHOUT_SUMMONER", "warning", "encounters", "encounter",
				str(encounter.get("id", "")),
				"Un budget d'invocation positif ne dispose d'aucun sort compatible actif.",
				str(encounter.get("source_path", "")),
				"type=%s, budget=%s." % [summon_type, encounter.get(budget_key)],
				"Verifier le roster, les sorts et les capacites desactivees.",
			))


static func _check_enemies(
		enemies: Array, enemy_spells: Array, audits: Array[Dictionary]
	) -> void:
	var spell_ids := _entity_ids(enemy_spells)
	for enemy_value in enemies:
		var enemy := enemy_value as Dictionary
		var enemy_id := str(enemy.get("id", ""))
		var source := str(enemy.get("source_path", ""))
		if str(enemy.get("id_source", "")) != "explicit":
			audits.append(_audit(
				"ENEMY.MISSING_EXPLICIT_ID", "blocking", "enemies", "enemy", enemy_id,
				"L'ennemi ne declare pas de unit_id explicite.", source,
				"id_source=%s." % enemy.get("id_source"), "Renseigner UnitData.unit_id.",
			))
		if int(enemy.get("team", -1)) != 1:
			audits.append(_audit(
				"ENEMY.WRONG_TEAM", "blocking", "enemies", "enemy", enemy_id,
				"Une unite de rencontre n'appartient pas a l'equipe ennemie.", source,
				"team=%s." % enemy.get("team"), "Corriger UnitData.team.",
			))
		var valid_spell_count := 0
		for spell_id in enemy.get("spell_ids", []) as Array:
			if spell_ids.has(str(spell_id)):
				valid_spell_count += 1
			else:
				audits.append(_audit(
					"ENEMY.UNKNOWN_SPELL_REFERENCE", "blocking", "enemies", "enemy", enemy_id,
					"Un sort reference par l'ennemi ne peut pas etre charge.", source,
					"Sort inconnu : %s." % spell_id, "Retablir la reference Spell.",
				))
		if not bool(enemy.get("basic_attack_enabled", false)) and valid_spell_count == 0:
			audits.append(_audit(
				"ENEMY.NO_ACTION_SOURCE", "warning", "enemies", "enemy", enemy_id,
				"L'ennemi n'a ni attaque de base active ni sort valide.", source,
				"basic_attack_enabled=false et aucun sort resolu.",
				"Verifier les actions disponibles dans UnitData.",
			))
		if str(enemy.get("ai_profile_id", "")).is_empty():
			audits.append(_audit(
				"ENEMY.AI_PROFILE_MISSING", "info", "enemies", "enemy", enemy_id,
				"Aucun profil d'IA specialise n'est reference.", source,
				"EnemyAI conserve son comportement generique via ai_behavior.",
				"Ajouter un profil uniquement si une strategie specialisee est voulue.",
			))


static func _check_summons(enemy_spells: Array, audits: Array[Dictionary]) -> void:
	for spell_value in enemy_spells:
		var spell := spell_value as Dictionary
		var delayed := spell.get("delayed_resolution", {}) as Dictionary
		if str(delayed.get("name", "")) == "summon" \
				and str(spell.get("summon_enemy_id", "")).is_empty():
			audits.append(_audit(
				"SUMMON.UNKNOWN_UNIT_REFERENCE", "blocking", "enemy_spells", "enemy_spell",
				str(spell.get("id", "")), "Le sort d'invocation ne resout aucune UnitData.",
				str(spell.get("source_path", "")), "summon_enemy_id est vide.",
				"Retablir Spell.summon_unit_data.",
			))


static func _check_derived_identities(
		runs: Array, rooms: Array, waves: Array, audits: Array[Dictionary]
	) -> void:
	for group in [[runs, "run"], [rooms, "room"], [waves, "wave"]]:
		for entity_value in group[0] as Array:
			var entity := entity_value as Dictionary
			if str(entity.get("identity_stability", "")) != "derived":
				continue
			audits.append(_audit(
				"IDENTITY.DERIVED_OBSERVATORY_ID", "info", str(group[1]) + "s",
				str(group[1]), str(entity.get("id", "")),
				"L'identifiant est derive par Observatory et n'existe pas dans le jeu.",
				str(entity.get("source_path", "")),
				"id_source=%s ; identity_stability=derived." % entity.get("id_source"),
				"Conserver l'ordre parent ou l'alias de manifeste.",
			))


static func _entity_ids(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		result[str((value as Dictionary).get("id", ""))] = true
	return result


static func _entity_map(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		var entity := value as Dictionary
		result[str(entity.get("id", ""))] = entity
	return result


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
	var affected_ids: Array[String] = []
	if not entity_id.is_empty():
		affected_ids.append(entity_id)
	return {
		"rule_id": rule_id,
		"severity": severity,
		"status": "open",
		"truth_status": "verified",
		"suggested_action_truth_status": "recommendation",
		"domain": domain,
		"entity_type": entity_type,
		"entity_id": entity_id,
		"affected_entity_type": entity_type,
		"affected_entity_ids": affected_ids,
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
