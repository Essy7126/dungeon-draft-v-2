extends GutTest

const ELF_PATH := "res://data/units/alliés/elfe.tres"


func _handle_known_production_uid_warning() -> void:
	for tracked_error in get_errors():
		if tracked_error.contains_text("frappe_lourde.tres") and tracked_error.contains_text("invalid UID"):
			tracked_error.handled = true


func test_catalog_discovers_playable_characters_without_a_hard_coded_list() -> void:
	# Ajouter un personnage ne doit plus demander de modifier le code : tout
	# UnitData d'équipe Joueur déposé dans un dossier d'alliés est découvert.
	var heroes := SkillTreeCatalogService.discover_heroes()
	_handle_known_production_uid_warning()
	var ids := heroes.map(func(entry: Dictionary): return str(entry.get("id", "")))
	for expected in ["achilles", "elf", "mage", "warrior"]:
		assert_has(ids, expected)
	assert_eq(ids.size(), heroes.size())
	for entry in heroes:
		assert_eq((entry.get("resource") as UnitData).team, 0, str(entry.get("id", "")))


func test_catalog_also_exposes_enemies_as_editable_units() -> void:
	var enemies := SkillTreeCatalogService.discover_enemies()
	_handle_known_production_uid_warning()
	assert_false(enemies.is_empty(), "aucun ennemi découvert")
	var ids := enemies.map(func(entry: Dictionary): return str(entry.get("id", "")))
	assert_has(ids, "skeleton_melee")
	for entry in enemies:
		assert_eq((entry.get("resource") as UnitData).team, 1, str(entry.get("id", "")))
		assert_true(bool(entry.get("is_enemy", false)), str(entry.get("id", "")))
	var units := SkillTreeCatalogService.discover_units()
	assert_eq(units.size(), SkillTreeCatalogService.discover_heroes().size() + enemies.size())
	var teams := {}
	for entry in units:
		teams[int(entry.get("team", -1))] = true
	assert_true(teams.has(0) and teams.has(1), "le catalogue mélange jouables et ennemis")


func test_working_copy_is_isolated_dirty_and_undoable() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	var original_health := source.max_hp
	assert_true(session.change_property(
		session.working_unit,
		&"max_hp",
		original_health + 7,
		"Tester les points de vie"
	))
	assert_eq(source.max_hp, original_health)
	assert_eq(session.working_unit.max_hp, original_health + 7)
	assert_true(session.is_dirty())
	assert_true(session.history_undo())
	assert_eq(session.working_unit.max_hp, original_health)
	assert_false(session.is_dirty())
	assert_true(session.history_redo())
	assert_eq(session.working_unit.max_hp, original_health + 7)


func test_production_tree_validation_paths_and_simulation_match_runtime() -> void:
	var hero := load(ELF_PATH) as UnitData
	var heroes := SkillTreeCatalogService.discover_heroes()
	_handle_known_production_uid_warning()
	var discipline := hero.disciplines[0] as DisciplineData
	var messages := SkillTreeEditorValidator.validate_unit(hero, true, heroes)
	var errors: Array[SkillTreeValidationMessage] = []
	for message in messages:
		if message.severity == SkillTreeValidationMessage.Severity.ERROR:
			errors.append(message)
	assert_eq(errors.size(), 0)
	assert_eq(SkillTreePathService.final_configurations(discipline).size(), 16)
	var simulation := SkillTreeSimulationService.simulate(discipline, 30)
	assert_true(simulation.get("ok", false))
	assert_eq(simulation.get("rank", 0), 5)
	assert_eq(simulation.get("pending_ranks", []), [2, 3, 4, 5])


func test_new_discipline_creates_its_base_spell_in_one_undoable_action() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	var discipline_count := session.working_unit.disciplines.size()
	var spell_count := session.working_unit.spells.size()
	var discipline := session.add_discipline("Alchimie", &"elf_alchemy")
	assert_not_null(discipline)
	assert_eq(session.working_unit.disciplines.size(), discipline_count + 1)
	assert_eq(session.working_unit.spells.size(), spell_count + 1)
	assert_not_null(session.current_spell())
	assert_same(session.current_spell().skill_tree, discipline)
	assert_true(session.history_undo())
	assert_eq(session.working_unit.disciplines.size(), discipline_count)
	assert_eq(session.working_unit.spells.size(), spell_count)


