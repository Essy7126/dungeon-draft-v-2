extends GutTest

## Contrat de la refonte du Studio Terrain.
##
## Chaque test correspond à un point du cahier des charges validé :
## accès Nouveau/Ouvrir dans le vrai StudioWorkspace, mode guidé par défaut et
## réellement masquant, conservation de la session au changement de mode, rail
## d'étapes, raccourcis réellement implémentés, parcours clavier, inspecteur
## accessible sous 1 180 px, contrats brouillon/test/intégration, test sans
## mutation de source, rollback de sauvegarde, projection runtime non mutante,
## transitions dirty, intégration UPDATE, focus/détachement et runner de
## captures.

const FOREST_PATH := "res://data/arenas/room_01_forest.tres"
const CAPTURE_RUNNER := "res://addons/dungeon_draft_arena_studio/test/terrain_studio_capture_runner.gd"


func before_each() -> void:
	ArenaValidator.clear_cache()
	ArenaVisualAssembler.clear_inspection_cache()
	ArenaTerrainRenderPlanService.clear_cache()
	ArenaTacticalMetricsService.clear_cache()
	# L'état d'interface est volontairement persistant entre deux sessions :
	# chaque test repart donc explicitement des valeurs par défaut.
	TerrainStudioUiStateService.clear_cache()
	TerrainStudioUiStateService.save_state(TerrainStudioUiStateService.default_state())


# --- 1. Nouveau / Ouvrir accessibles depuis le vrai StudioWorkspace ---------

func test_01_new_and_open_are_reachable_inside_the_real_workspace() -> void:
	var workspace := StudioWorkspace.new()
	add_child_autofree(workspace)
	await wait_process_frames(3)
	var terrain := workspace.arena_studio
	assert_not_null(terrain)
	# L'hôte masque la barre interne historique : c'est le constat TERRAIN-01.
	assert_false(terrain.top_bar.visible)
	# L'en-tête du domaine, lui, reste visible et porte les deux entrées.
	assert_true(terrain.header_bar.visible)
	assert_not_null(terrain.new_terrain_button)
	assert_not_null(terrain.open_terrain_button)
	assert_true(terrain.new_terrain_button.is_visible_in_tree())
	assert_true(terrain.open_terrain_button.is_visible_in_tree())
	assert_true(terrain.home_button.is_visible_in_tree())
	# L'accueil expose les mêmes entrées sous forme de cartes.
	assert_true(terrain.is_home_visible())
	assert_not_null(terrain.home_panel.create_card)
	assert_not_null(terrain.home_panel.open_card)
	assert_not_null(terrain.home_panel.active_card)
	assert_not_null(terrain.home_panel.sandbox_button)


func test_02_tab_is_named_terrains_with_a_readable_subtitle() -> void:
	assert_eq(TerrainVocabulary.TAB_TITLE, "TERRAINS")
	assert_eq(TerrainVocabulary.TAB_SUBTITLE, "Construire la zone tactique d'une salle")
	var workspace := StudioWorkspace.new()
	add_child_autofree(workspace)
	await wait_process_frames(3)
	assert_eq(workspace.tabs.get_tab_title(0), "TERRAINS")
	assert_eq(workspace.tabs.get_tab_tooltip(0), TerrainVocabulary.TAB_SUBTITLE)


# --- 2 et 3. Mode guidé par défaut, et réellement masquant ------------------

func test_03_guided_mode_is_active_by_default() -> void:
	var studio := _studio()
	assert_true(studio.is_guided())
	assert_true(studio.guided_toggle.button_pressed)


func test_04_guided_mode_really_hides_the_advanced_settings() -> void:
	var studio := _studio()
	studio.set_current_step(TerrainWorkflowService.Step.SCENERY)
	await wait_process_frames(1)
	for control in studio.advanced_only_controls():
		assert_false(
			control.is_visible_in_tree(),
			"« %s » ne doit pas être visible en mode guidé." % control.name
		)
	studio.set_guided(false)
	await wait_process_frames(1)
	var visible_in_advanced := 0
	for control in studio.advanced_only_controls():
		if control.visible:
			visible_in_advanced += 1
	assert_gt(visible_in_advanced, 0, "Le mode avancé doit rendre ces réglages accessibles.")


# --- 4. Le changement de mode ne perd ni session, ni sélection, ni zoom -----

