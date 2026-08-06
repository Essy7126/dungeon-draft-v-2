extends GutTest

const MAIN_RUN_PATH := "res://data/runs/first_run.tres"
const TEST_RUN_PATH := "res://data/runs/fixed_trio_prototype_run.tres"
const HUB_DATA_PATH := "res://hub/data/lanternbound_archivist.tres"
const EXPECTED_IDS: Array[StringName] = [&"elf", &"mage", &"warrior"]
const GameManagerScript = preload("res://core/game_manager.gd")
const TEMP_ROOT := "user://run_content_isolation_tests"

var main_run: RunData
var test_run: RunData
var temporary_files := PackedStringArray()


func before_all() -> void:
	main_run = load(MAIN_RUN_PATH) as RunData
	test_run = load(TEST_RUN_PATH) as RunData
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func after_all() -> void:
	for path in temporary_files:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func test_official_runs_own_distinct_valid_content_profiles() -> void:
	assert_not_null(main_run)
	assert_not_null(test_run)
	assert_not_null(main_run.content_profile)
	assert_not_null(test_run.content_profile)
	assert_not_same(main_run.content_profile, test_run.content_profile)
	assert_ne(main_run.content_profile.resource_path, test_run.content_profile.resource_path)
	assert_eq(main_run.content_profile.profile_id, &"main")
	assert_eq(test_run.content_profile.profile_id, &"test")
	assert_true(main_run.content_validation_errors(true).is_empty())
	assert_true(test_run.content_validation_errors(true).is_empty())
	assert_eq(_hero_ids(main_run), EXPECTED_IDS)
	assert_eq(_hero_ids(test_run), EXPECTED_IDS)


func test_official_runs_share_only_base_units_and_whitelisted_assets() -> void:
	var audit := RunContentIsolationAuditService.compare_runs(main_run, test_run)
	assert_eq(audit.get("verdict"), "VALID")
	assert_eq(audit.get("progression_shared_count"), 0)
	assert_true((audit.get("shared_progression") as Array).is_empty())
	assert_eq((audit.get("shared_base_unit_data") as Array).size(), 3)
	assert_gt((audit.get("shared_visual_assets") as Array).size(), 0)
	for index in range(3):
		assert_same(
			main_run.content_profile.hero_profiles[index].base_unit_data,
			test_run.content_profile.hero_profiles[index].base_unit_data,
		)
		var main_profile := main_run.content_profile.hero_profiles[index].progression_profile
		var test_profile := test_run.content_profile.hero_profiles[index].progression_profile
		assert_not_same(main_profile, test_profile)
		assert_ne(main_profile.resource_path, test_profile.resource_path)
		for shared_asset in RunProgressionCloneService.shared_assets(test_profile):
			assert_true(RunProgressionCloneService.is_shareable(shared_asset))


func test_official_graphs_keep_counts_ids_relations_and_different_paths() -> void:
	for index in range(3):
		var main_profile := main_run.content_profile.hero_profiles[index].progression_profile
		var test_profile := test_run.content_profile.hero_profiles[index].progression_profile
		assert_eq(_graph_contract(main_profile), _graph_contract(test_profile))
		var main_resources := RunProgressionCloneService.progression_resources(main_profile)
		var test_resources := RunProgressionCloneService.progression_resources(test_profile)
		assert_eq(main_resources.size(), test_resources.size())
		var main_paths := _resource_paths(main_resources)
		for test_resource in test_resources:
			assert_false(main_paths.has(test_resource.resource_path))
			assert_true(
				test_resource.resource_path.begins_with(test_profile.resource_path),
				"Chaque sous-ressource test appartient au profil test sauvegarde.",
			)


func test_clone_service_is_multipass_deterministic_and_idempotent() -> void:
	var source := main_run.content_profile.hero_profiles[0].progression_profile
	var first := RunProgressionCloneService.clone_profile(source, &"fixture")
	var second := RunProgressionCloneService.clone_profile(source, &"fixture")
	assert_true(first.is_valid())
	assert_true(second.is_valid())
	assert_eq(first.resources.size(), second.resources.size())
	assert_eq(first.source_to_clone.size(), first.resources.size())
	assert_eq(
		RunProgressionCloneService.semantic_fingerprint(first.profile),
		RunProgressionCloneService.semantic_fingerprint(second.profile),
	)
	assert_eq(
		RunProgressionCloneService.semantic_fingerprint(source),
		RunProgressionCloneService.semantic_fingerprint(first.profile),
	)
	for source_resource in first.source_to_clone:
		assert_not_same(source_resource, first.source_to_clone[source_resource])
	var cloned_again := RunProgressionCloneService.clone_profile(first.profile, &"fixture")
	assert_true(cloned_again.is_valid())
	assert_eq(cloned_again.resources.size(), first.resources.size())
	assert_eq(
		RunProgressionCloneService.semantic_fingerprint(cloned_again.profile),
		RunProgressionCloneService.semantic_fingerprint(first.profile),
	)
	assert_eq(_graph_contract(source), _graph_contract(first.profile))


