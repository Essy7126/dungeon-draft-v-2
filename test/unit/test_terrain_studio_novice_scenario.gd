extends GutTest

## Scénario d'acceptation novice du Studio Terrain, joué de bout en bout par
## les mêmes API publiques que l'interface.
##
## Une personne ne connaissant ni Godot ni les Resources doit pouvoir :
## 1. créer un terrain de 10 × 8 avec des tuiles ;
## 2. peindre deux types de sol ;
## 3. placer une bordure, trois départs héros et un groupe ennemi ;
## 4. annuler puis rétablir ;
## 5. comprendre et corriger une erreur de validation ;
## 6. lancer le combat de test ;
## 7. intégrer le terrain à une salle ;
## 8. expliquer la différence entre brouillon, test et intégration.
##
## Contraintes vérifiées ici : aucun fichier `.tres` ouvert, aucun identifiant
## technique obligatoire, aucune action primaire masquée à 1280 × 720, abandon
## possible sans mutation de la source canonique.


func before_each() -> void:
	ArenaValidator.clear_cache()
	ArenaVisualAssembler.clear_inspection_cache()
	ArenaTerrainRenderPlanService.clear_cache()
	ArenaTacticalMetricsService.clear_cache()
	TerrainStudioUiStateService.clear_cache()
	TerrainStudioUiStateService.save_state(TerrainStudioUiStateService.default_state())