func test_05_switching_guided_advanced_keeps_session_selection_zoom_and_history() -> void:
	var studio := _studio()
	_open_forest(studio)
	# set_arena() recentre la vue en differe : attendre avant de fixer le zoom.
	await wait_process_frames(2)
	var session := studio.edit_session
	var before := studio.arena.to_snapshot()
	studio.arena.grid_origin += Vector2(5, -3)
	studio._commit_change("Déplacer la grille", before, studio.arena.to_snapshot())
	studio.canvas.zoom = 2.5
	studio.canvas.selected_cells = [Vector2i(2, 2)]
	var history_index := session.history.get_current_index()
	studio.set_guided(false)
	await wait_process_frames(1)
	studio.set_guided(true)
	await wait_process_frames(1)
	assert_eq(studio.edit_session, session, "La session d'édition doit être conservée.")
	assert_eq(studio.arena, session.working_arena)
	assert_eq(studio.canvas.zoom, 2.5)
	assert_eq(studio.canvas.selected_cells, [Vector2i(2, 2)])
	assert_eq(session.history.get_current_index(), history_index)
	assert_true(session.history.can_undo())


# --- 5. Le parcours affiche la bonne étape et le bon état -------------------

func test_06_workflow_rail_exposes_seven_steps_with_state_and_next_action() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.validate_arena()
	var steps := studio.workflow_steps()
	assert_eq(steps.size(), TerrainWorkflowService.STEP_COUNT)
	assert_eq(steps.size(), 7)
	assert_eq(studio.workflow_rail.buttons.size(), 7)
	var labels := PackedStringArray()
	for entry in steps:
		labels.append(str(entry.label))
		assert_true(entry.has("goal"))
		assert_true(entry.has("state"))
		assert_true(entry.has("missing"))
		assert_true(entry.has("next_action"))
		assert_false(str(entry.goal).is_empty())
		assert_false(str(entry.next_action).is_empty())
		# Aucun état n'est transmis par la seule couleur.
		assert_false(str(entry.state_glyph).is_empty())
		assert_false(str(entry.state_word).is_empty())
	assert_eq(labels, PackedStringArray([
		"Départ", "Forme", "Sols", "Obstacles et départs", "Décor",
		"Vérifier", "Tester et intégrer",
	]))
	# Le parcours reste libre : n'importe quelle étape s'ouvre directement.
	studio.set_current_step(TerrainWorkflowService.Step.FINALIZE)
	assert_eq(studio.current_step, TerrainWorkflowService.Step.FINALIZE)
	assert_eq(studio.workflow_rail.current_step(), TerrainWorkflowService.Step.FINALIZE)
	studio.set_current_step(TerrainWorkflowService.Step.SHAPE)
	assert_eq(studio.current_step, TerrainWorkflowService.Step.SHAPE)


func test_07_workflow_states_follow_the_document_content() -> void:
	var empty := ArenaDefinition.new()
	empty.set_identity("Terrain vide", "terrain_vide")
	empty.grid_size = Vector2i(6, 6)
	var steps := TerrainWorkflowService.evaluate(empty, null, {})
	assert_eq(steps[TerrainWorkflowService.Step.SHAPE].state, TerrainWorkflowService.STATE_TODO)
	assert_eq(steps[TerrainWorkflowService.Step.CONTENT].state, TerrainWorkflowService.STATE_TODO)
	assert_eq(
		TerrainWorkflowService.readiness(steps, null),
		TerrainWorkflowService.READINESS_INCOMPLETE
	)
	var ready := _valid_arena()
	var report := ArenaValidator.validate(ready, false)
	var ready_steps := TerrainWorkflowService.evaluate(ready, report, {"has_report": true})
	assert_eq(
		ready_steps[TerrainWorkflowService.Step.SHAPE].state,
		TerrainWorkflowService.STATE_DONE
	)
	assert_eq(
		ready_steps[TerrainWorkflowService.Step.CONTENT].state,
		TerrainWorkflowService.STATE_DONE
	)
	assert_eq(
		TerrainWorkflowService.readiness(ready_steps, report),
		TerrainWorkflowService.READINESS_TESTABLE
	)


# --- 6. Les raccourcis affichés fonctionnent réellement ---------------------

func test_08_every_advertised_tool_shortcut_selects_its_tool() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.set_guided(false)
	await wait_process_frames(1)
	assert_eq(ArenaStudioMain.TOOL_SHORTCUT_KEYS.size(), ArenaStudioMain.TOOL_LABELS.size())
	for index in range(ArenaStudioMain.TOOL_LABELS.size()):
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = ArenaStudioMain.TOOL_SHORTCUT_KEYS[index]
		studio._unhandled_key_input(key)
		assert_eq(
			studio.canvas.active_tool, index,
			"Le raccourci %s doit sélectionner « %s »." % [
				ArenaStudioMain.TOOL_HELP[index][0], ArenaStudioMain.TOOL_LABELS[index],
			]
		)


