extends GutTest

## Parcours « Créer le terrain → Créer les combats de la salle → définir
## ennemis, vagues et placements sur le brouillon → tester → intégrer ».
##
## L'autorité vérifiée ici est celle de RoomDraftAuthority : la working copy
## ArenaDefinition de Terrain porte les deux moitiés du brouillon. Ces tests
## prouvent qu'ouvrir Rencontres n'écrit rien de canonique et que les deux
## domaines conservent leur travail et leur historique.

const ODYSSEY_RUN := "res://data/runs/odyssey.tres"
const ENCOUNTER_ROOT := "res://data/encounters"


func _workspace(run_path := ODYSSEY_RUN, room_index := 1) -> StudioWorkspace:
	var context := StudioProjectContext.new()
	assert_true(context.request_selection({
		"run": load(run_path), "room_index": room_index,
	}).ok)
	var workspace := StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, StudioReferenceGraphService.new())
	add_child_autofree(workspace)
	await wait_process_frames(2)
	return workspace


## Terrain non publié : un terrain créé de toutes pièces, jamais écrit sur
## disque et absent de toute RunData.
func _unpublished_terrain(workspace: StudioWorkspace) -> ArenaStudioMain:
	var terrain := workspace.arena_studio
	workspace.tabs.current_tab = 0
	# « Agrandir le terrain » masque volontairement l'en-tête : la vérification
	# des actions principales se fait dans la disposition normale.
	terrain.set_focus_map(false)
	terrain._create_with_tiles()
	terrain.show_editor()
	# Un terrain jouable a des zones de déploiement : sans elles, le brouillon
	# resterait volontairement non testable.
	var playable := terrain.arena.playable_cells()
	if playable.size() >= 4:
		ArenaDynamicEditingService.place_spawn(
			terrain.arena, playable[0], ArenaSpawnDefinition.Kind.HERO_1, false
		)
		ArenaDynamicEditingService.place_spawn(
			terrain.arena, playable[1], ArenaSpawnDefinition.Kind.HERO_2, false
		)
		ArenaDynamicEditingService.place_spawn(
			terrain.arena, playable[-1], ArenaSpawnDefinition.Kind.ENEMY, false
		)
	assert_true(terrain.arena.resource_path.is_empty(),
		"Le terrain de test doit rester non publié.")
	return terrain


func _canonical_snapshot() -> Dictionary:
	var result := {}
	var run := load(ODYSSEY_RUN) as RunData
	result[ODYSSEY_RUN] = FileAccess.get_sha256(ODYSSEY_RUN)
	for room in run.rooms:
		if room != null and not room.resource_path.is_empty():
			result[room.resource_path] = FileAccess.get_sha256(room.resource_path)
			if room.encounter_definition != null \
					and not room.encounter_definition.resource_path.is_empty():
				result[room.encounter_definition.resource_path] = FileAccess.get_sha256(
					room.encounter_definition.resource_path
				)
	return result


func _encounter_directory_listing() -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(ENCOUNTER_ROOT)
	if directory != null:
		for file_name in directory.get_files():
			result.append(file_name)
	result.sort()
	return result


func _enemy_units(count: int) -> Array[UnitData]:
	var result: Array[UnitData] = []
	for unit in StudioResourceCatalog.load_enemy_units():
		if unit != null and not result.has(unit):
			result.append(unit)
		if result.size() >= count:
			break
	return result


## --- Isolation --------------------------------------------------------------

