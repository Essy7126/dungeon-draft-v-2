@tool
class_name EncounterValidationService
extends RefCounted


static func validate_session(
		session: EncounterEditSession,
		test_seed: int = 1337
	) -> Array[StudioValidationMessage]:
	var messages: Array[StudioValidationMessage] = []
	if session == null or session.working_run == null:
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"run_missing", "RunData absente",
			"Ouvrez une RunData avant de valider."
		))
		return messages
	var run := session.working_run
	if run.rooms.is_empty():
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"run_empty", "Run sans salle", "La run doit contenir au moins une salle."
		))
	var graph := EncounterReferenceGraphService.build_for_run(run, session.source_run_path)
	for room_index in range(run.rooms.size()):
		var room := run.rooms[room_index]
		if room == null:
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"room_missing", "RoomData absente", "La salle referencee est nulle.",
				{"room_index": room_index}
			))
			continue
		_validate_room(messages, room, room_index, test_seed, graph)
	var conflict := session.conflict_report()
	if conflict.get("conflict", false):
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"external_conflict", "Conflit de fichier non resolu",
			"Des ressources ont change sur disque : %s" % ", ".join(
				conflict.get("changed_paths", PackedStringArray())
			)
		))
	session.validation_messages = messages
	return messages


static func has_errors(messages: Array[StudioValidationMessage]) -> bool:
	return messages.any(func(message: StudioValidationMessage) -> bool:
		return message.severity == StudioValidationMessage.Severity.ERROR
	)


static func summary(messages: Array[StudioValidationMessage]) -> Dictionary:
	var result := {"errors": 0, "warnings": 0, "information": 0}
	for message in messages:
		match message.severity:
			StudioValidationMessage.Severity.ERROR: result["errors"] += 1
			StudioValidationMessage.Severity.WARNING: result["warnings"] += 1
			_: result["information"] += 1
	result["valid"] = result["errors"] == 0
	return result


static func _validate_room(
		messages: Array[StudioValidationMessage],
		room: RoomData,
		room_index: int,
		test_seed: int,
		graph: Dictionary
	) -> void:
	var context := {"room_index": room_index, "resource_path": room.resource_path}
	var mode := "Vagues data-driven" if not room.waves.is_empty() \
		else "Rencontre unique historique" if room.encounter_definition != null \
		else "Liste d'ennemis historique" if not room.enemies.is_empty() \
		else "Sans rencontre"
	messages.append(_message(
		StudioValidationMessage.Severity.INFO,
		&"room_mode", "Mode de la salle", mode, context
	))
	var grid := EncounterGridFactory.build_from_room(room)
	if grid == null:
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"grid_missing", "Grille absente",
			"La grille runtime de cette salle ne peut pas etre construite.", context
		))
	elif room.grid_layout != null:
		for error in room.grid_layout.validation_errors():
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"layout_invalid", "Layout invalide", error, context
			))
	if room.hero_spawn_zone.is_empty():
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"ally_zone_empty", "Zone de deploiement alliee vide",
			"Le planificateur mesure les distances depuis cette zone.", context
		))
	elif grid != null and not room.hero_spawn_zone.any(
		func(cell): return grid.is_valid(cell) and grid.is_walkable(cell)
	):
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"ally_zone_unwalkable", "Aucune case alliee praticable",
			"Toutes les cases de deploiement allie sont hors grille ou bloquees.", context
		))
	if room.enemy_spawn_zone.is_empty():
		messages.append(_message(
			StudioValidationMessage.Severity.WARNING,
			&"preferred_enemy_zone_empty", "Zone ennemie preferee vide",
			"Le planificateur peut tout de meme utiliser les autres cases praticables.", context
		))
	if room.waves.is_empty():
		if room.encounter_definition != null:
			_validate_encounter(
				messages, room, null, room.encounter_definition,
				room_index, 0, test_seed, grid, graph
			)
		elif room.enemies.is_empty():
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"encounter_missing", "Rencontre absente",
				"La salle ne contient ni vagues, ni rencontre, ni liste historique.", context
			))
		return
	for wave_index in range(room.waves.size()):
		var wave := room.waves[wave_index]
		var wave_context := context.duplicate()
		wave_context["wave_index"] = wave_index
		if wave == null:
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"wave_missing", "RoomWaveData absente",
				"L'affrontement reference une vague nulle.", wave_context
			))
			continue
		if wave.wave_name.strip_edges().is_empty():
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"wave_name_empty", "Nom d'affrontement vide",
				"Donnez un nom lisible a l'affrontement.", wave_context
			))
		if wave.enemy_health_multiplier <= 0.0:
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"health_multiplier_invalid", "Multiplicateur de PV invalide",
				"Le multiplicateur de PV ennemis doit etre positif.", wave_context
			))
		if wave.enemy_attack_multiplier <= 0.0:
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"attack_multiplier_invalid", "Multiplicateur d'attaque invalide",
				"Le multiplicateur d'attaque ennemie doit etre positif.", wave_context
			))
		if wave.reward_multiplier < 0.0:
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"reward_multiplier_invalid", "Multiplicateur de recompense invalide",
				"Le multiplicateur de recompense ne peut pas etre negatif.", wave_context
			))
		_validate_encounter(
			messages, room, wave, wave.encounter_definition,
			room_index, wave_index, test_seed, grid, graph
		)


