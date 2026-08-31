extends GutTest

## Contrat de la refonte du Studio Terrain.
##
## Chaque test correspond à un point du cahier des charges validé :
## accès Nouveau/Ouvrir dans le vrai StudioWorkspace, mode guidé par défaut et
## réellement masquant, conservation de la session au changement de mode, rail
## d'outils permanent, checklist non bloquante, bibliothèque spatiale,
## raccourcis réellement implémentés, parcours clavier, inspecteur accessible
## sous 1 400 px, contrats brouillon/test/intégration, test sans
## mutation de source, rollback de sauvegarde, projection runtime non mutante,
## transitions dirty, intégration UPDATE, focus/détachement et runner de
## captures.

const FOREST_PATH := "res://data/arenas/room_01_forest.tres"
const CAPTURE_RUNNER := "res://addons/dungeon_draft_arena_studio/test/terrain_studio_capture_runner.gd"
const GridAlignmentService = preload(
	"res://addons/dungeon_draft_arena_studio/services/terrain_grid_alignment_service.gd"
)
const GridAlignmentPanel = preload(
	"res://addons/dungeon_draft_arena_studio/ui/terrain/terrain_grid_alignment_panel.gd"
)
const TerrainTypeSaveTransaction = preload(
	"res://addons/dungeon_draft_arena_studio/services/arena_terrain_type_save_transaction_service.gd"
)
const TERRAIN_TYPE_TEST_ROOT := (
	"user://dungeon_draft_studio/tests/terrain_type_transaction"
)


func before_each() -> void:
	_remove_user_tree(TERRAIN_TYPE_TEST_ROOT)
	ArenaValidator.clear_cache()
	ArenaVisualAssembler.clear_inspection_cache()
	ArenaTerrainRenderPlanService.clear_cache()
	ArenaTacticalMetricsService.clear_cache()
	# L'état d'interface est volontairement persistant entre deux sessions :
	# chaque test repart donc explicitement des valeurs par défaut.
	TerrainStudioUiStateService.clear_cache()
	TerrainStudioUiStateService.save_state(TerrainStudioUiStateService.default_state())


func after_each() -> void:
	_remove_user_tree(TERRAIN_TYPE_TEST_ROOT)


# --- 1. Nouveau / Ouvrir accessibles depuis le vrai StudioWorkspace ---------

func test_01_new_and_open_are_reachable_inside_the_real_workspace() -> void:
	var workspace := StudioWorkspace.new()
	add_child_autofree(workspace)
	await wait_process_frames(3)
	var terrain := workspace.arena_studio
	assert_not_null(terrain)
	# L'hôte masque la barre interne historique : c'est le constat TERRAIN-01.
	assert_false(terrain.top_bar.visible)
	# Le shell compact remplace l'en-tête Terrain dupliqué et garde Accueil
	# directement visible, sans enfouir la sortie dans un menu.
	assert_false(terrain.header_bar.visible)
	assert_not_null(workspace.home_button)
	assert_true(workspace.home_button.is_visible_in_tree())
	workspace.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	workspace.size = Vector2(1280, 720)
	workspace._apply_toolbar_responsive()
	assert_eq(workspace.home_button.text, "Accueil")
	assert_true(workspace.home_button.is_visible_in_tree())
	# L'accueil expose exactement les trois intentions nominales.
	assert_true(terrain.is_home_visible())
	assert_not_null(terrain.home_panel.open_card)
	assert_not_null(terrain.home_panel.image_card)
	assert_not_null(terrain.home_panel.tiles_card)


func test_02_tab_is_named_terrains_with_a_readable_subtitle() -> void:
	assert_eq(TerrainVocabulary.TAB_TITLE, "TERRAINS")
	assert_eq(TerrainVocabulary.TAB_SUBTITLE, "Construire la zone tactique d'une salle")
	var workspace := StudioWorkspace.new()
	add_child_autofree(workspace)
	await wait_process_frames(3)
	assert_eq(workspace.tabs.get_tab_title(0), "TERRAINS")
	assert_eq(workspace.tabs.get_tab_tooltip(0), TerrainVocabulary.TAB_SUBTITLE)


func test_02b_calibration_model_never_participates_in_the_toolbar_layout() -> void:
	var workspace := StudioWorkspace.new()
	add_child_autofree(workspace)
	await wait_process_frames(3)
	workspace.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	workspace.size = Vector2(1920, 1080)
	workspace.arena_studio.set_guided(false)
	workspace._refresh_history_controls()
	workspace._apply_toolbar_responsive()
	assert_false(workspace.workspace_preset_option.visible)
	assert_eq(workspace.workspace_preset_option.get_parent(), workspace)
	assert_eq(workspace.domain_buttons[3].text, "LAB VFX")
	assert_eq(workspace.save_button.text, "Enregistrer le brouillon")
	assert_eq(workspace.produce_button.text, "Intégrer à la partie")
	workspace._rebuild_window_menu()
	assert_eq(workspace.window_menu_button.get_popup().get_item_text(4), "Calibration")


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


# --- 5. Les outils restent libres et la checklist ne navigue pas ------------

func test_06_category_rail_replaces_generic_tools_and_step_navigation() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.validate_arena()
	assert_null(studio.workflow_rail)
	assert_eq(studio.tool_palette.category_buttons.size(), 4)
	for category in [
		TerrainToolPalette.CATEGORY_SELECTION,
		TerrainToolPalette.CATEGORY_GRID,
		TerrainToolPalette.CATEGORY_ELEMENTS,
		TerrainToolPalette.CATEGORY_ILLUSTRATION,
	]:
		assert_true(studio.tool_palette.category_buttons.has(category))
	for tool in studio.tool_palette.tool_buttons:
		var button := studio.tool_palette.tool_buttons[tool] as Button
		assert_false(button.disabled)
	var rail_texts := PackedStringArray()
	for button in studio.tool_palette.find_children("*", "Button", true, false):
		rail_texts.append((button as Button).text)
	for forbidden in ["Peindre", "Obstacle", "Placer", "Déplacer la vue"]:
		assert_false(rail_texts.has(forbidden))
	assert_false(studio.tool_palette.tool_buttons.has(ArenaStudioCanvas.Tool.PAN))
	assert_not_null(studio.checklist_panel)
	assert_eq(studio.checklist_panel._entries.size(), 5)
	if studio.bottom_drawer_content.visible:
		studio._toggle_bottom_drawer()
	assert_false(studio.checklist_panel.is_visible_in_tree())
	# La compatibilité avec l'ancien numéro d'étape ne pilote plus les outils.
	studio._on_tool_selected(ArenaStudioCanvas.Tool.OBSTACLE)
	studio.set_current_step(TerrainWorkflowService.Step.FINALIZE)
	assert_eq(studio.current_step, TerrainWorkflowService.Step.FINALIZE)
	assert_eq(studio.canvas.active_tool, ArenaStudioCanvas.Tool.OBSTACLE)


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
	await wait_process_frames(1)
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