func test_save_plan_is_empty_on_open_and_preserves_external_archer_files() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(SkillTreeSaveService._save_plan(session).is_empty())
	assert_true(session.select_discipline(&"archer"))
	var node := session.all_nodes()[0]
	var node_path := (session.work_to_source[node] as Resource).resource_path
	assert_true(session.change_property(
		node, &"display_name", node.display_name + " test", "Modifier un nœud externe"
	))
	var paths := SkillTreeSaveService._save_plan(session).map(
		func(entry: Dictionary): return str(entry.get("path", ""))
	)
	assert_true(paths.has(node_path))
	assert_false(paths.has("res://data/characters/elf/disciplines/archer.tres"))


func test_save_plan_keeps_embedded_nodes_inside_their_discipline_file() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.select_discipline(&"assassin"))
	var node := session.all_nodes()[0]
	assert_true(session.change_property(
		node, &"description", node.description + " test", "Modifier un nœud embarqué"
	))
	var paths := SkillTreeSaveService._save_plan(session).map(
		func(entry: Dictionary): return str(entry.get("path", ""))
	)
	assert_true(paths.has("res://data/characters/elf/disciplines/assassin.tres"))
	assert_eq(paths.size(), 1)


func test_working_copy_round_trip_can_be_reloaded_without_touching_sources() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.change_property(
		session.working_unit, &"initiative", source.initiative + 3,
		"Modifier l’initiative"
	))
	var path := "user://skill_tree_studio_round_trip.tres"
	assert_eq(ResourceSaver.save(session.working_unit, path), OK)
	var reloaded := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	assert_not_null(reloaded)
	assert_eq(reloaded.initiative, source.initiative + 3)
	assert_eq(reloaded.disciplines.size(), source.disciplines.size())
	assert_eq(source.initiative + 3, session.working_unit.initiative)
	assert_eq(source.initiative, (load(ELF_PATH) as UnitData).initiative)
	var recovery := SkillTreeSaveService._recovery_copy(session.working_unit)
	assert_not_null(recovery)
	assert_true(recovery.resource_path.is_empty())
	assert_true(recovery.disciplines[0].resource_path.is_empty())
	assert_true(recovery.disciplines[0].ranks[0].resource_path.is_empty())
	assert_eq(ResourceSaver.save(
		recovery, "user://skill_tree_studio_recovery_round_trip.tres"
	), OK)


func test_branch_creation_and_symmetric_exclusion_are_atomic() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.select_discipline(&"assassin"))
	var before := session.all_nodes().size()
	var branch := session.add_linear_branch("Voie de test", 2)
	assert_eq(branch.size(), 4)
	assert_eq(session.all_nodes().size(), before + 4)
	for index in range(1, branch.size()):
		assert_true((branch[index] as SkillTreeNodeData).prerequisite_node_ids.has(
			branch[index - 1].upgrade_id
		))
	var first := branch[0] as SkillTreeNodeData
	var second := branch[1] as SkillTreeNodeData
	assert_true(session.set_exclusion(first, second, true, true))
	assert_true(first.excluded_node_ids.has(second.upgrade_id))
	assert_true(second.excluded_node_ids.has(first.upgrade_id))
	assert_true(session.history_undo())
	assert_false(first.excluded_node_ids.has(second.upgrade_id))
	assert_true(session.history_undo())
	assert_eq(session.all_nodes().size(), before)


func test_duplicate_external_discipline_is_independent_and_has_its_own_spell() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	assert_true(session.select_discipline(&"archer"))
	var original := session.current_discipline()
	var original_node_id := session.all_nodes()[0].upgrade_id
	var copy := session.duplicate_current_discipline()
	assert_not_null(copy)
	assert_ne(copy, original)
	assert_ne(copy.ranks[1], original.ranks[1])
	assert_ne(copy.ranks[1].choices[0], original.ranks[1].choices[0])
	assert_ne(copy.ranks[1].choices[0].upgrade_id, original_node_id)
	assert_not_null(session.current_spell())
	assert_same(session.current_spell().skill_tree, copy)
	assert_ne(
		session.current_spell().get_effective_spell_id(),
		SkillTreeCatalogService.spell_for_discipline(session.working_unit, &"archer").get_effective_spell_id()
	)