func test_09_advertised_shortcut_matches_the_displayed_contract() -> void:
	for index in range(ArenaStudioMain.TOOL_LABELS.size()):
		var displayed := str(ArenaStudioMain.TOOL_HELP[index][0])
		var keycode: int = ArenaStudioMain.TOOL_SHORTCUT_KEYS[index]
		assert_eq(
			OS.get_keycode_string(keycode).to_upper(), displayed.to_upper(),
			"Le contrat affiché et le raccourci traité doivent être identiques."
		)


# --- 7. Toutes les actions primaires sont atteignables au clavier -----------

func test_10_all_primary_actions_are_keyboard_reachable() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	await wait_process_frames(1)
	var controls := studio.primary_action_controls()
	assert_gt(controls.size(), 10)
	for control in controls:
		assert_ne(
			control.focus_mode, Control.FOCUS_NONE,
			"« %s » doit pouvoir recevoir le focus clavier." % control.name
		)
	# Parcours réel : chaque contrôle visible accepte grab_focus().
	var focused := 0
	for control in controls:
		if not control.is_visible_in_tree() or control.is_queued_for_deletion():
			continue
		control.grab_focus()
		await wait_process_frames(1)
		if control.has_focus():
			focused += 1
	assert_gt(focused, 5, "Le parcours clavier doit atteindre les actions visibles.")


# --- 8. L'inspecteur reste accessible sous 1 180 px ------------------------

func test_11_inspector_stays_reachable_below_1180_px() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	_size_studio(studio, 1100, 720)
	await wait_process_frames(1)
	assert_false(studio.right_panel.visible, "L'inspecteur se replie sous 1 180 px.")
	assert_true(
		studio.inspector_drawer_button.visible,
		"Un accès de remplacement doit rester visible."
	)
	assert_true(studio.inspector_is_reachable())
	studio.toggle_inspector_drawer()
	assert_true(studio.right_panel.visible, "Le tiroir doit rouvrir l'inspecteur.")
	_size_studio(studio, 1600, 900)
	assert_true(studio.right_panel.visible)
	assert_false(studio.inspector_drawer_button.visible)


func test_12_no_primary_action_is_offscreen_at_1280_by_720() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	_size_studio(studio, 1280, 720)
	await wait_process_frames(2)
	# Une action placée dans une zone défilante reste atteignable : seules les
	# actions réellement hors fenêtre sont interdites.
	for control in studio.primary_action_controls():
		if not control.is_visible_in_tree() or _is_scrollable(studio, control):
			continue
		var rect := control.get_global_rect()
		assert_lte(
			rect.end.x, 1281.0,
			"« %s » ne doit pas sortir de l'écran en 1280 × 720." % control.name
		)
		assert_lte(
			rect.end.y, 721.0,
			"« %s » ne doit pas sortir de l'écran en 1280 × 720." % control.name
		)


# --- 9 et 11. Brouillon / Test / Intégration ont des contrats distincts ----

func test_13_draft_test_and_integration_have_distinct_contracts() -> void:
	var studio := _studio()
	_open_forest(studio)
	assert_not_null(studio.finalize_panel)
	assert_eq(studio.finalize_panel.draft_button.text, "Enregistrer le brouillon")
	assert_eq(studio.finalize_panel.test_button.text, "Tester")
	assert_eq(studio.finalize_panel.integrate_button.text, "Intégrer à la partie")
	var contracts := {}
	for contract in TerrainFinalizePanel.CONTRACTS:
		contracts[str(contract[0])] = str(contract[1])
	assert_eq(contracts.size(), 3)
	for key in contracts:
		assert_false(str(contracts[key]).is_empty())
	# Le brouillon reste sous user:// et hors des dossiers de production.
	var draft_path := ArenaDraftSaveService.draft_path(studio.arena.arena_id)
	assert_true(draft_path.begins_with("user://"))
	assert_false(draft_path.begins_with(ArenaProductionService.DEFAULT_ROOT))
	studio.save_draft()
	assert_true(ArenaDraftSaveService.has_draft(studio.arena.arena_id))
	var reloaded := ArenaDraftSaveService.load_draft(studio.arena.arena_id)
	assert_not_null(reloaded)
	assert_eq(reloaded.arena_id, studio.arena.arena_id)
	ArenaDraftSaveService.remove(studio.arena.arena_id)


func test_14_permanent_document_state_distinguishes_draft_and_integration() -> void:
	assert_eq(
		TerrainWorkflowService.document_state_text(true, "", false),
		"Brouillon modifié — non intégré"
	)
	assert_eq(
		TerrainWorkflowService.document_state_text(false, "Principale · Salle 2", false),
		"Intégré dans Principale · Salle 2"
	)
	assert_string_contains(
		TerrainWorkflowService.document_state_text(true, "Principale · Salle 2", false),
		"Modifications locales non publiées"
	)