func test_clone_service_saves_reloads_and_keeps_modifiers_independent() -> void:
	var source := main_run.content_profile.hero_profiles[0].progression_profile
	var source_before := RunProgressionCloneService.semantic_fingerprint(source)
	var result := RunProgressionCloneService.clone_profile(source, &"fixture")
	var source_modifier := _first_modifier(source)
	var clone_modifier := _first_modifier(result.profile)
	assert_not_null(source_modifier)
	assert_not_null(clone_modifier)
	assert_not_same(source_modifier, clone_modifier)
	var original_name := source_modifier.modifier_name
	clone_modifier.modifier_name += " [fixture clone]"
	assert_eq(source_modifier.modifier_name, original_name)
	var path := _temporary_path("clone_reload.tres")
	var save_report := RunProgressionCloneService.save_reload_and_compare(result, path)
	assert_true(save_report.get("ok", false))
	assert_not_null(save_report.get("reloaded"))
	assert_eq(
		RunProgressionCloneService.semantic_fingerprint(source),
		source_before,
	)
	assert_ne(save_report.get("after_fingerprint"), source_before)


func test_test_fixture_save_does_not_change_main_fingerprints() -> void:
	var main_before := _run_fingerprints(main_run)
	var source := test_run.content_profile.hero_profiles[0].progression_profile
	var result := RunProgressionCloneService.clone_profile(source, &"test_fixture")
	var modifier := _first_modifier(result.profile)
	assert_not_null(modifier)
	modifier.modifier_name += " [test reciprocal fixture]"
	var save_report := RunProgressionCloneService.save_reload_and_compare(
		result, _temporary_path("test_reciprocal.tres")
	)
	assert_true(save_report.get("ok", false))
	assert_ne(
		save_report.get("after_fingerprint"),
		RunProgressionCloneService.semantic_fingerprint(source),
	)
	assert_eq(_run_fingerprints(main_run), main_before)


func test_main_fixture_save_does_not_change_test_fingerprints() -> void:
	var test_before := _run_fingerprints(test_run)
	var source := main_run.content_profile.hero_profiles[0].progression_profile
	var result := RunProgressionCloneService.clone_profile(source, &"main_fixture")
	var node := _first_upgrade(result.profile)
	assert_not_null(node)
	node.description += " [main reciprocal fixture]"
	var save_report := RunProgressionCloneService.save_reload_and_compare(
		result, _temporary_path("main_reciprocal.tres")
	)
	assert_true(save_report.get("ok", false))
	assert_ne(
		save_report.get("after_fingerprint"),
		RunProgressionCloneService.semantic_fingerprint(source),
	)
	assert_eq(_run_fingerprints(test_run), test_before)


func test_resolver_uses_each_official_profile_without_canonical_mutation() -> void:
	var canonical_before := {
		"main": _run_fingerprints(main_run),
		"test": _run_fingerprints(test_run),
	}
	var main_result := RunHeroResolver.resolve_runtime_hero_data(main_run, false)
	var test_result := RunHeroResolver.resolve_runtime_hero_data(test_run, false)
	assert_true(main_result.is_valid())
	assert_true(test_result.is_valid())
	assert_false(main_result.used_legacy_fallback)
	assert_false(test_result.used_legacy_fallback)
	assert_eq(_unit_ids(main_result.heroes), EXPECTED_IDS)
	assert_eq(_unit_ids(test_result.heroes), EXPECTED_IDS)
	for index in range(3):
		var main_hero_profile := main_run.content_profile.hero_profiles[index]
		var test_hero_profile := test_run.content_profile.hero_profiles[index]
		var main_runtime := main_result.heroes[index]
		var test_runtime := test_result.heroes[index]
		assert_not_same(main_runtime, main_hero_profile.base_unit_data)
		assert_not_same(test_runtime, test_hero_profile.base_unit_data)
		assert_same(main_runtime.spells[0], main_hero_profile.progression_profile.spells[0])
		assert_same(test_runtime.spells[0], test_hero_profile.progression_profile.spells[0])
		assert_not_same(main_runtime.spells[0], test_runtime.spells[0])
		assert_eq(main_runtime.spells.size(), 4)
		assert_eq(test_runtime.spells.size(), 4)
		assert_eq(main_runtime.max_hp, main_hero_profile.base_unit_data.max_hp)
		assert_eq(main_runtime.team, main_hero_profile.base_unit_data.team)
		assert_same(main_runtime.visual_scene, main_hero_profile.base_unit_data.visual_scene)
	assert_eq(_run_fingerprints(main_run), canonical_before.main)
	assert_eq(_run_fingerprints(test_run), canonical_before.test)