func test_creating_room_encounters_writes_nothing_canonical_and_opens_the_draft() -> void:
	var workspace := await _workspace()
	var context := workspace.project_context
	var terrain := _unpublished_terrain(workspace)
	var run := context.active_run
	var rooms_before := run.rooms.duplicate()
	var hashes_before := _canonical_snapshot()
	var encounters_before := _encounter_directory_listing()
	var run_stable_before: Variant = RoomIntegrationFieldPolicy.stable_value(run)

	watch_signals(terrain)
	# Dans le vrai StudioWorkspace, l'en-tête Terrain est masqué : l'action
	# visible est celle de la barre partagée du Studio.
	assert_true(workspace.create_encounters_button.is_visible_in_tree(),
		"L'action principale doit être visible dans la barre du Studio.")
	assert_true(
		RoomDraftAuthority.ENCOUNTERS_ACTION_LABELS.has(
			workspace.create_encounters_button.text
		),
		"Libellé inattendu : %s" % workspace.create_encounters_button.text
	)
	assert_eq(workspace.create_encounters_button.tooltip_text,
		RoomDraftAuthority.ENCOUNTERS_ACTION_HELP)
	workspace.create_encounters_button.pressed.emit()
	assert_signal_emit_count(terrain, "domain_navigation_requested", 1)

	# 1 — l'assistant d'intégration ne s'ouvre pas.
	assert_false(terrain.production_dialog.visible,
		"« Créer les combats » ne doit jamais ouvrir l'assistant d'intégration.")
	# 2 — Rencontres est ouvert sur le brouillon courant.
	var encounter := workspace.encounter_studio
	assert_eq(workspace.tabs.current_tab, 1)
	assert_true(encounter.is_room_draft_mode())
	assert_same(encounter.session.draft_room, terrain.arena,
		"Rencontres doit éditer l'instance même du brouillon de Terrain.")
	assert_same(encounter.session.current_room(), terrain.arena)
	# 3 — la run active n'est qu'un contexte de lecture.
	assert_same(encounter.session.context_run, run)
	assert_true(RoomDraftAuthority.is_context_carrier(encounter.session.working_run),
		"Le porteur ne doit jamais avoir de chemin canonique.")
	assert_ne(encounter.session.working_run, run)
	# 4 — RunData.rooms est inchangé.
	assert_eq(run.rooms, rooms_before)
	assert_eq(RoomIntegrationFieldPolicy.stable_value(run), run_stable_before)
	assert_same(context.active_run, run)
	assert_eq(context.active_room_index, 1)
	assert_false(context.has_pending_transition())
	# 5 — aucun fichier canonique modifié, aucune rencontre créée.
	for path in hashes_before:
		assert_eq(FileAccess.get_sha256(path), hashes_before[path], path)
	assert_eq(_encounter_directory_listing(), encounters_before,
		"Aucun fichier ne doit apparaître sous res://data/encounters.")
	# 6 — bannière explicite.
	assert_true(encounter.draft_banner.visible)
	assert_string_contains(encounter.draft_banner.text, RoomDraftAuthority.DRAFT_BANNER)


func test_no_competing_continue_action_remains_in_terrain() -> void:
	var workspace := await _workspace()
	var terrain := _unpublished_terrain(workspace)
	terrain.show_production_wizard()
	await wait_process_frames(1)
	var buttons := workspace.find_children("*", "Button", true, false)
	for label in [
		"Continuer vers Rencontres", "Intégrer et continuer vers Rencontres",
		"Ouvrir Rencontres",
	]:
		for button in buttons:
			assert_ne((button as Button).text, label,
				"Le parcours candidat « %s » ne doit plus exister." % label)
	assert_eq(
		workspace.find_children("ContinueToEncountersButton", "Button", true, false).size(),
		0
	)
	var visible_count := 0
	for button in buttons:
		if RoomDraftAuthority.ENCOUNTERS_ACTION_LABELS.has((button as Button).text) \
				and (button as Button).is_visible_in_tree():
			visible_count += 1
	assert_eq(visible_count, 1,
		"L'action doit apparaître une seule fois dans le parcours nominal Terrain.")
	terrain.production_dialog.hide()


## --- Responsive -------------------------------------------------------------

func test_no_primary_action_is_offscreen_at_both_resolutions() -> void:
	for resolution in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		var workspace := await _workspace()
		_unpublished_terrain(workspace)
		workspace.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		workspace.custom_minimum_size = resolution
		workspace.size = resolution
		await wait_process_frames(3)
		var actions: Array[Button] = []
		for button in [
			workspace.home_button, workspace.save_button, workspace.validate_button,
			workspace.test_button, workspace.create_encounters_button,
			workspace.produce_button,
		]:
			if button != null and button.is_visible_in_tree():
				actions.append(button)
		assert_true(actions.has(workspace.create_encounters_button),
			"L'action principale doit rester atteignable en %d × %d." % [
				int(resolution.x), int(resolution.y),
			])
		for button in actions:
			var rect := button.get_global_rect()
			assert_lte(rect.end.x, resolution.x + 1.0,
				"« %s » sort de l'écran en %d de large." % [
					button.text, int(resolution.x),
				])
			assert_lte(rect.end.y, resolution.y + 1.0,
				"« %s » sort de l'écran en %d de haut." % [
					button.text, int(resolution.y),
				])
		workspace.free()
		await wait_process_frames(1)


## --- Aller-retour complet ---------------------------------------------------

