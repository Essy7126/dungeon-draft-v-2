extends GutTest

const RUN_PATH := "res://data/runs/fixed_trio_prototype_run.tres"
const ROOM_PATH := "res://data/rooms/test_waves/first_run_room_01_waves.tres"
const USER_FIXTURE_ROOT := "user://dungeon_draft_studio/encounter_studio/gut_fixtures"


func test_session_isole_source_dirty_abandon_et_conflit_externe() -> void:
	var source_run := ResourceLoader.load(
		RUN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData
	var session := EncounterEditSession.new()
	assert_true(session.open(source_run, RUN_PATH))
	var source_encounter := source_run.rooms[0].get_encounter_for_wave(0)
	var source_snapshot := EncounterCopyService.encounter_snapshot(source_encounter)
	var working := session.current_encounter()
	working.living_enemy_cap += 1
	session.mark_dirty(working)
	assert_true(session.is_dirty())
	assert_true(session.source_is_untouched())
	assert_eq(EncounterCopyService.encounter_snapshot(source_encounter), source_snapshot)
	assert_true(session.discard())
	assert_false(session.is_dirty())
	assert_eq(session.current_encounter().living_enemy_cap, source_encounter.living_enemy_cap)

	var conflict_path := USER_FIXTURE_ROOT.path_join("conflict_run.tres")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_FIXTURE_ROOT))
	var external_run := RunData.new()
	external_run.run_name = "Conflit A"
	external_run.rooms = [source_run.rooms[0]]
	assert_eq(ResourceSaver.save(external_run, conflict_path), OK)
	var conflict_source := ResourceLoader.load(
		conflict_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData
	var conflict_session := EncounterEditSession.new()
	assert_true(conflict_session.open(conflict_source, conflict_path))
	external_run.run_name = "Conflit B"
	assert_eq(ResourceSaver.save(external_run, conflict_path), OK)
	assert_true(conflict_session.conflict_report().conflict)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(conflict_path))


func test_copie_rencontre_independante_et_un_seul_usage_modifie() -> void:
	var source := (load(ROOM_PATH) as RoomData).get_encounter_for_wave(0)
	var copy := EncounterCopyService.copy_encounter(source)
	assert_ne(copy, source)
	assert_eq(copy.roster_units[0], source.roster_units[0])
	assert_eq(copy.roster_counts, source.roster_counts)
	assert_eq(copy.minimum_path_distance_by_role, source.minimum_path_distance_by_role)
	copy.roster_counts[0] += 4
	copy.minimum_path_distance_by_role[&"skeleton_normal"] = 99
	copy.forbidden_initial_spawn_cells.append(Vector2i(1, 1))
	assert_ne(copy.roster_counts, source.roster_counts)
	assert_ne(copy.minimum_path_distance_by_role, source.minimum_path_distance_by_role)
	assert_false(source.forbidden_initial_spawn_cells.has(Vector2i(1, 1)))
	var suggested := EncounterCopyService.suggested_path(
		load(ROOM_PATH) as RoomData, 0, "res://test/fixtures/encounter_studio"
	)
	assert_true(suggested.begins_with("res://test/fixtures/encounter_studio/"))


func test_copie_run_preserve_seed_et_profils_hors_domaine_rencontre() -> void:
	var source := _small_run()
	source.randomize_seed_each_run = false
	source.content_profile = RunContentProfile.new()
	source.economy_profile = RunEconomyProfile.new()
	var copied := EncounterCopyService.copy_run(source).get("run") as RunData
	assert_not_null(copied)
	assert_false(copied.randomize_seed_each_run)
	assert_same(copied.content_profile, source.content_profile)
	assert_same(copied.economy_profile, source.economy_profile)

	var session := _production_session()
	var shared := session.current_encounter()
	assert_eq(session.current_room().get_encounter_for_wave(1), shared)
	var independent := session.duplicate_current_encounter()
	assert_ne(independent, shared)
	assert_eq(session.current_room().get_encounter_for_wave(0), independent)
	assert_eq(session.current_room().get_encounter_for_wave(1), shared)
	assert_true(session.new_resource_paths.has(independent))