func test_interface_builds_and_loads_a_real_character() -> void:
	var studio := SkillTreeStudioMain.new()
	studio.setup(null, null)
	add_child(studio)
	for _frame in range(12):
		await get_tree().process_frame
	_handle_known_production_uid_warning()
	assert_true(studio.heroes.size() >= 3, "catalogue : %d personnage(s)" % studio.heroes.size())
	assert_not_null(studio.session.working_unit)
	# Le Studio rouvre le dernier personnage utilisé, qui dépend de l'état
	# enregistré dans user://. On en choisit un explicitement pour que le test
	# ne dépende pas de la machine sur laquelle il tourne.
	studio._choose_character(ELF_PATH)
	for _frame in range(8):
		await get_tree().process_frame
	# L'elfe possede plusieurs profils officiels : le Studio exige désormais
	# un choix explicite hors contexte de partie au lieu d'en prendre un au
	# hasard. Ce test choisit volontairement la première autorité proposée.
	if studio.authority_dialog.visible:
		studio._open_selected_authority()
		studio.authority_dialog.hide()
		for _frame in range(4):
			await get_tree().process_frame
	assert_eq(studio.session.working_unit.get_effective_unit_id(), &"elf")
	assert_eq(studio.current_screen, studio.SCREEN_CHARACTER)
	assert_true(studio.character_screen.visible)
	assert_null(studio.skills_screen_button)
	assert_eq(studio.character_screen._unit, studio.session.working_unit)
	assert_not_null(studio.session.current_discipline())
	assert_not_null(studio.catalog)
	assert_not_null(studio.graph)
	assert_not_null(studio.inspector)
	assert_not_null(studio.bottom)
	assert_gt(
		studio.graph.get_children().filter(func(child): return child is GraphNode).size(),
		1
	)
	var spell := studio.session.current_spell()
	assert_not_null(spell)
	studio._open_spell_tree(spell.get_skill_tree_id())
	assert_eq(studio.current_screen, studio.SCREEN_SKILLS)
	assert_true(studio.skills_screen.visible)
	assert_false(studio.character_screen.visible)
	assert_false(
		studio.inspector.visible,
		"L’éditeur du sort ne doit pas être dupliqué à droite de l’arbre."
	)
	var tree_nodes := studio.session.all_nodes()
	assert_false(tree_nodes.is_empty())
	studio.session.select_subject(tree_nodes[0])
	assert_true(
		studio.inspector.visible,
		"L’inspecteur reste nécessaire pour modifier une amélioration de l’arbre."
	)
	assert_true(studio.return_to_spell_button.visible)
	studio._return_to_spell()
	assert_eq(studio.current_screen, studio.SCREEN_CHARACTER)
	assert_true(studio.character_screen.visible)
	assert_eq(studio.character_screen._selected_spell, spell)
	var original_team := studio.session.working_unit.team
	studio._request_team_change(studio.session.working_unit, 1 - original_team)
	assert_true(studio._pending_confirm_action.is_valid())
	studio._pending_confirm_action.call()
	assert_eq(studio.session.working_unit.team, 1 - original_team)
	assert_eq(studio.session.source_unit.team, original_team)
	assert_true(studio.session.history_undo())
	assert_eq(studio.session.working_unit.team, original_team)
	for _frame in range(2):
		await get_tree().process_frame
	studio.dispose_document()
	studio.free()
	for _frame in range(2):
		await get_tree().process_frame


func test_character_sheet_emits_edits_without_mutating_the_working_copy() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	assert_not_null(source)
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	var sheet := SkillTreeCharacterScreen.new()
	add_child(sheet)
	await get_tree().process_frame
	sheet.set_document(
		session.working_unit, ELF_PATH, [], true
	)
	var request := {}
	sheet.property_change_requested.connect(
		func(target: Object, property_name: StringName, value: Variant, action_name: String):
			request.merge({
				"target": target,
				"property": property_name,
				"value": value,
				"action": action_name,
			}, true)
	)
	var before := session.working_unit.max_hp
	sheet._emit_change(&"max_hp", before + 25, "Modifier PV maximum")
	assert_eq(session.working_unit.max_hp, before)
	assert_eq(request.get("target"), session.working_unit)
	assert_eq(request.get("property"), &"max_hp")
	assert_eq(request.get("value"), before + 25)
	assert_true(session.change_property(
		request.get("target") as Object,
		StringName(request.get("property", &"")),
		request.get("value"),
		str(request.get("action", ""))
	))
	assert_eq(session.working_unit.max_hp, before + 25)
	assert_eq(source.max_hp, before)
	assert_true(session.history_undo())
	assert_eq(session.working_unit.max_hp, before)
	session.release_document(false)
	sheet.free()
	request.clear()
	source = null
	session = null
	for _frame in range(2):
		await get_tree().process_frame