static func _validate_encounter(
		messages: Array[StudioValidationMessage],
		room: RoomData,
		wave: RoomWaveData,
		encounter: EncounterDefinition,
		room_index: int,
		wave_index: int,
		test_seed: int,
		grid: GridData,
		graph: Dictionary
	) -> void:
	var context := {
		"room_index": room_index,
		"wave_index": wave_index,
		"resource_path": encounter.resource_path if encounter != null else "",
	}
	if encounter == null:
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"encounter_missing", "EncounterDefinition absente",
			"Assignez une rencontre a cet affrontement.", context
		))
		return
	if encounter.roster_units.is_empty():
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"roster_empty", "Composition vide", "Ajoutez au moins une unite ennemie.", context
		))
	if encounter.roster_units.size() != encounter.roster_counts.size():
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"roster_parallel_mismatch", "Composition incoherente",
			"Les donnees internes d'unites et de quantites ne sont pas paralleles.", context
		))
	var seen_units := {}
	var roles := {}
	var has_normal_summon := false
	var has_chief_summon := false
	for index in range(encounter.roster_units.size()):
		var unit := encounter.roster_units[index]
		var count := encounter.roster_counts[index] if index < encounter.roster_counts.size() else 0
		if unit == null:
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"unit_missing", "UnitData absente", "Une ligne de composition est nulle.", context
			))
			continue
		if count <= 0:
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"quantity_invalid", "Quantite invalide",
				"Chaque unite doit avoir une quantite strictement positive.", context
			))
		var unit_id := unit.get_effective_unit_id()
		if seen_units.has(unit_id):
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"unit_duplicate", "UnitData dupliquee",
				"Regroupez les quantites de %s sur une seule ligne." % unit.unit_name, context
			))
		seen_units[unit_id] = true
		var role := unit.tactical_role_id
		roles[role] = true
		if role != &"" and role not in encounter.minimum_path_distance_by_role:
			messages.append(_message(
				StudioValidationMessage.Severity.WARNING,
				&"role_unknown", "Role non specialise par le planificateur",
				"%s utilisera le comportement generique reel." % role, context
			))
		for spell in unit.spells:
			if spell == null or not spell.is_summon() \
					or not encounter.is_ability_enabled(spell.get_effective_spell_id()):
				continue
			has_normal_summon = has_normal_summon or spell.summon_type == &"normal"
			has_chief_summon = has_chief_summon or spell.summon_type == &"chief"
	if encounter.living_enemy_cap < encounter.get_initial_enemy_count():
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"living_cap_too_low", "Plafond vivant insuffisant",
			"Le plafond vivant est inferieur au roster initial.",
			context.merged({"fix_id": &"fit_living_cap"}, true)
		))
	if encounter.formation_profiles.is_empty():
		messages.append(_message(
			StudioValidationMessage.Severity.ERROR,
			&"formations_empty", "Aucune formation autorisee",
			"Activez au moins une formation reconnue.", context
		))
	for formation in encounter.formation_profiles:
		if formation not in EncounterDefinition.FORMATION_IDS:
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"formation_unknown", "Formation inconnue", str(formation), context
			))
	if encounter.room_index != room_index + 1:
		messages.append(_message(
			StudioValidationMessage.Severity.WARNING,
			&"room_index_mismatch", "Index de salle incoherent",
			"La rencontre indique %d, la salle est en position %d." % [
				encounter.room_index, room_index + 1,
			], context.merged({"fix_id": &"use_actual_room_index"}, true)
		))
	var seen_cells := {}
	for cell in encounter.forbidden_initial_spawn_cells:
		if seen_cells.has(cell):
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"forbidden_cell_duplicate", "Case interdite dupliquee",
				"Cette exclusion est presente plusieurs fois.",
				context.merged({"cell": cell, "fix_id": &"deduplicate_forbidden"}, true)
			))
		seen_cells[cell] = true
		if grid == null or not grid.is_valid(cell):
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"forbidden_cell_outside", "Case interdite hors grille",
				"Retirez cette exclusion ou corrigez la map dans Arena Studio.",
				context.merged({"cell": cell}, true)
			))
	if encounter.shared_normal_summon_budget > 0 and not has_normal_summon:
		messages.append(_message(
			StudioValidationMessage.Severity.WARNING,
			&"normal_budget_without_ability", "Budget normal sans capacite",
			"Aucune capacite normale active ne peut consommer ce budget.", context
		))
	if encounter.shared_chief_summon_budget > 0 and not has_chief_summon:
		messages.append(_message(
			StudioValidationMessage.Severity.WARNING,
			&"chief_budget_without_ability", "Budget de chef sans capacite",
			"Aucune capacite de chef active ne peut consommer ce budget.", context
		))
	if (has_normal_summon and encounter.shared_normal_summon_budget == 0) \
			or (has_chief_summon and encounter.shared_chief_summon_budget == 0):
		messages.append(_message(
			StudioValidationMessage.Severity.WARNING,
			&"ability_without_budget", "Invocation active sans budget",
			"La capacite ne pourra pas etre preparee par EncounterRuntimeState.", context
		))
	messages.append(_message(
		StudioValidationMessage.Severity.WARNING,
		&"allowed_spawn_groups_unused", "Groupes de spawn non consommes",
		"allowed_spawn_groups est conserve en mode Avance mais n'est pas lu par le runtime actuel.", context
	))
	var usage_count := EncounterReferenceGraphService.usages_for(encounter, graph).size()
	if usage_count > 1:
		messages.append(_message(
			StudioValidationMessage.Severity.WARNING,
			&"encounter_shared", "Rencontre partagee",
			"Cette ressource est utilisee par %d affrontements." % usage_count, context
		))
	if grid != null and not room.hero_spawn_zone.is_empty() and encounter.is_valid():
		var preview := EncounterPreviewService.generate(
			room, encounter, test_seed, room_index, wave_index
		)
		if not preview.get("valid", false):
			messages.append(_message(
				StudioValidationMessage.Severity.ERROR,
				&"required_seed_placement_failed", "Placement impossible pour la seed de test",
				"Raison runtime : %s." % preview.get("reason", &"unknown"), context
			))
		elif int(preview.get("outside_preferred_count", 0)) > 0:
			messages.append(_message(
				StudioValidationMessage.Severity.INFO,
				&"outside_preferred_zone", "Placement hors zone ennemie preferee",
				"La zone ennemie est une preference, pas une limite stricte.", context
			))


static func _message(
		severity: StudioValidationMessage.Severity,
		code: StringName,
		title: String,
		explanation: String,
		context: Dictionary = {}
	) -> StudioValidationMessage:
	return StudioValidationMessage.create(severity, code, title, explanation, context)