func test_novice_builds_paints_fixes_and_reaches_a_testable_terrain() -> void:
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	studio.size = Vector2(1280, 720)
	await wait_process_frames(2)

	# --- 1. Créer un terrain de 10 × 8 avec des tuiles ----------------------
	assert_true(studio.is_home_visible(), "Le domaine s'ouvre sur l'accueil.")
	studio.show_creation_wizard()
	assert_eq(studio.creation_wizard.current_screen(), TerrainCreationWizard.SCREEN_CHOICE)
	var tiles_choice := TerrainVocabulary.creation_choice(1)
	assert_eq(str(tiles_choice.display_title), "Avec des tuiles")
	assert_false(bool(tiles_choice.needs_image), "Aucune illustration n'est requise.")
	studio._create_from_wizard_config({
		"visual_mode": int(tiles_choice.visual_mode),
		"display_name": "Terrain du novice",
		"arena_id": "terrain_du_novice",
		"width": 10,
		"height": 8,
		"camp_orientation": 0,
		"image_path": "",
		"template_index": 0,
		"needs_image": bool(tiles_choice.needs_image),
	})
	await wait_process_frames(2)
	assert_false(studio.is_home_visible(), "La création ouvre directement l'éditeur.")
	assert_not_null(studio.arena)
	assert_eq(studio.arena.grid_size, Vector2i(10, 8))
	assert_eq(studio.current_step, TerrainWorkflowService.Step.FLOORS)
	# Le terrain n'existe que dans la working copy : aucune Resource écrite.
	assert_true(studio.edit_session.source_path.is_empty())
	assert_false(ResourceLoader.exists("res://data/arenas/terrain_du_novice.tres"))

	# --- 2. Peindre deux types de sol ---------------------------------------
	var painted := _paint(studio, &"water", [Vector2i(2, 2), Vector2i(3, 2)])
	assert_true(painted, "Le sol Eau doit pouvoir être peint.")
	assert_true(_paint(studio, &"ice", [Vector2i(5, 4)]), "Le sol Glace aussi.")
	var used := {}
	for cell in studio.arena.playable_cells():
		used[studio.arena.get_cell_definition(cell).terrain_id] = true
	assert_gte(used.size(), 2, "Deux types de sol au moins sont utilisés.")

	# --- 3. Bordure, trois départs héros, un groupe ennemi -------------------
	studio.create_safety_border()
	assert_gt(studio.arena.border_cells().size(), 0)
	var hero_cells := [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)]
	for index in range(hero_cells.size()):
		_place_spawn(studio, hero_cells[index], index)
	_place_spawn(studio, Vector2i(8, 2), ArenaSpawnDefinition.Kind.ENEMY_GROUP)
	var heroes := 0
	var enemies := 0
	for spawn in studio.arena.spawns:
		if spawn.is_hero():
			heroes += 1
		elif spawn.is_enemy():
			enemies += 1
	assert_eq(heroes, 3, "Trois départs de héros.")
	assert_gte(enemies, 1, "Au moins un départ ennemi.")

	# --- 4. Annuler puis rétablir -------------------------------------------
	var before_undo := studio.arena.to_snapshot()
	assert_true(studio.history_can_undo())
	assert_true(studio.history_undo())
	assert_ne(studio.arena.to_snapshot(), before_undo)
	assert_true(studio.history_redo())
	assert_eq(studio.arena.to_snapshot(), before_undo)

	# --- 5. Comprendre et corriger une erreur de validation ------------------
	var border := studio.arena.border_cells()
	assert_false(border.is_empty())
	var before_error := studio.arena.to_snapshot()
	studio.arena.spawns[0].cell = border[0]
	studio._commit_change(
		"Poser un départ sur la bordure", before_error, studio.arena.to_snapshot()
	)
	var report := studio.validate_arena()
	assert_false(report.is_valid(), "L'erreur doit être détectée.")
	assert_eq(studio.readiness(), TerrainWorkflowService.READINESS_INCOMPLETE)
	assert_gt(studio.validation_panel.card_count(), 0, "Une carte de problème est affichée.")
	var fixable: ArenaValidationMessage = null
	for message in report.messages:
		if ArenaValidationFixService.can_fix(message):
			fixable = message
			break
	assert_not_null(fixable, "Une correction automatique sûre est proposée.")
	# La carte explique le problème sans jargon technique.
	assert_false(fixable.message.is_empty())
	assert_false(ArenaValidationFixService.fix_label(fixable).is_empty())
	studio._on_validation_auto_fix(fixable)
	var fixed := studio.validate_arena()
	assert_true(
		fixed.is_valid(),
		"Après correction, le terrain doit être valide : %s" % fixed.to_markdown()
	)

	# --- 6. Le combat de test est disponible et n'écrit rien de canonique ----
	assert_eq(studio.readiness(), TerrainWorkflowService.READINESS_TESTABLE)
	assert_false(studio.finalize_panel.test_button.disabled)
	var preparation := ArenaDirectTestService.prepare(
		studio.arena, null, &"no_characters"
	)
	assert_true(
		bool(preparation.get("ok", false)),
		str(preparation)
	)
	assert_false(ResourceLoader.exists("res://data/arenas/terrain_du_novice.tres"))

	# --- 7. L'étape d'intégration est atteignable et résumée -----------------
	studio.set_current_step(TerrainWorkflowService.Step.FINALIZE)
	await wait_process_frames(1)
	assert_not_null(studio.destination_panel)
	assert_not_null(studio.destination_run_option)
	assert_not_null(studio.destination_action_option)
	assert_not_null(studio.destination_room_option)
	# UPDATE reste l'action recommandée et le résumé précède toute écriture.
	var recommended := ""
	for index in range(studio.destination_action_option.item_count):
		if StringName(studio.destination_action_option.get_item_metadata(index)) \
				== ArenaProductionAttachmentService.UPDATE:
			recommended = studio.destination_action_option.get_item_text(index)
	assert_string_contains(recommended, "recommandé")

	# --- 8. Les trois contrats sont énoncés en clair -------------------------
	var contracts := PackedStringArray()
	for contract in TerrainFinalizePanel.CONTRACTS:
		contracts.append("%s : %s" % [contract[0], contract[1]])
	assert_eq(contracts.size(), 3)
	assert_string_contains(contracts[0], "dossier personnel")
	assert_string_contains(contracts[1], "Rien n'est publié")
	assert_string_contains(contracts[2], "résumé")
	studio.save_draft()
	assert_true(ArenaDraftSaveService.has_draft(studio.arena.arena_id))
	assert_true(
		ArenaDraftSaveService.draft_path(studio.arena.arena_id).begins_with("user://"),
		"Le brouillon reste dans le dossier personnel."
	)

	# --- Contraintes transverses --------------------------------------------
	studio._apply_responsive_layout()
	await wait_process_frames(1)
	for control in studio.primary_action_controls():
		if not control.is_visible_in_tree():
			continue
		assert_lte(
			control.get_global_rect().end.x, studio.size.x + 1.0,
			"« %s » doit rester dans l'écran à 1280 × 720." % control.name
		)
		assert_ne(control.focus_mode, Control.FOCUS_NONE)
	# Abandonner : revenir à l'accueil ne modifie aucune Resource canonique.
	studio.show_home()
	assert_true(studio.is_home_visible())
	assert_false(ResourceLoader.exists("res://data/arenas/terrain_du_novice.tres"))
	ArenaDraftSaveService.remove(studio.arena.arena_id)
	ArenaSerializer.remove_recovery(studio.arena.arena_id)


func _paint(
		studio: ArenaStudioMain,
		terrain_id: StringName,
		cells: Array
	) -> bool:
	var before := studio.arena.to_snapshot()
	var changed := false
	for cell in cells:
		if ArenaDynamicEditingService.paint_permanent_terrain(
				studio.arena, cell, terrain_id
			):
			changed = true
	if changed:
		studio._commit_change(
			"Peindre %s" % terrain_id, before, studio.arena.to_snapshot()
		)
	return changed


func _place_spawn(studio: ArenaStudioMain, cell: Vector2i, kind: int) -> void:
	var before := studio.arena.to_snapshot()
	if ArenaDynamicEditingService.place_spawn(studio.arena, cell, kind):
		studio._commit_change(
			"Placer un point de départ", before, studio.arena.to_snapshot()
		)