# --- 10. Tester utilise la working copy sans écrire la source --------------

func test_15_testing_uses_the_working_copy_without_touching_the_source() -> void:
	var source := load(FOREST_PATH) as ArenaDefinition
	assert_not_null(source)
	var source_before := ArenaEditSession.fingerprint(source.to_snapshot())
	var session := ArenaEditSession.new()
	assert_true(session.open(source, FOREST_PATH, false, "terrain_test_isolation"))
	ArenaEditingService.prepare_automatically(session.working_arena)
	session.working_arena.display_name = "Terrain modifié pour le test"
	var preparation := ArenaDirectTestService.prepare(
		session.working_arena, null, &"no_characters"
	)
	assert_true(
		bool(preparation.get("ok", false)),
		str(preparation)
	)
	assert_eq(
		ArenaEditSession.fingerprint(source.to_snapshot()), source_before,
		"Tester ne doit modifier aucune Resource source."
	)
	assert_false(
		str(preparation.get("arena_path", "")).begins_with("res://"),
		"La copie de test vit sous user://."
	)


# --- 11. La sauvegarde rollback tous les fichiers après échec injecté ------

func test_16_canonical_save_rolls_back_every_file_after_injected_failure() -> void:
	var target := "res://data/arenas/terrain_transaction_rollback.tres"
	var target_absolute := ProjectSettings.globalize_path(target)
	if FileAccess.file_exists(target_absolute):
		DirAccess.remove_absolute(target_absolute)
	var arena := _valid_arena()
	arena.set_identity("Terrain transaction original", "terrain_transaction_rollback")
	assert_eq(ResourceSaver.save(arena, target), OK)
	var original_hash := FileAccess.get_sha256(target)
	var session := ArenaEditSession.new()
	assert_true(session.open(arena, target, false, "terrain_transaction_rollback"))
	var working := session.working_arena
	var before := working.to_snapshot()
	working.production_notes = "Cette version ne doit jamais survivre au rollback."
	assert_true(session.commit("Modifier les notes", before, working.to_snapshot()))
	var plan := ArenaCanonicalSaveTransactionService.plan(working, session)
	assert_true(bool(plan.get("ok", false)), str(plan.get("blocking", [])))
	assert_eq(str(plan.path), target)
	assert_true((plan.modifies as PackedStringArray).has(target))
	var failed := ArenaCanonicalSaveTransactionService.save(
		working, session, {"failure_step": "after_write"}
	)
	assert_false(bool(failed.get("ok", false)))
	assert_true(bool(failed.get("rolled_back", false)))
	assert_true(FileAccess.file_exists(target_absolute))
	assert_eq(FileAccess.get_sha256(target), original_hash,
		"Le contenu canonique préexistant doit être restauré octet pour octet.")
	# La session n'est jamais marquée sauvegardée après un rollback.
	assert_true(session.is_dirty())
	ArenaSerializer.remove_recovery(working.arena_id)
	DirAccess.remove_absolute(target_absolute)


func test_17_canonical_save_plan_lists_files_before_writing() -> void:
	var arena := _valid_arena()
	arena.set_identity("Terrain plan", "terrain_plan_contract")
	var session := ArenaEditSession.new()
	assert_true(session.open(arena, "", true, "terrain_plan_contract"))
	var plan := ArenaCanonicalSaveTransactionService.plan(session.working_arena, session)
	assert_true(plan.has("creates"))
	assert_true(plan.has("modifies"))
	assert_true(plan.has("blocking"))
	assert_string_contains(str(plan.summary), "Terrain plan")
	var creates := plan.creates as PackedStringArray
	var modifies := plan.modifies as PackedStringArray
	assert_eq(creates.size() + modifies.size(), 1)


