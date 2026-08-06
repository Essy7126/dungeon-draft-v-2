extends GutTest

const ELF_PATH := "res://data/units/alliés/elfe.tres"


func _handle_known_production_uid_warning() -> void:
	for tracked_error in get_errors():
		if tracked_error.contains_text("frappe_lourde.tres") and tracked_error.contains_text("invalid UID"):
			tracked_error.handled = true


func test_catalog_discovers_only_the_three_playable_characters() -> void:
	var heroes := SkillTreeCatalogService.discover_heroes()
	_handle_known_production_uid_warning()
	assert_eq(heroes.size(), 3)
	var ids := heroes.map(func(entry: Dictionary): return str(entry.get("id", "")))
	ids.sort()
	assert_eq(ids, ["elf", "mage", "warrior"])


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
	assert_eq(session.current_spell().discipline_id, &"elf_alchemy")
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
	assert_eq(session.current_spell().discipline_id, copy.discipline_id)
	assert_ne(
		session.current_spell().get_effective_spell_id(),
		SkillTreeCatalogService.spell_for_discipline(session.working_unit, &"archer").get_effective_spell_id()
	)


func test_interface_builds_and_loads_a_real_character() -> void:
	var studio := SkillTreeStudioMain.new()
	studio.setup(null, null)
	add_child_autofree(studio)
	for _frame in range(12):
		await get_tree().process_frame
	_handle_known_production_uid_warning()
	assert_eq(studio.heroes.size(), 3)
	assert_not_null(studio.session.working_unit)
	assert_not_null(studio.session.current_discipline())
	assert_not_null(studio.catalog)
	assert_not_null(studio.graph)
	assert_not_null(studio.inspector)
	assert_not_null(studio.bottom)
	assert_gt(
		studio.graph.get_children().filter(func(child): return child is GraphNode).size(),
		1
	)