func test_graphe_references_plusieurs_vagues_salles_et_retrait_sans_fichier() -> void:
	var encounter := (load(ROOM_PATH) as RoomData).get_encounter_for_wave(0)
	var first := _small_room(encounter)
	var second := _small_room(encounter)
	first.room_name = "Premiere"
	second.room_name = "Seconde"
	var shared_wave := RoomWaveData.new()
	shared_wave.wave_name = "Usage partage supplementaire"
	shared_wave.encounter_definition = encounter
	first.waves.append(shared_wave)
	var run := RunData.new()
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.rooms = [first, second]
	var graph := EncounterReferenceGraphService.build_for_run(run, "res://fixture.tres")
	var summary := EncounterReferenceGraphService.summary_for(encounter, graph)
	assert_eq(summary.usage_count, 3)
	assert_eq(summary.room_count, 2)
	assert_eq(summary.usages.size(), 3)
	var canonical_path := encounter.resource_path
	first.waves.remove_at(1)
	graph = EncounterReferenceGraphService.build_for_run(run, "res://fixture.tres")
	assert_eq(EncounterReferenceGraphService.usages_for(encounter, graph).size(), 2)
	assert_true(FileAccess.file_exists(canonical_path))


func test_timeline_ajout_duplication_reorganisation_suppression_et_references() -> void:
	var session := _production_session()
	var room := session.current_room()
	var initial_count := room.waves.size()
	var added := session.add_wave(true, false)
	assert_not_null(added)
	assert_eq(room.waves.size(), initial_count + 1)
	assert_ne(added.encounter_definition, room.waves[initial_count - 1].encounter_definition)
	var duplicated := session.duplicate_current_wave(true)
	assert_not_null(duplicated)
	assert_ne(duplicated.encounter_definition, added.encounter_definition)
	var duplicated_reference := duplicated.encounter_definition
	assert_true(session.move_current_wave(-1))
	assert_eq(session.current_wave().encounter_definition, duplicated_reference)
	assert_true(session.remove_current_wave())
	assert_eq(room.waves.size(), initial_count + 1)
	assert_true(session.is_dirty())


func test_studio_fallback_undo_redo_et_registre_des_formations() -> void:
	var studio := EncounterStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	assert_true(studio.open_run(RUN_PATH))
	var encounter := studio.session.current_encounter()
	var before := encounter.living_enemy_cap
	studio._set_property(encounter, &"living_enemy_cap", before + 1, "Test Undo")
	assert_eq(encounter.living_enemy_cap, before + 1)
	studio._undo()
	assert_eq(encounter.living_enemy_cap, before)
	studio._redo()
	assert_eq(encounter.living_enemy_cap, before + 1)
	for formation_id in EncounterDefinition.FORMATION_IDS:
		assert_true(
			EncounterStudioMain.FORMATION_LABELS.has(formation_id), str(formation_id)
		)


func test_validation_structurelle_couvre_erreurs_et_avertissements_v1() -> void:
	var session := _session_for_run(_small_run())
	var encounter := session.current_encounter()
	encounter.roster_units.clear()
	encounter.roster_counts = PackedInt32Array()
	var codes := _validation_codes(session)
	assert_true(codes.has(&"roster_empty"))

	var unit := _unit(&"validation", &"role_non_specialise")
	encounter.roster_units = [unit, unit]
	encounter.roster_counts = PackedInt32Array([0])
	encounter.living_enemy_cap = 0
	encounter.formation_profiles = [&"formation_inconnue"]
	encounter.room_index = 99
	encounter.forbidden_initial_spawn_cells = [Vector2i(50, 50)]
	encounter.shared_normal_summon_budget = 2
	codes = _validation_codes(session)
	for expected in [
		&"roster_parallel_mismatch", &"quantity_invalid", &"unit_duplicate",
		&"formation_unknown", &"forbidden_cell_outside", &"room_index_mismatch",
		&"normal_budget_without_ability", &"role_unknown",
	]:
		assert_true(codes.has(expected), str(expected))

	var summon := Spell.new()
	summon.spell_id = &"summon_fixture"
	summon.delayed_resolution = Spell.DelayedResolution.SUMMON
	summon.summon_type = &"normal"
	unit.spells = [summon]
	encounter.roster_units = [unit]
	encounter.roster_counts = PackedInt32Array([2])
	encounter.living_enemy_cap = 1
	encounter.formation_profiles = [&"line"]
	encounter.room_index = 1
	encounter.forbidden_initial_spawn_cells.clear()
	encounter.shared_normal_summon_budget = 0
	codes = _validation_codes(session)
	assert_true(codes.has(&"living_cap_too_low"))
	assert_true(codes.has(&"ability_without_budget"))

	session.working_run.rooms[0].waves[0].wave_name = ""
	session.working_run.rooms[0].waves[0].enemy_health_multiplier = 0.0
	codes = _validation_codes(session)
	assert_true(codes.has(&"wave_name_empty"))
	assert_true(codes.has(&"health_multiplier_invalid"))