func test_17b_successful_save_reopens_the_verified_snapshot_as_clean() -> void:
	var target := "res://data/arenas/terrain_verified_reopen.tres"
	var target_absolute := ProjectSettings.globalize_path(target)
	if FileAccess.file_exists(target_absolute):
		DirAccess.remove_absolute(target_absolute)
	var studio := _studio()
	var candidate := _valid_arena()
	candidate.set_identity("Terrain vérifié", "terrain_verified_reopen")
	studio._set_arena(candidate, true, "terrain_verified_reopen")
	var result := studio.save_arena()
	assert_true(bool(result.get("ok", false)), str(result))
	var reloaded := ResourceLoader.load(
		target, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	assert_not_null(reloaded)
	assert_eq(studio.arena.to_snapshot(), reloaded.to_snapshot())
	assert_eq(studio.edit_session.source_arena.to_snapshot(), reloaded.to_snapshot())
	assert_false(studio.edit_session.is_dirty())
	assert_false(studio.edit_session.has_external_conflict())
	ArenaSerializer.remove_recovery(studio.arena.arena_id)
	DirAccess.remove_absolute(target_absolute)


# --- 12. La projection runtime ne modifie pas la working copy --------------

func test_18_runtime_projection_never_mutates_the_working_copy() -> void:
	var source := load(FOREST_PATH) as ArenaDefinition
	var session := ArenaEditSession.new()
	assert_true(session.open(source, FOREST_PATH, false, "terrain_projection"))
	var working := session.working_arena
	assert_true(working.authoring_document)
	assert_null(working.grid_layout)
	assert_null(working.painted_map_visual_data)
	assert_true(working.hero_spawn_zone.is_empty())
	assert_true(working.enemy_spawn_zone.is_empty())
	# Même en demandant explicitement une synchronisation, le document d'auteur
	# reste intact : c'est la projection qui porte les champs dérivés.
	var complete_snapshot_before := working.to_snapshot().duplicate(true)
	ArenaRuntimeBridge.sync_runtime_resources(working)
	assert_eq(working.to_snapshot(), complete_snapshot_before,
		"La synchronisation runtime ne doit modifier aucun champ de la working copy.")
	assert_null(working.grid_layout)
	assert_null(working.painted_map_visual_data)
	var projection := session.runtime_projection()
	assert_not_null(projection)
	assert_not_null(projection.grid_layout)
	assert_not_null(projection.painted_map_visual_data)
	assert_false(projection.authoring_document)
	assert_eq(
		ArenaSnapshotService.arena_fingerprint(working),
		ArenaSnapshotService.arena_fingerprint(projection),
		"Les champs runtime dérivés ne changent pas l'empreinte du terrain."
	)
	assert_null(working.grid_layout, "La lecture de la projection ne mute rien.")
	# Une validation complète ne mute pas davantage le document.
	var fingerprint_before := ArenaEditSession.fingerprint(working.to_snapshot())
	ArenaValidator.validate(working, false)
	assert_eq(ArenaEditSession.fingerprint(working.to_snapshot()), fingerprint_before)
	assert_null(working.grid_layout)


func test_18b_automatic_preparation_reads_a_projection_for_authoring_documents() -> void:
	var source := ArenaDefinition.new()
	source.set_identity("Préparation document auteur", "preparation_document_auteur")
	source.grid_size = Vector2i(8, 8)
	var source_before := source.to_snapshot().duplicate(true)
	var session := ArenaEditSession.new()
	assert_true(session.open(source, "", true, "preparation_document_auteur"))
	var result := ArenaEditingService.prepare_automatically(session.working_arena)
	assert_true(bool(result.get("ok", false)), str(result))
	assert_gt(int(result.get("connected", 0)), 0)
	assert_gte(int(result.get("hero_spawns", 0)), 3)
	assert_gte(int(result.get("enemy_spawns", 0)), 3)
	assert_null(session.working_arena.grid_layout)
	assert_null(session.working_arena.painted_map_visual_data)
	var projection := session.runtime_projection()
	assert_not_null(projection)
	assert_eq(int(result.hero_spawns), projection.hero_spawn_zone.size())
	assert_eq(int(result.enemy_spawns), projection.enemy_spawn_zone.size())
	assert_eq(source.to_snapshot(), source_before,
		"Préparer la working copy ne doit jamais modifier la Resource source.")


func test_19_projection_is_rebuilt_when_the_document_changes() -> void:
	var source := load(FOREST_PATH) as ArenaDefinition
	var session := ArenaEditSession.new()
	assert_true(session.open(source, FOREST_PATH, false, "terrain_projection_cache"))
	var first := session.runtime_projection()
	assert_same(first, session.runtime_projection())
	var before := session.working_arena.to_snapshot()
	session.working_arena.grid_origin += Vector2(4, 4)
	session.commit("Déplacer la grille", before, session.working_arena.to_snapshot())
	var second := session.runtime_projection()
	assert_not_same(first, second)
	assert_eq(second.painted_map_visual_data.grid_origin, session.working_arena.grid_origin)


# --- 13. Les transitions dirty conservent SAVE/DRAFT/DISCARD/CANCEL --------

func test_20_dirty_transitions_keep_the_four_explicit_choices() -> void:
	assert_eq(StudioProjectContext.ACTION_SAVE, &"SAVE")
	assert_eq(StudioProjectContext.ACTION_DRAFT, &"DRAFT")
	assert_eq(StudioProjectContext.ACTION_DISCARD, &"DISCARD")
	assert_eq(StudioProjectContext.ACTION_CANCEL, &"CANCEL")
	var studio := _studio()
	assert_true(studio.has_method("_context_save"))
	assert_true(studio.has_method("_context_draft"))
	assert_true(studio.has_method("_context_discard"))
	assert_true(studio.has_method("_context_is_dirty"))


# --- 14. L'intégration UPDATE conserve rencontre, vagues et récompenses ----

func test_21_update_integration_preserves_encounter_waves_and_rewards() -> void:
	for field in [
		"encounter_definition", "waves", "minimum_wave_count", "maximum_wave_count",
		"ultimate_reward_base_chance", "ultimate_reward_min_gain_per_wave",
		"ultimate_reward_max_gain_per_wave", "enemies",
	]:
		assert_eq(
			RoomIntegrationFieldPolicy.classification_for(StringName(field)),
			RoomIntegrationFieldPolicy.GAMEPLAY_OWNED,
			"UPDATE doit conserver « %s »." % field
		)
	var historical_target := ArenaDefinition.new()
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"enemies", historical_target),
		RoomIntegrationFieldPolicy.GAMEPLAY_OWNED,
		"Une ArenaDefinition déjà produite conserve ses ennemis historiques."
	)
	var authoring_source := ArenaDefinition.new()
	authoring_source.authoring_document = true
	assert_eq(
		RoomIntegrationFieldPolicy.classification_for(&"enemies", authoring_source),
		RoomIntegrationFieldPolicy.DERIVED_RUNTIME,
		"La working copy n'est pas propriétaire de la projection des ennemis."
	)
	# UPDATE reste l'action recommandée et REPLACE reste explicitement avancée.
	var source := FileAccess.get_file_as_string(
		"res://addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd"
	)
	assert_string_contains(source, "Mettre à jour l’arène — recommandé")
	assert_string_contains(source, "Remplacer toute la salle — avancé")