# --- Écran « Sorts » commun héros/ennemis et création autonome de sorts ---

const MAGE_PATH := "res://data/units/alliés/mage.tres"
const SHARED_ENEMY_SPELL_PATH := "res://data/spells/enemies/frost_lance.tres"


func _open_elf_session() -> SkillTreeEditSession:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	assert_not_null(source)
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	return session


func test_project_spell_catalog_covers_shared_and_character_folders() -> void:
	# Le sélecteur « Ajouter un sort existant » ne doit dépendre d'aucun
	# personnage ouvert : il balaie les deux emplacements légitimes.
	var entries := SkillTreeCatalogService.all_project_spells()
	_handle_known_production_uid_warning()
	assert_false(entries.is_empty())
	var paths: Array = entries.map(func(entry: Dictionary): return str(entry.get("path", "")))
	assert_has(paths, "res://data/spells/mur_de_glace.tres")
	assert_has(paths, "res://data/characters/elf/spells/precise_shot.tres")
	assert_eq(paths.size(), entries.size())
	for entry in entries:
		assert_true(entry.get("spell") is Spell, str(entry.get("path", "")))
		assert_ne(str(entry.get("spell_id", "")), "")


func test_spell_creation_attaches_to_the_character_and_uses_its_folder() -> void:
	var session := _open_elf_session()
	var before := session.working_unit.spells.size()
	var spell := session.create_spell(&"simple_attack", "Flèche rapide", true)
	assert_not_null(spell)
	assert_eq(session.working_unit.spells.size(), before + 1)
	assert_true(session.working_unit.spells.has(spell))
	assert_eq(
		str(session.new_resource_paths.get(spell, "")),
		"res://data/characters/elf/spells/fleche_rapide.tres"
	)
	assert_true(spell.can_target_enemy)
	# Un modèle n'invente aucune valeur d'équilibrage : elles restent à la
	# valeur par défaut de Spell, à décider par l'auteur.
	assert_eq(spell.damage, 0)
	assert_eq(spell.heal, 0)
	assert_true(session.is_dirty())
	assert_true(session.history_undo())
	assert_eq(session.working_unit.spells.size(), before)
	session.release_document(false)


func test_shared_spell_creation_stays_unattached_and_uses_the_shared_folder() -> void:
	var session := _open_elf_session()
	var before := session.working_unit.spells.size()
	var spell := session.create_spell(&"heal", "Souffle vital", false)
	assert_not_null(spell)
	assert_eq(session.working_unit.spells.size(), before)
	assert_false(session.working_unit.spells.has(spell))
	assert_true(session.standalone_spells.has(spell))
	assert_eq(
		str(session.new_resource_paths.get(spell, "")),
		"res://data/spells/souffle_vital.tres"
	)
	assert_true(spell.can_target_ally)
	assert_true(spell.can_target_self)
	assert_false(spell.can_target_enemy)
	# Sans ces deux garanties, le plan de sauvegarde déclarerait ce nouveau
	# fichier « non rattaché » et ne l'écrirait jamais.
	assert_true(session.is_dirty())
	assert_true(session.is_resource_reachable(spell))
	session.release_document(false)


func test_summon_template_only_preselects_its_resolution_mode() -> void:
	var session := _open_elf_session()
	var spell := session.create_spell(&"summon", "Appel des loups", true)
	assert_not_null(spell)
	assert_eq(spell.delayed_resolution, Spell.DelayedResolution.SUMMON)
	assert_true(spell.is_summon())
	assert_null(spell.summon_unit_data)
	assert_eq(spell.summon_max_living_team, 0)
	session.release_document(false)