func test_semantique_placement_preferee_interdite_minimum_strict_maximum_souple() -> void:
	var unit := _unit(&"placement", &"fixture_role")
	var encounter := _encounter(unit, 2)
	encounter.minimum_path_distance_by_role = {}
	encounter.maximum_path_distance_by_role = {&"fixture_role": 0}
	var room := _small_room(encounter)
	room.enemy_spawn_zone = [Vector2i(7, 7)]
	var preview := EncounterPreviewService.generate(room, encounter, 1234, 0, 0)
	assert_true(preview.valid, str(preview.reason))
	assert_eq(preview.placements.size(), 2)
	assert_gt(preview.outside_preferred_count, 0)
	var pathfinder := Pathfinder.new(preview.grid)
	for entry in preview.placements:
		assert_eq(
			entry.distance_to_ally_deployment,
			EncounterPreviewService.minimum_path_distance(
				pathfinder, entry.cell, room.hero_spawn_zone
			)
		)

	encounter.forbidden_initial_spawn_cells = [Vector2i(7, 7)]
	preview = EncounterPreviewService.generate(room, encounter, 1234, 0, 0)
	assert_true(preview.valid, str(preview.reason))
	assert_false(preview.placements.any(func(entry):
		return entry.cell == Vector2i(7, 7)
	))

	encounter.minimum_path_distance_by_role = {&"fixture_role": 30}
	preview = EncounterPreviewService.generate(room, encounter, 1234, 0, 0)
	assert_false(preview.valid)
	encounter.minimum_path_distance_by_role = {}
	encounter.maximum_path_distance_by_role = {&"fixture_role": 0}
	preview = EncounterPreviewService.generate(room, encounter, 1234, 0, 0)
	assert_true(preview.valid, "La distance maximale est une preference souple.")


func test_placement_deterministe_seeds_variables_et_rng_global_intact() -> void:
	var encounter := _encounter(_unit(&"rng", &"fixture_role"), 3)
	encounter.minimum_path_distance_by_role = {}
	encounter.maximum_path_distance_by_role = {}
	encounter.formation_profiles = EncounterDefinition.FORMATION_IDS.duplicate()
	var room := _small_room(encounter)
	var first := EncounterPreviewService.serializable(
		EncounterPreviewService.generate(room, encounter, 777, 0, 2)
	)
	var second := EncounterPreviewService.serializable(
		EncounterPreviewService.generate(room, encounter, 777, 0, 2)
	)
	assert_eq(first, second)
	var signatures := {}
	for run_seed in range(20):
		var result := EncounterPreviewService.generate(room, encounter, run_seed, 0, 2)
		signatures["%s:%s" % [result.formation_id, result.placements]] = true
	assert_gt(signatures.size(), 1)

	seed(42)
	var expected_first := randi()
	var expected_second := randi()
	seed(42)
	var actual_first := randi()
	EncounterPreviewService.generate(room, encounter, 999, 0, 0)
	var actual_second := randi()
	assert_eq(actual_first, expected_first)
	assert_eq(actual_second, expected_second)