# --- 8. Les propriétés restent superposées à toutes les résolutions --------

func test_11_properties_drawer_never_becomes_a_permanent_column() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	_size_studio(studio, 1280, 720)
	await wait_process_frames(1)
	assert_false(studio.right_panel.visible)
	assert_eq(studio.right_panel.get_parent(), studio.inspector_overlay_host)
	assert_eq(studio.inspector_drawer_button.text, "Propriétés")
	assert_true(studio.inspector_is_reachable())
	var canvas_width := studio.view_stack.size.x
	studio.toggle_inspector_drawer()
	await wait_process_frames(1)
	assert_true(studio.right_panel.visible)
	assert_almost_eq(studio.view_stack.size.x, canvas_width, 0.1)
	studio.toggle_inspector_drawer()
	_size_studio(studio, 1920, 1080)
	await wait_process_frames(1)
	assert_false(studio.right_panel.visible)
	assert_eq(studio.right_panel.get_parent(), studio.inspector_overlay_host)
	assert_true(studio.inspector_drawer_button.visible)
	var wide_canvas_width := studio.view_stack.size.x
	studio.toggle_inspector_drawer()
	await wait_process_frames(1)
	assert_almost_eq(studio.view_stack.size.x, wide_canvas_width, 0.1)


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
	var context := StudioProjectContext.new()
	assert_true(bool(context.initialize().get("ok", false)))
	var direct := ArenaStudioMain.new()
	direct.auto_load_initial_arena = false
	direct.setup(null, null, context, StudioReferenceGraphService.new())
	add_child_autofree(direct)
	await wait_process_frames(2)
	direct._create_with_tiles()
	var discarded_key := direct.edit_session.session_key
	assert_true(direct.dirty)
	direct.request_home()
	assert_true(context.has_pending_transition())
	assert_false(direct.is_home_visible())
	context.resolve_pending_transition(StudioProjectContext.ACTION_CANCEL)
	assert_false(direct.is_home_visible())
	assert_not_null(direct.edit_session)
	direct.request_home()
	context.resolve_pending_transition(StudioProjectContext.ACTION_DISCARD)
	assert_true(direct.is_home_visible())
	assert_null(direct.edit_session)
	assert_false(direct._sessions.has(discarded_key))
	direct._create_with_tiles()
	var draft_key := direct.edit_session.session_key
	var draft_arena_id := direct.arena.arena_id
	direct.request_home()
	context.resolve_pending_transition(StudioProjectContext.ACTION_DRAFT)
	assert_true(direct.is_home_visible())
	assert_true(direct._sessions.has(draft_key))
	assert_true(direct._available_recent_documents().any(func(value):
		return str((value as Dictionary).get("session_key", "")) == draft_key
	))
	ArenaSerializer.remove_recovery(draft_arena_id)


func test_20b_home_treats_a_terrain_type_only_edit_as_dirty() -> void:
	var context := StudioProjectContext.new()
	assert_true(bool(context.initialize().get("ok", false)))
	var direct := ArenaStudioMain.new()
	direct.auto_load_initial_arena = false
	direct.setup(null, null, context, StudioReferenceGraphService.new())
	add_child_autofree(direct)
	await wait_process_frames(2)
	_open_forest(direct)
	assert_false(direct.dirty)
	var fixture := _terrain_type_fixture("home_type_only")
	direct._terrain_type_source = fixture.source as ArenaTerrainDefinition
	direct._terrain_type_working = TerrainTypeSaveTransaction.create_working_copy(
		direct._terrain_type_source
	)
	direct._terrain_type_opening_state = TerrainTypeSaveTransaction.capture_opening_state(
		direct._terrain_type_source, _terrain_type_test_options(str(fixture.root))
	)
	direct._terrain_type_working.walkable = not direct._terrain_type_source.walkable
	direct._on_dirty_state_changed(false)
	assert_true(context.is_dirty(&"arena"))
	direct.request_home()
	assert_true(context.has_pending_transition())
	assert_false(direct.is_home_visible())
	assert_true(context.resolve_pending_transition(StudioProjectContext.ACTION_CANCEL).ok)
	direct._reset_terrain_type_session()


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


func test_25_home_launches_both_creations_without_obsolete_screens() -> void:
	var studio := _studio()
	await wait_process_frames(1)
	assert_false(FileAccess.file_exists(
		"res://addons/dungeon_draft_arena_studio/ui/terrain/terrain_creation_wizard.gd"
	))
	studio._create_with_tiles()
	assert_true(studio.editor_screen.visible)
	assert_eq(studio.arena.grid_size, Vector2i(10, 8))
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.MODULAR)
	studio._create_from_image_path(
		"res://asset/map/painted/room_01_forest/forest_background_source.png"
	)
	assert_true(studio.editor_screen.visible)
	assert_eq(studio.arena.grid_size, Vector2i(3, 3))
	assert_eq(studio.arena.visual_mode, ArenaDefinition.VisualMode.PAINTED)
	assert_false(studio.arena.background_path.is_empty())


func test_25b_grid_alignment_uses_node2d_style_settings_and_round_trips() -> void:
	var input := {
		"grid_size": Vector2i(14, 9),
		"position": Vector2(321.5, 208.25),
		"rotation_degrees": 12.0,
		"scale": Vector2(0.95, 1.15),
		"skew_degrees": -18.0,
	}
	var result: Dictionary = GridAlignmentService.snapshot_from_settings(input)
	assert_true(bool(result.get("ok", false)))
	var arena := ArenaDefinition.new()
	arena.grid_size = input.grid_size
	var snapshot := result.get("snapshot") as GridTransformSnapshot
	snapshot.apply_to(arena)
	var resolved: Dictionary = GridAlignmentService.settings_from_arena(arena)
	assert_almost_eq((resolved.position as Vector2).x, 321.5, 0.001)
	assert_almost_eq((resolved.position as Vector2).y, 208.25, 0.001)
	assert_almost_eq(float(resolved.rotation_degrees), 12.0, 0.001)
	assert_almost_eq((resolved.scale as Vector2).x, 0.95, 0.001)
	assert_almost_eq((resolved.scale as Vector2).y, 1.15, 0.001)
	assert_almost_eq(float(resolved.skew_degrees), -18.0, 0.001)
	var round_trip: Dictionary = GridAlignmentService.snapshot_from_settings(resolved)
	assert_true(bool(round_trip.get("ok", false)))
	assert_true(snapshot.is_equal_to(round_trip.get("snapshot"), 0.001))