func test_round_trip_keeps_both_domains_and_their_histories() -> void:
	var workspace := await _workspace()
	var terrain := _unpublished_terrain(workspace)
	var encounter := workspace.encounter_studio
	workspace.create_encounters_button.pressed.emit()
	assert_true(encounter.is_room_draft_mode())

	# Ennemis : au moins deux types différents.
	var units := _enemy_units(2)
	assert_eq(units.size(), 2, "Le catalogue doit fournir deux types d'ennemis.")
	if encounter.session.current_encounter() == null:
		encounter.session.set_current_encounter(EncounterDefinition.new())
	for unit in units:
		encounter._add_unit(unit)
	await wait_process_frames(1)
	var roster := encounter.session.current_encounter().roster_units
	assert_eq(roster.size(), 2)
	# Quantités.
	encounter._change_quantity(0, 3)
	await wait_process_frames(1)
	assert_eq(int(encounter.session.current_encounter().roster_counts[0]), 3)
	# Placement : une case interdite.
	encounter._on_forbidden_cell_toggled(Vector2i(1, 1))
	await wait_process_frames(1)
	assert_true(
		encounter.session.current_encounter().forbidden_initial_spawn_cells.has(
			Vector2i(1, 1)
		)
	)
	# Vagues : plusieurs affrontements.
	encounter._add_wave()
	await wait_process_frames(1)
	assert_eq(terrain.arena.waves.size(), 1,
		"La vague ajoutée doit vivre dans le brouillon de Terrain, autorité unique.")

	var gameplay_after_encounters := RoomDraftAuthority.gameplay_fingerprint(terrain.arena)
	var encounter_history_depth := encounter._fallback_undo_redo.get_history_count()

	# Retour dans Terrain et modification spatiale.
	workspace.tabs.current_tab = 0
	await wait_process_frames(1)
	var playable := terrain.arena.playable_cells()
	assert_false(playable.is_empty(), "Le terrain de test doit avoir des cases jouables.")
	var cells_before := playable.size()
	terrain._select_tool_from_palette(ArenaStudioCanvas.Tool.REMOVE_CELL)
	terrain._on_stroke_started("Retirer une case")
	terrain._on_cells_edit_requested([playable[0]], false)
	terrain._on_stroke_finished("Retirer une case")
	await wait_process_frames(1)
	assert_ne(terrain.arena.playable_cells().size(), cells_before,
		"La modification spatiale doit s'appliquer au brouillon.")
	assert_eq(RoomDraftAuthority.gameplay_fingerprint(terrain.arena),
		gameplay_after_encounters,
		"Modifier le terrain ne doit pas toucher aux rencontres du brouillon.")

	# Annuler / Rétablir côté Terrain : les rencontres restent intactes.
	assert_true(terrain.history_undo())
	await wait_process_frames(1)
	assert_eq(RoomDraftAuthority.gameplay_fingerprint(terrain.arena),
		gameplay_after_encounters,
		"Annuler dans Terrain ne doit pas altérer les rencontres.")
	assert_eq(terrain.arena.waves.size(), 1)
	assert_true(terrain.history_redo())
	await wait_process_frames(1)
	assert_eq(RoomDraftAuthority.gameplay_fingerprint(terrain.arena),
		gameplay_after_encounters)

	# Retour dans Rencontres : tout est conservé des deux côtés.
	workspace.tabs.current_tab = 1
	await wait_process_frames(1)
	assert_true(encounter.is_room_draft_mode())
	assert_same(encounter.session.draft_room, terrain.arena)
	assert_eq(encounter.session.current_room().waves.size(), 1)
	assert_eq(encounter._fallback_undo_redo.get_history_count(), encounter_history_depth,
		"L'historique de Rencontres n'est pas touché par celui de Terrain.")


func test_encounter_undo_does_not_touch_terrain() -> void:
	var workspace := await _workspace()
	var terrain := _unpublished_terrain(workspace)
	var encounter := workspace.encounter_studio
	workspace.create_encounters_button.pressed.emit()
	if encounter.session.current_encounter() == null:
		encounter.session.set_current_encounter(EncounterDefinition.new())
	var terrain_fingerprint := ArenaSnapshotService.arena_fingerprint(terrain.arena)
	var terrain_history := terrain.edit_session.history.undo_redo.get_version()
	var units := _enemy_units(1)
	encounter._add_unit(units[0])
	await wait_process_frames(1)
	assert_eq(encounter.session.current_encounter().roster_units.size(), 1)
	assert_true(encounter.history_undo())
	await wait_process_frames(1)
	assert_eq(encounter.session.current_encounter().roster_units.size(), 0)
	assert_eq(ArenaSnapshotService.arena_fingerprint(terrain.arena), terrain_fingerprint,
		"Annuler dans Rencontres ne doit pas modifier le terrain.")
	assert_eq(terrain.edit_session.history.undo_redo.get_version(), terrain_history)


