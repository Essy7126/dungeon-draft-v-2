extends GutTest

## Frontière RoomIntegrationFieldPolicy à l'intégration finale.
##
## Deux intentions coexistent, et seule la seconde publie les affrontements du
## brouillon. Elle n'est jamais déduite : sans le drapeau explicite, le
## comportement historique « mettre à jour le terrain en conservant le gameplay
## du disque » reste identique, y compris ses vérifications.

const ROOT := "res://artifacts/room_draft_publication"
const MAIN_ROOM_PATH := "res://data/rooms/first_run_room_01.tres"


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))


func _directory(name: String) -> String:
	var path := ROOT.path_join(name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	return path


func _enemy() -> UnitData:
	for unit in StudioResourceCatalog.load_enemy_units():
		if unit != null:
			return unit
	return null


func _encounter(cap: int, forbidden: Vector2i) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	# Une rencontre sans roster est invalide pour RunData : la fixture doit
	# rester publiable pour que la vérification finale porte sur le gameplay.
	var unit := _enemy()
	if unit != null:
		encounter.roster_units = [unit]
		encounter.roster_counts = PackedInt32Array([1])
	encounter.living_enemy_cap = cap
	encounter.forbidden_initial_spawn_cells = [forbidden]
	return encounter


## Salle canonique de destination, avec son gameplay propre déjà sur disque.
func _target_room(path: String) -> RoomData:
	var room := RoomData.new()
	room.room_name = "Salle de destination"
	room.encounter_definition = _encounter(3, Vector2i(1, 1))
	# `enemies` est une projection du roster : une salle canonique cohérente la
	# porte déjà, sinon la vérification de préservation la verrait changer.
	room.enemies = room.encounter_definition.expanded_roster()
	room.minimum_wave_count = 1
	room.maximum_wave_count = 1
	assert_eq(ResourceSaver.save(room, path), OK)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RoomData


## Brouillon produit : un terrain complet et publiable (fond, calibration,
## zone héros — via `prepare_automatically`, comme le ferait le Studio), avec un
## gameplay différent de celui du disque, comme après un passage dans Rencontres.
func _produced_draft(path: String) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Brouillon publiable", "brouillon_publiable")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.grid_size = Vector2i(8, 8)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32.0, 16.0)
	arena.axis_y = Vector2(-32.0, 16.0)
	for y in arena.grid_size.y:
		for x in arena.grid_size.x:
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(arena)
	arena.encounter_definition = _encounter(9, Vector2i(4, 4))
	arena.minimum_wave_count = 1
	arena.maximum_wave_count = 2
	var wave := RoomWaveData.new()
	wave.wave_name = "Affrontement du brouillon"
	wave.encounter_definition = _encounter(5, Vector2i(2, 2))
	var second_wave := RoomWaveData.new()
	second_wave.wave_name = "Deuxième affrontement du brouillon"
	second_wave.encounter_definition = _encounter(7, Vector2i(3, 3))
	second_wave.reward_multiplier = 1.5
	arena.waves = [wave, second_wave]
	arena.enemies = arena.encounter_definition.expanded_roster()
	assert_eq(ResourceSaver.save(arena, path), OK)
	return ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition


func _run_fixture(room: RoomData, path: String) -> RunData:
	var run := RunData.new()
	run.run_name = "Partie de publication"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 4
	run.rooms = [room]
	assert_eq(ResourceSaver.save(run, path), OK)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunData


## Preuve synthétique limitée à cette fixture unitaire : elle satisfait le
## contrat attendu par la porte de qualité (gate) sans prétendre qu'un boot E2E
## de la scène de bataille a été exécuté par ce test. Même fixture que
## test_room_integration_guided_pipeline.gd, pour rester comparable.
func _proof(arena: ArenaDefinition) -> Dictionary:
	var fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var topology: Dictionary = ArenaTopologySignatureService.build(arena)
	var topology_hash := str(topology.get("topology_hash", ""))
	var battle_scene_path := arena.battle_scene.resource_path \
		if arena != null and arena.battle_scene != null else ""
	return {
		"ok": true,
		"proof_kind": "UNIT_FIXTURE_CONTRACT_PROOF",
		"fixture_only": true,
		"e2e_boot_performed": false,
		"runtime_scene_inspected": true,
		"script_parse_ok": true,
		"scene_instantiated": true,
		"runtime_ready": true,
		"grid_ready": true,
		"pathfinder_ready": true,
		"render_ready": true,
		"spawn_ready": true,
		"cleanup_ok": true,
		"produced_bundle_loaded": false,
		"configuration": "UNIT_FIXTURE_CONTRACT",
		"expected_battle_scene_path": battle_scene_path,
		"battle_scene_path": battle_scene_path,
		"working_fingerprint": fingerprint,
		"temporary_fingerprint": fingerprint,
		"runtime_fingerprint": fingerprint,
		"fingerprints_identical": true,
		"working_topology_hash": topology_hash,
		"temporary_topology_hash": topology_hash,
		"runtime_topology_hash": topology_hash,
		"topology_hashes_identical": true,
	}


## --- Comportement historique, strictement inchangé --------------------------

func test_update_without_explicit_intent_keeps_disk_gameplay() -> void:
	var directory := _directory("keep_disk_gameplay")
	var room_path := directory.path_join("room.tres")
	var arena_path := directory.path_join("arena.tres")
	var run_path := directory.path_join("run.tres")
	var target := _target_room(room_path)
	var produced := _produced_draft(arena_path)
	var run := _run_fixture(target, run_path)
	var gameplay_before := RoomIntegrationFieldPolicy.signature(
		target, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)

	var planned := ArenaProductionAttachmentService.plan(
		run, ArenaProductionAttachmentService.UPDATE, 0, arena_path
	)
	assert_true(bool(planned.get("ok", false)), str(planned.get("error", "")))
	assert_true(bool(planned.get("preserves_gameplay", false)))
	assert_false(bool(planned.get("publish_draft_gameplay", true)),
		"L'intention de publication ne doit jamais être déduite.")

	var attachment := ArenaProductionAttachmentService.attach_and_save(
		arena_path, run, ArenaProductionAttachmentService.UPDATE, 0
	)
	assert_true(bool(attachment.get("ok", false)), str(attachment.get("error", "")))
	assert_true(bool(attachment.get("preserved_gameplay", false)))
	var reloaded := ResourceLoader.load(
		room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RoomData
	assert_eq(
		RoomIntegrationFieldPolicy.signature(
			reloaded, RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		),
		gameplay_before,
		"Sans intention explicite, le gameplay du disque doit être conservé."
	)
	assert_eq(reloaded.encounter_definition.living_enemy_cap, 3)
	assert_true(reloaded.waves.is_empty())
	# Le terrain, lui, a bien été mis à jour.
	assert_eq((reloaded as ArenaDefinition).grid_size, Vector2i(8, 8))


## --- Intention explicite ----------------------------------------------------

func test_explicit_intent_publishes_the_complete_room_after_a_cacheless_reload() -> void:
	var directory := _directory("publish_draft_gameplay")
	var room_path := directory.path_join("room.tres")
	var arena_path := directory.path_join("arena.tres")
	var run_path := directory.path_join("run.tres")
	var target := _target_room(room_path)
	var produced := _produced_draft(arena_path)
	var run := _run_fixture(target, run_path)

	var planned := ArenaProductionAttachmentService.plan(
		run, ArenaProductionAttachmentService.UPDATE, 0, arena_path, null,
		{"publish_draft_gameplay": true}
	)
	assert_true(bool(planned.get("ok", false)), str(planned.get("error", "")))
	assert_true(bool(planned.get("publish_draft_gameplay", false)))
	assert_false(bool(planned.get("preserves_gameplay", true)),
		"Publier le brouillon ne préserve volontairement plus le gameplay du disque.")

	var attachment := ArenaProductionAttachmentService.attach_and_save(
		arena_path, run, ArenaProductionAttachmentService.UPDATE, 0, null,
		{"publish_draft_gameplay": true}
	)
	assert_true(bool(attachment.get("ok", false)), str(attachment.get("error", "")))
	assert_true(bool(attachment.get("published_draft_gameplay", false)))
	assert_false(bool(attachment.get("preserved_gameplay", true)))

	# Relecture sans cache : terrain, ennemis, vagues, récompenses et index.
	var reloaded_run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	assert_eq(reloaded_run.rooms.size(), 1)
	var reloaded := reloaded_run.rooms[0]
	assert_eq(reloaded.resource_path, room_path, "L'index de la salle est conservé.")
	assert_eq((reloaded as ArenaDefinition).grid_size, Vector2i(8, 8))
	assert_eq(reloaded.encounter_definition.living_enemy_cap, 9,
		"Les ennemis du brouillon doivent être publiés.")
	assert_eq(reloaded.waves.size(), 2, "Les vagues du brouillon doivent être publiées.")
	assert_eq(reloaded.waves[0].wave_name, "Affrontement du brouillon")
	assert_eq(reloaded.waves[0].encounter_definition.living_enemy_cap, 5)
	assert_eq(reloaded.waves[1].encounter_definition.living_enemy_cap, 7)
	assert_eq(reloaded.waves[1].reward_multiplier, 1.5,
		"Les récompenses par vague doivent être publiées.")
	assert_eq(reloaded.maximum_wave_count, 2)
	assert_eq(
		reloaded.encounter_definition.forbidden_initial_spawn_cells,
		[Vector2i(4, 4)] as Array[Vector2i],
		"Les placements du brouillon doivent être publiés."
	)
	# L'identité de la salle dans la partie n'est jamais changée par effet de bord.
	assert_eq(reloaded.room_name, "Salle de destination")
	assert_true(reloaded_run.validation_errors().is_empty(),
		str(reloaded_run.validation_errors()))


## --- Échec injecté après chaque phase d'écriture : rollback exact ----------
##
## Limite comblée : je disais ne pas avoir prouvé que « ça plante en cours
## d'écriture » se rattrape aussi pour l'intention « publier le brouillon ».
## Ces deux tests simulent une panne juste avant, puis juste après, l'écriture
## de la salle, et vérifient que rien de canonique ne reste modifié.

func test_publish_draft_gameplay_failure_before_attachment_leaves_everything_untouched() -> void:
	var directory := _directory("publish_failure_before")
	var room_path := directory.path_join("room.tres")
	var arena_path := directory.path_join("arena.tres")
	var run_path := directory.path_join("run.tres")
	var target := _target_room(room_path)
	var draft := _produced_draft(arena_path)
	var run := _run_fixture(target, run_path)
	var run_before := FileAccess.get_sha256(run_path)
	var room_before := FileAccess.get_sha256(room_path)
	var gameplay_before := RoomIntegrationFieldPolicy.signature(
		ResourceLoader.load(room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)
	var production_destination := directory.path_join("production")

	var result := ArenaIntegrationService.integrate_with_options(
		draft,
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE, 0, production_destination,
		null, {}, {
			"failure_step": "before_attachment",
			"gate_options": {
				"publish_draft_gameplay": true,
				"runtime_scene_result": _proof(draft),
			},
		}
	)
	assert_false(bool(result.get("ok", false)), str(result))
	assert_eq(str(result.get("status", "")), "INTEGRATION_ROLLED_BACK", str(result.get("error", "")))
	assert_true(bool((result.get("production_rollback", {}) as Dictionary).get("ok", false)))
	assert_false(DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(production_destination)
	), "Le dossier de production échoué ne doit laisser aucune trace.")
	# Rien de canonique n'a bougé : ni la partie, ni la salle, ni son gameplay.
	assert_eq(FileAccess.get_sha256(run_path), run_before)
	assert_eq(FileAccess.get_sha256(room_path), room_before)
	assert_eq(
		RoomIntegrationFieldPolicy.signature(
			ResourceLoader.load(room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
			RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		),
		gameplay_before,
		"Un échec avant l'écriture ne doit jamais laisser passer le gameplay du brouillon."
	)


func test_publish_draft_gameplay_failure_after_attachment_restores_room_and_run() -> void:
	var directory := _directory("publish_failure_after")
	var room_path := directory.path_join("room.tres")
	var arena_path := directory.path_join("arena.tres")
	var run_path := directory.path_join("run.tres")
	var target := _target_room(room_path)
	var draft := _produced_draft(arena_path)
	var run := _run_fixture(target, run_path)
	var run_before := FileAccess.get_sha256(run_path)
	var room_before := FileAccess.get_sha256(room_path)
	var gameplay_before := RoomIntegrationFieldPolicy.signature(
		ResourceLoader.load(room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
	)
	var production_destination := directory.path_join("production")

	var result := ArenaIntegrationService.integrate_with_options(
		draft,
		ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		ArenaProductionAttachmentService.UPDATE, 0, production_destination,
		null, {}, {
			"failure_step": "after_attachment",
			"gate_options": {
				"publish_draft_gameplay": true,
				"runtime_scene_result": _proof(draft),
			},
		}
	)
	assert_false(bool(result.get("ok", false)), str(result))
	assert_eq(str(result.get("status", "")), "INTEGRATION_ROLLED_BACK", str(result.get("error", "")))
	assert_true(bool((result.get("attachment_rollback", {}) as Dictionary).get("ok", false)),
		str(result.get("attachment_rollback", {})))
	assert_true(bool((result.get("production_rollback", {}) as Dictionary).get("ok", false)))
	assert_false(DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(production_destination)
	))
	# La salle a bien été écrite puis restaurée : le disque doit retrouver
	# exactement son contenu et son gameplay d'avant la tentative.
	assert_eq(FileAccess.get_sha256(run_path), run_before)
	assert_eq(FileAccess.get_sha256(room_path), room_before)
	assert_eq(
		RoomIntegrationFieldPolicy.signature(
			ResourceLoader.load(room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
			RoomIntegrationFieldPolicy.GAMEPLAY_OWNED
		),
		gameplay_before,
		"Après rollback, le gameplay du brouillon ne doit pas être resté publié."
	)


## --- Le plan de confirmation dit tout --------------------------------------

func test_publication_summary_states_what_happens_to_existing_gameplay() -> void:
	var directory := _directory("summary")
	var target := _target_room(directory.path_join("room.tres"))
	var draft := _produced_draft(directory.path_join("arena.tres"))

	var kept := RoomIntegrationFieldPolicy.publication_summary(draft, target, false)
	assert_eq(str(kept.get("decision", "")), "Gameplay existant conservé")
	assert_false((kept.get("gameplay_kept") as PackedStringArray).is_empty())
	assert_true((kept.get("gameplay_replaced") as PackedStringArray).is_empty())

	var published := RoomIntegrationFieldPolicy.publication_summary(draft, target, true)
	assert_eq(str(published.get("decision", "")),
		"Gameplay remplacé par celui du brouillon")
	assert_true((published.get("gameplay_kept") as PackedStringArray).is_empty())
	assert_false((published.get("gameplay_replaced") as PackedStringArray).is_empty())
	assert_false((published.get("gameplay_published") as PackedStringArray).is_empty())


func test_plan_lists_the_new_encounters_and_the_shared_ones() -> void:
	var directory := _directory("encounter_plan")
	var draft := _produced_draft(directory.path_join("arena.tres"))
	# Trois rencontres définies dans le brouillon (la salle et ses deux
	# affrontements), aucune encore canonique : ce sont des sous-ressources du
	# document produit, pas des fichiers partagés.
	var report := ArenaIntegrationService.draft_encounter_plan(draft)
	assert_eq((report.get("new_encounters", []) as Array).size(), 3)
	assert_eq((report.get("existing_usages", []) as Array).size(), 0)

	# Une rencontre déjà partagée est annoncée comme telle, pas comme nouvelle.
	var shared_path := directory.path_join("shared_encounter.tres")
	assert_eq(ResourceSaver.save(draft.waves[0].encounter_definition, shared_path), OK)
	draft.waves[0].encounter_definition = ResourceLoader.load(
		shared_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as EncounterDefinition
	var second := ArenaIntegrationService.draft_encounter_plan(draft)
	assert_eq((second.get("new_encounters", []) as Array).size(), 2)
	assert_eq((second.get("existing_usages", []) as Array).size(), 1)
	assert_eq(
		str(((second.get("existing_usages", []) as Array)[0] as Dictionary).get("path", "")),
		shared_path
	)


## --- Aucune intention silencieuse ------------------------------------------

func test_intent_defaults_to_false_in_the_studio_until_the_user_checks_it() -> void:
	var studio := ArenaStudioMain.new()
	studio.auto_load_initial_arena = false
	studio.production_planning_enabled = false
	add_child_autofree(studio)
	await wait_process_frames(2)
	assert_not_null(studio.publish_draft_gameplay_check)
	assert_false(studio.publish_draft_gameplay_check.button_pressed,
		"L'intention doit être décochée par défaut.")
	assert_false(studio.publish_draft_gameplay_requested())
	studio.publish_draft_gameplay_check.button_pressed = true
	assert_true(studio.publish_draft_gameplay_requested())
	studio._create_with_tiles()
	var options := studio._integration_gate_options(
		studio.arena, null, ArenaProductionAttachmentService.UPDATE, 0
	)
	assert_true(bool(options.get("publish_draft_gameplay", false)),
		"L'intention cochée doit atteindre le service d'intégration.")


func test_non_update_actions_never_carry_the_draft_publication_intent() -> void:
	var directory := _directory("non_update")
	var room_path := directory.path_join("room.tres")
	var arena_path := directory.path_join("arena.tres")
	var target := _target_room(room_path)
	_produced_draft(arena_path)
	var run := _run_fixture(target, directory.path_join("run.tres"))
	for action in [
		ArenaProductionAttachmentService.APPEND,
		ArenaProductionAttachmentService.INSERT_AFTER,
		ArenaProductionAttachmentService.REPLACE,
	]:
		var planned := ArenaProductionAttachmentService.plan(
			run, action, 0, arena_path, null, {"publish_draft_gameplay": true}
		)
		assert_true(bool(planned.get("ok", false)), str(planned.get("error", "")))
		assert_false(bool(planned.get("publish_draft_gameplay", true)),
			"%s publie déjà le document complet : l'option n'a pas de sens." % action)