func test_25c_new_illustration_grid_is_centered_and_panel_exposes_all_settings() -> void:
	var centered: GridTransformSnapshot = GridAlignmentService.centered_snapshot(
		Vector2i(1280, 720), Vector2i(10, 8)
	)
	var grid_center: Vector2 = centered.origin \
		+ 4.5 * centered.axis_x + 3.5 * centered.axis_y
	assert_almost_eq(grid_center.x, 640.0, 0.001)
	assert_almost_eq(grid_center.y, 360.0, 0.001)
	var panel: VBoxContainer = GridAlignmentPanel.new()
	add_child_autofree(panel)
	await wait_process_frames(1)
	for field in [
		panel.width_spin, panel.height_spin, panel.position_x_spin,
		panel.position_y_spin, panel.rotation_spin, panel.scale_x_spin,
		panel.scale_y_spin, panel.skew_spin,
	]:
		assert_not_null(field)
	assert_null(panel.find_child("TerrainGridApplySettings", true, false))
	assert_null(panel.find_child("TerrainGridConfirmAlignment", true, false))


func test_25d_grid_settings_update_immediately_and_create_one_history_action() -> void:
	var studio := _studio()
	studio._set_arena(_valid_arena(), true, "terrain_live_grid_settings")
	studio.set_current_step(TerrainWorkflowService.Step.SCENERY)
	await wait_process_frames(1)
	var history_before := studio.edit_session.history.get_current_index()
	var origin_before := studio.arena.grid_origin
	var position_x: SpinBox = studio.grid_alignment_panel.position_x_spin
	position_x.value = position_x.value + 12.0
	assert_almost_eq(position_x.value, origin_before.x + 12.0, 0.001)
	await wait_process_frames(1)
	assert_almost_eq(studio.arena.grid_origin.x, origin_before.x + 12.0, 0.001)
	assert_eq(studio.edit_session.history.get_current_index(), history_before)
	await wait_seconds(0.5)
	assert_eq(studio.edit_session.history.get_current_index(), history_before + 1)
	assert_eq(
		studio.edit_session.history.get_undo_action_name(),
		"Ajuster la grille sur l'illustration"
	)


func test_25e_library_is_resizable_tall_enough_and_not_reset_by_responsive_updates() -> void:
	TerrainStudioUiStateService.set_value("library_height", 236)
	var studio := _studio()
	studio._set_arena(_valid_arena(), true, "terrain_compact_scenery")
	studio.set_guided(true)
	studio.set_current_step(TerrainWorkflowService.Step.SCENERY)
	studio.show_editor()
	_size_studio(studio, 1280, 720)
	studio._on_palette_action(&"show_elements")
	await wait_process_frames(1)
	assert_not_null(studio.library_panel)
	assert_true(studio.canvas_library_split is VSplitContainer)
	assert_eq(studio.library_panel.get_parent(), studio.canvas_library_split)
	assert_eq(studio.view_stack.get_parent(), studio.canvas_library_split)
	assert_gte(studio.library_panel.custom_minimum_size.y, 160.0)
	studio.library_panel.show()
	studio._restore_library_height(236)
	await wait_process_frames(2)
	assert_between(int(round(studio.library_panel.size.y)), 220, 260)
	var chosen_offset := studio.canvas_library_split.split_offsets[0]
	studio._on_library_split_dragged(chosen_offset)
	_size_studio(studio, 1280, 720)
	await wait_process_frames(1)
	assert_eq(studio.canvas_library_split.split_offsets[0], chosen_offset)
	_size_studio(studio, 1920, 1080)
	await wait_process_frames(1)
	assert_eq(studio.canvas_library_split.split_offsets[0], chosen_offset)
	assert_between(int(TerrainStudioUiStateService.get_value("library_height", 0)), 220, 260)
	assert_false(studio.tool_palette.contract_label.visible)
	assert_eq(studio.library_panel.filter_buttons.size(), 8)
	assert_gt(studio.library_panel.cards.get_child_count(), 0)


func test_25f_guided_illustration_opens_a_direct_image_chooser() -> void:
	var studio := _studio()
	studio._set_arena(_valid_arena(), true, "terrain_direct_illustration")
	studio.set_guided(true)
	studio._request_backdrop_change()
	await wait_process_frames(1)
	assert_true(studio.guided_backdrop_image_dialog.visible)
	assert_false(studio.backdrop_dialog.visible)
	assert_string_contains(studio.guided_backdrop_image_dialog.title, "illustration")
	studio.guided_backdrop_image_dialog.hide()


func test_25g_grid_owns_transform_and_multipoint_is_advanced_only() -> void:
	var studio := _studio()
	studio._set_arena(_valid_arena(), true, "terrain_grid_categories")
	studio.set_guided(true)
	await wait_process_frames(1)
	var palette := studio.tool_palette
	var transform := palette.tool_buttons[ArenaStudioCanvas.Tool.TRANSFORM_GRID] as Button
	var multipoint := palette.tool_buttons[ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS] as Button
	assert_eq(transform.get_parent(), palette.category_panels[TerrainToolPalette.CATEGORY_GRID])
	assert_eq(multipoint.get_parent(), palette.category_panels[TerrainToolPalette.CATEGORY_GRID])
	assert_false(multipoint.visible)
	var illustration := palette.category_panels[TerrainToolPalette.CATEGORY_ILLUSTRATION] as Control
	var illustration_texts := PackedStringArray()
	for button in illustration.find_children("*", "Button", true, false):
		illustration_texts.append((button as Button).text)
	assert_eq(illustration_texts, PackedStringArray(["Changer l'image"]))
	studio._on_tool_selected(ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS)
	assert_ne(studio.canvas.active_tool, ArenaStudioCanvas.Tool.CALIBRATION_ANCHORS)
	studio.set_guided(false)
	assert_true(multipoint.visible)
	studio._on_tool_selected(ArenaStudioCanvas.Tool.TRANSFORM_GRID)
	assert_eq(studio.inspector_panel.header_label.text, "PROPRIÉTÉS — Grille")
	assert_false((studio.inspector_panel.sections[&"selection"].container as Control).visible)
	assert_true((studio.inspector_panel.sections[&"shape"].container as Control).visible)


func test_25g_vortex_choices_are_explicit_and_impulse_finishes_after_one_cell() -> void:
	var studio := _studio()
	studio._set_arena(_valid_arena(), true, "terrain_vortex_intents")
	studio.set_guided(true)
	studio.set_current_step(TerrainWorkflowService.Step.CONTENT)
	await wait_process_frames(1)
	assert_null(studio.workflow_rail)
	for stable_id in [&"vortex_impulse", &"vortex_portal_two", &"vortex_portal_multi"]:
		var catalog_entry := TerrainPlaceableCatalogService.entry_by_id(
			studio.arena, stable_id, true
		)
		assert_false(catalog_entry.is_empty())
		assert_false(str(catalog_entry.tooltip).is_empty())
	var impulse := TerrainPlaceableCatalogService.entry_by_id(
		studio.arena, &"vortex_impulse", true
	)
	studio._on_library_placeable_selected(impulse)
	assert_true(studio._placement_session.active)
	assert_eq(studio.canvas.active_tool, ArenaStudioCanvas.Tool.SPAWN)
	studio._on_stroke_started("Placer une case d'impulsion")
	studio._on_cells_edit_requested([Vector2i(2, 2)], false)
	studio._on_stroke_finished("Placer une case d'impulsion")
	await wait_process_frames(2)
	assert_eq(studio.arena.vortex_networks.size(), 1)
	assert_eq(studio.arena.vortex_networks[0].unique_cells().size(), 1)
	assert_false(studio._placement_session.active)


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