func test_profile_driven_fixture_reaches_test_runtime_only() -> void:
	var fixture_copy := RunProgressionCloneService.clone_profile(
		test_run.content_profile.hero_profiles[0].progression_profile, &"runtime_fixture"
	)
	assert_true(fixture_copy.is_valid())
	var marker := "[RUN CONTENT TEST FIXTURE]"
	fixture_copy.profile.spells[0].description += marker
	var fixture_content := RunContentProfile.new()
	fixture_content.profile_id = &"runtime_fixture"
	fixture_content.display_name = "Runtime fixture"
	for index in range(3):
		var source_hero := test_run.content_profile.hero_profiles[index]
		var hero := RunHeroProfile.new()
		hero.character_id = source_hero.character_id
		hero.base_unit_data = source_hero.base_unit_data
		hero.progression_profile = fixture_copy.profile if index == 0 else source_hero.progression_profile
		fixture_content.hero_profiles.append(hero)
	var fixture_run := test_run.duplicate(false) as RunData
	fixture_run.content_profile = fixture_content
	var fixture_result := RunHeroResolver.resolve_runtime_hero_data(fixture_run, false)
	var main_result := RunHeroResolver.resolve_runtime_hero_data(main_run, false)
	assert_true(fixture_result.is_valid())
	assert_true(fixture_result.heroes[0].spells[0].description.contains(marker))
	assert_false(main_result.heroes[0].spells[0].description.contains(marker))


func test_hub_runs_resolve_their_own_profiles() -> void:
	var hub_data := load(HUB_DATA_PATH) as LanternboundArchivistData
	assert_not_null(hub_data)
	assert_eq(hub_data.available_runs.size(), 2)
	for available_run in hub_data.available_runs:
		var result := RunHeroResolver.resolve_runtime_hero_data(available_run, false)
		assert_true(result.is_valid())
		assert_same(result.hero_profiles[0].progression_profile, available_run.content_profile.hero_profiles[0].progression_profile)
	assert_not_same(
		hub_data.available_runs[0].content_profile,
		hub_data.available_runs[1].content_profile,
	)


func test_explicit_game_manager_injection_remains_prioritary() -> void:
	var manager = GameManagerScript.new()
	manager._ready()
	var explicit := main_run.content_profile.hero_profiles[0].base_unit_data.duplicate(false) as UnitData
	explicit.set_path_cache("")
	explicit.unit_id = &"explicit_fixture"
	explicit.unit_name = "Explicit Fixture"
	var fixture_run := RunData.new()
	fixture_run.run_name = "Injection fixture"
	fixture_run.rooms.append(RoomData.new())
	manager.start_preconfigured_run(fixture_run, [explicit])
	assert_eq(manager.heroes.size(), 1)
	assert_eq(manager.heroes[0].unit_id, &"explicit_fixture")
	assert_eq(manager.heroes[0].unit_name, "Explicit Fixture")
	assert_false(
		manager.start_direct_encounter_test(fixture_run, [explicit]),
		"L'API directe utilise la source explicite puis refuse seulement la salle sans battle_scene.",
	)
	manager.cleanup_run_state()
	manager._exit_tree()
	manager.free()


func test_legacy_run_fallback_is_explicit_and_official_runs_do_not_use_it() -> void:
	var legacy := RunData.new()
	legacy.run_name = "Legacy"
	var legacy_result := RunHeroResolver.resolve_runtime_hero_data(legacy, true)
	assert_true(legacy_result.is_valid())
	assert_true(legacy_result.used_legacy_fallback)
	assert_eq(legacy_result.heroes.size(), 3)
	assert_eq(legacy_result.warnings.size(), 1)
	assert_false(RunHeroResolver.resolve_runtime_hero_data(legacy, false).is_valid())
	assert_false(RunHeroResolver.resolve_runtime_hero_data(main_run, false).used_legacy_fallback)
	assert_false(RunHeroResolver.resolve_runtime_hero_data(test_run, false).used_legacy_fallback)