func test_analyse_100_seeds_deterministe_agregee_annulable_et_immutable() -> void:
	var room := load(ROOM_PATH) as RoomData
	var encounter := room.get_encounter_for_wave(0)
	var source_snapshot := EncounterCopyService.encounter_snapshot(encounter)
	var first_service := EncounterSeedAnalysisService.new()
	var first := await first_service.analyze(room, encounter, 500, 100, 0, 0, 25)
	var second := await EncounterSeedAnalysisService.new().analyze(
		room, encounter, 500, 100, 0, 0, 25
	)
	assert_eq(first, second)
	assert_eq(first.completed, 100)
	assert_eq(first.successes + first.failures, 100)
	assert_true(first.has("failure_reasons"))
	assert_true(first.has("formations"))
	assert_true(first.has("cell_frequency"))
	assert_eq(EncounterCopyService.encounter_snapshot(encounter), source_snapshot)

	var cancellable := EncounterSeedAnalysisService.new()
	cancellable.progress_changed.connect(func(completed, _total, _generation):
		if completed >= 10:
			cancellable.cancel()
	)
	var cancelled := await cancellable.analyze(room, encounter, 0, 1000, 0, 0, 5)
	assert_true(cancelled.cancelled)
	assert_lt(cancelled.completed, 1000)
	assert_eq(EncounterCopyService.encounter_snapshot(encounter), source_snapshot)


func test_projection_run_parite_game_manager_bornes_plafond_et_pas_de_duree() -> void:
	var run := load(RUN_PATH) as RunData
	for run_seed in [0, 1, 42, 1337, 987654]:
		GameManager.cleanup_run_state()
		GameManager.rooms = run.rooms.duplicate()
		GameManager.run_seed = run_seed
		GameManager._maximum_waves_per_room = maxi(1, run.maximum_waves_per_room)
		GameManager._build_hidden_room_wave_counts(run)
		assert_eq(
			GameManager._room_wave_counts,
			RunWaveCountResolver.resolve_counts(run, run_seed),
			"seed %d" % run_seed
		)
	GameManager.cleanup_run_state()
	var projection := EncounterRunProjectionService.project(run, 100, 100)
	assert_gte(projection.observed_minimum, projection.theoretical_minimum)
	assert_lte(projection.observed_maximum, projection.theoretical_maximum)
	assert_eq(projection.seed_count, 100)
	assert_true("NON ESTIMEE" in projection.duration_status)
	assert_false(projection.has("estimated_duration"))