# --- 15. Focus et détachement conservent workspace et session --------------

func test_22_focus_and_detach_keep_the_same_workspace_and_session() -> void:
	var workspace := StudioWorkspace.new()
	add_child_autofree(workspace)
	await wait_process_frames(3)
	var terrain := workspace.arena_studio
	_open_forest(terrain)
	var identity := workspace.active_session_identity()
	var session := terrain.edit_session
	terrain.set_focus_map(true)
	assert_true(terrain.focus_map_enabled)
	terrain.set_focus_map(false)
	assert_false(terrain.focus_map_enabled)
	var host := EmbeddedStudioHost.new()
	add_child_autofree(host)
	host.attach_workspace(workspace)
	await wait_process_frames(1)
	assert_eq(workspace.active_session_identity(), identity)
	assert_eq(terrain.edit_session, session)
	assert_eq(
		host.find_children("*", "StudioWorkspace", true, false).size(), 1,
		"Un seul StudioWorkspace doit exister."
	)


# --- 16. Le runner de captures instancie le véritable StudioWorkspace ------

func test_23_capture_runners_instantiate_the_real_workspace() -> void:
	for path in [
		CAPTURE_RUNNER,
		"res://addons/dungeon_draft_arena_studio/test/arena_studio_capture_runner.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		assert_string_contains(source, "StudioWorkspace.new()")
		assert_false(
			"DungeonDraftStudioMain.new()" in source,
			"%s ne doit plus instancier le shell nu." % path
		)


# --- Vocabulaire, guidage et validation actionnable ------------------------

func test_24_guided_vocabulary_avoids_technical_terms() -> void:
	var forbidden := [
		"PAINTED", "MODULAR", "HYBRID", "Spawn", "spawns", "foreground",
		"occlusion", "runtime", "bundle",
	]
	var texts := PackedStringArray()
	texts.append_array(TerrainWorkflowService.STEP_LABELS)
	texts.append_array(TerrainWorkflowService.STEP_GOALS)
	texts.append_array(TerrainWorkflowService.STEP_ACTIONS)
	texts.append_array(TerrainWorkflowService.STEP_HINTS)
	for choice in TerrainVocabulary.CREATION_CHOICES:
		texts.append(str(choice.display_title))
		texts.append(str(choice.summary))
		texts.append(str(choice.detail))
		texts.append(str(choice.confirm_label))
	for text in texts:
		for term in forbidden:
			assert_false(
				term in text,
				"Le parcours guidé ne doit pas employer « %s » : %s" % [term, text]
			)
	assert_eq(TerrainVocabulary.user_term("spawn"), "Point de départ")
	assert_eq(TerrainVocabulary.user_term("foreground"), "Premier plan")
	assert_eq(TerrainVocabulary.user_term("occlusion"), "Zones masquées")
	assert_eq(TerrainVocabulary.user_term("runtime"), "Résultat en jeu")


func test_25_creation_wizard_offers_three_intentions_and_adapts_its_button() -> void:
	var wizard := TerrainCreationWizard.new()
	add_child_autofree(wizard)
	await wait_process_frames(1)
	wizard.start()
	assert_eq(wizard.choice_buttons.size(), 3)
	assert_eq(wizard.current_screen(), TerrainCreationWizard.SCREEN_CHOICE)
	# Avec des tuiles : aucune illustration demandée, bouton « Créer et peindre ».
	wizard._on_choice_pressed(1)
	assert_eq(wizard.current_screen(), TerrainCreationWizard.SCREEN_DETAILS)
	assert_false(wizard.image_row.visible)
	assert_eq(wizard.confirm_button.text, "Créer et peindre")
	assert_false(wizard.confirm_button.disabled)
	# Depuis une illustration : le bouton change et l'image devient obligatoire.
	wizard._on_choice_pressed(0)
	assert_true(wizard.image_row.visible)
	assert_eq(wizard.confirm_button.text, "Créer et aligner l'illustration")
	assert_true(wizard.confirm_button.disabled)
	assert_string_contains(wizard.blocking_label.text, "illustration")
	# Les réglages techniques n'apparaissent qu'en mode avancé.
	assert_false(wizard.advanced_box.visible)
	wizard.set_advanced(true)
	assert_true(wizard.advanced_box.visible)


func test_26_validation_cards_are_actionable_and_auto_fix_is_undoable() -> void:
	var studio := _studio()
	var arena := _valid_arena()
	studio._set_arena(arena, true, "terrain_validation_cards")
	studio.show_editor()
	# Erreur déterministe : un point de départ posé sur la bordure.
	var border := studio.arena.border_cells()
	assert_false(border.is_empty())
	var before := studio.arena.to_snapshot()
	studio.arena.spawns[0].cell = border[0]
	studio._commit_change("Poser un départ sur la bordure", before, studio.arena.to_snapshot())
	var report := studio.validate_arena()
	assert_false(report.is_valid())
	assert_gt(studio.validation_panel.card_count(), 0)
	var target: ArenaValidationMessage = null
	for message in report.messages:
		if ArenaValidationFixService.can_fix(message):
			target = message
			break
	assert_not_null(target, "Une correction automatique sûre doit être proposée.")
	var history_index := studio.edit_session.history.get_current_index()
	studio._on_validation_auto_fix(target)
	assert_gt(studio.edit_session.history.get_current_index(), history_index)
	assert_true(studio.edit_session.history.can_undo(), "La correction est annulable.")
	studio.edit_session.history.undo()
	assert_eq(studio.edit_session.history.get_current_index(), history_index)


func test_27_validation_only_offers_deterministic_and_safe_fixes() -> void:
	# Les suggestions de navigation ne doivent jamais proposer une correction.
	for code in ["select_isolated_cells", "select_chokepoints", "restart_calibration"]:
		var message := ArenaValidationMessage.new()
		message.suggested_fix = StringName(code)
		assert_false(ArenaValidationFixService.can_fix(message))
	for code in ["create_border", "make_border_non_playable", "move_spawn_to_nearest_valid"]:
		var message := ArenaValidationMessage.new()
		message.suggested_fix = StringName(code)
		assert_true(ArenaValidationFixService.can_fix(message))
		assert_false(ArenaValidationFixService.fix_label(message).is_empty())
	# Le déplacement d'un point de départ est déterministe : deux exécutions
	# identiques donnent la même case.
	var first := _spawn_fix_result()
	var second := _spawn_fix_result()
	assert_eq(first, second)


func test_28_contextual_guidance_replaces_the_twenty_two_page_tour() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	studio.set_current_step(TerrainWorkflowService.Step.FLOORS)
	await wait_process_frames(1)
	assert_true(studio.guidance_panel.visible)
	assert_string_contains(studio.guidance_panel.step_label.text, "Étape 3")
	assert_string_contains(studio.guidance_panel.step_label.text, "Sols")
	assert_string_contains(studio.guidance_panel.instruction_label.text, "Clic gauche")
	assert_eq(studio.guidance_panel.continue_button.text, "Continuer")
	# Le guidage se masque sans bloquer les outils.
	studio.set_guidance_visible(false)
	assert_false(studio.guidance_panel.visible)
	assert_false(studio.canvas.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	studio.set_guidance_visible(true)
	assert_true(studio.guidance_panel.visible)
	# Retour à l'étape précédente.
	studio._on_guidance_previous()
	assert_eq(studio.current_step, TerrainWorkflowService.Step.SHAPE)
	studio._on_guidance_continue()
	assert_eq(studio.current_step, TerrainWorkflowService.Step.FLOORS)
	# La visite complète reste consultable comme aide.
	assert_not_null(studio.guided_tour)
	assert_gt(ArenaStudioGuidedTour.PAGES.size(), 0)


func test_29_floor_palette_separates_permanent_floors_from_temporary_surfaces() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.set_current_step(TerrainWorkflowService.Step.FLOORS)
	await wait_process_frames(1)
	assert_not_null(studio.floor_palette)
	assert_gt(studio.floor_palette.buttons.size(), 3)
	for terrain_id in studio.floor_palette.buttons:
		var button := studio.floor_palette.buttons[terrain_id] as Button
		assert_false(button.tooltip_text.is_empty(), "Chaque sol porte une infobulle.")
		var definition := ArenaCatalogService.terrain(terrain_id)
		assert_not_null(definition)
		assert_string_contains(button.tooltip_text, definition.display_name)
	assert_string_contains(
		studio.floor_palette.temporary_label.text, "SURFACES TEMPORAIRES"
	)
	assert_string_contains(
		studio.floor_palette.temporary_label.text, "pendant le combat"
	)


func test_30_destination_is_absent_from_construction_and_present_in_finalize() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	_size_studio(studio, 1600, 900)
	studio.set_current_step(TerrainWorkflowService.Step.FLOORS)
	await wait_process_frames(1)
	assert_false(
		studio.destination_panel.is_visible_in_tree(),
		"La destination de salle ne doit pas occuper l'inspecteur pendant la construction."
	)
	studio.set_current_step(TerrainWorkflowService.Step.FINALIZE)
	await wait_process_frames(1)
	assert_true(
		studio.destination_panel.is_visible_in_tree(),
		"La destination apparaît à l'étape Tester et intégrer."
	)


func test_31_panel_state_is_persisted_outside_business_resources() -> void:
	assert_true(TerrainStudioUiStateService.STATE_PATH.begins_with("user://"))
	var state := TerrainStudioUiStateService.default_state()
	for key in state:
		assert_false(
			state[key] is Resource,
			"L'état d'interface ne doit sérialiser aucune Resource métier."
		)
	var studio := _studio()
	_open_forest(studio)
	studio.set_guided(false)
	studio.set_current_step(TerrainWorkflowService.Step.VERIFY)
	var snapshot := studio.get_workspace_state()
	assert_false(bool(snapshot.guided))
	assert_eq(int(snapshot.step), TerrainWorkflowService.Step.VERIFY)
	assert_true(snapshot.has("guidance_visible"))


# --- Utilitaires ------------------------------------------------------------

func _studio() -> ArenaStudioMain:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	return studio


## Un Control ancré en plein cadre voit sa taille réécrite après _ready() :
## on repasse en ancrage haut-gauche avant de fixer une résolution de test.
func _size_studio(studio: ArenaStudioMain, width: float, height: float) -> void:
	studio.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	studio.size = Vector2(width, height)
	studio._apply_responsive_layout()


func _is_scrollable(studio: ArenaStudioMain, control: Control) -> bool:
	var node := control.get_parent()
	while node != null and node != studio:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


func _open_forest(studio: ArenaStudioMain) -> void:
	var source := load(FOREST_PATH) as ArenaDefinition
	if source == null:
		return
	studio._set_arena(source, false, "terrain_refonte_forest")
	studio.show_editor()


func _valid_arena() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Terrain de contrat", "terrain_de_contrat")
	arena.background_path = "res://asset/map/painted/room_01_forest/forest_background_v2.webp"
	arena.source_image_size = Vector2i(1376, 768)
	arena.grid_size = Vector2i(10, 8)
	arena.grid_origin = Vector2(688, 164)
	arena.axis_x = Vector2(34.4, 17.1)
	arena.axis_y = Vector2(-34.2, 17.0)
	arena.calibration_cells = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	arena.calibration_pixels = [
		arena.grid_origin,
		arena.grid_origin + arena.axis_x,
		arena.grid_origin + arena.axis_y,
	]
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	return arena


func _spawn_fix_result() -> Vector2i:
	var arena := _valid_arena()
	var border := arena.border_cells()
	arena.spawns[0].cell = border[0]
	var message := ArenaValidationMessage.new()
	message.suggested_fix = &"move_spawn_to_nearest_valid"
	message.cell = border[0]
	var result := ArenaValidationFixService.apply(arena, message)
	return arena.spawns[0].cell if bool(result.get("ok", false)) else Vector2i(-1, -1)