func test_28_checklist_and_problems_only_appear_in_detailed_validation() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	studio.set_current_step(TerrainWorkflowService.Step.FLOORS)
	await wait_process_frames(1)
	assert_null(studio.guidance_panel)
	assert_not_null(studio.checklist_panel)
	assert_false(studio.checklist_panel.is_visible_in_tree())
	var drawer_tabs := studio.bottom_drawer_content as TabContainer
	assert_not_null(drawer_tabs)
	drawer_tabs.current_tab = 2
	studio._open_validation_drawer()
	await wait_process_frames(1)
	assert_eq(drawer_tabs.current_tab, 0)
	assert_true(studio.checklist_panel.is_visible_in_tree())
	assert_true(studio.checklist_panel.entries_box.visible)
	studio._toggle_bottom_drawer()
	if studio.validation_report.error_count() == 0 \
			and studio.validation_report.warning_count() == 0:
		assert_true(studio.bottom_drawer_button.text.begins_with("✓ Validation réussie"))
	else:
		assert_true(studio.bottom_drawer_button.text.begins_with("⚠ Validation"))
	assert_false(studio.canvas.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	studio._on_tool_selected(ArenaStudioCanvas.Tool.OBSTACLE)
	assert_eq(studio.canvas.active_tool, ArenaStudioCanvas.Tool.OBSTACLE)
	# La visite complète reste consultable comme aide facultative.
	assert_not_null(studio.guided_tour)
	assert_gt(ArenaStudioGuidedTour.PAGES.size(), 0)


func test_29_library_unifies_all_placeable_families_and_keeps_tooltips() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.set_current_step(TerrainWorkflowService.Step.FLOORS)
	await wait_process_frames(1)
	assert_null(studio.floor_palette)
	assert_not_null(studio.library_panel)
	var families := {}
	for entry in studio.library_panel._entries:
		families[int(entry.family)] = true
		assert_false(str(entry.tooltip).is_empty())
	for family in TerrainPlaceableDefinition.Family.values():
		assert_true(families.has(family), "Chaque famille doit être représentée.")
	studio.library_panel.search_edit.text = "impulsion"
	await wait_process_frames(1)
	assert_not_null(studio.library_panel.find_child("TerrainLibraryCard_vortex_impulse", true, false))


func test_29b_floor_cards_own_selection_and_compact_actions() -> void:
	var studio := _studio()
	_open_forest(studio)
	await wait_process_frames(1)
	assert_false(studio.terrain_option.visible)
	assert_eq(studio.terrain_option.get_parent(), studio)
	assert_null(studio.inspector_panel.find_child("TerrainFloorOption", true, false))
	assert_not_null(studio.library_panel.find_child("TerrainLibraryCard_floor_water", true, false))
	var menu := studio.library_panel.find_child(
		"TerrainLibraryMenu_floor_water", true, false
	) as MenuButton
	assert_not_null(menu)
	assert_eq(menu.get_popup().get_item_text(0), "Modifier ce type de tuile…")
	assert_eq(menu.get_popup().get_item_text(1), "Remplacer partout ce sol…")


func test_29c_selecting_or_painting_never_opens_properties_automatically() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	studio.set_inspector_drawer_open(false)
	var water := TerrainPlaceableCatalogService.entry_by_id(studio.arena, &"floor:water", true)
	studio._on_library_placeable_selected(water)
	assert_false(studio.right_panel.visible)
	studio._on_stroke_started("Peindre de l’eau")
	studio._on_cells_edit_requested([Vector2i(2, 2)], false)
	studio._on_stroke_finished("Peindre de l’eau")
	assert_false(studio.right_panel.visible)


func test_29d_terrain_type_editor_is_a_cancelable_isolated_working_copy() -> void:
	var studio := _studio()
	_open_forest(studio)
	var water := TerrainPlaceableCatalogService.entry_by_id(studio.arena, &"floor:water", true)
	var source := ArenaCatalogService.terrain(&"water")
	var source_walkable := source.walkable
	studio._on_library_card_action_requested(&"edit_terrain_type", water)
	assert_true(studio.right_panel.visible)
	assert_true((studio.inspector_panel.sections[&"tile_type"].container as Control).visible)
	assert_false((studio.inspector_panel.sections[&"selection"].container as Control).visible)
	assert_false((studio.inspector_panel.sections[&"shape"].container as Control).visible)
	assert_not_same(studio._terrain_type_working, source)
	assert_not_same(studio._terrain_type_working.unit_effect, source.unit_effect)
	studio.terrain_type_walkable_check.button_pressed = not source_walkable
	assert_eq(studio._terrain_type_working.walkable, not source_walkable)
	assert_eq(source.walkable, source_walkable)
	studio._show_terrain_type_save_choices()
	assert_false(studio.terrain_type_shared_button.disabled)
	assert_null(studio.terrain_type_duplicate_button)
	assert_string_contains(studio.terrain_type_save_dialog.dialog_text, "ArenaTerrainDefinition")
	assert_string_contains(studio.terrain_type_save_dialog.dialog_text, "transactionnelle")
	assert_string_contains(studio.terrain_type_save_dialog.dialog_text, "variante n’est pas proposée")
	studio.terrain_type_save_dialog.hide()
	studio._cancel_terrain_type_edit()
	assert_null(studio._terrain_type_working)
	assert_eq(source.walkable, source_walkable)


func test_29f_terrain_type_transaction_writes_and_reloads_both_user_resources() -> void:
	var fixture := _terrain_type_fixture("success")
	var source := fixture.source as ArenaTerrainDefinition
	var working := _terrain_type_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	assert_true(bool(opening.get("ok", false)), str(opening))
	var terrain_uid_before := ResourceLoader.get_resource_uid(str(fixture.terrain_path))
	var effect_uid_before := ResourceLoader.get_resource_uid(str(fixture.effect_path))
	assert_ne(terrain_uid_before, ResourceUID.INVALID_ID)
	assert_ne(effect_uid_before, ResourceUID.INVALID_ID)
	assert_eq(
		_serialized_resource_uid(str(fixture.terrain_path)), terrain_uid_before
	)
	assert_eq(
		_serialized_resource_uid(str(fixture.effect_path)), effect_uid_before
	)
	working.walkable = false
	working.movement_cost = 4
	working.unit_effect.damage = 42
	working.unit_effect.dangerous_for_ai = true
	var result := TerrainTypeSaveTransaction.save(
		source, working, opening, options
	)
	assert_true(bool(result.get("ok", false)), str(result))
	assert_false(bool(result.get("rolled_back", true)))
	for path in result.saved_paths as PackedStringArray:
		assert_true(path.begins_with(TERRAIN_TYPE_TEST_ROOT + "/"), path)
	var reloaded := ResourceLoader.load(
		str(fixture.terrain_path), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	assert_not_null(reloaded)
	assert_false(reloaded.walkable)
	assert_eq(reloaded.movement_cost, 4)
	assert_not_null(reloaded.unit_effect)
	assert_eq(reloaded.unit_effect.damage, 42)
	assert_true(reloaded.unit_effect.dangerous_for_ai)
	assert_eq(reloaded.unit_effect.resource_path, str(fixture.effect_path))
	assert_eq(ResourceLoader.get_resource_uid(
		str(fixture.terrain_path)
	), terrain_uid_before)
	assert_eq(ResourceLoader.get_resource_uid(
		str(fixture.effect_path)
	), effect_uid_before)
	assert_eq(
		_serialized_resource_uid(str(fixture.terrain_path)), terrain_uid_before
	)
	assert_eq(
		_serialized_resource_uid(str(fixture.effect_path)), effect_uid_before
	)
	assert_eq(ResourceUID.get_id_path(terrain_uid_before), str(fixture.terrain_path))
	assert_eq(ResourceUID.get_id_path(effect_uid_before), str(fixture.effect_path))


func test_29g_terrain_type_transaction_refuses_an_external_effect_change() -> void:
	var fixture := _terrain_type_fixture("external_conflict")
	var source := fixture.source as ArenaTerrainDefinition
	var working := _terrain_type_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	working.unit_effect.damage = 23
	var external := _terrain_effect_copy(source.unit_effect)
	external.damage = 77
	assert_eq(ResourceSaver.save(external, str(fixture.effect_path)), OK)
	var external_hash := FileAccess.get_sha256(str(fixture.effect_path))
	var terrain_hash := FileAccess.get_sha256(str(fixture.terrain_path))
	var result := TerrainTypeSaveTransaction.save(
		source, working, opening, options
	)
	assert_false(bool(result.get("ok", true)))
	assert_eq(str(result.get("step", "")), "BLOCKED")
	assert_false(bool(result.get("rolled_back", true)))
	assert_eq(FileAccess.get_sha256(str(fixture.effect_path)), external_hash)
	assert_eq(FileAccess.get_sha256(str(fixture.terrain_path)), terrain_hash)
	assert_false((result.plan.conflicts as Array).is_empty())
	assert_eq(
		StringName((result.plan.conflicts[0] as Dictionary).code),
		&"EXTERNAL_MODIFICATION"
	)


func test_29h_terrain_type_transaction_rolls_back_both_files_byte_for_byte() -> void:
	var fixture := _terrain_type_fixture("rollback")
	var source := fixture.source as ArenaTerrainDefinition
	var working := _terrain_type_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	options["failure_step"] = "after_effect_commit"
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	var terrain_hash := FileAccess.get_sha256(str(fixture.terrain_path))
	var effect_hash := FileAccess.get_sha256(str(fixture.effect_path))
	var terrain_uid := ResourceLoader.get_resource_uid(str(fixture.terrain_path))
	var effect_uid := ResourceLoader.get_resource_uid(str(fixture.effect_path))
	working.transparent = false
	working.unit_effect.damage = 99
	var result := TerrainTypeSaveTransaction.save(
		source, working, opening, options
	)
	assert_false(bool(result.get("ok", true)))
	assert_true(bool(result.get("rolled_back", false)), str(result))
	assert_eq(FileAccess.get_sha256(str(fixture.terrain_path)), terrain_hash)
	assert_eq(FileAccess.get_sha256(str(fixture.effect_path)), effect_hash)
	assert_eq(ResourceLoader.get_resource_uid(str(fixture.terrain_path)), terrain_uid)
	assert_eq(ResourceLoader.get_resource_uid(str(fixture.effect_path)), effect_uid)


func test_29i_terrain_type_save_does_not_create_an_empty_effect() -> void:
	var fixture := _terrain_type_fixture("without_effect", false)
	var source := fixture.source as ArenaTerrainDefinition
	var working := _terrain_type_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	var plan := TerrainTypeSaveTransaction.plan(source, working, opening, options)
	assert_true(bool(plan.get("ok", false)), str(plan))
	assert_false(bool(plan.get("writes_effect", true)))
	working.walkable = false
	var result := TerrainTypeSaveTransaction.save(
		source, working, opening, options
	)
	assert_true(bool(result.get("ok", false)), str(result))
	assert_eq((result.saved_paths as PackedStringArray).size(), 1)
	assert_false(FileAccess.file_exists(str(fixture.derived_effect_path)))
	var reloaded := ResourceLoader.load(
		str(fixture.terrain_path), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	assert_not_null(reloaded)
	assert_false(reloaded.walkable)
	assert_null(reloaded.unit_effect)


func test_29j_terrain_type_dirty_working_copy_has_verified_user_recovery() -> void:
	var fixture := _terrain_type_fixture("working_recovery")
	var source := fixture.source as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	options["ui_state"] = {
		"base_texture_path": "res://missing_texture_for_recovery.png",
		"input_error": "Texture de base invalide",
	}
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	working.walkable = not source.walkable
	working.unit_effect.damage = source.unit_effect.damage + 17
	var saved := TerrainTypeSaveTransaction.save_working_recovery(
		source, working, opening, options
	)
	assert_true(bool(saved.get("ok", false)), str(saved))
	assert_true(str(saved.get("manifest_path", "")).begins_with(
		TERRAIN_TYPE_TEST_ROOT + "/"
	))
	var recovered := TerrainTypeSaveTransaction.load_working_recovery(
		source, opening, options
	)
	assert_true(bool(recovered.get("ok", false)), str(recovered))
	assert_true(bool(recovered.get("found", false)), str(recovered))
	var restored := recovered.working as ArenaTerrainDefinition
	assert_not_null(restored)
	assert_eq(restored.walkable, working.walkable)
	assert_eq(restored.unit_effect.damage, working.unit_effect.damage)
	assert_eq(str((recovered.ui_state as Dictionary).get(
		"base_texture_path", ""
	)), "res://missing_texture_for_recovery.png")
	assert_eq(FileAccess.get_sha256(str(fixture.terrain_path)), (
		(opening.files[str(fixture.terrain_path)] as Dictionary).sha256
	))
	assert_true(TerrainTypeSaveTransaction.clear_working_recovery(source, options))
	assert_false(FileAccess.file_exists(str(saved.manifest_path)))


func test_29k_interrupted_terrain_type_transaction_recovers_on_next_open() -> void:
	var fixture := _terrain_type_fixture("interrupted_recovery")
	var source := fixture.source as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	var terrain_hash := FileAccess.get_sha256(str(fixture.terrain_path))
	var effect_hash := FileAccess.get_sha256(str(fixture.effect_path))
	var terrain_uid := ResourceLoader.get_resource_uid(str(fixture.terrain_path))
	var effect_uid := ResourceLoader.get_resource_uid(str(fixture.effect_path))
	working.unit_effect.damage += 50
	options["failure_step"] = "interrupt_after_effect_rename"
	var interrupted := TerrainTypeSaveTransaction.save(
		source, working, opening, options
	)
	assert_false(bool(interrupted.get("ok", true)))
	assert_eq(str(interrupted.get("step", "")), "INJECTED_INTERRUPTION")
	assert_ne(FileAccess.get_sha256(str(fixture.effect_path)), effect_hash)
	options.erase("failure_step")
	var recovered := TerrainTypeSaveTransaction.recover_pending_transactions(options)
	assert_true(bool(recovered.get("ok", false)), str(recovered))
	assert_eq(int(recovered.get("recovered_count", 0)), 1)
	assert_eq(FileAccess.get_sha256(str(fixture.terrain_path)), terrain_hash)
	assert_eq(FileAccess.get_sha256(str(fixture.effect_path)), effect_hash)
	assert_eq(ResourceLoader.get_resource_uid(str(fixture.terrain_path)), terrain_uid)
	assert_eq(ResourceLoader.get_resource_uid(str(fixture.effect_path)), effect_uid)


func test_29n_ui_only_recovery_keeps_the_unchanged_shared_effect() -> void:
	var fixture := _terrain_type_fixture("ui_only_recovery")
	var source := fixture.source as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	options["ui_state"] = {
		"status_path": "res://missing_status_for_recovery.tres",
		"input_error": "Statut appliqué invalide",
	}
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	assert_false(TerrainTypeSaveTransaction.has_changes(source, working))
	var saved := TerrainTypeSaveTransaction.save_working_recovery(
		source, working, opening, options
	)
	assert_true(bool(saved.get("ok", false)), str(saved))
	var recovered := TerrainTypeSaveTransaction.load_working_recovery(
		source, opening, options
	)
	assert_true(bool(recovered.get("ok", false)), str(recovered))
	assert_true(bool(recovered.get("found", false)), str(recovered))
	var restored := recovered.working as ArenaTerrainDefinition
	assert_not_null(restored)
	assert_not_null(restored.unit_effect)
	assert_eq(
		TerrainTypeSaveTransaction.effect_fingerprint(restored.unit_effect),
		TerrainTypeSaveTransaction.effect_fingerprint(source.unit_effect)
	)
	assert_eq(str((recovered.ui_state as Dictionary).get(
		"input_error", ""
	)), "Statut appliqué invalide")


func test_29o_recovery_does_not_overwrite_a_post_rename_deletion() -> void:
	var fixture := _terrain_type_fixture("rename_then_external_delete")
	var source := fixture.source as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	working.unit_effect.damage += 33
	options["failure_step"] = "interrupt_after_effect_rename"
	var interrupted := TerrainTypeSaveTransaction.save(
		source, working, opening, options
	)
	assert_false(bool(interrupted.get("ok", true)))
	assert_eq(str(interrupted.get("step", "")), "INJECTED_INTERRUPTION")
	assert_eq(DirAccess.remove_absolute(
		ProjectSettings.globalize_path(str(fixture.effect_path))
	), OK)
	options.erase("failure_step")
	var recovered := TerrainTypeSaveTransaction.recover_pending_transactions(options)
	assert_false(bool(recovered.get("ok", true)), str(recovered))
	assert_false(FileAccess.file_exists(str(fixture.effect_path)))
	var failures := recovered.get("failures", []) as Array
	assert_false(failures.is_empty())
	assert_eq(str((failures[0] as Dictionary).get(
		"status", ""
	)), "ROLLBACK_CONFLICT")


func test_29p_commit_quarantine_preserves_a_racing_external_write() -> void:
	var fixture := _terrain_type_fixture("commit_quarantine_race")
	var source := fixture.source as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	var external_bytes := "external-during-commit".to_utf8_buffer()
	var hook_state := {"injected": false}
	options["before_target_quarantine_hook"] = func(
			source_path: String, _destination_path: String
		) -> void:
		if bool(hook_state.injected) or source_path != str(fixture.effect_path):
			return
		hook_state.injected = true
		var file := FileAccess.open(source_path, FileAccess.WRITE)
		assert_not_null(file)
		file.store_buffer(external_bytes)
		file.flush()
		file.close()
	working.unit_effect.damage += 9
	var result := TerrainTypeSaveTransaction.save(source, working, opening, options)
	assert_false(bool(result.get("ok", true)), str(result))
	assert_true(bool(hook_state.injected))
	assert_eq(FileAccess.get_file_as_bytes(str(fixture.effect_path)), external_bytes)
	assert_eq(StringName(result.get("rollback_status", &"")), &"ROLLBACK_CONFLICT")


func test_29q_rollback_quarantine_preserves_a_racing_external_write() -> void:
	var fixture := _terrain_type_fixture("rollback_quarantine_race")
	var source := fixture.source as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	var terrain_hash := FileAccess.get_sha256(str(fixture.terrain_path))
	var external_bytes := "external-during-rollback".to_utf8_buffer()
	var hook_state := {"injected": false}
	options["failure_step"] = "after_effect_commit"
	options["before_rollback_quarantine_hook"] = func(
			source_path: String, _destination_path: String
		) -> void:
		if bool(hook_state.injected) or source_path != str(fixture.effect_path):
			return
		hook_state.injected = true
		var file := FileAccess.open(source_path, FileAccess.WRITE)
		assert_not_null(file)
		file.store_buffer(external_bytes)
		file.flush()
		file.close()
	working.unit_effect.damage += 11
	var result := TerrainTypeSaveTransaction.save(source, working, opening, options)
	assert_false(bool(result.get("ok", true)), str(result))
	assert_true(bool(hook_state.injected))
	assert_eq(StringName(result.get("rollback_status", &"")), &"ROLLBACK_CONFLICT")
	assert_eq(FileAccess.get_file_as_bytes(str(fixture.effect_path)), external_bytes)
	assert_eq(FileAccess.get_sha256(str(fixture.terrain_path)), terrain_hash)


func test_29r_clear_and_terminal_journal_failures_are_explicit() -> void:
	var fixture := _terrain_type_fixture("terminal_failures")
	var source := fixture.source as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	var clear_options := options.duplicate(true)
	clear_options["test_fail_clear"] = true
	var clear_result := TerrainTypeSaveTransaction.save_working_recovery(
		source, working, opening, clear_options
	)
	assert_false(bool(clear_result.get("ok", true)), str(clear_result))
	assert_eq(str(clear_result.get("error", "")), "working_recovery_cleanup_failed")
	var terrain_hash := FileAccess.get_sha256(str(fixture.terrain_path))
	var effect_hash := FileAccess.get_sha256(str(fixture.effect_path))
	working.unit_effect.damage += 13
	options["failure_step"] = "close_journal"
	var result := TerrainTypeSaveTransaction.save(source, working, opening, options)
	assert_false(bool(result.get("ok", true)), str(result))
	assert_eq(StringName(result.get("status", &"")), &"ROLLBACK_JOURNAL_FAILED")
	assert_false(bool(result.get("transaction_terminal", true)))
	assert_eq(FileAccess.get_sha256(str(fixture.terrain_path)), terrain_hash)
	assert_eq(FileAccess.get_sha256(str(fixture.effect_path)), effect_hash)


func test_29s_original_neighbor_is_retained_when_target_is_raced() -> void:
	var fixture := _terrain_type_fixture("post_quarantine_race")
	var source := fixture.source as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	var original_hash := FileAccess.get_sha256(str(fixture.effect_path))
	var external_bytes := "external-after-quarantine".to_utf8_buffer()
	var hook_state := {"injected": false}
	options["after_target_quarantine_hook"] = func(
			target_path: String, _previous_path: String
		) -> void:
		if bool(hook_state.injected) or target_path != str(fixture.effect_path):
			return
		hook_state.injected = true
		var file := FileAccess.open(target_path, FileAccess.WRITE)
		assert_not_null(file)
		file.store_buffer(external_bytes)
		file.flush()
		file.close()
	working.unit_effect.damage += 17
	var result := TerrainTypeSaveTransaction.save(source, working, opening, options)
	assert_false(bool(result.get("ok", true)), str(result))
	assert_eq(StringName(result.get("rollback_status", &"")), &"ROLLBACK_CONFLICT")
	assert_eq(FileAccess.get_file_as_bytes(str(fixture.effect_path)), external_bytes)
	var cleanup_conflicts := result.cleanup.get("conflicts", []) as Array
	var retained := cleanup_conflicts.filter(func(entry):
		return str((entry as Dictionary).get("target", "")) == str(fixture.effect_path)
	)
	assert_eq(retained.size(), 1, str(result.cleanup))
	if retained.size() == 1:
		var previous_path := str((retained[0] as Dictionary).get("path", ""))
		assert_true(FileAccess.file_exists(previous_path), previous_path)
		assert_eq(FileAccess.get_sha256(previous_path), original_hash)


func test_29l_opening_rejects_an_external_unit_effect_reference_change() -> void:
	var fixture := _terrain_type_fixture("reference_change")
	var source := fixture.source as ArenaTerrainDefinition
	var options := _terrain_type_test_options(str(fixture.root))
	var other_effect_path := str(fixture.root).path_join("other_effect.tres")
	var other_effect := _terrain_effect_copy(source.unit_effect)
	other_effect.damage += 1
	assert_eq(ResourceSaver.save(other_effect, other_effect_path), OK)
	var stored_other := ResourceLoader.load(
		other_effect_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as TerrainEffectData
	var changed_terrain := source.duplicate(true) as ArenaTerrainDefinition
	changed_terrain.unit_effect = stored_other
	assert_eq(ResourceSaver.save(changed_terrain, str(fixture.terrain_path)), OK)
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	assert_false(bool(opening.get("ok", true)), str(opening))
	assert_string_contains(str(opening.get("message", "")), "differe")


func test_29m_legacy_uidless_resources_can_be_saved_transactionally() -> void:
	var fixture := _terrain_type_fixture("legacy_uidless")
	_strip_resource_uid(str(fixture.terrain_path))
	_strip_resource_uid(str(fixture.effect_path))
	# Le registre global peut conserver une entrée de cache pour un chemin
	# user:// ; l'autorité historique à tester est bien l'en-tête sur disque.
	assert_false(FileAccess.get_file_as_string(
		str(fixture.terrain_path)
	).get_slice("\n", 0).contains(' uid="'))
	assert_false(FileAccess.get_file_as_string(
		str(fixture.effect_path)
	).get_slice("\n", 0).contains(' uid="'))
	var source := ResourceLoader.load(
		str(fixture.terrain_path), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	var working := TerrainTypeSaveTransaction.create_working_copy(source)
	var options := _terrain_type_test_options(str(fixture.root))
	var opening := TerrainTypeSaveTransaction.capture_opening_state(source, options)
	assert_true(bool(opening.get("ok", false)), str(opening))
	working.movement_cost += 1
	working.unit_effect.damage += 1
	var saved := TerrainTypeSaveTransaction.save(
		source, working, opening, options
	)
	assert_true(bool(saved.get("ok", false)), str(saved))
	assert_true(FileAccess.file_exists(str(fixture.terrain_path)))
	assert_true(FileAccess.file_exists(str(fixture.effect_path)))


func test_29e_editor_status_uses_context_line_without_reserving_bottom_height() -> void:
	var studio := _studio()
	_open_forest(studio)
	await wait_process_frames(1)
	assert_false(studio.status_label.visible)
	assert_eq(studio.status_label.get_combined_minimum_size().y, 28.0)
	studio._set_status("Indication contextuelle")
	assert_false(studio.status_label.visible)
	assert_eq(studio.active_tool_label.text, "Indication contextuelle")
	studio._set_status("Erreur importante", true)
	assert_true(studio.bottom_drawer_content.visible)
	assert_true(studio.validation_panel.external_error_label.visible)
	assert_string_contains(studio.validation_panel.external_error_label.text, "Erreur importante")


func test_30_validation_test_and_integration_stay_reachable_without_a_finalize_step() -> void:
	var studio := _studio()
	_open_forest(studio)
	studio.show_editor()
	_size_studio(studio, 1600, 900)
	studio.set_current_step(TerrainWorkflowService.Step.FLOORS)
	await wait_process_frames(1)
	assert_not_null(studio.header_bar.validation_button)
	assert_not_null(studio.header_bar.test_button)
	assert_not_null(studio.header_bar.integrate_button)
	assert_true(studio.header_bar.validation_button.is_visible_in_tree())
	studio.set_current_step(TerrainWorkflowService.Step.FINALIZE)
	await wait_process_frames(1)
	assert_true(studio.header_bar.validation_button.is_visible_in_tree())
	assert_true(studio.header_bar.test_button.is_visible_in_tree())
	assert_true(studio.header_bar.integrate_button.is_visible_in_tree())


func test_31_panel_state_is_persisted_outside_business_resources() -> void:
	assert_true(TerrainStudioUiStateService.STATE_PATH.begins_with("user://"))
	var state := TerrainStudioUiStateService.default_state()
	assert_false(bool(state.inspector_visible))
	for key in state:
		assert_false(
			state[key] is Resource,
			"L'état d'interface ne doit sérialiser aucune Resource métier."
		)
	var studio := _studio()
	_open_forest(studio)
	await wait_process_frames(1)
	studio.set_guided(false)
	studio.set_current_step(TerrainWorkflowService.Step.VERIFY)
	var snapshot := studio.get_workspace_state()
	assert_false(bool(snapshot.guided))
	assert_eq(int(snapshot.step), TerrainWorkflowService.Step.VERIFY)
	assert_true(snapshot.has("guidance_visible"))
	assert_true(snapshot.has("checklist_collapsed"))
	assert_true(snapshot.has("library"))
	assert_true(snapshot.has("library_height"))


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


func _terrain_type_fixture(label: String, with_effect := true) -> Dictionary:
	var root := TERRAIN_TYPE_TEST_ROOT.path_join(
		"%s_%d" % [label, Time.get_ticks_usec()]
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(root)
	), OK)
	var effect_path := root.path_join("effect.tres")
	var stored_effect: TerrainEffectData = null
	if with_effect:
		var effect := TerrainEffectData.new()
		effect.effect_name = "Effet de test"
		effect.surface_id = &"test_surface"
		effect.visual_terrain_id = &"test_terrain"
		effect.trigger = TerrainEffectData.Trigger.ON_ENTER
		effect.damage = 3
		effect.duration = 2
		assert_eq(ResourceSaver.save(effect, effect_path), OK)
		_ensure_test_resource_uid(effect_path)
		stored_effect = ResourceLoader.load(
			effect_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as TerrainEffectData
		assert_not_null(stored_effect)
	var terrain_path := root.path_join("terrain.tres")
	var terrain := ArenaTerrainDefinition.new()
	terrain.stable_id = &"test_terrain"
	terrain.display_name = "Terrain de test"
	terrain.unit_effect = stored_effect
	terrain.apply_on_enter = with_effect
	terrain.ai_danger_weight = 3.0
	assert_eq(ResourceSaver.save(terrain, terrain_path), OK)
	_ensure_test_resource_uid(terrain_path)
	var source := ResourceLoader.load(
		terrain_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	assert_not_null(source)
	return {
		"root": root,
		"terrain_path": terrain_path,
		"effect_path": effect_path,
		"derived_effect_path": terrain_path.get_basename() + "_effect.tres",
		"source": source,
	}


func _terrain_type_working_copy(
		source: ArenaTerrainDefinition
	) -> ArenaTerrainDefinition:
	var working := source.duplicate(true) as ArenaTerrainDefinition
	assert_not_null(working)
	working.set_path_cache("")
	working.unit_effect = _terrain_effect_copy(source.unit_effect) \
		if source.unit_effect != null else TerrainEffectData.new()
	return working


func _terrain_effect_copy(source: TerrainEffectData) -> TerrainEffectData:
	var copy := TerrainEffectData.new()
	for property_value in source.get_property_list():
		var property := property_value as Dictionary
		var property_name := str(property.get("name", ""))
		if property_name in [
			"resource_local_to_scene", "resource_name", "resource_path", "script",
		] or not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
			continue
		copy.set(property_name, source.get(property_name))
	return copy


func _terrain_type_test_options(root: String) -> Dictionary:
	return {
		"allowed_roots": PackedStringArray([root]),
		"transaction_root": root.path_join("transactions"),
		"working_recovery_root": root.path_join("working_recovery"),
	}


func _strip_resource_uid(path: String) -> void:
	var contents := FileAccess.get_file_as_string(path)
	var header := contents.get_slice("\n", 0)
	var marker := ' uid="'
	var marker_index := header.find(marker)
	# Selon la version de Godot, set_uid() sous user:// peut ne renseigner que le
	# registre en mémoire. Dans ce cas la fixture est déjà réellement historique.
	if marker_index < 0:
		return
	var value_start := marker_index + marker.length()
	var value_end := header.find('"', value_start)
	if value_end <= value_start:
		return
	var uid_text := header.substr(value_start, value_end - value_start)
	var uid := ResourceUID.text_to_id(uid_text)
	var uid_attribute := ' uid="%s"' % uid_text
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(contents.replace(uid_attribute, ""))
	file.flush()
	file.close()
	if uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid):
		ResourceUID.remove_id(uid)


func _ensure_test_resource_uid(path: String) -> void:
	var uid := ResourceUID.create_id()
	assert_ne(uid, ResourceUID.INVALID_ID)
	assert_eq(ResourceSaver.set_uid(path, uid), OK)
	if _serialized_resource_uid(path) != uid:
		_write_test_resource_uid(path, uid)
	if ResourceUID.has_id(uid):
		ResourceUID.set_id(uid, path)
	else:
		ResourceUID.add_id(uid, path)
	assert_eq(_serialized_resource_uid(path), uid)
	assert_eq(ResourceLoader.get_resource_uid(path), uid)


func _serialized_resource_uid(path: String) -> int:
	if not FileAccess.file_exists(path):
		return ResourceUID.INVALID_ID
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ResourceUID.INVALID_ID
	var header := file.get_line()
	file.close()
	var marker := " uid=\""
	var marker_index := header.find(marker)
	if marker_index < 0:
		return ResourceUID.INVALID_ID
	var value_start := marker_index + marker.length()
	var value_end := header.find("\"", value_start)
	if value_end <= value_start:
		return ResourceUID.INVALID_ID
	return ResourceUID.text_to_id(header.substr(
		value_start, value_end - value_start
	))


func _write_test_resource_uid(path: String, uid: int) -> void:
	var uid_text := ResourceUID.id_to_text(uid)
	var contents := FileAccess.get_file_as_string(path)
	var line_end := contents.find("\n")
	assert_gt(line_end, 0, path)
	var header := contents.substr(0, line_end)
	assert_true(header.trim_suffix("\r").begins_with("[gd_resource"), path)
	var marker := " uid=\""
	var marker_index := header.find(marker)
	if marker_index >= 0:
		var value_start := marker_index + marker.length()
		var value_end := header.find("\"", value_start)
		assert_gt(value_end, value_start, path)
		header = header.substr(0, value_start) + uid_text + header.substr(value_end)
	else:
		var bracket_index := header.rfind("]")
		assert_gt(bracket_index, 0, path)
		header = header.insert(bracket_index, " uid=\"%s\"" % uid_text)
	var rewritten := header + contents.substr(line_end)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(rewritten)
	file.flush()
	file.close()
	assert_eq(FileAccess.get_file_as_string(path), rewritten)


func _remove_user_tree(path: String) -> bool:
	if path != TERRAIN_TYPE_TEST_ROOT \
			and not path.begins_with(TERRAIN_TYPE_TEST_ROOT + "/"):
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return true
	for child_directory in directory.get_directories():
		_remove_user_tree(path.path_join(child_directory))
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	return DirAccess.remove_absolute(absolute) == OK