func test_existing_spell_is_referenced_by_two_characters_without_duplication() -> void:
	var session := _open_elf_session()
	var shared := ResourceLoader.load(
		SHARED_ENEMY_SPELL_PATH, "", ResourceLoader.CACHE_MODE_REUSE
	) as Spell
	assert_not_null(shared)
	var before := session.working_unit.spells.size()
	assert_true(session.attach_existing_spell(shared))
	assert_eq(session.working_unit.spells.size(), before + 1)
	var attached := session.working_unit.spells.back() as Spell
	# Le Studio n'édite jamais une Resource source : la copie de travail garde
	# le chemin du fichier, donc un seul .tres continue de servir tout le monde.
	assert_ne(attached, shared)
	assert_eq(attached.resource_path, SHARED_ENEMY_SPELL_PATH)
	assert_eq(session.work_to_source.get(attached), shared)
	# Un second rattachement du même sort ne crée pas de doublon.
	assert_false(session.attach_existing_spell(shared))
	assert_eq(session.working_unit.spells.size(), before + 1)
	var mage_source := ResourceLoader.load(
		MAGE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	assert_not_null(mage_source)
	var second := SkillTreeEditSession.new()
	assert_true(second.open(mage_source))
	assert_true(second.attach_existing_spell(shared))
	var second_attached := second.working_unit.spells.back() as Spell
	assert_ne(second_attached, attached)
	assert_eq(second_attached.resource_path, attached.resource_path)
	assert_eq(second_attached.get_effective_spell_id(), attached.get_effective_spell_id())
	second.release_document(false)
	session.release_document(false)


func test_detaching_a_spell_removes_the_reference_and_keeps_the_file() -> void:
	var session := _open_elf_session()
	var shared := ResourceLoader.load(
		SHARED_ENEMY_SPELL_PATH, "", ResourceLoader.CACHE_MODE_REUSE
	) as Spell
	assert_true(session.attach_existing_spell(shared))
	var attached := session.working_unit.spells.back() as Spell
	var before := session.working_unit.spells.size()
	assert_true(session.detach_spell(attached))
	assert_eq(session.working_unit.spells.size(), before - 1)
	assert_false(session.working_unit.spells.has(attached))
	assert_true(
		FileAccess.file_exists(SHARED_ENEMY_SPELL_PATH),
		"un retrait est une perte de référence, jamais une suppression de fichier"
	)
	assert_true(session.history_undo())
	assert_eq(session.working_unit.spells.size(), before)
	session.release_document(false)


func test_spell_owning_a_tree_can_be_detached_without_deleting_resources() -> void:
	var session := _open_elf_session()
	var discipline := session.working_unit.disciplines[0] as DisciplineData
	assert_not_null(discipline)
	var base_spell := SkillTreeCatalogService.spell_for_discipline(
		session.working_unit, discipline.discipline_id
	)
	assert_not_null(base_spell)
	assert_eq(session.base_spell_discipline(base_spell), discipline)
	var before := session.working_unit.spells.size()
	assert_true(session.detach_spell(base_spell))
	assert_eq(session.working_unit.spells.size(), before - 1)
	assert_false(session.working_unit.spells.has(base_spell))
	assert_true(session.is_dirty())
	assert_true(FileAccess.file_exists(base_spell.resource_path))
	session.release_document(false)


func test_two_spells_named_alike_receive_distinct_identifiers_and_paths() -> void:
	var session := _open_elf_session()
	var first := session.create_spell(&"status", "Marque", true)
	var second := session.create_spell(&"status", "Marque", true)
	assert_not_null(first)
	assert_not_null(second)
	assert_eq(str(first.spell_id), "marque")
	assert_eq(str(second.spell_id), "marque_2")
	assert_ne(first.spell_id, second.spell_id)
	assert_ne(
		str(session.new_resource_paths.get(first, "")),
		str(session.new_resource_paths.get(second, ""))
	)
	session.release_document(false)


func test_spell_help_text_only_claims_a_discipline_root_when_there_is_one() -> void:
	# Un ennemi n'a aucune discipline, et un sort partagé sert à plusieurs
	# personnages : l'aide ne doit parler de racine d'arbre que quand c'en est une.
	var session := _open_elf_session()
	var panel := SkillTreeInspectorPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var discipline := session.working_unit.disciplines[0] as DisciplineData
	var base_spell := SkillTreeCatalogService.spell_for_discipline(
		session.working_unit, discipline.discipline_id
	)
	assert_not_null(base_spell)
	panel.set_context(
		session.working_unit, discipline, base_spell, base_spell, [], true
	)
	assert_string_contains(panel.help_label.text, "possède son arbre")
	var free_spell := session.create_spell(&"simple_attack", "Sort libre", true)
	assert_not_null(free_spell)
	panel.set_context(
		session.working_unit, discipline, base_spell, free_spell, [], true
	)
	assert_string_contains(panel.help_label.text, "Resource autonome")
	panel.free()
	session.release_document(false)
	for _frame in range(2):
		await get_tree().process_frame


func test_character_sheet_is_the_single_place_that_creates_and_attaches_spells() -> void:
	# Les boutons vivent dans l'onglet Sorts de la fiche personnage, pas dans un
	# écran racine séparé. La fiche n'agit jamais elle-même : elle émet.
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	var sheet := SkillTreeCharacterScreen.new()
	add_child(sheet)
	await get_tree().process_frame
	sheet.set_document(session.working_unit, ELF_PATH, [], true)
	await get_tree().process_frame
	var creations := []
	var attachments := []
	var detachments := []
	sheet.spell_creation_requested.connect(func() -> void: creations.append(true))
	sheet.existing_spell_requested.connect(func(spell): attachments.append(spell))
	sheet.spell_detach_requested.connect(func(spell): detachments.append(spell))
	var buttons := _sheet_buttons(sheet)
	assert_true(
		buttons.has("+ Nouveau sort"), "bouton de création absent de la fiche"
	)
	assert_true(
		buttons.has("+ Ajouter un sort existant"),
		"bouton de référencement absent de la fiche"
	)
	(buttons["+ Nouveau sort"] as Button).emit_signal("pressed")
	assert_eq(creations.size(), 1)
	# Le sort propriétaire peut être retiré : son arbre suit la référence et les
	# fichiers restent intacts sur le disque.
	var base_spell := SkillTreeCatalogService.spell_for_discipline(
		session.working_unit,
		(session.working_unit.disciplines[0] as DisciplineData).discipline_id
	)
	sheet.select_spell(base_spell)
	await get_tree().process_frame
	var remove := _sheet_buttons(sheet).get("Retirer de ce personnage") as Button
	assert_not_null(remove, "bouton de retrait absent de la fiche")
	assert_false(remove.disabled, "un sort propriétaire doit être retirable")
	assert_string_contains(remove.tooltip_text, "fichiers restent")
	remove.emit_signal("pressed")
	assert_eq(detachments, [base_spell])
	# Un sort ordinaire, lui, est retirable et la fiche se contente d'émettre.
	var shared := ResourceLoader.load(
		SHARED_ENEMY_SPELL_PATH, "", ResourceLoader.CACHE_MODE_REUSE
	) as Spell
	assert_true(session.attach_existing_spell(shared))
	var attached := session.working_unit.spells.back() as Spell
	sheet.set_document(session.working_unit, ELF_PATH, [], true)
	sheet.select_spell(attached)
	await get_tree().process_frame
	var free_remove := _sheet_buttons(sheet).get("Retirer de ce personnage") as Button
	assert_false(free_remove.disabled, "un sort ordinaire doit rester retirable")
	free_remove.emit_signal("pressed")
	assert_eq(detachments.size(), 2)
	assert_eq(detachments[1], attached)
	assert_eq(session.working_unit.spells.size(), 5)
	sheet.free()
	session.release_document(false)
	for _frame in range(2):
		await get_tree().process_frame


func test_shared_spell_created_in_session_stays_visible_and_adoptable() -> void:
	var source := ResourceLoader.load(
		ELF_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData
	var session := SkillTreeEditSession.new()
	assert_true(session.open(source))
	var spell := session.create_spell(&"heal", "Souffle partage", false)
	assert_not_null(spell)
	var sheet := SkillTreeCharacterScreen.new()
	add_child(sheet)
	await get_tree().process_frame
	sheet.set_document(
		session.working_unit, ELF_PATH, [], true, session.standalone_spells
	)
	await get_tree().process_frame
	var adopt := _sheet_buttons(sheet).get("Ajouter à ce personnage") as Button
	assert_not_null(
		adopt,
		"un sort partagé créé dans la session doit rester visible et rattachable"
	)
	var attachments := []
	sheet.existing_spell_requested.connect(func(value): attachments.append(value))
	adopt.emit_signal("pressed")
	assert_eq(attachments.size(), 1)
	assert_eq(attachments[0], spell)
	sheet.free()
	session.release_document(false)
	for _frame in range(2):
		await get_tree().process_frame


func _sheet_buttons(sheet: SkillTreeCharacterScreen) -> Dictionary:
	var result := {}
	for node in sheet.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and not result.has(button.text):
			result[button.text] = button
	return result