func test_skill_tree_session_can_edit_a_profile_view_without_touching_source() -> void:
	var hero := test_run.content_profile.hero_profiles[0]
	var source_before := RunProgressionCloneService.semantic_fingerprint(hero.progression_profile)
	var view := RunContentCatalogService.as_editable_unit_view(
		hero.base_unit_data, hero.progression_profile
	)
	assert_not_null(view)
	assert_not_same(view, hero.base_unit_data)
	var session := SkillTreeEditSession.new()
	assert_true(session.open(view))
	assert_not_null(session.working_unit)
	session.working_unit.spells[0].description += " [studio fixture]"
	assert_eq(
		RunProgressionCloneService.semantic_fingerprint(hero.progression_profile),
		source_before,
	)


func test_catalog_discovers_usage_and_manifest_is_deterministic() -> void:
	var profile := main_run.content_profile.hero_profiles[0].progression_profile
	assert_same(
		RunContentCatalogService.progression_profile_for(main_run, &"elf"),
		profile,
	)
	assert_eq(RunContentCatalogService.heroes_for_run(main_run).size(), 3)
	assert_false(RunContentCatalogService.is_shared_between_runs(profile))
	assert_eq(RunContentCatalogService.usages_for_progression_profile(profile).size(), 1)
	var first := RunContentIsolationAuditService.deterministic_manifest(main_run)
	var second := RunContentIsolationAuditService.deterministic_manifest(main_run)
	assert_eq(JSON.stringify(first), JSON.stringify(second))
	assert_eq(first.get("verdict"), "VALID")


func _hero_ids(run_data: RunData) -> Array[StringName]:
	var ids: Array[StringName] = []
	for hero in run_data.content_profile.hero_profiles:
		ids.append(hero.character_id)
	return ids


func _unit_ids(units: Array[UnitData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for unit in units:
		ids.append(unit.get_effective_unit_id())
	return ids


func _run_fingerprints(run_data: RunData) -> Dictionary:
	var fingerprints := {}
	for hero in run_data.content_profile.hero_profiles:
		fingerprints[str(hero.character_id)] = (
			RunProgressionCloneService.semantic_fingerprint(hero.progression_profile)
		)
	return fingerprints


func _graph_contract(profile: CharacterProgressionProfile) -> Dictionary:
	var ranks: Array[int] = []
	var nodes: Array[String] = []
	var relations: Array[String] = []
	var modifier_count := 0
	for discipline in profile.disciplines:
		for rank_data in discipline.ranks:
			ranks.append(rank_data.rank)
			for node in rank_data.choices:
				nodes.append(str(node.upgrade_id))
				modifier_count += node.spell_modifiers.size()
				if node is SkillTreeNodeData:
					relations.append(JSON.stringify({
						"id": str(node.upgrade_id),
						"prerequisites": Array(node.prerequisite_node_ids),
						"exclusions": Array(node.excluded_node_ids),
					}))
	for spell in profile.spells:
		modifier_count += spell.modifiers.size()
	return {
		"character_id": str(profile.character_id),
		"active_spell_slots": profile.active_spell_slots,
		"spell_ids": profile.spells.map(func(spell: Spell): return str(spell.get_effective_spell_id())),
		"discipline_ids": profile.disciplines.map(func(discipline: DisciplineData): return str(discipline.discipline_id)),
		"ranks": ranks,
		"nodes": nodes,
		"relations": relations,
		"modifier_count": modifier_count,
	}


func _resource_paths(resources: Array[Resource]) -> Dictionary:
	var paths := {}
	for resource in resources:
		paths[resource.resource_path] = true
	return paths


func _first_modifier(profile: CharacterProgressionProfile) -> SpellModifier:
	for resource in RunProgressionCloneService.progression_resources(profile):
		if resource is SpellModifier:
			return resource as SpellModifier
	return null


func _first_upgrade(profile: CharacterProgressionProfile) -> SkillUpgradeData:
	for resource in RunProgressionCloneService.progression_resources(profile):
		if resource is SkillUpgradeData:
			return resource as SkillUpgradeData
	return null


func _temporary_path(file_name: String) -> String:
	var path := TEMP_ROOT.path_join(file_name)
	if not temporary_files.has(path):
		temporary_files.append(path)
	return path