## --- Contexte de partie -----------------------------------------------------

func test_draft_survives_a_context_run_change_used_as_read_only_context() -> void:
	var workspace := await _workspace()
	var terrain := _unpublished_terrain(workspace)
	var encounter := workspace.encounter_studio
	workspace.create_encounters_button.pressed.emit()
	var draft := encounter.session.draft_room
	var other := ResourceLoader.load(
		ODYSSEY_RUN, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	other.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	other.maximum_waves_per_room = 4
	assert_true(encounter.refresh_draft_context(other))
	assert_same(encounter.session.draft_room, draft,
		"Changer de contexte ne remplace jamais l'autorité du brouillon.")
	assert_same(encounter.session.context_run, other)
	assert_true(encounter.session.working_run.uses_wave_chain())
	assert_eq(encounter.session.working_run.maximum_waves_per_room, 4)
	assert_true(RoomDraftAuthority.is_context_carrier(encounter.session.working_run))
	assert_eq(encounter.session.selected_room_index, 0)


func test_context_room_change_never_moves_the_draft_selection() -> void:
	var workspace := await _workspace()
	var context := workspace.project_context
	var terrain := _unpublished_terrain(workspace)
	var encounter := workspace.encounter_studio
	workspace.create_encounters_button.pressed.emit()
	var draft := encounter.session.draft_room
	encounter._on_shared_room_changed(0, context.active_run.rooms[0])
	assert_same(encounter.session.draft_room, draft)
	assert_same(encounter.session.current_room(), draft)
	assert_eq(encounter.session.selected_room_index, 0)


func test_dirty_draft_uses_the_four_explicit_decisions() -> void:
	for action in [
		StudioProjectContext.ACTION_CANCEL,
		StudioProjectContext.ACTION_DRAFT,
		StudioProjectContext.ACTION_DISCARD,
	]:
		var workspace := await _workspace()
		var context := workspace.project_context
		var terrain := _unpublished_terrain(workspace)
		var encounter := workspace.encounter_studio
		workspace.create_encounters_button.pressed.emit()
		if encounter.session.current_encounter() == null:
			encounter.session.set_current_encounter(EncounterDefinition.new())
		encounter._add_unit(_enemy_units(1)[0])
		await wait_process_frames(1)
		assert_true(context.is_dirty(&"encounter"),
			"Le brouillon modifié doit rendre le domaine Rencontres modifié.")
		var requested := context.request_room(0, &"arena")
		assert_false(bool(requested.get("ok", false)))
		assert_true(context.has_pending_transition())
		var resolved := context.resolve_pending_transition(action)
		assert_true(bool(resolved.get("ok", false)), str(action))
		if action == StudioProjectContext.ACTION_CANCEL:
			assert_true(context.is_dirty(&"encounter"))
			assert_eq(encounter.session.current_encounter().roster_units.size(), 1)
		elif action == StudioProjectContext.ACTION_DISCARD:
			assert_false(context.is_dirty(&"encounter"))
			assert_eq(encounter.session.current_room().waves.size(), 0)
		workspace.free()
		await wait_process_frames(1)


func test_opening_a_room_draft_never_overrides_a_pending_transition() -> void:
	var workspace := await _workspace()
	var context := workspace.project_context
	var terrain := _unpublished_terrain(workspace)
	var encounter := workspace.encounter_studio
	# Un autre domaine (Terrain) est modifié et une décision SAVE/DRAFT/DISCARD/
	# CANCEL est déjà ouverte ailleurs dans le Studio, sans que Rencontres n'ait
	# lui-même le moindre changement. C'est exactement le cas dangereux visé :
	# ouvrir directement le brouillon de salle ne doit ni écraser cette
	# décision, ni la résoudre implicitement, ni changer l'autorité du
	# document de Rencontres pendant qu'elle reste ouverte.
	context.set_dirty(&"arena", true, {"document": "Fixture"})
	var requested := context.request_room(0, &"encounter")
	assert_false(bool(requested.get("ok", false)))
	assert_true(context.has_pending_transition())
	var pending_before := context.pending_transition()
	assert_false(encounter.session.is_dirty())
	assert_false(encounter.session.room_draft_mode)

	var opened := encounter.open_room_draft(
		terrain.room_draft(), context.active_run, context.active_run.resource_path,
		terrain.room_draft_gameplay_mapping()
	)

	assert_false(opened,
		"Une décision déjà ouverte ailleurs doit bloquer l'ouverture directe du brouillon.")
	assert_false(encounter.session.room_draft_mode,
		"Rencontres ne doit pas changer d'autorité pendant une décision ouverte.")
	assert_true(context.has_pending_transition(),
		"La décision en attente ne doit pas être écrasée.")
	assert_eq(context.pending_transition(), pending_before,
		"La transition en attente ne doit ni être écrasée ni résolue implicitement.")
	assert_true(context.is_dirty(&"arena"),
		"Le domaine modifié en attente de décision doit rester intact.")


## --- Enregistrement du brouillon --------------------------------------------

func test_saving_a_room_draft_only_writes_under_user_and_restores_everything() -> void:
	var workspace := await _workspace()
	var terrain := _unpublished_terrain(workspace)
	var encounter := workspace.encounter_studio
	workspace.create_encounters_button.pressed.emit()
	if encounter.session.current_encounter() == null:
		encounter.session.set_current_encounter(EncounterDefinition.new())
	encounter._add_unit(_enemy_units(1)[0])
	encounter._edit_encounter_property(&"living_enemy_cap", 7, "Fixture")
	await wait_process_frames(1)
	var encounters_before := _encounter_directory_listing()
	var hashes_before := _canonical_snapshot()

	# La sauvegarde canonique n'est pas atteignable par erreur.
	var refused := EncounterSaveService.save(encounter.session)
	assert_false(bool(refused.get("ok", false)))
	assert_eq(str(refused.get("error", "")), "room_draft_not_publishable")

	var saved := encounter.save_room_draft()
	assert_true(bool(saved.get("ok", false)), str(saved))
	assert_true(str(saved.get("path", "")).begins_with("user://"),
		"Un brouillon de salle ne s'écrit que sous user://.")
	assert_eq(_encounter_directory_listing(), encounters_before)
	for path in hashes_before:
		assert_eq(FileAccess.get_sha256(path), hashes_before[path], path)

	# Restauration : terrain, rencontres, sélection et état modifié.
	var reloaded := RoomDraftSaveService.load_draft(encounter._room_draft_session_key())
	assert_true(bool(reloaded.get("ok", false)))
	var stored := reloaded.get("room") as ArenaDefinition
	assert_eq(stored.grid_size, terrain.arena.grid_size)
	assert_eq(stored.cells.size(), terrain.arena.cells.size())
	assert_eq(stored.encounter_definition.roster_units.size(), 1)
	assert_eq(stored.encounter_definition.living_enemy_cap, 7)
	var state := reloaded.get("state", {}) as Dictionary
	assert_true(bool(state.get("room_draft", false)))
	assert_eq(int(state.get("room_index", -1)), 0)
	RoomDraftSaveService.remove(encounter._room_draft_session_key())


## --- Test runtime depuis un brouillon non publié ----------------------------

func test_testing_a_draft_builds_its_context_from_the_draft_and_the_context_run() -> void:
	var workspace := await _workspace()
	var terrain := _unpublished_terrain(workspace)
	var encounter := workspace.encounter_studio
	workspace.create_encounters_button.pressed.emit()
	if encounter.session.current_encounter() == null:
		encounter.session.set_current_encounter(EncounterDefinition.new())
	encounter._add_unit(_enemy_units(1)[0])
	encounter._edit_encounter_property(&"living_enemy_cap", 6, "Fixture")
	await wait_process_frames(1)

	var context_run := encounter.session.context_run
	var terrain_fingerprint := ArenaSnapshotService.arena_fingerprint(terrain.arena)
	var hashes_before := _canonical_snapshot()
	var encounters_before := _encounter_directory_listing()

	# editor_interface est nul en test : le contexte temporaire est construit et
	# vérifié, mais aucune scène de jeu n'est réellement lancée.
	var messages := EncounterValidationService.validate_session(encounter.session, 4242)
	var blocking := PackedStringArray()
	for message in messages:
		if message.severity == StudioValidationMessage.Severity.ERROR:
			blocking.append("%s — %s" % [message.code, message.explanation])
	assert_true(blocking.is_empty(), "Brouillon non testable : %s" % ", ".join(blocking))
	var result := EncounterTestLauncher.prepare_and_launch(
		encounter.session, null, 4242
	)
	assert_eq(str(result.get("error", "")), "editor_play_api_missing",
		"Le contexte doit être construit jusqu'au lancement.")
	var request := result.get("request", {}) as Dictionary
	var run_path := str(request.get("run_path", ""))
	assert_true(run_path.begins_with("user://"),
		"Le contexte de test vit uniquement dans le dossier temporaire possédé.")
	assert_eq(int(request.get("run_seed", 0)), 4242, "La seed choisie est utilisée.")

	var test_run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as RunData
	assert_not_null(test_run)
	var test_room := test_run.rooms[0]
	# Le terrain courant : la projection runtime du brouillon, pas une salle vide.
	assert_not_null(test_room.grid_layout,
		"Le test doit jouer la grille du brouillon.")
	assert_eq(test_room.grid_layout.logical_size, terrain.arena.grid_size)
	# Les rencontres courantes.
	assert_eq(test_room.waves.size(), 1)
	assert_eq(test_room.waves[0].encounter_definition.living_enemy_cap, 6)
	assert_eq(test_room.waves[0].encounter_definition.roster_units.size(), 1)
	# Les héros et règles de la run de contexte.
	var expected_heroes := PackedStringArray()
	for hero in RunContentCatalogService.heroes_for_run(context_run):
		if hero != null and hero.base_unit_data != null:
			expected_heroes.append(hero.base_unit_data.resource_path)
	if not expected_heroes.is_empty():
		assert_eq(Array(request.get("heroes", [])), Array(expected_heroes),
			"Le test doit utiliser les héros de la partie de contexte.")
	# Relu sans cache, le profil est une autre instance du même fichier : c'est
	# bien la règle de la partie de contexte qui est jouée.
	assert_eq(
		test_run.content_profile.resource_path if test_run.content_profile != null else "",
		context_run.content_profile.resource_path \
			if context_run.content_profile != null else "",
		"Le test doit rejouer les règles de la partie de contexte."
	)

	# Après coup : brouillon inchangé, Resources canoniques intactes.
	assert_eq(ArenaSnapshotService.arena_fingerprint(terrain.arena), terrain_fingerprint)
	assert_true(encounter.is_room_draft_mode())
	assert_same(encounter.session.draft_room, terrain.arena)
	for path in hashes_before:
		assert_eq(FileAccess.get_sha256(path), hashes_before[path], path)
	assert_eq(_encounter_directory_listing(), encounters_before)

	# Le dossier temporaire possédé est supprimable sans toucher au brouillon.
	var context_dir := run_path.get_base_dir()
	_remove_directory(context_dir)
	assert_false(FileAccess.file_exists(run_path))
	assert_same(encounter.session.draft_room, terrain.arena)


func _remove_directory(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)


## --- Rencontres partagées, en mode brouillon --------------------------------
##
## Limite comblée : je disais ne pas avoir de test dédié pour « modifier le
## partagé » et « dupliquer pour cet affrontement » sur un brouillon de salle.
##
## Le vrai partage qui compte ici est *interne au brouillon* : la working copy
## d'une salle isole toujours sa rencontre en copie dès l'ouverture
## (RoomDraftAuthority.isolate_gameplay_into) — elle n'est donc plus jamais
## littéralement la Resource canonique. « Modifier » ne peut donc affecter que
## les affrontements de CE brouillon qui partagent encore la même copie ; les
## autres salles du projet ne sont jamais concernées, quel que soit le choix.
## La fixture construit délibérément deux affrontements d'une même salle qui
## pointent vers la même rencontre, pour exercer ce cas réel.

const SHARED_ROOT := "res://artifacts/room_draft_shared_encounter"


func _shared_encounter_fixture() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHARED_ROOT))
	var unit := _enemy_units(1)[0]
	var shared := EncounterDefinition.new()
	shared.roster_units = [unit]
	shared.roster_counts = PackedInt32Array([1])
	var encounter_path := SHARED_ROOT.path_join("shared_encounter.tres")
	assert_eq(ResourceSaver.save(shared, encounter_path), OK)

	var arena := ArenaDefinition.new()
	arena.set_identity("Salle à rencontre partagée", "salle_rencontre_partagee")
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
	var reloaded_shared := ResourceLoader.load(
		encounter_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as EncounterDefinition
	var wave_one := RoomWaveData.new()
	wave_one.wave_name = "Affrontement 1"
	wave_one.encounter_definition = reloaded_shared
	var wave_two := RoomWaveData.new()
	wave_two.wave_name = "Affrontement 2"
	# Même instance que wave_one : c'est ce partage interne à la salle que la
	# case à cocher « Modifier la rencontre partagée » doit honnêtement décrire.
	wave_two.encounter_definition = reloaded_shared
	arena.waves = [wave_one, wave_two]
	arena.minimum_wave_count = 1
	arena.maximum_wave_count = 2
	var room_path := SHARED_ROOT.path_join("room.tres")
	assert_eq(ResourceSaver.save(arena, room_path), OK)
	var reloaded_room := ResourceLoader.load(
		room_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition

	var run := RunData.new()
	run.run_name = "Partie de test — rencontre partagée"
	run.room_flow_mode = RunData.RoomFlowMode.WAVE_CHAIN
	run.maximum_waves_per_room = 2
	run.rooms = [reloaded_room]
	var run_path := SHARED_ROOT.path_join("run.tres")
	assert_eq(ResourceSaver.save(run, run_path), OK)
	return {
		"run": ResourceLoader.load(run_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP),
		"encounter_path": encounter_path,
	}


## Ouvre la salle-fixture (dont deux affrontements partagent la même rencontre)
## dans Terrain, puis son brouillon dans Rencontres, sur le premier affrontement.
func _shared_room_draft_workspace() -> Dictionary:
	var fixture := _shared_encounter_fixture()
	var run: RunData = fixture.run
	var context := StudioProjectContext.new()
	assert_true(context.request_selection({"run": run, "room_index": 0}).ok)
	var workspace := StudioWorkspace.new()
	workspace.arena_auto_load_enabled = false
	workspace.arena_production_planning_enabled = false
	workspace.setup(null, null, context, StudioReferenceGraphService.new())
	add_child_autofree(workspace)
	await wait_process_frames(2)
	var terrain := workspace.arena_studio
	terrain.set_focus_map(false)
	assert_true(terrain._open_context_room(context.active_room()))
	terrain.show_editor()
	workspace.create_encounters_button.pressed.emit()
	var encounter := workspace.encounter_studio
	assert_true(encounter.is_room_draft_mode())
	encounter.session.select(0, 0)
	var local_usage := encounter._draft_local_usage_count(encounter.session.current_encounter())
	assert_eq(local_usage, 2,
		"La fixture attend deux affrontements de la même salle partageant la rencontre.")
	return {
		"workspace": workspace, "terrain": terrain, "encounter": encounter,
		"encounter_path": fixture.encounter_path,
	}


func test_modifying_a_shared_draft_encounter_asks_and_affects_only_this_draft() -> void:
	var context := await _shared_room_draft_workspace()
	var encounter: EncounterStudioMain = context.encounter
	var draft_encounter := encounter.session.current_encounter()
	var canonical_path := str(context.encounter_path)
	var canonical_cap_before := (
		ResourceLoader.load(canonical_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			as EncounterDefinition
	).living_enemy_cap

	watch_signals(encounter.shared_dialog)
	encounter._add_unit(_enemy_units(1)[0])
	assert_true(encounter.shared_dialog.visible,
		"Modifier une rencontre encore partagée dans ce brouillon doit demander confirmation.")
	assert_string_contains(encounter.shared_dialog.dialog_text, "2 affrontements")
	# Le texte historique promettait un effet sur toutes les salles du projet ;
	# en brouillon, ce serait faux (la copie est déjà isolée). Il ne doit plus
	# apparaître ici.
	assert_false(encounter.shared_dialog.dialog_text.contains("affectera tous ses usages"))

	# « Modifier la rencontre partagée » : les deux affrontements de CETTE
	# salle reçoivent le changement, puisqu'ils pointent la même copie.
	encounter.shared_dialog.hide()
	encounter.shared_dialog.confirmed.emit()
	assert_eq(draft_encounter.roster_units.size(), 2)
	encounter.session.select(0, 1)
	assert_same(encounter.session.current_encounter(), draft_encounter,
		"Le deuxième affrontement doit pointer la même copie de travail.")
	assert_eq(encounter.session.current_encounter().roster_units.size(), 2)

	# Une deuxième modification de la même rencontre ne redemande plus.
	encounter._edit_encounter_property(&"living_enemy_cap", 42, "Fixture")
	assert_false(encounter.shared_dialog.visible)

	# La rencontre canonique sur disque n'a jamais bougé : rien n'est publié
	# hors intégration, et les autres salles du projet ne sont pas concernées.
	assert_eq(
		(
			ResourceLoader.load(canonical_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
				as EncounterDefinition
		).living_enemy_cap,
		canonical_cap_before
	)


func test_duplicating_a_shared_draft_encounter_detaches_only_this_affrontement() -> void:
	var context := await _shared_room_draft_workspace()
	var encounter: EncounterStudioMain = context.encounter
	var shared_copy := encounter.session.current_encounter()
	var canonical_fingerprint_before := FileAccess.get_sha256(str(context.encounter_path))

	watch_signals(encounter.shared_dialog)
	encounter._add_unit(_enemy_units(1)[0])
	assert_true(encounter.shared_dialog.visible)

	# « Dupliquer pour cet affrontement » : seul l'affrontement courant reçoit
	# une copie indépendante ; le deuxième affrontement de la salle continue de
	# pointer l'ancienne copie, inchangée.
	encounter._on_shared_custom_action(&"duplicate")
	var duplicated := encounter.session.current_encounter()
	assert_ne(duplicated, shared_copy, "Dupliquer doit produire une Resource distincte.")
	assert_eq(duplicated.roster_units.size(), 2)

	encounter.session.select(0, 1)
	assert_same(encounter.session.current_encounter(), shared_copy,
		"Le deuxième affrontement ne doit pas être touché par la duplication du premier.")
	assert_eq(encounter.session.current_encounter().roster_units.size(), 1)

	assert_eq(FileAccess.get_sha256(str(context.encounter_path)), canonical_fingerprint_before,
		"La rencontre canonique sur disque ne doit jamais être mutée par une duplication.")
	assert_true(encounter.session.new_resource_paths.has(duplicated),
		"La copie doit être marquée comme nouvelle ressource, pas encore publiée.")
	assert_false(ResourceLoader.exists(str(encounter.session.new_resource_paths[duplicated])),
		"La copie ne doit pas exister comme fichier avant l'intégration.")


func test_cancelling_the_shared_encounter_prompt_mutates_neither_affrontement() -> void:
	var context := await _shared_room_draft_workspace()
	var encounter: EncounterStudioMain = context.encounter
	var draft_encounter := encounter.session.current_encounter()
	var roster_before := draft_encounter.roster_units.size()

	encounter._add_unit(_enemy_units(1)[0])
	assert_true(encounter.shared_dialog.visible)
	# Fermer sans choisir : ni « modifier », ni « dupliquer ». L'action en
	# attente n'est jamais appliquée à l'aveugle.
	encounter.shared_dialog.hide()
	encounter._pending_shared_action = Callable()

	assert_eq(draft_encounter.roster_units.size(), roster_before,
		"Un abandon ne doit laisser passer aucune modification.")
	encounter.session.select(0, 1)
	assert_same(encounter.session.current_encounter(), draft_encounter,
		"Les deux affrontements doivent rester rattachés à la même copie, inchangée.")
	assert_eq(encounter.session.current_encounter().roster_units.size(), roster_before)


## --- Autorité ---------------------------------------------------------------

func test_arena_definition_carries_both_halves_of_the_draft() -> void:
	var draft := ArenaDefinition.new()
	draft.authoring_document = true
	var gameplay_fields := RoomDraftAuthority.gameplay_property_names(draft)
	for expected in [
		&"encounter_definition", &"waves", &"minimum_wave_count",
		&"maximum_wave_count", &"ultimate_reward_base_chance",
	]:
		assert_true(gameplay_fields.has(expected),
			"Le champ %s doit être possédé par le domaine Rencontres." % expected)
	# Aucune propriété stockée ne doit rester sans politique : la frontière est
	# explicite et couvre le brouillon complet.
	assert_true(bool(RoomIntegrationFieldPolicy.coverage_report(draft).get("ok", false)))


func test_terrain_working_copy_deeply_isolates_canonical_gameplay() -> void:
	# Une source portant des rencontres et des vagues : la working copy doit les
	# recevoir, mais jamais partager leurs instances.
	var source := ArenaDefinition.new()
	source.grid_size = Vector2i(6, 6)
	source.encounter_definition = EncounterDefinition.new()
	source.encounter_definition.living_enemy_cap = 4
	var wave := RoomWaveData.new()
	wave.wave_name = "Affrontement canonique"
	wave.encounter_definition = EncounterDefinition.new()
	source.waves = [wave]
	var session := ArenaEditSession.new()
	assert_true(session.open(source, "res://artifacts/fixture_source.tres"))
	var working := session.working_arena
	assert_eq(working.waves.size(), 1, "Le brouillon doit recevoir les vagues source.")
	assert_eq(working.encounter_definition.living_enemy_cap, 4)
	assert_ne(working.encounter_definition, source.encounter_definition,
		"La working copy ne doit jamais partager l'EncounterDefinition source.")
	assert_ne(working.waves[0], wave)
	assert_ne(working.waves[0].encounter_definition, wave.encounter_definition)
	assert_same(session.gameplay_work_to_source.get(working.encounter_definition),
		source.encounter_definition)
	# L'historique de Terrain conserve la moitié Rencontres.
	working.encounter_definition.living_enemy_cap = 9
	session.apply_snapshot(source.to_snapshot())
	assert_eq(working.waves.size(), 1,
		"Annuler dans Terrain ne doit pas supprimer les vagues du brouillon.")
	assert_eq(working.encounter_definition.living_enemy_cap, 9)