func test_sauvegarde_enfants_parents_rechargement_recuperation_et_chemins_surs() -> void:
	var fixture := _create_user_hierarchy("save_ok")
	var source_run := ResourceLoader.load(
		fixture.run_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData
	var session := EncounterEditSession.new()
	assert_true(session.open(source_run, fixture.run_path))
	var independent := session.duplicate_current_encounter()
	var encounter_path: String = fixture.root.path_join("independent_encounter.tres")
	session.new_resource_paths[independent] = encounter_path
	independent.living_enemy_cap += 1
	session.mark_dirty(independent)
	session.mark_dirty(session.current_room())
	var result := EncounterSaveService.save(session)
	assert_true(result.ok, str(result))
	assert_true(result.saved_paths.has(encounter_path))
	assert_true(result.saved_paths.has(fixture.room_path))
	for path in result.saved_paths:
		assert_true(
			str(path).begins_with("res://") or str(path).begins_with("user://")
		)
	var reloaded := ResourceLoader.load(
		fixture.room_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RoomData
	assert_eq(reloaded.waves[0].encounter_definition.resource_path, encounter_path)
	assert_eq(
		reloaded.waves[0].encounter_definition.living_enemy_cap,
		independent.living_enemy_cap
	)

	var failed_fixture := _create_user_hierarchy("save_failure")
	var failed_source := ResourceLoader.load(
		failed_fixture.run_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData
	var failed_session := EncounterEditSession.new()
	assert_true(failed_session.open(failed_source, failed_fixture.run_path))
	var unsafe := failed_session.duplicate_current_encounter()
	failed_session.new_resource_paths[unsafe] = "C:/outside_encounter.tres"
	failed_session.mark_dirty(failed_session.current_room())
	var failed := EncounterSaveService.save(failed_session)
	assert_false(failed.ok)
	assert_eq(failed.error, "unsafe_or_missing_path")
	assert_true(FileAccess.file_exists(EncounterSaveService.latest_recovery_path()))
	var restored_session := EncounterEditSession.new()
	var restored := EncounterSaveService.restore_latest(restored_session)
	assert_true(restored.ok, str(restored))
	assert_eq(restored_session.source_run_path, failed_fixture.run_path)
	assert_true(restored_session.is_dirty())
	assert_eq(restored_session.current_encounter().living_enemy_cap, unsafe.living_enemy_cap)


func test_migration_historique_explicite_preserve_source_et_comportement() -> void:
	var enemy := _unit(&"legacy", &"")
	var source_room := _small_room(_encounter(enemy, 1))
	source_room.waves.clear()
	source_room.encounter_definition = null
	source_room.enemies = [enemy, enemy]
	var run := RunData.new()
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.rooms = [source_room]
	var session := _session_for_run(run)
	assert_eq(session.room_mode(), &"legacy_enemies")
	var preview := EncounterMigrationService.preview(session.current_room(), 0)
	assert_true(preview.available)
	assert_eq(preview.enemy_count_before, 2)
	var report := EncounterMigrationService.migrate_working_room(
		session.current_room(), 0
	)
	assert_true(report.success)
	assert_eq(session.current_room().waves.size(), 1)
	assert_eq(session.current_encounter().get_initial_enemy_count(), 2)
	assert_eq(session.current_room().enemies.size(), 2)
	assert_true(source_room.waves.is_empty())
	assert_eq(source_room.enemies.size(), 2)


func test_pont_test_direct_prepare_copie_temporaire_sans_muter_canonique() -> void:
	var session := _production_session()
	var canonical := session.source_encounter()
	var before := EncounterCopyService.encounter_snapshot(canonical)
	session.current_encounter().living_enemy_cap += 1
	var result := EncounterTestLauncher.prepare_and_launch(session, null, 2468)
	assert_false(result.ok)
	assert_eq(result.error, "editor_play_api_missing")
	var request := result.request as Dictionary
	assert_true(FileAccess.file_exists(request.run_path))
	assert_true(FileAccess.file_exists(request.result_path.get_base_dir().path_join("encounter.tres")))
	var temp_run := ResourceLoader.load(
		request.run_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData
	assert_eq(
		temp_run.rooms[0].waves[0].encounter_definition.living_enemy_cap,
		session.current_encounter().living_enemy_cap
	)
	assert_eq(EncounterCopyService.encounter_snapshot(canonical), before)
	assert_true(str(request.run_path).begins_with(EncounterTestLauncher.ROOT + "/"))
	assert_true(EncounterTestLauncher.cleanup_context(request))
	assert_false(FileAccess.file_exists(request.run_path))


func test_plugin_coquille_activation_etat_affichage_fermeture_sans_signaux_doubles() -> void:
	var studio := DungeonDraftStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	assert_not_null(studio.tabs)
	assert_eq(studio.tabs.get_tab_count(), 4)
	assert_eq(studio.tabs.get_child(0).name, StringName("Arenes"))
	assert_eq(studio.tabs.get_child(1).name, StringName("Rencontres"))
	assert_eq(studio.tabs.get_child(2).name, StringName("Objets"))
	assert_eq(studio.tabs.get_child(3).name, StringName("VFX"))
	assert_not_null(studio.encounter_studio)
	assert_not_null(studio.arena_studio)
	assert_not_null(studio.item_studio)
	assert_not_null(studio.vfx_composer)
	var state := studio.get_state_snapshot()
	state.tab = 1
	studio.apply_state_snapshot(state)
	assert_eq(studio.tabs.current_tab, 1)
	studio.hide()
	assert_false(studio.visible)
	studio.show()
	assert_true(studio.visible)
	var plugin_source := FileAccess.get_file_as_string(
		"res://addons/dungeon_draft_arena_studio/arena_studio_plugin.gd"
	)
	for method in ["_enter_tree", "_exit_tree", "_make_visible", "_get_state", "_set_state"]:
		assert_true(method in plugin_source, method)
	assert_true(FileAccess.file_exists("res://tools/arena_map_editor/ArenaMapEditor.tscn"))


func test_rapport_markdown_json_contient_contexte_verdict_et_validation() -> void:
	var session := _production_session()
	var preview := EncounterPreviewService.generate(
		session.current_room(), session.current_encounter(), 1337, 0, 0
	)
	session.validation_messages = EncounterValidationService.validate_session(
		session, 1337
	)
	var result := EncounterReportExporter.export_report(
		session, preview, {}, {"victory": true}
	)
	assert_true(result.ok, str(result))
	assert_true(FileAccess.file_exists(result.markdown_path))
	assert_true(FileAccess.file_exists(result.json_path))
	var markdown := FileAccess.get_file_as_string(result.markdown_path)
	for expected in ["Run", "Salle", "Affrontement", "Seed", "Validation", "Verdict"]:
		assert_true(expected in markdown, expected)


func _production_session() -> EncounterEditSession:
	return _session_for_run(ResourceLoader.load(
		RUN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData, RUN_PATH)


func _session_for_run(run: RunData, path := "") -> EncounterEditSession:
	var session := EncounterEditSession.new()
	assert_true(session.open(run, path))
	return session


func _unit(id: StringName, role: StringName) -> UnitData:
	var unit := UnitData.new()
	unit.unit_id = id
	unit.unit_name = str(id)
	unit.team = 1
	unit.tactical_role_id = role
	unit.max_hp = 10
	unit.attack_power = 3
	return unit


func _encounter(unit: UnitData, count: int) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.room_index = 1
	encounter.roster_units = [unit]
	encounter.roster_counts = PackedInt32Array([count])
	encounter.living_enemy_cap = count
	encounter.formation_profiles = [&"line"]
	return encounter


func _small_room(encounter: EncounterDefinition) -> RoomData:
	var layout := RoomGridLayout.new()
	layout.layout_id = &"encounter_studio_fixture"
	layout.logical_size = Vector2i(8, 8)
	layout.layout_rows = PackedStringArray([
		"........", "........", "........", "........",
		"........", "........", "........", "........",
	])
	var wave := RoomWaveData.new()
	wave.wave_name = "Affrontement fixture"
	wave.encounter_definition = encounter
	var room := RoomData.new()
	room.room_name = "Salle fixture"
	room.grid_layout = layout
	room.hero_spawn_zone = [Vector2i(0, 0), Vector2i(0, 1)]
	room.enemy_spawn_zone = [Vector2i(7, 7), Vector2i(7, 6)]
	room.waves = [wave]
	room.encounter_definition = encounter
	room.minimum_wave_count = 1
	room.maximum_wave_count = 1
	return room


func _small_run() -> RunData:
	var run := RunData.new()
	run.run_name = "Run fixture Encounter Studio"
	run.default_seed = 1337
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 1
	run.rooms = [_small_room(_encounter(_unit(&"fixture", &""), 1))]
	return run


func _validation_codes(session: EncounterEditSession) -> Array:
	return EncounterValidationService.validate_session(session, 1337).map(
		func(message): return message.code
	)


func _create_user_hierarchy(label: String) -> Dictionary:
	var root := USER_FIXTURE_ROOT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var production_room := load(ROOM_PATH) as RoomData
	var room := EncounterCopyService.copy_room(production_room)
	room.waves = [room.waves[0]]
	room.minimum_wave_count = 1
	room.maximum_wave_count = 1
	var encounter := room.waves[0].encounter_definition
	var encounter_path := root.path_join("source_encounter.tres")
	assert_eq(ResourceSaver.save(encounter, encounter_path), OK)
	encounter = ResourceLoader.load(
		encounter_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EncounterDefinition
	room.encounter_definition = encounter
	room.waves[0].encounter_definition = encounter
	var room_path := root.path_join("source_room.tres")
	assert_eq(ResourceSaver.save(room, room_path), OK)
	var run := RunData.new()
	run.run_name = "Fixture sauvegarde"
	run.default_seed = 1337
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 1
	run.rooms = [ResourceLoader.load(
		room_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RoomData]
	var run_path := root.path_join("source_run.tres")
	assert_eq(ResourceSaver.save(run, run_path), OK)
	return {
		"root": root,
		"encounter_path": encounter_path,
		"room_path": room_path,
		"run_path": run_path,
	}
